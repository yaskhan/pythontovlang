import textwrap
import pytest
import ast
from typing import cast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestIssue5Mutability:
    def _transpile(self, python_code):
        python_code = textwrap.dedent(python_code).strip()
        parser = PyASTParser()
        analyzer = TypeInference()
        tree = parser.parse(python_code)
        analyzer.analyze(tree)
        translator = VNodeVisitor(analyzer)
        translator.visit_Module(cast(ast.Module, tree))
        return translator.emitter.emit()

    def test_field_mutability(self):
        code = """
        class IdleTaskRec:
            count: int = 10000
            _private: int = 0

            def decrement(self):
                self.count -= 1
                self._private += 1
        """
        result = self._transpile(code)

        # Check public mutated field
        assert "pub mut:" in result
        assert "count int = 10000" in result

        # Check private mutated field
        assert "mut:" in result
        # Note: _private is sanitized to private_
        assert "private_ int = 0" in result

        # Check receiver is mut self
        assert "fn (mut self IdleTaskRec) decrement()" in result

    def test_unmutated_visibility(self):
        code = """
        class Data:
            name: str
            value: int

            def __init__(self, name: str, value: int):
                self.name = name
                self.value = value
        """
        result = self._transpile(code)

        # In __init__, fields are mutated (assigned for the first time).
        # But if they are only assigned in __init__ and never again,
        # are they considered mutated?
        # Our analyzer currently treats ANY assignment to self.attr as mutation.

        assert "pub mut:" in result
        assert "name string" in result
        assert "value int" in result
