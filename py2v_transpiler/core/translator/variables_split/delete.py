import ast
from ..base import TranslatorBase


class DeleteMixin(TranslatorBase):
    """Обработка оператора del"""
    
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
