import ast
from ..base import TranslatorBase

class ControlMixin(TranslatorBase):
    """Обработка операторов управления: break, continue"""
    
    def visit_Break(self, node: ast.Break) -> None:
        if self.loop_stack:
            current_loop = self.loop_stack[-1]
            if 'flag' in current_loop:
                flag = current_loop['flag']
                self.output.append(f"{self._indent()}{flag} = false")

            target_depth = current_loop.get('vexc_depth', 0)
            diff = self.vexc_depth - target_depth
            for _ in range(diff):
                 self.output.append(f"{self._indent()}vexc.end_try()")
        else:
            for _ in range(self.vexc_depth):
                 self.output.append(f"{self._indent()}vexc.end_try()")

        self.output.append(f"{self._indent()}break")

    def visit_Continue(self, node: ast.Continue) -> None:
        if getattr(self, 'in_finally', False):
             # We are inside a finally block.
             # V `defer` cannot contain `continue`.
             # Emit warning or handle specially.
             pass

        if self.loop_stack:
            current_loop = self.loop_stack[-1]
            target_depth = current_loop.get('vexc_depth', 0)
            diff = self.vexc_depth - target_depth
            for _ in range(diff):
                 self.output.append(f"{self._indent()}vexc.end_try()")
        else:
            for _ in range(self.vexc_depth):
                 self.output.append(f"{self._indent()}vexc.end_try()")

        self.output.append(f"{self._indent()}continue")
