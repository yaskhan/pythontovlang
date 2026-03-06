import ast
from typing import Any
from ..base import TranslatorBase

class ExceptionsMixin(TranslatorBase):
    """Обработка исключений: try, except, raise, finally"""
    
    def visit_Raise(self, node: ast.Raise) -> None:
        if self.in_pydantic_validator:
            if node.exc:
                if isinstance(node.exc, ast.Call):
                    msg = ""
                    if node.exc.args:
                        msg = self.visit(node.exc.args[0])
                    self.output.append(f"{self._indent()}return error({msg})")
                elif isinstance(node.exc, ast.Name):
                    self.output.append(f"{self._indent()}return error('{node.exc.id}')")
                else:
                    val = self.visit(node.exc)
                    self.output.append(f"{self._indent()}return error('${{{val}}}')")
            else:
                self.output.append(f"{self._indent()}return error('Validation Error')")
            return

        self.emitter.add_import('div72.vexc')
        if node.exc:
            if isinstance(node.exc, ast.Call):
                 exc_name = self.visit(node.exc.func)
                 msg = ""
                 if node.exc.args:
                      msg = self.visit(node.exc.args[0])
                      # Remove quotes if it's a string literal visit
                      if msg.startswith("'") and msg.endswith("'"):
                           msg = msg[1:-1]
                      elif msg.startswith('"') and msg.endswith('"'):
                           msg = msg[1:-1]
                 self.output.append(f"{self._indent()}vexc.raise('{exc_name}', '{msg}')")
            elif isinstance(node.exc, ast.Name):
                 exc_name = self.visit(node.exc)
                 self.output.append(f"{self._indent()}vexc.raise('{exc_name}', '')")
            else:
                 val = self.visit(node.exc)
                 self.output.append(f"{self._indent()}vexc.raise('Exception', '${{{val}}}')")
        else:
            # Reraise
            self.output.append(f"{self._indent()}if vexc.get_curr_exc().name != '' {{")
            self.output.append(f"{self._indent()}    vexc.raise(vexc.get_curr_exc().name, vexc.get_curr_exc().msg)")
            self.output.append(f"{self._indent()}}} else {{")
            self.output.append(f"{self._indent()}    panic('reraise not supported outside except block')")
            self.output.append(f"{self._indent()}}}")

    def visit_Try(self, node: ast.Try) -> None:
        self.emitter.add_import('div72.vexc')

        # Need to support finally using defer
        if node.finalbody:
            self.finally_stack.append(node)
            # Check if finally block contains continue
            has_continue = False
            for stmt in node.finalbody:
                for sub in ast.walk(stmt):
                    if isinstance(sub, ast.Continue):
                        has_continue = True
                        break
                if has_continue: break

            if has_continue:
                self.output.append(f"{self._indent()}// Warning: 'continue' in 'finally' detected. 'defer' cannot be used.")
            else:
                self.output.append(f"{self._indent()}{{")
                self.output.append(f"{self._indent()}    defer {{")
                self._indent_level += 2
                for stmt in node.finalbody:
                    self.visit(stmt)
                self._indent_level -= 2
                self.output.append(f"{self._indent()}    }}")

        self.vexc_depth += 1
        success_var = f"py_success_{self.unique_id_counter}"
        self.unique_id_counter += 1
        if node.orelse:
            self.output.append(f"{self._indent()}mut {success_var} := false")

        self.output.append(f"{self._indent()}if C.try() {{")
        self._indent_level += 1

        for stmt in node.body:
            self.visit(stmt)

        if node.orelse:
            self.output.append(f"{self._indent()}{success_var} = true")

        self.output.append(f"{self._indent()}vexc.end_try()")
        self._indent_level -= 1
        self.vexc_depth -= 1
        self.output.append(f"{self._indent()}}} else {{")
        self._indent_level += 1

        if node.handlers:
             exc_var = f"py_exc_{self.unique_id_counter}"
             self.unique_id_counter += 1
             self.output.append(f"{self._indent()}{exc_var} := vexc.get_curr_exc()")

             is_first = True
             has_default = False

             for handler in node.handlers:
                 type_str = ""
                 if handler.type:
                     if isinstance(handler.type, ast.Tuple):
                         type_str = " || ".join([f"{exc_var}.name == '{self.visit(t)}'" for t in handler.type.elts])
                     else:
                         type_str = f"{exc_var}.name == '{str(self.visit(handler.type))}'"
                 else:
                     has_default = True

                 handler_opened_block = True
                 if has_default:
                      prefix = "else" if not is_first else ""
                      if prefix:
                           self.output.append(f"{self._indent()}{prefix} {{")
                      else:
                           handler_opened_block = False
                 else:
                      prefix = "if" if is_first else "else if"
                      self.output.append(f"{self._indent()}{prefix} {type_str} {{")

                 if handler_opened_block:
                      self._indent_level += 1
                 if handler.name:
                      self.output.append(f"{self._indent()}{handler.name} := {exc_var}")

                 for stmt in handler.body:
                      self.visit(stmt)

                 if handler_opened_block:
                      self._indent_level -= 1
                      self.output.append(f"{self._indent()}}}")

                 is_first = False
                 if has_default: break

             if not has_default:
                  self.output.append(f"{self._indent()}else {{")
                  self.output.append(f"{self._indent()}    vexc.raise({exc_var}.name, {exc_var}.msg)")
                  self.output.append(f"{self._indent()}}}")
        else:
             # Just try/finally
             self.output.append(f"{self._indent()}py_exc := vexc.get_curr_exc()")
             self.output.append(f"{self._indent()}vexc.raise(py_exc.name, py_exc.msg)")

        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

        if node.orelse:
            self.output.append(f"{self._indent()}if {success_var} {{")
            self._indent_level += 1
            for stmt in node.orelse:
                self.visit(stmt)
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

        if node.finalbody:
            self.finally_stack.pop()
            if not has_continue:
                 self.output.append(f"{self._indent()}}}")
            else:
                 # Inlining finally block
                 for stmt in node.finalbody:
                     self.in_finally = True
                     self.visit(stmt)
                     self.in_finally = False

    # V does not natively support Python exception groups (PEP 654).
    # Since PEP 758 allows bracketless except*, we alias TryStar to Try
    # so that basic exception handling can still happen rather than crashing.
    # Note: ast.TryStar is only available in Python 3.11+.
    # We use Any to avoid AttributeError on older versions during class definition.
    def visit_TryStar(self, node: Any) -> None:
        return self.visit_Try(node)  # type: ignore[arg-type]
