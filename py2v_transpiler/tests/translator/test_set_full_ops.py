import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestSetFullOps(unittest.TestCase):
    def setUp(self):
        self.ti = TypeInference()
        self.translator = VNodeVisitor(self.ti)

    def translate_stmt(self, code, index=-1):
        tree = ast.parse(code)
        self.ti.analyze(tree)
        stmt = tree.body[index]
        self.translator.output = []
        self.translator.visit(stmt)
        return "\n".join(self.translator.output).strip()

    def translate_expr(self, code):
        tree = ast.parse(code)
        self.ti.analyze(tree)
        last_stmt = tree.body[-1]
        if isinstance(last_stmt, ast.Expr):
            node = last_stmt.value
        elif isinstance(last_stmt, ast.Assign):
            node = last_stmt.value
        else:
            node = last_stmt
        return self.translator.visit(node)

    def test_set_init_from_list(self):
        code = "s: set[int] = set([1, 2, 2])"
        tree = ast.parse(code)
        self.ti.analyze(tree)
        # Manually set the current assignment type to simulate AnnAssign context
        self.translator.current_assignment_type = "map[int]bool"
        result = self.translator.visit(tree.body[0].value)
        self.assertEqual(result, "py_set_from_list<map[int]bool>([1, 2, 2])")
        self.assertIn("py_set_from_list", self.translator.used_builtins)

    def test_set_add(self):
        code = "s = {1}; s.add(2)"
        result = self.translate_stmt(code, index=1)
        self.assertEqual(result, "s[2] = true")

    def test_set_remove(self):
        code = "s = {1}; s.remove(1)"
        result = self.translate_stmt(code, index=1)
        self.assertEqual(result, "py_set_remove(mut s, 1)")
        self.assertIn("py_set_remove", self.translator.used_builtins)

    def test_set_discard(self):
        code = "s = {1}; s.discard(1)"
        result = self.translate_stmt(code, index=1)
        self.assertEqual(result, "s.delete(1)")

    def test_set_pop(self):
        code = "s = {1}; s.pop()"
        result = self.translate_expr(code)
        self.assertEqual(result, "py_set_pop(mut s)")
        self.assertIn("py_set_pop", self.translator.used_builtins)

    def test_set_clear(self):
        code = "s = {1}; s.clear()"
        result = self.translate_stmt(code, index=1)
        self.assertEqual(result, "/* s.clear() */ s = {}")

    def test_set_comparison_subset(self):
        code = "a = {1}; b = {1, 2}; a <= b"
        result = self.translate_expr(code)
        self.assertEqual(result, "py_set_subset(a, b)")
        self.assertIn("py_set_subset", self.translator.used_builtins)

    def test_set_comparison_strict_subset(self):
        code = "a = {1}; b = {1, 2}; a < b"
        result = self.translate_expr(code)
        self.assertEqual(result, "py_set_strict_subset(a, b)")
        self.assertIn("py_set_strict_subset", self.translator.used_builtins)

    def test_set_union_method(self):
        code = "a = {1}; b = {2}; a.union(b)"
        result = self.translate_expr(code)
        self.assertEqual(result, "py_set_union(a, b)")
        self.assertIn("py_set_union", self.translator.used_builtins)

    def test_set_update_method(self):
        code = "a = {1}; b = {2}; a.update(b)"
        result = self.translate_stmt(code, index=2)
        self.assertEqual(result, "py_set_update(mut a, b)")
        self.assertIn("py_set_update", self.translator.used_builtins)

if __name__ == "__main__":
    unittest.main()
