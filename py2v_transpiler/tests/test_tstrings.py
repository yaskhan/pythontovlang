import unittest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def transpile_code(source_code: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source_code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(tree)

class TestTStrings(unittest.TestCase):
    def test_basic_tstring(self):
        code = 't"hello"'
        v_code = transpile_code(code)
        self.assertIn("Template{strings: ['hello'], interpolations: []}", v_code)

    def test_interpolation(self):
        code = 'name = "world"\nt"hello {name}"'
        v_code = transpile_code(code)
        self.assertIn("Template{strings: ['hello ', ''], interpolations: [Interpolation{value: name, expression: 'name', conversion: none, format_spec: ''}]}", v_code)

    def test_multiple_interpolations(self):
        code = 't"{a} {b}"'
        v_code = transpile_code(code)
        self.assertIn("Template{strings: ['', ' ', ''], interpolations: [Interpolation{value: a, expression: 'a', conversion: none, format_spec: ''}, Interpolation{value: b, expression: 'b', conversion: none, format_spec: ''}]}", v_code)

    def test_conversions(self):
        code = 't"{x!r} {y!s} {z!a}"'
        v_code = transpile_code(code)
        self.assertIn("conversion: 'r'", v_code)
        self.assertIn("conversion: 's'", v_code)
        self.assertIn("conversion: 'a'", v_code)

    def test_format_spec(self):
        code = 't"{x:.2f}"'
        v_code = transpile_code(code)
        self.assertIn("format_spec: '.2f'", v_code)

    def test_debug_specifier(self):
        code = 't"{x=}"'
        v_code = transpile_code(code)
        # PEP 750: t"{x=}" is t"x={x!r}"
        self.assertIn("strings: ['x=', '']", v_code)
        self.assertIn("conversion: 'r'", v_code)

    def test_raw_tstring(self):
        code = 'rt"hello\\n{x}"'
        v_code = transpile_code(code)
        self.assertIn("strings: ['hello\\n', '']", v_code)

    def test_concatenation(self):
        code = 't"a" + t"b"'
        v_code = transpile_code(code)
        self.assertIn(" + ", v_code)

if __name__ == "__main__":
    unittest.main()
