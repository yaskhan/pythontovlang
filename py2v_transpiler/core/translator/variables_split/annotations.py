import ast
from typing import Any
from ..base import TranslatorBase
from py2v_transpiler.models.v_types import map_python_type_to_v


class AnnotationsMixin(TranslatorBase):
    """Обработка аннотированных присваиваний: visit_AnnAssign"""

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
                    self._check_experimental_type(type_str, node.annotation)
                    v_type = self._map_type(type_str)
                except Exception:
                    pass

            if not v_type:
                v_type = getattr(self, "_guess_type", lambda x: "unknown")(node.target)

            is_literal_string_type = type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString")

            # Check if this is a LiteralString being assigned a non-literal value
            if is_literal_string_type:
                if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "input":
                    self.output.append(f"{self._indent()}// WARNING: LiteralString variable '{target}' receives value from input() (loss of guarantee)")
                elif not self._is_literal_string_expr(node.value):
                    self.output.append(f"{self._indent()}// WARNING: LiteralString variable '{target}' receives non-literal value")

            if self.in_main and isinstance(node.target, ast.Name):
                if is_literal_string_type and not self._is_literal_string_expr(node.value) and not self._is_compile_time_evaluable(node.value):
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
                elif isinstance(node.value, (ast.List, ast.Tuple)) and not node.value.elts and v_type.startswith("[]"):
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
                         (v_type == "Final" or is_literal_string_type or
                          getattr(node, "annotation", None) and
                          (getattr(getattr(node, "annotation", None), "id", "") == "Final" or
                           getattr(getattr(node, "annotation", None), "attr", "") == "Final")):
                        emit_fn = lambda stmt: self.emitter.add_init_statement(stmt.strip())
                        if isinstance(node.target, ast.Name):
                            v_target = self._to_snake_case(target)
                            if not v_type or v_type in ("unknown", "Final", "Any"):
                                v_type = "Any"
                            if is_literal_string_type:
                                v_type = "string"
                            if not is_literal_string_type:
                                self.emitter.add_global(f"{v_target} {v_type}")

                            # Use const block only if it evaluates at compile-time (e.g., literal string)
                            if self._is_compile_time_evaluable(node.value) or (is_literal_string_type and self._is_literal_string_expr(node.value)):
                                self.emitter.add_constant(f"{v_target} = {rhs}")
                                return
                            else:
                                self.emitter.add_init_statement(f"{v_target} = {rhs}")
                                return

                # Обычное присваивание, если не перехвачено выше
                if self.in_main and isinstance(node.target, ast.Name) and \
                   (target in getattr(self, "global_vars", set()) or target.isupper() or is_literal_string_type):
                    v_target = self._to_snake_case(target)
                    if is_literal_string_type:
                         # Only literal string expressions and compile time evaluables are placed in const
                         if self._is_literal_string_expr(node.value) or self._is_compile_time_evaluable(node.value):
                              self.emitter.add_constant(f"{v_target} = {rhs}")
                         else:
                              self.emitter.add_init_statement(f"{v_target} = {rhs}")
                         return
                    emit_fn(f"{self._indent()}{v_target} = {rhs}")

                elif rhs == "none":
                    if v_type and v_type != "unknown":
                        if not v_type.startswith("?"):
                            v_type = f"?{v_type}"
                        emit_fn(f"{self._indent()}mut {target} := {v_type}(none)")
                    else:
                        emit_fn(f"{self._indent()}mut {target} := ?Any(none)")
                    if not self.in_main: self._local_vars_in_scope.add(target)
                else:
                    # We ignore the annotation for now and rely on type inference and V's auto-typing
                    # But we could potentially use it to hint types for empty lists/maps
                    if isinstance(node.target, ast.Attribute) or isinstance(node.target, ast.Subscript):
                        emit_fn(f"{self._indent()}{target} = {rhs}")
                    else:
                        v_target = self._to_snake_case(target) if not target.islower() else target
                        if emit_fn == self.output.append:
                            if not self.in_main and v_target in self._local_vars_in_scope:
                                emit_fn(f"{self._indent()}{v_target} = {rhs}")
                            else:
                                is_mut = False
                                if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                                    # Try precise lookup by location first
                                    loc_key = f"{v_target}@{node.lineno}:{node.col_offset}"
                                    mut_info = self.type_inference.mutability_map.get(loc_key)
                                    if not mut_info:
                                        mut_info = self.type_inference.mutability_map.get(v_target)

                                    if mut_info:
                                        is_mut = mut_info.get("is_reassigned", False) and not mut_info.get("is_final", False)

                                mut_prefix = "mut " if is_mut else ""
                                emit_fn(f"{self._indent()}{mut_prefix}{v_target} := {rhs}")
                                if not self.in_main: self._local_vars_in_scope.add(v_target)
                        else:
                            emit_fn(f"{self._indent()}{v_target} = {rhs}")
        else:
            # Declaration only: x: int
            # V needs initialization. We map type to default value.
            try:
                type_str = ast.unparse(node.annotation)
                self._check_experimental_type(type_str, node.annotation)
                v_type = self._map_type(type_str)

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
