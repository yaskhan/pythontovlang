import ast
from py2v_transpiler.core.translator.expressions_split.calls import CallsMixin
from py2v_transpiler.core.translator.expressions_split.calls_generators import GeneratorCallsMixin
from py2v_transpiler.core.translator.base_split.state import TranslatorStateMixin

class MockTranslator(CallsMixin, GeneratorCallsMixin, TranslatorStateMixin):
    def __init__(self):
        super().__init__(type_inference=None)
        self.class_hierarchy = {
            "Dog": ["Animal"],
            "Cat": ["Animal"],
            "Animal": ["object"],
        }

    def visit(self, node):
        if isinstance(node, ast.Name):
            return node.id
        return "Unknown"

    def _to_snake_case(self, name):
        return name

def test_issubclass_static_true():
    t = MockTranslator()
    node = ast.Call(
        func=ast.Name(id="issubclass", ctx=ast.Load()),
        args=[ast.Name(id="Dog", ctx=ast.Load()), ast.Name(id="Animal", ctx=ast.Load())],
        keywords=[]
    )
    result = t._handle_issubclass(node, ["Dog", "Animal"])
    assert result == "/* issubclass(Dog, Animal) */ true"

def test_issubclass_static_false():
    t = MockTranslator()
    node = ast.Call(
        func=ast.Name(id="issubclass", ctx=ast.Load()),
        args=[ast.Name(id="Dog", ctx=ast.Load()), ast.Name(id="Cat", ctx=ast.Load())],
        keywords=[]
    )
    result = t._handle_issubclass(node, ["Dog", "Cat"])
    assert result == "/* issubclass(Dog, Cat) */ false"

def test_issubclass_dynamic():
    t = MockTranslator()
    node = ast.Call(
        func=ast.Name(id="issubclass", ctx=ast.Load()),
        args=[ast.Name(id="UnknownClass", ctx=ast.Load()), ast.Name(id="Animal", ctx=ast.Load())],
        keywords=[]
    )
    result = t._handle_issubclass(node, ["UnknownClass", "Animal"])
    assert result == "/* //##LLM@@ issubclass(UnknownClass, Animal) - dynamic check not supported */ false"

def test_issubclass_tuple():
    t = MockTranslator()
    node = ast.Call(
        func=ast.Name(id="issubclass", ctx=ast.Load()),
        args=[
            ast.Name(id="Dog", ctx=ast.Load()),
            ast.Tuple(elts=[ast.Name(id="Cat", ctx=ast.Load()), ast.Name(id="Animal", ctx=ast.Load())])
        ],
        keywords=[]
    )
    result = t._handle_issubclass(node, ["Dog", "TupleArg"])
    assert result == "(/* issubclass(Dog, Cat) */ false || /* issubclass(Dog, Animal) */ true)"
