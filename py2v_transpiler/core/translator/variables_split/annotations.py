import ast
from typing import Any
from ..base import TranslatorBase


class AnnotationsMixin(TranslatorBase):
    """Handling annotated assignments: visit_AnnAssign"""

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
        from py2v_transpiler.pydantic_support.detector import PydanticDetector
        if node.value and PydanticDetector.is_pydantic_field(node.value):
            # For class-level Pydantic fields outside of PydanticModelProcessor
            # we just skip generating assignments here, since PydanticModelProcessor
            # extracts and processes them directly from the class body.
            if getattr(self, "current_class", None):
                return

        target = self.visit(node.target)
        if node.value:
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

            # Check if this is a type alias (PEP 613)
            if self.in_main and isinstance(node.target, ast.Name):
                is_pep613 = False
                if type_str.startswith("TypeAlias") or type_str.startswith("typing.TypeAlias") or type_str.startswith("typing_extensions.TypeAlias"):
                    is_pep613 = True

                if is_pep613:
                    rhs_v_type = self._map_type(ast.unparse(node.value), allow_union=True)
                    pub = "pub " if self._is_exported(node.target.id) else ""
                    self.emitter.add_struct(f"{pub}type {target} = {rhs_v_type}")
                    return

            is_literal_string_type = type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString")

            # Check if this is a LiteralString being assigned a non-literal value
            if is_literal_string_type:
                if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "input":
                    self.output.append(f"{self._indent()}//##LLM@@ LiteralString variable '{target}' receives value from input() (loss of guarantee). Please review the security implications.")
                elif not self._is_literal_string_expr(node.value):
                    self.output.append(f"{self._indent()}//##LLM@@ LiteralString variable '{target}' receives non-literal value. Please review the security implications.")

            if self.in_main and isinstance(node.target, ast.Name):
                if is_literal_string_type and not self._is_literal_string_expr(node.value) and not self._is_compile_time_evaluable(node.value):
                     self.emitter.add_global(f"{target} string")

            if v_type.startswith("[") and "]" in v_type and not v_type.startswith("[]") and isinstance(node.value, (ast.List, ast.Tuple)):
                prev_type = self.current_assignment_type
                self.current_assignment_type = v_type
                rhs = self.visit(node.value)
                self.current_assignment_type = prev_type
                self.output.append(f"{self._indent()}mut {target} := {rhs}")
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
                # Check for interface array initialization
                is_interface_array = False
                base_v_type = ""
                if v_type.startswith("[]"):
                    base_v_type = v_type[2:]
                elif v_type.startswith("?[]"):
                    base_v_type = v_type[3:]


                if base_v_type and base_v_type in self.known_interfaces:
                    is_interface_array = True

                if is_interface_array and isinstance(node.value, (ast.List, ast.Tuple)) and node.value.elts:
                    # To initialize interface arrays, V requires using `mut arr := []Interface{}` then `arr << ...`
                    if not self.in_main and target in self._local_vars_in_scope:
                        self.output.append(f"{self._indent()}{target} = {v_type}{{}}")
                    else:
                        self.output.append(f"{self._indent()}mut {target} := {v_type}{{}}")
                        if not self.in_main: self._local_vars_in_scope.add(target)

                    for elt in node.value.elts:
                        val = self.visit(elt)
                        self.output.append(f"{self._indent()}{target} << {val}")
                    return

                if isinstance(node.value, ast.Dict) and not node.value.keys and v_type.startswith("map["):
                    rhs = f"{v_type}{{}}"
                elif isinstance(node.value, (ast.List, ast.Tuple)) and not node.value.elts and v_type.startswith("[]"):
                    rhs = f"{v_type}{{}}"
                else:
                    prev_type = self.current_assignment_type
                    self.current_assignment_type = v_type
                    rhs = self.visit(node.value)
                    self.current_assignment_type = prev_type

                emit_fn = self.output.append
                if self.in_main:
                    base_lhs = target.split('.')[0].split('[')[0]

                    if base_lhs in getattr(self, "global_vars", set()):
                        emit_fn = lambda stmt: self.emitter.add_init_statement(stmt.strip())
                        if isinstance(node.target, ast.Name):
                            if not v_type or v_type == "unknown":
                                v_type = "Any"
                            self.emitter.add_global(f"{target} {v_type}")

                    elif (isinstance(node.target, ast.Name) and node.target.id.isupper()) or \
                         (v_type == "Final" or is_literal_string_type or
                          getattr(node, "annotation", None) and
                          (getattr(getattr(node, "annotation", None), "id", "") == "Final" or
                           getattr(getattr(node, "annotation", None), "attr", "") == "Final")) or \
                         (type_str and ("Final" in type_str)):
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
                                pub = "pub " if self._is_exported(target) else ""
                                # Convert UPPER_CASE to snake_case for V constants
                                v_const = self._to_snake_case(v_target) if v_target else self._to_snake_case(target)
                                self.emitter.add_constant(f"pub {v_const} = {rhs}" if pub else f"{v_const} = {rhs}")
                                return
                            else:
                                self.emitter.add_init_statement(f"{v_target} = {rhs}")
                                return

                # Regular assignment if it was not handled above
                if self.in_main and isinstance(node.target, ast.Name) and \
                   (target in getattr(self, "global_vars", set()) or (isinstance(node.target, ast.Name) and node.target.id.isupper()) or is_literal_string_type):
                    v_target = self._to_snake_case(target)
                    if is_literal_string_type:
                         # Only literal string expressions and compile time evaluables are placed in const
                         if self._is_literal_string_expr(node.value) or self._is_compile_time_evaluable(node.value):
                              pub = "pub " if self._is_exported(target) else ""
                              v_const = self._to_snake_case(v_target) if v_target else self._to_snake_case(target)
                              self.emitter.add_constant(f"pub {v_const} = {rhs}" if pub else f"{v_const} = {rhs}")
                         else:
                              self.emitter.add_init_statement(f"{v_target} = {rhs}")
                         return
                    emit_fn(f"{self._indent()}{v_target} = {rhs}")

                elif rhs == "none":
                    if isinstance(node.target, (ast.Attribute, ast.Subscript)) or (not self.in_main and target in self._local_vars_in_scope):
                        if v_type == "Any" or (v_type and v_type.startswith("map[") and v_type.endswith("]Any")):
                             emit_fn(f"{self._indent()}{target} = Any(NoneType{{}})")
                        else:
                             emit_fn(f"{self._indent()}{target} = none")
                    else:
                        if v_type and v_type != "unknown":
                            if v_type == "Any" or (v_type.startswith("map[") and v_type.endswith("]Any")):
                                emit_fn(f"{self._indent()}mut {target} := Any(NoneType{{}})")
                            else:
                                if not v_type.startswith("?"): v_type = f"?{v_type}"
                                emit_fn(f"{self._indent()}mut {target} := {v_type}(none)")
                        else:
                            emit_fn(f"{self._indent()}mut {target} := Any(NoneType{{}})")
                        if not self.in_main: self._local_vars_in_scope.add(target)
                else:
                    # Check for UPPER_CASE const (e.g., I_IDLE: Final = 1) when not in_main or other conditions
                    if isinstance(node.target, ast.Name) and target.isupper() and self._is_compile_time_evaluable(node.value):
                        v_const = self._to_snake_case(target)
                        pub = "pub " if self._is_exported(target) else ""
                        self.emitter.add_constant(f"pub {v_const} = {rhs}" if pub else f"{v_const} = {rhs}")
                        return
                    
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
                                        is_mut = (mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)) and not mut_info.get("is_final", False)

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
                    elif isinstance(node.target, ast.Name) and node.target.id.isupper():
                        # V requires consts to be initialized
                        pub = "pub " if self._is_exported(target) else ""
                        self.emitter.add_constant(f"pub {target_name} = /* uninitialized constant */ 0" if pub else f"{target_name} = /* uninitialized constant */ 0")
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
                self.output.append(f"{self._indent()}//##LLM@@ {target} declared (annotation processing failed). Please manually infer the correct type and initialize it.")
