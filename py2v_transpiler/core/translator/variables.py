import ast
from typing import Optional
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
                             mapped_base = map_python_type_to_v(base_str)
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
                     # Try to map RHS as a type
                     try:
                         # Unparse RHS to string
                         if hasattr(ast, 'unparse'):
                             rhs_source = ast.unparse(node.value)
                             mapped = map_python_type_to_v(rhs_source)
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
            lhs = f"{self.visit(target.value)}.{target.attr}"
        elif isinstance(target, ast.Subscript):
            # list[index] = value
            lhs = self.visit(target)
        elif isinstance(target, (ast.Tuple, ast.List)):
             # Destructuring assignment
             rhs = self.visit(node.value)

             # Optimization: If simple unpacking a, b = 1, 2 (RHS is Tuple/List literal) and no starred elements
             has_starred = any(isinstance(elt, ast.Starred) for elt in target.elts)
             if not has_starred and isinstance(node.value, (ast.Tuple, ast.List)) and len(node.value.elts) == len(target.elts):
                  lhs_parts = [self.visit(t) for t in target.elts]
                  rhs_parts = [self.visit(v) for v in node.value.elts]
                  # Use := for all? Or check? Assuming declarations for simplicity as per existing logic
                  self.output.append(f"{self._indent()}{', '.join(lhs_parts)} := {', '.join(rhs_parts)}")
                  return

             # General case: a, *b = l OR a, b = l
             # Assign RHS to temp var
             tmp_var = f"_destruct_{self._zip_counter}"
             self._zip_counter += 1
             self.output.append(f"{self._indent()}{tmp_var} := {rhs}")

             starred_idx = -1
             for i, elt in enumerate(target.elts):
                 if isinstance(elt, ast.Starred):
                     starred_idx = i
                     break

             if starred_idx == -1:
                 # Simple unpacking: a, b = l
                 for i, elt in enumerate(target.elts):
                     lhs_elt = self.visit(elt)
                     op = "=" if isinstance(elt, (ast.Attribute, ast.Subscript)) else ":="
                     self.output.append(f"{self._indent()}{lhs_elt} {op} {tmp_var}[{i}]")
             else:
                 # Starred unpacking
                 # Pre-star
                 for i in range(starred_idx):
                     elt = target.elts[i]
                     lhs_elt = self.visit(elt)
                     op = "=" if isinstance(elt, (ast.Attribute, ast.Subscript)) else ":="
                     self.output.append(f"{self._indent()}{lhs_elt} {op} {tmp_var}[{i}]")

                 # Star
                 star_elt = target.elts[starred_idx]
                 if isinstance(star_elt, ast.Starred):
                     lhs_star = self.visit(star_elt.value)
                     op = "=" if isinstance(star_elt.value, (ast.Attribute, ast.Subscript)) else ":="
                     # Slice: start = starred_idx, end = len - (total - 1 - starred_idx)
                     trailing = len(target.elts) - 1 - starred_idx
                     if trailing == 0:
                          self.output.append(f"{self._indent()}{lhs_star} {op} {tmp_var}[{starred_idx}..]")
                     else:
                          self.output.append(f"{self._indent()}{lhs_star} {op} {tmp_var}[{starred_idx}..{tmp_var}.len-{trailing}]")

                 # Post-star
                 for i in range(starred_idx + 1, len(target.elts)):
                     elt = target.elts[i]
                     lhs_elt = self.visit(elt)
                     op = "=" if isinstance(elt, (ast.Attribute, ast.Subscript)) else ":="
                     offset = len(target.elts) - i
                     self.output.append(f"{self._indent()}{lhs_elt} {op} {tmp_var}[{tmp_var}.len-{offset}]")

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
            rhs = self.visit(node.value)
            self.output.append(f"{self._indent()}{lhs} := {rhs}")

    def visit_AugAssign(self, node: ast.AugAssign) -> None:
        target = self.visit(node.target)
        value = self.visit(node.value)
        op_map = {
            ast.Add: "+=", ast.Sub: "-=", ast.Mult: "*=", ast.Div: "/=",
            ast.Mod: "%="
        }
        # V supports +=, -=, *=, /=, %=
        # V does not support **= (must use math.pow or similar, which is not AugAssign compatible directly)
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
            rhs = self.visit(node.value)
            # We ignore the annotation for now and rely on type inference and V's auto-typing
            # But we could potentially use it to hint types for empty lists/maps
            self.output.append(f"{self._indent()}{target} := {rhs}")
        else:
            # Declaration only: x: int
            # V needs initialization.
            self.output.append(f"{self._indent()}// {target} declared (annotation ignored)")

    def visit_Name(self, node: ast.Name) -> str:
        if node.id in self.name_remap:
            return self.name_remap[node.id]
        return node.id
