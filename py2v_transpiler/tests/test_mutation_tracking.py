
import textwrap
import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestMutationTracking:
    def _transpile(self, python_code):
        python_code = textwrap.dedent(python_code).strip()
        parser = PyASTParser()
        analyzer = TypeInference()
        tree = parser.parse(python_code)
        analyzer.analyze(tree)
        translator = VNodeVisitor(analyzer)
        return translator.visit_Module(tree)

    def test_dict_del_mutability(self):
        code = """
        def foo():
            d = {'a': 1}
            del d['a']
        """
        result = self._transpile(code)
        assert "mut d := {'a': 1}" in result

    def test_dict_subscript_assign_mutability(self):
        code = """
        def foo():
            d = {}
            d['a'] = 1
        """
        result = self._transpile(code)
        assert "mut d := map[string]int{}" in result

    def test_list_append_mutability(self):
        code = """
        def foo():
            l = [1]
            l.append(2)
        """
        # Note: current implementation might use cap: 1 initialization
        result = self._transpile(code)
        assert "mut l :=" in result
        assert "l.append(2)" in result

    def test_aug_assign_mutability(self):
        code = """
        def foo():
            x = 1
            x += 1
        """
        result = self._transpile(code)
        assert "mut x := 1" in result

    def test_param_mutation(self):
        code = """
        def foo(d: dict):
            d['a'] = 1
        """
        result = self._transpile(code)
        assert "fn foo(mut d map[string]int)" in result or "fn foo(mut d map[string]Any)" in result
