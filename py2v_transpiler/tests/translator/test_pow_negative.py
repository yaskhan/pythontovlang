from py2v_transpiler.core.translator.expressions import ExpressionsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.analyzer import TypeInference
import ast

class MockEmitter:
    def __init__(self):
        self.imports = set()
    def add_import(self, module):
        self.imports.add(module)

class TestTranslator(ExpressionsMixin, LiteralsMixin):
    def __init__(self, emitter, type_inference):
        self.output = []
        self.emitter = emitter
        self.type_inference = type_inference
        self.imported_modules = {}
        self.imported_symbols = {}
        self.renamed_functions = {}
        self.used_builtins = set()
        self.function_names = set()
        self.current_class = None
        self.current_class_bases = []
        self.mapper = None
        self._indent_level = 0
        self.coroutine_handler = None
        self.loop_stack = []
        self.name_remap = {}

    def _indent(self):
        return "    " * self._indent_level

    def _mangle_name(self, name, class_name):
        return name

    def visit(self, node):
        return super().visit(node)

    def _guess_type(self, node):
         if isinstance(node, ast.Constant):
             if isinstance(node.value, int): return "int"
             if isinstance(node.value, float): return "f64"
             if isinstance(node.value, str): return "string"
         elif isinstance(node, ast.Name):
            # If not in type map, assume int for test simplicity or check default
            resolved = self.type_inference.resolve_type(node)
            if resolved == "void": return "int" # Fallback to int if unknown
            return resolved
         return "int"

    def visit_Name(self, node: ast.Name):
        return node.id

def translate_expr(expr_str):
    tree = ast.parse(expr_str).body[0].value
    emitter = MockEmitter()
    analyzer = TypeInference()
    analyzer.analyze(ast.parse(expr_str))
    translator = TestTranslator(emitter=emitter, type_inference=analyzer)
    return translator.visit(tree)

def translate_stmt_expr(code, stmt_index):
    tree = ast.parse(code)
    emitter = MockEmitter()
    analyzer = TypeInference()
    analyzer.analyze(tree)
    # Manually seed type for 'n' since analyzer is limited and tests rely on inference
    # In a real run, inference might be better or worse, but here we want to test expression generation logic given types.
    if 'n' in code:
        analyzer.type_map['n'] = 'int'

    translator = TestTranslator(emitter=emitter, type_inference=analyzer)
    expr_node = tree.body[stmt_index].value
    return translator.visit(expr_node)

def test_pow_negative_literal():
    # 2 ** -1 -> math.pow(f64(2), f64(-1))
    assert translate_expr("2 ** -1") == "math.pow(f64(2), f64(-1))"

    # 2 ** -2 -> math.pow(f64(2), f64(-2))
    assert translate_expr("2 ** -2") == "math.pow(f64(2), f64(-2))"

def test_pow_float_base_negative_exponent():
    # 2.0 ** -1 -> math.pow(2.0, f64(-1))
    assert translate_expr("2.0 ** -1") == "math.pow(2.0, f64(-1))"

def test_pow_positive_literal():
    # 2 ** 2 -> math.powi(2, 2)
    assert translate_expr("2 ** 2") == "math.powi(2, 2)"

def test_pow_variable_exponent():
    # n = -1; 2 ** n -> math.powi(2, n) (current limitation)
    # n is int, 2 is int.
    code = "n = -1\n2 ** n"
    assert translate_stmt_expr(code, 1) == "math.powi(2, n)"

def test_pow_float_base_variable_exponent():
    # n = -1; 2.0 ** n
    # left f64, right int.
    # is_float_op = True.
    # left is f64 -> l_val = 2.0
    # right is int -> r_val = f64(n)
    code = "n = -1\n2.0 ** n"
    assert translate_stmt_expr(code, 1) == "math.pow(2.0, f64(n))"
