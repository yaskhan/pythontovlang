
import textwrap
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestMutabilityRequirements:
    def _transpile(self, python_code):
        python_code = textwrap.dedent(python_code).strip()
        parser = PyASTParser()
        analyzer = TypeInference()
        tree = parser.parse(python_code)

        # We need to run mypy to get the plugin's analysis
        import tempfile
        import os
        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
            f.write(python_code)
            tmp_path = f.name

        try:
            analyzer.run_mypy(tmp_path)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

        analyzer.analyze(tree)
        translator = VNodeVisitor(analyzer)
        return translator.visit_Module(tree)

    def test_reassignment(self):
        code = """
        def test():
            x = 1
            x = 2
            return x
        """
        result = self._transpile(code)
        assert "mut x := 1" in result

    def test_augmented_assignment(self):
        code = """
        def test():
            counter = 0
            counter += 1
            return counter
        """
        result = self._transpile(code)
        assert "mut counter := 0" in result

    def test_list_mutating_methods(self):
        code = """
        def test():
            items = [1, 2, 3]
            items.append(4)
            items.extend([5])
            items.pop()
            return items
        """
        result = self._transpile(code)
        assert "mut items :=" in result

    def test_dict_mutating_methods(self):
        code = """
        def test():
            data = {'a': 1}
            data.update({'b': 2})
            return data
        """
        result = self._transpile(code)
        assert "mut data :=" in result

    def test_dict_item_assignment(self):
        code = """
        def test():
            data = {}
            data['key'] = 'value'
            return data
        """
        result = self._transpile(code)
        assert "mut data :=" in result

    def test_set_mutating_methods(self):
        code = """
        def test():
            s = {1, 2}
            s.add(3)
            s.remove(1)
            return s
        """
        result = self._transpile(code)
        assert "mut s :=" in result

    def test_final_variables(self):
        code = """
        from typing import Final
        def test():
            CONST: Final = 42
            # Even if we try to "mutate" it (though mypy would complain),
            # the transpiler should respect Final.
            return CONST
        """
        result = self._transpile(code)
        assert "mut CONST" not in result

    def test_non_mutating_operations(self):
        code = """
        def test():
            items = [1, 2, 3]
            y = len(items)
            z = items + [4]
            w = items[0]
            return y, z, w
        """
        result = self._transpile(code)
        assert "mut items" not in result

    def test_conditional_mutation(self):
        code = """
        def test(condition: bool):
            flag = True
            if condition:
                flag = False
            return flag
        """
        result = self._transpile(code)
        assert "mut flag := true" in result

    def test_loop_mutation(self):
        code = """
        def test():
            total = 0
            for i in range(10):
                total += i
            return total
        """
        result = self._transpile(code)
        assert "mut total := 0" in result
