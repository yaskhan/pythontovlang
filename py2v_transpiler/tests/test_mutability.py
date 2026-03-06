import textwrap
import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestMutability:
    def _transpile(self, python_code, mutability_map=None):
        python_code = textwrap.dedent(python_code).strip()
        parser = PyASTParser()
        analyzer = TypeInference()
        tree = parser.parse(python_code)
        analyzer.analyze(tree)

        if mutability_map:
            if not hasattr(analyzer, 'mutability_map'):
                analyzer.mutability_map = {}
            analyzer.mutability_map.update(mutability_map)

        translator = VNodeVisitor(analyzer)
        return translator.visit_Module(tree)

    def test_immutable_variable(self):
        code = """
        def foo():
            x = 1
            return x
        """
        # x is not reassigned
        mut_map = {"x": {"is_reassigned": False, "is_final": False}}
        result = self._transpile(code, mut_map)
        assert "x := 1" in result
        assert "mut x := 1" not in result

    def test_mutable_variable(self):
        code = """
        def foo():
            x = 1
            x = 2
            return x
        """
        # x is reassigned
        mut_map = {"x": {"is_reassigned": True, "is_final": False}}
        result = self._transpile(code, mut_map)
        assert "mut x := 1" in result
        assert "x = 2" in result

    def test_final_variable(self):
        code = """
        from typing import Final
        def foo():
            x: Final = 1
            return x
        """
        # x is final
        mut_map = {"x": {"is_reassigned": False, "is_final": True}}
        result = self._transpile(code, mut_map)
        assert "x := 1" in result
        assert "mut x" not in result

    def test_function_argument_immutable(self):
        code = """
        def foo(x: int):
            return x
        """
        mut_map = {"x": {"is_reassigned": False, "is_final": False}}
        result = self._transpile(code, mut_map)
        assert "fn foo(x int)" in result

    def test_function_argument_mutable(self):
        code = """
        def foo(x: int):
            x = x + 1
            return x
        """
        mut_map = {"x": {"is_reassigned": True, "is_final": False}}
        result = self._transpile(code, mut_map)
        assert "fn foo(mut x int)" in result

    def test_conditional_initialization_mut(self):
        code = """
        def foo(cond: bool):
            if cond:
                x = 1
            else:
                x = 2
            return x
        """
        # x is conditionally initialized, so it is pre-declared as mut
        result = self._transpile(code)
        assert "mut x := ?int(none)" in result

    def test_shadowing_mutability(self):
        code = """
        def foo():
            x = 1
            if True:
                x = 2 # Shadows or reassigns? In Python it reassigns.
            return x
        """
        # Mypy tracks 'x' as reassigned.
        mut_map = {"x": {"is_reassigned": True, "is_final": False}}
        result = self._transpile(code, mut_map)
        assert "mut x := 1" in result
        assert "x = 2" in result

    def test_local_variable_in_loop(self):
        code = """
        def foo():
            for i in range(10):
                x = i
                x = x + 1
        """
        # x is reassigned within the loop.
        # Note: In V, variables declared in loop are local to the loop.
        mut_map = {"x": {"is_reassigned": True, "is_final": False}}
        result = self._transpile(code, mut_map)
        assert "mut x := i" in result
