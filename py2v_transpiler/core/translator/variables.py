import ast
from typing import Optional, Any
from py2v_transpiler.models.v_types import map_python_type_to_v
from .base import TranslatorBase

class VariablesMixin(TranslatorBase):
    def visit_Assign(self, node: ast.Assign) -> None:
        target = node.targets[0]
        lhs = ""
        if isinstance(target, ast.Name):
            lhs = target.id

            # Check for NewType: UserId = NewType('UserId', int)
            if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "NewType":
                if len(node.value.args) == 2:
                    # Arg 1 is name, Arg 2 is base type
                    # we use lhs as name
                    try:
                        if hasattr(ast, 'unparse'):
                             base_str = ast.unparse(node.value.args[1])
                             mapped_base = map_python_type_to_v(base_str, allow_union=True)
                             self.emitter.add_struct(f"type {lhs} = {mapped_base}")
                             return
                    except:
                        pass

            # Check for TypeVar: T = TypeVar("T", int, str)
            if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "TypeVar":
                # Check args for constraints
                # args[0] is name
                constraints = []
                for arg in node.value.args[1:]:
                    if isinstance(arg, ast.Name):
                        constraints.append(map_python_type_to_v(arg.id))
                    elif isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                        constraints.append(map_python_type_to_v(arg.value))

                # Check keyword bound
                for kw in node.value.keywords:
                    if kw.arg == "bound":
                        # bound=Union[int, str] or bound=int
                        # We can use ast.unparse and map
                         try:
                             bound_str = ast.unparse(kw.value)
                             mapped = map_python_type_to_v(bound_str)
                             # If mapped is "int | string", we use it
                             constraints.append(mapped)
                         except:
                             pass

                if constraints:
                    # Emit sum type
                    # Sanitize lhs?
                    sanitized_lhs = lhs.lstrip('_')
                    # If multiple constraints, join with |
                    # But mapped bound might already be a union string "A | B"
                    # We need to be careful not to create "A | B | C" if they are distinct

                    final_type = " | ".join(constraints)
                    self.emitter.add_struct(f"type {sanitized_lhs} = {final_type}")
                return

            # Check for type alias: MyType = int or MyType = OtherType or MyType = List[int]
            if self.in_main:
                is_type_alias = False
                type_alias_val = ""

                # Check if LHS is capitalized (heuristic)
                if lhs[0].isupper():
                     # Check if it was inferred by TypeInference (e.g. OrderedCollection = list)
                     if hasattr(self, 'type_inference') and lhs in self.type_inference.type_map:
                          is_type_alias = True
                          type_alias_val = self.type_inference.type_map[lhs]
                     else:
                          # Try to map RHS as a type
                          try:
                              # Unparse RHS to string
                              if hasattr(ast, 'unparse'):
                                  rhs_source = ast.unparse(node.value)
                                  mapped = map_python_type_to_v(rhs_source, allow_union=True)
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
                     self.emitter.add_struct(f"type {lhs} = {type_alias_val}")
                     return

        elif isinstance(target, ast.Attribute):
            # obj.attr = value
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
                    lhs = f"{list_obj}.{target.slice.value}"
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
            tmp = f"_assign_tmp_{self.unique_id_counter}"
            self.unique_id_counter += 1
            self.output.append(f"{self._indent()}{tmp} := {rhs}")

            for t in node.targets:
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
                 self.output.append(f"{self._indent()}// Error: List comprehension support missing")
        elif isinstance(node.value, ast.SetComp):
            # visit_SetComp is defined in ExpressionsMixin, but available on self at runtime
            if hasattr(self, 'visit_SetComp'):
                 self.visit_SetComp(node.value, target_var=lhs) # type: ignore
            else:
                 self.output.append(f"{self._indent()}// Error: Set comprehension support missing")
        elif isinstance(node.value, ast.DictComp):
            # visit_DictComp is defined in ExpressionsMixin, but available on self at runtime
            if hasattr(self, 'visit_DictComp'):
                 self.visit_DictComp(node.value, target_var=lhs) # type: ignore
            else:
                 self.output.append(f"{self._indent()}// Error: Dict comprehension support missing")
        elif isinstance(node.value, ast.GeneratorExp):
            # Treat generator expression as list comprehension (eager evaluation)
            if hasattr(self, 'visit_ListComp'):
                 self.visit_ListComp(node.value, target_var=lhs) # type: ignore
            else:
                 self.output.append(f"{self._indent()}// Error: Generator expression support missing")
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

            if is_simple_list and v_type.startswith("[]") and cap > 0:
                # To initialize V arrays with exact capacities (`[]int{cap: N}`) during assignments like `arr = [x, y, z]`
                # We emit:
                # mut arr := []T{cap: N}
                # arr << x ...
                self.output.append(f"{self._indent()}mut {lhs} := {v_type}{{cap: {cap}}}")
                value_node: Any = node.value
                for elt in value_node.elts:
                    val = self.visit(elt)
                    self.output.append(f"{self._indent()}{lhs} << {val}")
            elif hasattr(self, 'dataclasses') and v_type in self.dataclasses and isinstance(node.value, ast.Dict):
                # TypedDict assignment
                pairs = []
                for k, v in zip(node.value.keys, node.value.values):
                    if isinstance(k, ast.Constant) and isinstance(k.value, str):
                        key_str = k.value
                        val_str = self.visit(v)
                        pairs.append(f"{key_str}: {val_str}")

                rhs = f"{v_type}{{{', '.join(pairs)}}}"
                self.output.append(f"{self._indent()}{lhs} := {rhs}")
            else:
                rhs = self.visit(node.value)

                if rhs == "none":
                    local_v_type = getattr(self, "_guess_type", lambda x: "unknown")(target)
                    if local_v_type and local_v_type != "unknown":
                        if not local_v_type.startswith("?"):
                            local_v_type = f"?{local_v_type}"
                        rhs_expr = f"{local_v_type}(none)"
                    else:
                        rhs_expr = "?Any(none)"

                    if self.in_main and isinstance(target, ast.Name):
                        if lhs in getattr(self, "global_vars", set()):
                            glob_v_type = local_v_type if local_v_type != "unknown" else "Any"
                            self.emitter.add_global(f"{lhs} {glob_v_type}")
                            self.output.append(f"{self._indent()}{lhs} = {rhs_expr}")
                            return
                        elif lhs.isupper():
                            self.emitter.add_constant(f"{lhs} = {rhs_expr}")
                            return

                    self.output.append(f"{self._indent()}mut {lhs} := {rhs_expr}")
                else:
                    if self.in_main and isinstance(target, ast.Name):
                        if lhs in getattr(self, "global_vars", set()):
                            if v_type == "unknown":
                                v_type = "Any"
                            self.emitter.add_global(f"{lhs} {v_type}")
                            self.output.append(f"{self._indent()}{lhs} = {rhs}")
                            return
                        elif lhs.isupper():
                            self.emitter.add_constant(f"{lhs} = {rhs}")
                            return

                    if isinstance(target, ast.Attribute) or isinstance(target, ast.Subscript):
                        self.output.append(f"{self._indent()}{lhs} = {rhs}")
                    else:
                        self.output.append(f"{self._indent()}{lhs} := {rhs}")

    def _visit_destructuring(self, target: ast.AST, source_expr: str) -> None:
        """
        Recursively handles destructuring assignments, including nested tuples/lists.
        target: The AST node for the target (Tuple, List, Name, etc.)
        source_expr: The V expression representing the value to unpack (e.g. `_destruct_0`, `my_list[1]`)
        """
        if isinstance(target, (ast.Tuple, ast.List)):
             # Assign source to a temporary variable to avoid repeated evaluation
             # and allow slicing
             tmp_var = f"_destruct_{self._zip_counter}"
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
            self.output.append(f"{self._indent()}{lhs} := {source_expr}")

        elif isinstance(target, (ast.Attribute, ast.Subscript)):
             lhs = self.visit(target)
             self.output.append(f"{self._indent()}{lhs} = {source_expr}")

        else:
             self.output.append(f"{self._indent()}// Unsupported destructuring target: {type(target)}")

    def _create_temp(self) -> str:
        self.unique_id_counter += 1
        return f"_aug_tmp_{self.unique_id_counter}"

    def _capture_value(self, node: ast.AST) -> tuple[str, list[str]]:
        """
        Captures an expression into a temporary variable if it's not simple (Name/Constant).
        Returns (expr_string, setup_statements).
        """
        if isinstance(node, (ast.Name, ast.Constant)):
            return self.visit(node), []

        tmp = self._create_temp()
        val_code = self.visit(node)
        return tmp, [f"{self._indent()}{tmp} := {val_code}"]

    def _capture_target(self, node: ast.AST) -> tuple[str, list[str]]:
        """
        Prepares a target for AugAssign by capturing its components.
        Recurses on L-value bases (Attribute, Subscript) to preserve reference path.
        Returns (new_target_string, setup_statements).
        """
        if isinstance(node, ast.Name):
            return self.visit(node), []

        elif isinstance(node, ast.Attribute):
            # Recurse on base if it's an L-value container (Name, Attribute, Subscript)
            # Otherwise capture value (Call, etc.)
            if isinstance(node.value, (ast.Name, ast.Attribute, ast.Subscript)):
                base_expr, base_setup = self._capture_target(node.value)
            else:
                base_expr, base_setup = self._capture_value(node.value)

            return f"{base_expr}.{node.attr}", base_setup

        elif isinstance(node, ast.Subscript):
            # Recurse on base if it's an L-value container
            if isinstance(node.value, (ast.Name, ast.Attribute, ast.Subscript)):
                base_expr, base_setup = self._capture_target(node.value)
            else:
                base_expr, base_setup = self._capture_value(node.value)

            idx_node = node.slice
            # Handle Py < 3.9 ast.Index
            if hasattr(ast, "Index") and isinstance(idx_node, getattr(ast, "Index")):
                 idx_node = idx_node.value

            idx_expr, idx_setup = self._capture_value(idx_node)
            return f"{base_expr}[{idx_expr}]", base_setup + idx_setup

        return self.visit(node), [] # Fallback

    def visit_AugAssign(self, node: ast.AugAssign) -> None:
        if isinstance(node.op, (ast.Pow, ast.FloorDiv)):
            # Handle special cases **= and //= which need expansion to target = func(target, value)
            # We must ensure target components (e.g. index) are evaluated once.
            new_target, setup_stmts = self._capture_target(node.target)
            value = self.visit(node.value)

            for stmt in setup_stmts:
                self.output.append(stmt)

            if isinstance(node.op, ast.Pow):
                self.emitter.add_import("math")
                target_type = self._guess_type(node.target) if hasattr(self, '_guess_type') else "unknown"
                if target_type == "int":
                     self.output.append(f"{self._indent()}{new_target} = int(math.pow({new_target}, {value}))")
                else:
                     self.output.append(f"{self._indent()}{new_target} = math.pow({new_target}, {value})")
            elif isinstance(node.op, ast.FloorDiv):
                # //= -> floor division
                # If types are int, use math.floor(f64(a)/f64(b)) cast to int to match Python
                # If types are float, use math.floor(a/b)
                target_type = self._guess_type(node.target) if hasattr(self, '_guess_type') else "unknown"
                self.emitter.add_import("math")
                if target_type == "f64" or target_type == "float":
                     self.output.append(f"{self._indent()}{new_target} = math.floor({new_target} / {value})")
                else:
                     # Integer division (safe floor div)
                     self.output.append(f"{self._indent()}{new_target} = int(math.floor(f64({new_target}) / f64({value})))")
            return

        target = self.visit(node.target)
        value = self.visit(node.value)
        op_map = {
            ast.Add: "+=", ast.Sub: "-=", ast.Mult: "*=", ast.Div: "/=",
            ast.Mod: "%="
        }
        # V supports +=, -=, *=, /=, %=
        op_str = op_map.get(type(node.op))
        if op_str:
             self.output.append(f"{self._indent()}{target} {op_str} {value}")
        elif isinstance(node.op, ast.MatMult):
             self.output.append(f"{self._indent()}{target} = {target}.matmul({value})")
        else:
             self.output.append(f"{self._indent()}// Unsupported AugAssign operator: {type(node.op)}")

    def visit_Delete(self, node: ast.Delete) -> None:
        # Support for multiple delete targets (e.g. del a, b)
        for target in node.targets:
            if isinstance(target, ast.Subscript):
                # del l[i] -> l.delete(i)
                value = self.visit(target.value)
                index = self.visit(target.slice)
                self.output.append(f"{self._indent()}{value}.delete({index})")
            elif isinstance(target, ast.Name):
                self.output.append(f"{self._indent()}/* del {target.id} */")
            elif isinstance(target, ast.Attribute):
                value = self.visit(target.value)
                self.output.append(f"{self._indent()}/* del {value}.{target.attr} */")
            else:
                self.output.append(f"{self._indent()}// del statement with unsupported target type")

    def visit_NamedExpr(self, node: ast.NamedExpr) -> str:
        # (target := value)
        target = node.target.id
        value = self.visit(node.value)
        self._walrus_assignments.append(f"{target} := {value}")
        return target

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
            if hasattr(ast, 'unparse'):
                try:
                    type_str = ast.unparse(node.annotation)
                    v_type = map_python_type_to_v(type_str)
                except Exception:
                    pass

            if not v_type:
                v_type = getattr(self, "_guess_type", lambda x: "unknown")(node.target)

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
                        key_str = k.value
                        val_str = self.visit(v)
                        pairs.append(f"{key_str}: {val_str}")

                rhs = f"{v_type}{{{', '.join(pairs)}}}"
                self.output.append(f"{self._indent()}{target} := {rhs}")
            else:
                rhs = self.visit(node.value)

                is_final = False
                try:
                    if hasattr(ast, 'unparse'):
                        type_str = ast.unparse(node.annotation)
                        if "Final" in type_str:
                            is_final = True
                except Exception:
                    pass

                if rhs == "none":
                    local_v_type = v_type
                    if local_v_type and local_v_type != "unknown":
                        if not local_v_type.startswith("?"):
                            local_v_type = f"?{local_v_type}"
                        rhs_expr = f"{local_v_type}(none)"
                    else:
                        rhs_expr = "?Any(none)"

                    if self.in_main and isinstance(node.target, ast.Name):
                        target_name = target
                        if target_name in getattr(self, "global_vars", set()):
                            glob_v_type = local_v_type if local_v_type != "unknown" else "Any"
                            self.emitter.add_global(f"{target_name} {glob_v_type}")
                            self.output.append(f"{self._indent()}{target_name} = {rhs_expr}")
                            return
                        elif target_name.isupper() or is_final:
                            self.emitter.add_constant(f"{target_name} = {rhs_expr}")
                            return

                    self.output.append(f"{self._indent()}mut {target} := {rhs_expr}")
                else:
                    if self.in_main and isinstance(node.target, ast.Name):
                        target_name = target
                        if target_name in getattr(self, "global_vars", set()):
                            glob_v_type = v_type if v_type and v_type != "unknown" else "Any"
                            self.emitter.add_global(f"{target_name} {glob_v_type}")
                            self.output.append(f"{self._indent()}{target_name} = {rhs}")
                            return
                        elif target_name.isupper() or is_final:
                            self.emitter.add_constant(f"{target_name} = {rhs}")
                            return

                    # We ignore the annotation for now and rely on type inference and V's auto-typing
                    # But we could potentially use it to hint types for empty lists/maps
                    if isinstance(node.target, ast.Attribute) or isinstance(node.target, ast.Subscript):
                        self.output.append(f"{self._indent()}{target} = {rhs}")
                    else:
                        self.output.append(f"{self._indent()}{target} := {rhs}")
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

    def visit_Name(self, node: ast.Name) -> str:
        if node.id in self.name_remap:
            return self.name_remap[node.id]

        # Name mangling for class-private attributes
        return self._mangle_name(node.id, self.current_class)

    def visit_TypeAlias(self, node: Any) -> None:
        name = node.name.id
        type_params = ""

        # Safe access to ast.TypeVar for Py < 3.12 compatibility
        TypeVar = getattr(ast, 'TypeVar', type(None))

        if node.type_params:
            # Handle generics [T, U]
            params = []
            for param in node.type_params:
                if isinstance(param, TypeVar):
                    params.append(param.name)
                # Basic support for TypeVar only for now
            if params:
                type_params = f"[{', '.join(params)}]"

        if hasattr(ast, 'unparse'):
            val_str = ast.unparse(node.value)
            v_type = map_python_type_to_v(val_str, allow_union=True)
            self.emitter.add_struct(f"type {name}{type_params} = {v_type}")
        else:
            self.output.append(f"{self._indent()}// TypeAlias {name} skipped (no ast.unparse)")
