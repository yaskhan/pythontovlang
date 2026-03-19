from .utils import TranspilerTest

class TestTupleMethodsFix(TranspilerTest):
    def test_translator_tuple_nested_append(self):
        """Test transpilation of append() on a nested list inside a tuple."""
        code = """
    t2 = ([1, 2], [3, 4])
    t2[0].append(3)
    """
        # Should use << operator
        self.assert_transpilation(code, "mut t2 := [[1, 2], [3, 4]]")
        self.assert_transpilation(code, "t2[0] << 3")

    def test_translator_tuple_count(self):
        """Test transpilation of count() on a tuple."""
        code = """
    t = (1, 2, 3, 2)
    c = t.count(2)
    """
        # Should use .filter().len
        self.assert_transpilation(code, "t.filter(it == 2).len")
