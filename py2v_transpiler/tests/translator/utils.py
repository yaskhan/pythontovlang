from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import textwrap
import ast
from typing import cast

class TranspilerTest:
    def assert_transpilation(self, python_code: str, v_code: str):
        python_code = textwrap.dedent(python_code).strip()
        v_code = textwrap.dedent(v_code).strip()

        parser = PyASTParser()
        analyzer = TypeInference()
        tree = parser.parse(python_code)
        analyzer.analyze(tree)
        translator = VNodeVisitor(analyzer)

        translator.visit_Module(cast(ast.Module, tree))
        result = translator.emitter.emit() + "\n" + translator.emitter.emit_helpers()

        # Normalize whitespace for comparison
        result = self._normalize(result)
        expected = self._normalize(v_code)

        if expected not in result:
             print(f"FAILED. \nExpected:\n{expected}\n\nGot:\n{result}")
        assert expected in result

    def _normalize(self, code: str) -> str:
        lines = [line.strip() for line in code.splitlines() if line.strip()]
        return "\n".join(lines)
