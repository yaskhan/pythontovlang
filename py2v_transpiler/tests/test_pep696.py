import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestPEP696(unittest.TestCase):
    def setUp(self):
        self.inference = TypeInference()
        self.visitor = VNodeVisitor(self.inference)

    def test_class_generic_default(self):
        # class Box[T = int]: pass
        # Manually construct AST for Python 3.13 syntax
        type_param = ast.TypeVar(name='T', default=ast.Name(id='int', ctx=ast.Load()))
        node = ast.ClassDef(
            name='Box',
            bases=[],
            keywords=[],
            body=[ast.Pass()],
            decorator_list=[],
            type_params=[type_param]
        )
        self.visitor.visit(node)
        output = self.visitor.emitter.emit()
        self.assertIn('struct Box[T = int] {', output)

    def test_function_generic_default(self):
        # def foo[T = str](x: T): pass
        type_param = ast.TypeVar(name='T', default=ast.Name(id='str', ctx=ast.Load()))
        node = ast.FunctionDef(
            name='foo',
            args=ast.arguments(
                posonlyargs=[],
                args=[ast.arg(arg='x', annotation=ast.Name(id='T', ctx=ast.Load()))],
                kwonlyargs=[],
                kw_defaults=[],
                defaults=[]
            ),
            body=[ast.Pass()],
            decorator_list=[],
            returns=None,
            type_params=[type_param]
        )
        self.visitor.visit(node)
        output = self.visitor.emitter.emit()
        self.assertIn('fn foo[T = string](x T) {', output)

    def test_type_alias_generic_default(self):
        # type Alias[T = int] = list[T]
        if hasattr(ast, 'TypeAlias'):
            type_param = ast.TypeVar(name='T', default=ast.Name(id='int', ctx=ast.Load()))
            node = ast.TypeAlias(
                name=ast.Name(id='Alias', ctx=ast.Store()),
                type_params=[type_param],
                value=ast.Subscript(
                    value=ast.Name(id='list', ctx=ast.Load()),
                    slice=ast.Name(id='T', ctx=ast.Load()),
                    ctx=ast.Load()
                )
            )
            self.visitor.visit(node)
            output = self.visitor.emitter.emit()
            self.assertIn('type Alias[T = int] = []T', output)

    def test_typevar_call_default(self):
        # T = TypeVar("T", default=int)
        node = ast.Assign(
            targets=[ast.Name(id='T', ctx=ast.Store())],
            value=ast.Call(
                func=ast.Name(id='TypeVar', ctx=ast.Load()),
                args=[ast.Constant(value='T')],
                keywords=[ast.keyword(arg='default', value=ast.Name(id='int', ctx=ast.Load()))]
            )
        )
        self.visitor.visit(node)

        # Now use T in a class
        class_node = ast.ClassDef(
            name='Container',
            bases=[ast.Subscript(
                value=ast.Name(id='Generic', ctx=ast.Load()),
                slice=ast.Name(id='T', ctx=ast.Load()),
                ctx=ast.Load()
            )],
            keywords=[],
            body=[ast.Pass()],
            decorator_list=[],
            type_params=[]
        )
        self.visitor.visit(class_node)
        output = self.visitor.emitter.emit()
        self.assertIn('struct Container[T = int] {', output)

if __name__ == '__main__':
    unittest.main()
