import ast
from typing import Any
from ..base import TranslatorBase
from py2v_transpiler.models.v_types import map_python_type_to_v


class AssignmentsMixin(TranslatorBase):
    """Assignment handling: visit_Assign and helper methods"""

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

    def visit_Assign(self, node: ast.Assign) -> None:
        target = node.targets[0]
        lhs = ""
        if isinstance(target, ast.Name):
            lhs = self._sanitize_name(target.id)

            if target.id in self.name_remap:
                del self.name_remap[target.id]

            if self.in_main:
                 self.defined_top_level_symbols.add(target.id)

            # Check for NewType: UserId = NewType('UserId', int)
            if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "NewType":
                if len(node.value.args) == 2:
                    # Arg 1 is name, Arg 2 is base type
                    # we use lhs as name
                    try:
                        if hasattr(ast, 'unparse'):
                             base_str = ast.unparse(node.value.args[1])
                             mapped_base = map_python_type_to_v(base_str, allow_union=True, self_name=self._get_full_self_type())
                             pub = "pub " if self._is_exported(target.id) else ""
                             self.emitter.add_struct(f"{pub}type {lhs} = {mapped_base}")
                             return
                    except:
                        pass

            # Check for TypeVar: T = TypeVar("T", int, str)
            if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "TypeVar":
                self.type_vars.add(target.id)
                # Check args for constraints
                # args[0] is name
                is_constrained = False
                constraints = []
                for arg in node.value.args[1:]:
                    is_constrained = True
                    if isinstance(arg, ast.Name):
                        constraints.append(map_python_type_to_v(arg.id, self_name=self._get_full_self_type()))
                    elif isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                        constraints.append(map_python_type_to_v(arg.value, self_name=self._get_full_self_type()))

                # Check keyword bound
                for kw in node.value.keywords:
                    if kw.arg == "bound":
                        is_constrained = True
                        # bound=Union[int, str] or bound=int
                        # We can use ast.unparse and map
                        try:
                            bound_str = ast.unparse(kw.value)
                            mapped = map_python_type_to_v(bound_str, self_name=self._get_full_self_type())
                            # If mapped is "int | string", we use it
                            if "|" in mapped:
                                constraints.extend([s.strip() for s in mapped.split("|")])
                            else:
                                constraints.append(mapped)
                        except:
                            pass

                if is_constrained:
                    self.constrained_typevars.add(target.id)

                if constraints:
                    # Emit sum type
                    # Sanitize lhs?
                    sanitized_lhs = lhs.lstrip('_')
                    # If multiple constraints, join with |
                    # But mapped bound might already be a union string "A | B"
                    # We need to be careful not to create "A | B | C" if they are distinct

                    final_type = " | ".join(constraints)
                    pub = "pub " if self._is_exported(target.id) else ""
                    self.emitter.add_struct(f"{pub}type {sanitized_lhs} = {final_type}")
                return

            # Check for type alias: MyType = int or MyType = OtherType or MyType = List[int]
            if self.in_main:
                is_type_alias = False
                type_alias_val = ""

                # Check if LHS is capitalized or looks like a private type alias (heuristic)
                if lhs[0].isupper() or (lhs.startswith('_') and len(lhs) > 1 and any(c.isupper() for c in lhs)):
                     # Check if it was inferred by TypeInference (e.g. OrderedCollection = list)
                     if hasattr(self, 'type_inference') and lhs in self.type_inference.type_map and isinstance(node.value, ast.Name):
                          is_type_alias = True
                          type_alias_val = self.type_inference.type_map[lhs]

                     else:
                          # Try to map RHS as a type
                          try:
                              # Unparse RHS to string
                              if hasattr(ast, 'unparse'):
                                  rhs_source = ast.unparse(node.value)
                                  mapped = self._map_type(rhs_source, allow_union=True, register_sum_types=False)
                                  # Check if mapped value looks like a type and not void/same-as-input-expression
                                  # map_python_type_to_v returns input if it fails to map usually, unless it parses successfully via _map_ast_type
                                  # For List[int], it returns []int. List[int] != []int.
                                  # For int, it returns int.
                                  # For "unknown", it returns "unknown".

                                  if mapped != "void" and mapped != rhs_source:
                                       is_type_alias = True
                                       type_alias_val = mapped
                                  elif mapped == "int" and rhs_source == "int": # Primitive
                                       is_type_alias = True
                                       type_alias_val = "int"
                                  elif mapped == "f64" and rhs_source == "float":
                                       is_type_alias = True
                                       type_alias_val = "f64"
                                  elif mapped == "string" and rhs_source == "str":
                                       is_type_alias = True
                                       type_alias_val = "string"
                                  elif mapped == "bool" and rhs_source == "bool":
                                       is_type_alias = True
                                       type_alias_val = "bool"
                                  # For MyType = OtherType (Name = Name)
                                  elif isinstance(node.value, ast.Name) and node.value.id[0].isupper():
                                       is_type_alias = True
                                       type_alias_val = node.value.id
                              else:
                                  # Fallback for older python without ast.unparse (unlikely in this env)
                                  pass
                          except:
                              pass

                if is_type_alias:
                     pub = "pub " if self._is_exported(target.id) else ""

                     # Extract potential generic parameters from type_alias_val
                     # If it contains _T (and we tracked _T as TypeVar), we might need [T]
                     # However, V type aliases for generics MUST have [T] explicitly.
                     # Since this is a simple assignment alias, we look for tracked type_vars
                     found_vars = []
                     for tv in self.type_vars:
                         if f"{tv}" in type_alias_val:
                             v_gen = self._get_generic_map([tv]).get(tv, "T")
                             if v_gen not in found_vars:
                                 found_vars.append(v_gen)

                     gen_str = f"[{', '.join(found_vars)}]" if found_vars else ""

                     # If it's a generic alias, we need to replace the Python TypeVar name with V generic name in the RHS too
                     if found_vars:
                         # This is a bit naive, but let's try
                         for tv in sorted(list(self.type_vars), key=len, reverse=True):
                              v_gen = self._get_generic_map([tv]).get(tv, "T")
                              type_alias_val = type_alias_val.replace(tv, v_gen)

                     self.emitter.add_struct(f"{pub}type {lhs}{gen_str} = {type_alias_val}")
                     return

        elif isinstance(target, ast.Attribute):
            # obj.attr = value
            # Check for property setter
            obj_type = self._guess_type(target.value)
            if (obj_type, target.attr) in self.property_setters:
                obj_expr = self.visit(target.value)
                rhs_expr = self.visit(node.value)
                self.output.append(f"{self._indent()}{obj_expr}.set_{target.attr}({rhs_expr})")
                return

            # Check for function attribute assignment
            obj_name = self.visit(target.value)
            if obj_name in self.function_names:
                 lhs = f"{obj_name}__{target.attr}"
            else:
                 lhs = f"{obj_name}.{target.attr}"
        elif isinstance(target, ast.Subscript):
            # dict["key"] = value (TypedDict)
            obj_type = getattr(self, "_guess_type", lambda x: "unknown")(target.value)
            if hasattr(self, 'dataclasses') and obj_type in self.dataclasses:
                list_obj = self.visit(target.value)
                if isinstance(target.slice, ast.Constant) and isinstance(target.slice.value, str):
                    field_name = self._sanitize_name(target.slice.value)

                    # Check for ReadOnly field assignment
                    if hasattr(self, 'readonly_fields') and obj_type in self.readonly_fields:
                        if field_name in self.readonly_fields[obj_type]:
                            self.output.append(f"{self._indent()}$compile_error('Cannot assign to ReadOnly TypedDict field \\'{field_name}\\'')")
                            return

                    lhs = f"{list_obj}.{field_name}"
                    rhs = self.visit(node.value)
                    self.output.append(f"{self._indent()}{lhs} = {rhs}")
                    return

            # list[index] = value
            # Check for slice assignment: l[1:3] = [4, 5]
            if isinstance(target.slice, ast.Slice):
                # We need to access the list and range
                # target.value is the list
                list_obj = self.visit(target.value)

                # target.slice is the range
                lower = self.visit(target.slice.lower) if target.slice.lower else "0"
                upper = self.visit(target.slice.upper) if target.slice.upper else f"{list_obj}.len"

                # Check if upper is omitted or None
                # If upper is empty string from visit, it usually means "up to end".
                # But V range [a..b] works?
                # Actually visit_Subscript emits [lower..upper].
                # Here we need values for delete_many/insert_many.

                # We need to know 'count' for delete_many.
                # count = upper - lower.
                # If upper is relative to len, we need runtime calculation?
                # V Arrays: delete_many(start, count)
                # insert_many(index, val)

                # We assume RHS is an array.
                rhs = self.visit(node.value)

                # We need to handle mutability. 'list_obj' should be mutable.
                # Assuming it is declared as mut.

                # Logic:
                # start = lower
                # end = upper
                # count = end - start
                # list_obj.delete_many(start, count)
                # list_obj.insert_many(start, rhs)

                # Handle missing bounds
                start_expr = lower
                end_expr = upper

                # If we emit multiple statements, we need self.output.append.
                # But visit_Assign does that at the end based on lhs.
                # Here we handle it manually and return.

                self.output.append(f"{self._indent()}{list_obj}.delete_many({start_expr}, ({end_expr}) - ({start_expr}))")
                self.output.append(f"{self._indent()}{list_obj}.insert_many({start_expr}, {rhs})")
                return

            lhs = self.visit(target)
        elif isinstance(target, (ast.Tuple, ast.List)):
             # Destructuring assignment with nested support
             rhs = self.visit(node.value)

             if self.in_main:
                  # Track top-level symbols for destructuring
                  def track_targets(t):
                       if isinstance(t, (ast.Tuple, ast.List)):
                            for elt in t.elts:
                                 track_targets(elt)
                       elif isinstance(t, ast.Starred):
                            track_targets(t.value)
                       elif isinstance(t, ast.Name):
                            self.defined_top_level_symbols.add(t.id)
                  track_targets(target)

             # Optimization: If simple unpacking a, b = 1, 2 (RHS is Tuple/List literal) and no starred elements
             # And no nested targets!
             def is_simple(targets):
                 return not any(isinstance(elt, (ast.Tuple, ast.List, ast.Starred)) for elt in targets)

             if is_simple(target.elts) and isinstance(node.value, (ast.Tuple, ast.List)) and len(node.value.elts) == len(target.elts):
                  lhs_parts = [self.visit(t) for t in target.elts]
                  rhs_parts = [self.visit(v) for v in node.value.elts]
                  self.output.append(f"{self._indent()}{', '.join(lhs_parts)} := {', '.join(rhs_parts)}")
                  return

             # Use recursive destructuring helper
             self._visit_destructuring(target, rhs)
             return

        if len(node.targets) > 1:
            # chained assignment: a = b = c = 1
            rhs = self.visit(node.value)
            tmp = f"py_assign_tmp_{self.unique_id_counter}"
            self.unique_id_counter += 1
            self.output.append(f"{self._indent()}{tmp} := {rhs}")

            for t in node.targets:
                # Reset rhs for each target to avoid accumulation of .clone()
                self._visit_destructuring(t, tmp)
            return

        if not lhs:
             # Should be covered by destructuring
             return

        if isinstance(node.value, ast.ListComp):
            # visit_ListComp is defined in ExpressionsMixin, but available on self at runtime
            if hasattr(self, 'visit_ListComp'):
                 self.visit_ListComp(node.value, target_var=lhs) # type: ignore
            else:
                 self.output.append(f"{self._indent()}//##LLM@@ List comprehension support is missing in the transpiler. Please manually transpile this list comprehension.")
        elif isinstance(node.value, ast.SetComp):
            # visit_SetComp is defined in ExpressionsMixin, but available on self at runtime
            if hasattr(self, 'visit_SetComp'):
                 self.visit_SetComp(node.value, target_var=lhs) # type: ignore
            else:
                 self.output.append(f"{self._indent()}//##LLM@@ Set comprehension support is missing in the transpiler. Please manually transpile this set comprehension.")
        elif isinstance(node.value, ast.DictComp):
            # visit_DictComp is defined in ExpressionsMixin, but available on self at runtime
            if hasattr(self, 'visit_DictComp'):
                 self.visit_DictComp(node.value, target_var=lhs) # type: ignore
            else:
                 self.output.append(f"{self._indent()}//##LLM@@ Dict comprehension support is missing in the transpiler. Please manually transpile this dict comprehension.")
        elif isinstance(node.value, ast.GeneratorExp):
            # Treat generator expression as list comprehension (eager evaluation)
            if hasattr(self, 'visit_ListComp'):
                 self.visit_ListComp(node.value, target_var=lhs) # type: ignore
            else:
                 self.output.append(f"{self._indent()}//##LLM@@ Generator expression support is missing in the transpiler. Please manually transpile this generator expression.")
        else:
            # Check for pre-allocated capacity for typed collections
            # Context: assignments like `arr = [x, y, z]`
            # If mypy inferred it as a list, or it's a list literal, and it has no starred items
            is_simple_list = False
            cap = 0
            if isinstance(node.value, (ast.List, ast.Tuple)):
                has_starred = any(isinstance(elt, ast.Starred) for elt in node.value.elts)
                if not has_starred:
                    is_simple_list = True
                    cap = len(node.value.elts)

            # Determine type
            v_type = getattr(self, "_guess_type", lambda x: "unknown")(target)

            # Update type map on normal assignment if type is unknown or we have a literal
            if isinstance(target, ast.Name):
                assigned_type = getattr(self, "_guess_type", lambda x: "unknown")(node.value)
                if assigned_type != "unknown" and assigned_type != "int":
                    if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'type_map'):
                        # If not already statically typed, save the literal assigned type
                        if target.id not in self.type_inference.type_map:
                            self.type_inference.type_map[target.id] = assigned_type

            # Check for LiteralString
            is_literal_string = False
            if v_type == "LiteralString":
                is_literal_string = True
                if not self._is_literal_string_expr(node.value):
                    self.output.append(f"{self._indent()}//##LLM@@ LiteralString variable '{lhs}' receives non-literal value. Please review the security implications.")

            # Check for implicit LiteralString (constant strings, concatenation, f-strings without vars)
            # If so, we track it as string and potentially as a constant
            is_implicit_literal = False
            # Ensure it is a known literal string expression but ONLY convert to const
            # if we explicitly have a LiteralString annotation. Implicit literals
            # should remain runtime variables unless explicitly requested as const via type
            if self._is_literal_string_expr(node.value):
                 is_implicit_literal = True
                 if v_type == "unknown":
                     v_type = "string"
                     # mark the type as literal string if not already typed
                     if isinstance(target, ast.Name):
                          if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'type_map'):
                              if target.id not in self.type_inference.type_map:
                                  self.type_inference.type_map[target.id] = "string"

            is_mut = False
            if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                # Try precise lookup by location first
                loc_key = f"{lhs}@{node.lineno}:{node.col_offset}"
                mut_info = self.type_inference.mutability_map.get(loc_key)
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(lhs)

                if mut_info:
                    is_mut = (mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)) and not mut_info.get("is_final", False)

            if is_simple_list and v_type.startswith("[]") and cap > 0 and is_mut:
                # To initialize V arrays with exact capacities (`[]int{cap: N}`) during assignments like `arr = [x, y, z]`
                # We emit:
                # mut arr := []T{cap: N}
                # arr << x ...
                v_lhs = self._to_snake_case(lhs) if (isinstance(target, ast.Name) and not lhs.islower()) else lhs
                if not self.in_main and v_lhs in self._local_vars_in_scope:
                    self.output.append(f"{self._indent()}{v_lhs} = {v_type}{{cap: {cap}}}")
                else:
                    self.output.append(f"{self._indent()}mut {v_lhs} := {v_type}{{cap: {cap}}}")
                    if not self.in_main: self._local_vars_in_scope.add(v_lhs)

                value_node: Any = node.value
                for elt in value_node.elts:
                    val = self.visit(elt)
                    self.output.append(f"{self._indent()}{v_lhs} << {val}")
            elif hasattr(self, 'dataclasses') and v_type in self.dataclasses and isinstance(node.value, ast.Dict):
                # TypedDict assignment
                pairs = []
                for k, v in zip(node.value.keys, node.value.values):
                    if isinstance(k, ast.Constant) and isinstance(k.value, str):
                        key_str = self._sanitize_name(k.value)
                        val_str = self.visit(v)
                        pairs.append(f"{key_str}: {val_str}")

                rhs = f"{v_type}{{{', '.join(pairs)}}}"
                v_lhs = self._to_snake_case(lhs) if (isinstance(target, ast.Name) and not lhs.islower()) else lhs
                if not self.in_main and v_lhs in self._local_vars_in_scope:
                    self.output.append(f"{self._indent()}{v_lhs} = {rhs}")
                else:
                    self.output.append(f"{self._indent()}{v_lhs} := {rhs}")
                    if not self.in_main: self._local_vars_in_scope.add(v_lhs)

            else:
                if isinstance(node.value, ast.Dict) and not node.value.keys and v_type.startswith("map["):
                    rhs = f"{v_type}{{}}"
                else:
                    prev_type = self.current_assignment_type
                    self.current_assignment_type = v_type
                    rhs = self.visit(node.value)
                    self.current_assignment_type = prev_type

                emit_fn = self.output.append
                if self.in_main:
                    base_lhs = lhs.split('.')[0].split('[')[0]

                    if base_lhs in getattr(self, "global_vars", set()):
                        emit_fn = lambda stmt: self.emitter.add_init_statement(stmt.strip())
                        if isinstance(target, ast.Name):
                            if v_type == "unknown":
                                v_type = "Any"
                            self.emitter.add_global(f"{lhs} {v_type}")
                    elif base_lhs.isupper():
                        emit_fn = lambda stmt: self.emitter.add_init_statement(stmt.strip())
                        if isinstance(target, ast.Name):
                            v_lhs = self._to_snake_case(lhs)
                            if self._is_compile_time_evaluable(node.value):
                                # Compile-time constant (e.g. DEFAULT_WIDTH = 100) -> const block
                                pub = "pub " if self._is_exported(target.id) else ""
                                self.emitter.add_constant(f"pub {v_lhs} = {rhs}" if pub else f"{v_lhs} = {rhs}")
                                return
                            else:
                                # Runtime UPPER_CASE (e.g. Vector_ZERO = new_Vector(...)) -> global + init()
                                if v_type == "unknown" or v_type == "int":
                                    v_type = "Any"
                                self.emitter.add_global(f"{v_lhs} {v_type}")
                                lhs = v_lhs

                if self.in_main and isinstance(target, ast.Name) and (lhs in getattr(self, "global_vars", set()) or lhs.isupper() or is_implicit_literal or is_literal_string):
                    v_lhs = self._to_snake_case(lhs) if not lhs.islower() else lhs
                    # For compile-time constants we already returned above - assignment not needed
                    if (is_implicit_literal or is_literal_string) and self._is_compile_time_evaluable(node.value) and not lhs.isupper():
                        pub = "pub " if self._is_exported(target.id) else ""
                        self.emitter.add_constant(f"pub {v_lhs} = {rhs}" if pub else f"{v_lhs} = {rhs}")
                        return
                    if (is_implicit_literal or is_literal_string) and not self._is_compile_time_evaluable(node.value) and not lhs.isupper():
                        if lhs not in getattr(self, "global_vars", set()):
                            self.emitter.add_global(f"{v_lhs} string")
                        self.emitter.add_init_statement(f"{v_lhs} = {rhs}")
                        return
                    if not (lhs.isupper() and self._is_compile_time_evaluable(node.value)):
                        emit_fn(f"{self._indent()}{v_lhs} = {rhs}")
                elif rhs == "none":
                    # v_type might be defined above if we were checking is_simple_list, but let's be safe
                    local_v_type = getattr(self, "_guess_type", lambda x: "unknown")(target)
                    v_lhs = self._to_snake_case(lhs) if (isinstance(target, ast.Name) and not lhs.islower()) else lhs
                    if not self.in_main and v_lhs in self._local_vars_in_scope:
                        if local_v_type == "Any" or (local_v_type.startswith("map[") and local_v_type.endswith("]Any")):
                            emit_fn(f"{self._indent()}{v_lhs} = Any(NoneType{{}})")
                        else:
                            emit_fn(f"{self._indent()}{v_lhs} = none")
                    else:
                        if local_v_type and local_v_type != "unknown":
                            if local_v_type == "Any" or (local_v_type.startswith("map[") and local_v_type.endswith("]Any")):
                                emit_fn(f"{self._indent()}mut {v_lhs} := Any(NoneType{{}})")
                            else:
                                if not local_v_type.startswith("?"):
                                    local_v_type = f"?{local_v_type}"
                                emit_fn(f"{self._indent()}mut {v_lhs} := {local_v_type}(none)")
                        else:
                            emit_fn(f"{self._indent()}mut {v_lhs} := Any(NoneType{{}})")
                        if not self.in_main: self._local_vars_in_scope.add(v_lhs)
                else:
                    v_lhs = self._to_snake_case(lhs) if (isinstance(target, ast.Name) and not lhs.islower()) else lhs
                    if isinstance(target, ast.Attribute) or isinstance(target, ast.Subscript):
                        emit_fn(f"{self._indent()}{lhs} = {rhs}")
                    else:
                        v_lhs = self._to_snake_case(lhs) if not lhs.islower() else lhs
                        if emit_fn == self.output.append:
                            if not self.in_main and v_lhs in self._local_vars_in_scope:
                                emit_fn(f"{self._indent()}{v_lhs} = {rhs}")
                            else:
                                is_mut = False
                                if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                                    # Try precise lookup by location first
                                    loc_key = f"{v_lhs}@{node.lineno}:{node.col_offset}"
                                    mut_info = self.type_inference.mutability_map.get(loc_key)
                                    if not mut_info:
                                        mut_info = self.type_inference.mutability_map.get(v_lhs)

                                    if mut_info:
                                        is_mut = (mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)) and not mut_info.get("is_final", False)

                                # Special handling for buffer protocol: always mutable if bytearray
                                if not is_mut:
                                    # check if it is a call to bytearray
                                    if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "bytearray":
                                        is_mut = True

                                if is_mut and self._is_clonable_collection(v_type):
                                    if not (rhs.startswith("[") or rhs.startswith("map[") or rhs.startswith("{")):
                                        rhs = f"{rhs}.clone()"

                                mut_prefix = "mut " if is_mut else ""
                                emit_fn(f"{self._indent()}{mut_prefix}{v_lhs} := {rhs}")
                                if not self.in_main: self._local_vars_in_scope.add(v_lhs)
                        else:
                            # if it's going to init(), it shouldn't be := if it's a global
                            emit_fn(f"{self._indent()}{v_lhs} = {rhs}")

    def _visit_destructuring(self, target: ast.AST, source_expr: str) -> None:
        """
        Recursively handles destructuring assignments, including nested tuples/lists.
        target: The AST node for the target (Tuple, List, Name, etc.)
        source_expr: The V expression representing the value to unpack (e.g. `_destruct_0`, `my_list[1]`)
        """
        if isinstance(target, (ast.Tuple, ast.List)):
             # Assign source to a temporary variable to avoid repeated evaluation
             # and allow slicing
             tmp_var = f"py_destruct_{self._zip_counter}"
             self._zip_counter += 1
             self.output.append(f"{self._indent()}{tmp_var} := {source_expr}")

             starred_idx = -1
             for i, elt in enumerate(target.elts):
                 if isinstance(elt, ast.Starred):
                     starred_idx = i
                     break

             if starred_idx == -1:
                 # Simple unpacking: a, b = l
                 for i, elt in enumerate(target.elts):
                     # Recursive call for each element
                     self._visit_destructuring(elt, f"{tmp_var}[{i}]")
             else:
                 # Starred unpacking
                 # Pre-star
                 for i in range(starred_idx):
                     elt = target.elts[i]
                     self._visit_destructuring(elt, f"{tmp_var}[{i}]")

                 # Star
                 star_elt = target.elts[starred_idx]
                 if isinstance(star_elt, ast.Starred):
                     # Slice: start = starred_idx, end = len - (total - 1 - starred_idx)
                     trailing = len(target.elts) - 1 - starred_idx
                     slice_expr = ""
                     if trailing == 0:
                          slice_expr = f"{tmp_var}[{starred_idx}..]"
                     else:
                          slice_expr = f"{tmp_var}[{starred_idx}..{tmp_var}.len-{trailing}]"

                     self._visit_destructuring(star_elt.value, slice_expr)

                 # Post-star
                 for i in range(starred_idx + 1, len(target.elts)):
                     elt = target.elts[i]
                     offset = len(target.elts) - i
                     self._visit_destructuring(elt, f"{tmp_var}[{tmp_var}.len-{offset}]")

        elif isinstance(target, ast.Name):
            lhs = self.visit(target)
            if not self.in_main and lhs in self._local_vars_in_scope:
                self.output.append(f"{self._indent()}{lhs} = {source_expr}")
            else:
                is_mut = False
                if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                    loc_key = f"{lhs}@{target.lineno}:{target.col_offset}"
                    mut_info = self.type_inference.mutability_map.get(loc_key)
                    if not mut_info:
                        mut_info = self.type_inference.mutability_map.get(lhs)

                    if mut_info:
                        is_mut = (mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)) and not mut_info.get("is_final", False)

                v_type = getattr(self, "_guess_type", lambda x: "unknown")(target)
                if is_mut and self._is_clonable_collection(v_type):
                    # For collections, V requires .clone() when assigning to a mutable variable
                    # unless it's a fresh literal
                    if not (source_expr.startswith("[") or source_expr.startswith("map[") or source_expr.startswith("{")):
                        source_expr = f"{source_expr}.clone()"

                mut_prefix = "mut " if is_mut else ""
                self.output.append(f"{self._indent()}{mut_prefix}{lhs} := {source_expr}")
                if not self.in_main:
                    self._local_vars_in_scope.add(lhs)

        elif isinstance(target, (ast.Attribute, ast.Subscript)):
             lhs = self.visit(target)
             self.output.append(f"{self._indent()}{lhs} = {source_expr}")

        else:
             self.output.append(f"{self._indent()}//##LLM@@ Unsupported destructuring target: {type(target)}. Please manually implement this unpacking logic in V.")

    def visit_NamedExpr(self, node: ast.NamedExpr) -> str:
        # (target := value)
        target = self._sanitize_name(node.target.id)
        value = self.visit(node.value)
        self._walrus_assignments.append(f"{target} := {value}")
        return target
