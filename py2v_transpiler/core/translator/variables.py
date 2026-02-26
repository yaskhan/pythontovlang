import ast
from typing import Optional
from py2v_transpiler.models.v_types import map_python_type_to_v
from .base import TranslatorBase

class VariablesMixin(TranslatorBase):
    def visit_Assign(self, node: ast.Assign) -> None:
        targets = node.targets

        if len(targets) == 1:
            # Single assignment logic (merged from main)
            target = targets[0]
            lhs = ""
            if isinstance(target, ast.Name):
                lhs = target.id

                # Check for NewType: UserId = NewType('UserId', int)
                if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "NewType":
                    if len(node.value.args) == 2:
                        try:
                            if hasattr(ast, 'unparse'):
                                 base_str = ast.unparse(node.value.args[1])
                                 mapped_base = map_python_type_to_v(base_str)
                                 self.emitter.add_struct(f"type {lhs} = {mapped_base}")
                                 return
                        except:
                            pass

                # Check for TypeVar: T = TypeVar("T", int, str)
                if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "TypeVar":
                    constraints = []
                    for arg in node.value.args[1:]:
                        if isinstance(arg, ast.Name):
                            constraints.append(map_python_type_to_v(arg.id))
                        elif isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                            constraints.append(map_python_type_to_v(arg.value))

                    for kw in node.value.keywords:
                        if kw.arg == "bound":
                             try:
                                 bound_str = ast.unparse(kw.value)
                                 mapped = map_python_type_to_v(bound_str)
                                 constraints.append(mapped)
                             except:
                                 pass

                    if constraints:
                        sanitized_lhs = lhs.lstrip('_')
                        final_type = " | ".join(constraints)
                        self.emitter.add_struct(f"type {sanitized_lhs} = {final_type}")
                    return

                # Check for type alias
                if self.in_main:
                    is_type_alias = False
                    type_alias_val = ""
                    if lhs[0].isupper():
                         try:
                             if hasattr(ast, 'unparse'):
                                 rhs_source = ast.unparse(node.value)
                                 mapped = map_python_type_to_v(rhs_source)
                                 if mapped != "void" and mapped != rhs_source:
                                      is_type_alias = True
                                      type_alias_val = mapped
                                 elif mapped == "int" and rhs_source == "int": is_type_alias = True; type_alias_val = "int"
                                 elif mapped == "f64" and rhs_source == "float": is_type_alias = True; type_alias_val = "f64"
                                 elif mapped == "string" and rhs_source == "str": is_type_alias = True; type_alias_val = "string"
                                 elif mapped == "bool" and rhs_source == "bool": is_type_alias = True; type_alias_val = "bool"
                                 elif isinstance(node.value, ast.Name) and node.value.id[0].isupper():
                                      is_type_alias = True
                                      type_alias_val = node.value.id
                         except:
                             pass

                    if is_type_alias:
                         self.emitter.add_struct(f"type {lhs} = {type_alias_val}")
                         return

            elif isinstance(target, ast.Attribute):
                # obj.attr = value
                # Check for function attribute assignment
                obj_name = self.visit(target.value)
                if hasattr(self, 'function_names') and obj_name in self.function_names:
                     lhs = f"{obj_name}__{target.attr}"
                else:
                     lhs = f"{obj_name}.{target.attr}"
            elif isinstance(target, ast.Subscript):
                # list[index] = value
                # Check for slice assignment: l[1:3] = [4, 5]
                if isinstance(target.slice, ast.Slice):
                    list_obj = self.visit(target.value)
                    lower = self.visit(target.slice.lower) if target.slice.lower else "0"
                    upper = self.visit(target.slice.upper) if target.slice.upper else f"{list_obj}.len"

                    rhs = self.visit(node.value)
                    start_expr = lower
                    end_expr = upper

                    self.output.append(f"{self._indent()}{list_obj}.delete_many({start_expr}, ({end_expr}) - ({start_expr}))")
                    self.output.append(f"{self._indent()}{list_obj}.insert_many({start_expr}, {rhs})")
                    return

                lhs = self.visit(target)
            elif isinstance(target, (ast.Tuple, ast.List)):
                 rhs = self.visit(node.value)
                 def is_simple(targets):
                     return not any(isinstance(elt, (ast.Tuple, ast.List, ast.Starred)) for elt in targets)

                 if is_simple(target.elts) and isinstance(node.value, (ast.Tuple, ast.List)) and len(node.value.elts) == len(target.elts):
                      lhs_parts = [self.visit(t) for t in target.elts]
                      rhs_parts = [self.visit(v) for v in node.value.elts]
                      self.output.append(f"{self._indent()}{', '.join(lhs_parts)} := {', '.join(rhs_parts)}")
                      return

                 self._visit_destructuring(target, rhs)
                 return

            if not lhs:
                 return

            # Assignment generation
            if isinstance(node.value, ast.ListComp):
                if hasattr(self, 'visit_ListComp'): self.visit_ListComp(node.value, target_var=lhs) # type: ignore
                else: self.output.append(f"{self._indent()}// Error: List comprehension support missing")
            elif isinstance(node.value, ast.SetComp):
                if hasattr(self, 'visit_SetComp'): self.visit_SetComp(node.value, target_var=lhs) # type: ignore
                else: self.output.append(f"{self._indent()}// Error: Set comprehension support missing")
            elif isinstance(node.value, ast.DictComp):
                if hasattr(self, 'visit_DictComp'): self.visit_DictComp(node.value, target_var=lhs) # type: ignore
                else: self.output.append(f"{self._indent()}// Error: Dict comprehension support missing")
            elif isinstance(node.value, ast.GeneratorExp):
                if hasattr(self, 'visit_ListComp'): self.visit_ListComp(node.value, target_var=lhs) # type: ignore
                else: self.output.append(f"{self._indent()}// Error: Generator expression support missing")
            else:
                rhs = self.visit(node.value)
                self.output.append(f"{self._indent()}{lhs} := {rhs}")

        else:
            # Chained assignment: a = b = 1
            rhs = self.visit(node.value)
            self._zip_counter += 1
            temp_var = f"_assign_tmp_{self._zip_counter}"
            self.output.append(f"{self._indent()}{temp_var} := {rhs}")

            for target in targets:
                if isinstance(target, ast.Name):
                    lhs = target.id
                    self.output.append(f"{self._indent()}{lhs} := {temp_var}")
                elif isinstance(target, ast.Attribute):
                    obj_name = self.visit(target.value)
                    if hasattr(self, 'function_names') and obj_name in self.function_names:
                         lhs = f"{obj_name}__{target.attr}"
                    else:
                         lhs = f"{obj_name}.{target.attr}"
                    self.output.append(f"{self._indent()}{lhs} = {temp_var}")
                elif isinstance(target, ast.Subscript):
                    if isinstance(target.slice, ast.Slice):
                        # Slice assignment logic using temp_var
                        list_obj = self.visit(target.value)
                        lower = self.visit(target.slice.lower) if target.slice.lower else "0"
                        upper = self.visit(target.slice.upper) if target.slice.upper else f"{list_obj}.len"
                        start_expr = lower
                        end_expr = upper
                        self.output.append(f"{self._indent()}{list_obj}.delete_many({start_expr}, ({end_expr}) - ({start_expr}))")
                        self.output.append(f"{self._indent()}{list_obj}.insert_many({start_expr}, {temp_var})")
                    else:
                        lhs = self.visit(target)
                        self.output.append(f"{self._indent()}{lhs} = {temp_var}")
                elif isinstance(target, (ast.Tuple, ast.List)):
                     self._visit_destructuring(target, temp_var)
                else:
                     self.output.append(f"{self._indent()}// Unsupported target in chained assignment")


    def _visit_destructuring(self, target: ast.AST, source_expr: str) -> None:
        """
        Recursively handles destructuring assignments, including nested tuples/lists.
        target: The AST node for the target (Tuple, List, Name, etc.)
        source_expr: The V expression representing the value to unpack (e.g. `_destruct_0`, `my_list[1]`)
        """
        if isinstance(target, (ast.Tuple, ast.List)):
             tmp_var = f"_destruct_{self._zip_counter}"
             self._zip_counter += 1
             self.output.append(f"{self._indent()}{tmp_var} := {source_expr}")

             starred_idx = -1
             for i, elt in enumerate(target.elts):
                 if isinstance(elt, ast.Starred):
                     starred_idx = i
                     break

             if starred_idx == -1:
                 for i, elt in enumerate(target.elts):
                     self._visit_destructuring(elt, f"{tmp_var}[{i}]")
             else:
                 for i in range(starred_idx):
                     elt = target.elts[i]
                     self._visit_destructuring(elt, f"{tmp_var}[{i}]")

                 star_elt = target.elts[starred_idx]
                 if isinstance(star_elt, ast.Starred):
                     trailing = len(target.elts) - 1 - starred_idx
                     slice_expr = ""
                     if trailing == 0:
                          slice_expr = f"{tmp_var}[{starred_idx}..]"
                     else:
                          slice_expr = f"{tmp_var}[{starred_idx}..{tmp_var}.len-{trailing}]"

                     self._visit_destructuring(star_elt.value, slice_expr)

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

    def visit_AugAssign(self, node: ast.AugAssign) -> None:
        target = self.visit(node.target)
        value = self.visit(node.value)
        op_map = {
            ast.Add: "+=", ast.Sub: "-=", ast.Mult: "*=", ast.Div: "/=",
            ast.Mod: "%="
        }
        op_str = op_map.get(type(node.op))
        if op_str:
             self.output.append(f"{self._indent()}{target} {op_str} {value}")
        elif isinstance(node.op, ast.MatMult):
             self.output.append(f"{self._indent()}{target} = {target}.matmul({value})")
        else:
             self.output.append(f"{self._indent()}// Unsupported AugAssign operator: {type(node.op)}")

    def visit_Delete(self, node: ast.Delete) -> None:
        for target in node.targets:
            if isinstance(target, ast.Subscript):
                if isinstance(target.slice, ast.Slice):
                    # Slice deletion logic
                    value = self.visit(target.value)
                    lower = target.slice.lower
                    upper = target.slice.upper
                    start_val = "0"
                    if lower: start_val = self.visit(lower)

                    if upper:
                        end_val = self.visit(upper)
                        count_expr = f"{end_val} - {start_val}"
                    else:
                        count_expr = f"{value}.len - {start_val}"

                    self.output.append(f"{self._indent()}{value}.delete_many({start_val}, {count_expr})")
                else:
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
        target = node.target.id
        value = self.visit(node.value)
        self._walrus_assignments.append(f"{target} := {value}")
        return target

    def visit_AnnAssign(self, node: ast.AnnAssign) -> None:
        target = self.visit(node.target)
        if node.value:
            rhs = self.visit(node.value)
            self.output.append(f"{self._indent()}{target} := {rhs}")
        else:
            try:
                type_str = ast.unparse(node.annotation)
                v_type = map_python_type_to_v(type_str)
                default_val = "0"
                if v_type == "int": default_val = "0"
                elif v_type == "f64": default_val = "0.0"
                elif v_type == "bool": default_val = "false"
                elif v_type == "string": default_val = "''"
                elif v_type.startswith("[]"): default_val = f"{v_type}{{}}"
                elif v_type.startswith("map["): default_val = f"{v_type}{{}}"
                elif v_type.startswith("?"): default_val = "none"
                else:
                    pass

                self.output.append(f"{self._indent()}{target} := {default_val}")
            except:
                self.output.append(f"{self._indent()}// {target} declared (annotation processing failed)")

    def visit_Name(self, node: ast.Name) -> str:
        if node.id in self.name_remap:
            return self.name_remap[node.id]
        return self._mangle_name(node.id, self.current_class)
