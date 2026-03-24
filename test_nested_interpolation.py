from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor
import ast

def test_nested_interpolation_v_code():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    translator.used_builtins.add("py_format")

    # Trigger visit_Module to generate helpers
    translator.visit_Module(ast.parse("pass"))
    helpers = translator.emitter.emit_helpers()

    assert "strconv.format_f64" in helpers
    assert "${val:.${prec}f}" not in helpers
    assert "import strconv" in helpers

if __name__ == "__main__":
    test_nested_interpolation_v_code()
    print("Test passed!")
