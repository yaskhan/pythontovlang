import ast
from ..base import TranslatorBase


class DeleteMixin(TranslatorBase):
    """Обработка оператора del"""
    
    def visit_Delete(self, node: ast.Delete) -> None:
        # Support for multiple delete targets (e.g. del a, b)
        for target in node.targets:
            if isinstance(target, ast.Subscript):
                # del l[i] -> l.delete(i) or l.delete_many(start, count)
                value = self.visit(target.value)

                # Check for slice
                if isinstance(target.slice, ast.Slice):
                    lower = self.visit(target.slice.lower) if target.slice.lower else "0"
                    upper = self.visit(target.slice.upper) if target.slice.upper else f"{value}.len"
                    self.used_delete_many = True
                    self.output.append(f"{self._indent()}{value}.delete_many({lower}, ({upper}) - ({lower}))")
                else:
                    index = self.visit(target.slice)
                    self.output.append(f"{self._indent()}{value}.delete({index})")
            elif isinstance(target, ast.Name):
                self.output.append(f"{self._indent()}//##LLM@@ 'del {target.id}' statement ignored. V does not support deleting variables from scope. Please refactor if this deletion is semantically important.")
            elif isinstance(target, ast.Attribute):
                value = self.visit(target.value)
                self.output.append(f"{self._indent()}//##LLM@@ 'del {value}.{target.attr}' statement ignored. V does not support deleting struct attributes. Please refactor.")
            else:
                self.output.append(f"{self._indent()}//##LLM@@ 'del' statement with unsupported target type. Please manually implement the required deletion logic.")
