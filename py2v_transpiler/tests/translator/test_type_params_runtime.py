
import unittest
import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestTypeParamsRuntime(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        # Clear emitter for each call
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_class_type_params(self):
        source = """
class MyGeneric[T, U]:
    pass

print(MyGeneric.__type_params__)
"""
        result = self.transpile(source)
        self.assertIn("['T', 'U']", result)

    def test_function_type_params(self):
        source = """
def my_func[T](x: T):
    pass

print(my_func.__type_params__)
"""
        result = self.transpile(source)
        self.assertIn("['T']", result)

    def test_specialized_class_type_params(self):
        source = """
class G[T]:
    pass

print(G[int].__type_params__)
"""
        result = self.transpile(source)
        self.assertIn("['T']", result)

    def test_type_alias_type_params(self):
        source = """
type MyAlias[T] = list[T]
print(MyAlias.__type_params__)
"""
        result = self.transpile(source)
        self.assertIn("['T']", result)

    def test_no_type_params(self):
        source = """
class Normal:
    pass

def normal_func(x):
    pass

print(Normal.__type_params__)
print(normal_func.__type_params__)
"""
        result = self.transpile(source)
        self.assertIn("[]string{}", result)

if __name__ == "__main__":
    unittest.main()
