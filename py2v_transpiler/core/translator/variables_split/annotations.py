import ast
from typing import Any
from ..base import TranslatorBase
from py2v_transpiler.models.v_types import map_python_type_to_v


class AnnotationsMixin(TranslatorBase):
    """Обработка аннотированных присваиваний: visit_AnnAssign"""
    
    def _is_literal_string_expr(self, node: ast.AST) -> bool:
        """Checks if an expression is a literal string, literal concatenation, or f-string without variables."""
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return True
        if isinstance(node, ast.JoinedStr):
            return all(self._is_literal_string_expr(v) for v in node.values)
        if isinstance(node, ast.FormattedValue):
            return self._is_literal_string_expr(node.value)
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
            return self._is_literal_string_expr(node.left) and self._is_literal_string_expr(node.right)
        return False

    def _is_compile_time_evaluable(self, node: ast.AST) -> bool:
        """
        Checks if an AST node represents a value that can be evaluated at compile time in V.
        """
        if isinstance(node, ast.Constant):
            return True
        if isinstance(node, ast.Name):
            return node.id.isupper()
        if isinstance(node, ast.UnaryOp):
            return self._is_compile_time_evaluable(node.operand)
        if isinstance(node, ast.BinOp):
            return self._is_compile_time_evaluable(node.left) and self._is_compile_time_evaluable(node.right)
        if isinstance(node, (ast.List, ast.Tuple, ast.Set)):
            return all(self._is_compile_time_evaluable(elt) for elt in node.elts)
        if isinstance(node, ast.Dict):
            return all(self._is_compile_time_evaluable(k) for k in node.keys if k) and all(self._is_compile_time_evaluable(v) for v in node.values)
        return False

    def visit_AnnAssign(self, node: ast.AnnAssign) -> None:
        target = self.visit(node.target)
        if node.value:
            # Pre-allocated Capacity for Typed Collections
            # Context: assignments like `arr: list[int] = [x, y, z]`
            is_simple_list = False
            cap = 0
            if isinstance(node.value, (ast.List, ast.Tuple)):
                has_starred = any(isinstance(elt, ast.Starred) for elt in node.value.elts)
                if not has_starred:
                    is_simple_list = True
                    cap = len(node.value.elts)

            # Determine type
            v_type = None
            type_str = ""
            if hasattr(ast, 'unparse'):
                try:
                    type_str = ast.unparse(node.annotation)
                    v_type = map_python_type_to_v(type_str)
                except Exception:
                    pass

            if not v_type:
                v_type = getattr(self, "_guess_type", lambda x: "unknown")(node.target)

            # Check if this is a LiteralString being assigned an input() call
            if type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString") and isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "input":
                 self.output.append(f"{self._indent()}// WARNING: LiteralString variable '{target}' receives value from input() (loss of guarantee)")

            if self.in_main and isinstance(node.target, ast.Name):
                if type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString") and not self._is_literal_string_expr(node.value) and not self._is_compile_time_evaluable(node.value):
                     self.emitter.add_global(f"{target} string")

            if is_simple_list and v_type.startswith("[]") and cap > 0:
                self.output.append(f"{self._indent()}mut {target} := {v_type}{{cap: {cap}}}")
                value_node: Any = node.value
                for elt in value_node.elts:
                    val = self.visit(elt)
                    self.output.append(f"{self._indent()}{target} << {val}")
            elif hasattr(self, 'dataclasses') and v_type in self.dataclasses and isinstance(node.value, ast.Dict):
                # TypedDict assignment
                pairs = []
                for k, v in zip(node.value.keys, node.value.values):
                    if isinstance(k, ast.Constant) and isinstance(k.value, str):
                        key_str = self._sanitize_name(k.value)
                        val_str = self.visit(v)
                        pairs.append(f"{key_str}: {val_str}")

                rhs = f"{v_type}{{{', '.join(pairs)}}}"
                self.output.append(f"{self._indent()}{target} := {rhs}")

            else:
                if isinstance(node.value, ast.Dict) and not node.value.keys and v_type.startswith("map["):
                    rhs = f"{v_type}{{}}"
                else:
                    self.current_assignment_type = v_type
                    rhs = self.visit(node.value)
                    if hasattr(self, "current_assignment_type"):
                        del self.current_assignment_type

                emit_fn = self.output.append
                if self.in_main:
                    base_lhs = target.split('.')[0].split('[')[0]

                    if base_lhs in getattr(self, "global_vars", set()):
                        emit_fn = lambda stmt: self.emitter.add_init_statement(stmt.strip())
                        if isinstance(node.target, ast.Name):
                            if not v_type or v_type == "unknown":
                                v_type = "Any"
                            self.emitter.add_global(f"{target} {v_type}")

                    elif base_lhs.isupper() or \
                         (v_type == "Final" or type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString") or
                          getattr(node, "annotation", None) and
                          (getattr(getattr(node, "annotation", None), "id", "") == "Final" or
                           getattr(getattr(node, "annotation", None), "attr", "") == "Final")):
                        emit_fn = lambda stmt: self.emitter.add_init_statement(stmt.strip())
                        if isinstance(node.target, ast.Name):
                            if not v_type or v_type in ("unknown", "Final"):
                                v_type = "Any"
                            if type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString"):
                                v_type = "string"
                            if type_str not in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString"):
                                self.emitter.add_global(f"{target} {v_type}")

                            # Use const block only if it evaluates at compile-time (e.g., literal string)
                            if self._is_compile_time_evaluable(node.value) or (type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString") and self._is_literal_string_expr(node.value)):
                                self.emitter.add_constant(f"{target} = {rhs}")
                                return
                            else:
                                self.emitter.add_init_statement(f"{target} = {rhs}")
                                return

                # Обычное присваивание, если не перехвачено выше
                if self.in_main and isinstance(node.target, ast.Name) and \
                   (target in getattr(self, "global_vars", set()) or target.isupper()):

                    if type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString"):
                         # UPPER_CASE LiteralString переменные идут в const, lowercase — как обычные
                         if target.isupper() and (self._is_literal_string_expr(node.value) or self._is_compile_time_evaluable(node.value)):
                              self.emitter.add_constant(f"{target} = {rhs}")
                              return
                         else:
                              self.emitter.add_init_statement(f"{target} = {rhs}")
                              return
                    emit_fn(f"{self._indent()}{target} = {rhs}")

                elif rhs == "none":
                    if v_type and v_type != "unknown":
                        if not v_type.startswith("?"):
                            v_type = f"?{v_type}"
                        emit_fn(f"{self._indent()}mut {target} := {v_type}(none)")
                    else:
                        emit_fn(f"{self._indent()}mut {target} := ?Any(none)")
                else:
                    # We ignore the annotation for now and rely on type inference and V's auto-typing
                    # But we could potentially use it to hint types for empty lists/maps
                    if isinstance(node.target, ast.Attribute) or isinstance(node.target, ast.Subscript):
                        emit_fn(f"{self._indent()}{target} = {rhs}")
                    else:
                        if emit_fn == self.output.append:
                            emit_fn(f"{self._indent()}{target} := {rhs}")
                        else:
                            emit_fn(f"{self._indent()}{target} = {rhs}")
        else:
            # Declaration only: x: int
            # V needs initialization. We map type to default value.
            try:
                type_str = ast.unparse(node.annotation)
                v_type = map_python_type_to_v(type_str)

                if self.in_main and isinstance(node.target, ast.Name):
                    target_name = target
                    if not v_type or v_type == "unknown":
                        v_type = "Any"
                    if target_name in getattr(self, "global_vars", set()):
                        self.emitter.add_global(f"{target_name} {v_type}")
                        return
                    elif target_name.isupper():
                        # V requires consts to be initialized
                        self.emitter.add_constant(f"{target_name} = /* uninitialized constant */ 0")
                        return
                default_val = "0"
                if v_type == "int": default_val = "0"
                elif v_type == "f64": default_val = "0.0"
                elif v_type == "bool": default_val = "false"
                elif v_type == "string": default_val = "''"
                elif v_type.startswith("[]"): default_val = f"{v_type}{{}}"
                elif v_type.startswith("map["): default_val = f"{v_type}{{}}"
                elif v_type.startswith("?"): default_val = "none"
                else:
                    # Fallback for structs? or unknowns
                    pass

                self.output.append(f"{self._indent()}{target} := {default_val}")
            except:
                self.output.append(f"{self._indent()}// {target} declared (annotation processing failed)")
