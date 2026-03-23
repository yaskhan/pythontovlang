from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import textwrap
import ast
import tempfile
import os
from typing import cast

def translate_with_mypy(code: str, parser: PyASTParser, type_inference: TypeInference) -> str:
    """Helper to translate code with Mypy analysis using a temporary file."""
    tree = parser.parse(code)

    with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
        f.write(code)
        temp_path = f.name

    try:
        type_inference.run_mypy(temp_path)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

    visitor = VNodeVisitor(type_inference)
    visitor.visit(tree)
    return visitor.emitter.emit()

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
