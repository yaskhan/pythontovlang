import ast
from py2v_transpiler.tests.translator.utils import TranspilerTest
from py2v_transpiler.models.v_types import map_python_type_to_v
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestTypeNarrowing(TranspilerTest):
    def test_attribute_narrowing(self):
        code = """
class Base:
    pass

class Derived(Base):
    def derived_method(self) -> int:
        return 1

def test_func(obj: Base):
    if isinstance(obj, Derived):
        return obj.derived_method()
"""
        type_inference = TypeInference()
        # Mock what the mypy plugin would give us
        # obj.derived_method() is at line 10, col 15
        type_inference.type_map["obj"] = "Base"
        # However, at line 12, obj is narrowed to Derived
        type_inference.type_map["obj@12:15"] = "Derived"

        translator = VNodeVisitor(type_inference)
        tree = ast.parse(code)

        # Debug the AST node to find the exact line and col offset
        for node in ast.walk(tree):
            if isinstance(node, ast.Attribute) and node.attr == "derived_method":
                type_inference.type_map[f"obj@{node.value.lineno}:{node.value.col_offset}"] = "Derived"

        translator.visit(tree)
        v_code = translator.emitter.emit()

        # In V, obj.derived_method() should either cast it, or use the narrowed type
        # E.g. (obj as Derived).derived_method()
        assert "as Derived" in v_code

    def test_descriptor_narrowing(self):
        code = """
class Descriptor:
    def __get__(self, instance, owner) -> int:
        return 42

class MyClass:
    desc = Descriptor()

def test_func():
    m = MyClass()
    return m.desc
"""
        type_inference = TypeInference()

        translator = VNodeVisitor(type_inference)
        tree = ast.parse(code)

        type_inference.type_map["m"] = "MyClass"
        type_inference.type_map["MyClass.desc"] = "int" # Since it is a descriptor with __get__ returning int

        for node in ast.walk(tree):
            if isinstance(node, ast.Attribute) and node.attr == "desc":
                type_inference.type_map[f"{node.value.id}@{node.value.lineno}:{node.value.col_offset}"] = "MyClass"

        translator.visit(tree)
        v_code = translator.emitter.emit()

        # V transpilations of descriptors that have a different returned type
        # should map to the property getter call instead of simple field access,
        # but in Python "m.desc" just calls __get__.
        # For now let's just assert that narrowing doesn't crash and we get 'm.desc'
        assert "m.desc" in v_code

    def test_mutation_invalidates_narrowing(self):
        code = """
def test(x: str | int):
    if isinstance(x, str):
        print(x.upper())
        x = 1
        print(x + 1)
"""
        type_inference = TypeInference()
        # Mock narrowing
        # x.upper() at line 4:14
        type_inference.type_map["x@4:14"] = "string"
        # x = 1 at line 5:8
        # print(x+1) at line 6:14
        type_inference.type_map["x"] = "str | int"

        translator = VNodeVisitor(type_inference)
        tree = ast.parse(code)

        # Manually set locations for the mock to work correctly
        for node in ast.walk(tree):
            if isinstance(node, ast.Name) and node.id == "x":
                if node.lineno == 4:
                    type_inference.type_map[f"x@{node.lineno}:{node.col_offset}"] = "string"

        translator.visit(tree)
        v_code = translator.emitter.emit()

        # First print should have cast or narrowing
        assert "(narrowed_x as string).upper()" in v_code
        # Second print should NOT have string cast
        assert "(narrowed_x as string) + 1" not in v_code
        assert "x + 1" in v_code

if __name__ == '__main__':
    import unittest
    unittest.main()
