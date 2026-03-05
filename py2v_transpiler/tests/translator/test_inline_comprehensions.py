from .utils import TranspilerTest

class TestInlineComprehensions(TranspilerTest):
    def test_inline_list_comp(self):
        code = "a = [x * 2 for x in [1, 2, 3]]"
        expected = """
        mut a := []int{cap: 3}
        for x in [1, 2, 3] {
            a << x * 2
        }
        """
        self.assert_transpilation(code, expected)

    def test_inline_list_comp_in_call(self):
        code = "max([x * 2 for x in [1, 2, 3]])"
        expected = """
        mut comp_1 := []int{cap: 3}
        for x in [1, 2, 3] {
            comp_1 << x * 2
        }
        max(comp_1)
        """
        self.assert_transpilation(code, expected)

    def test_inline_dict_comp(self):
        code = "d = {x: x * 2 for x in [1, 2, 3]}"
        expected = """
        mut d := map[int]int{}
        for x in [1, 2, 3] {
            d[x] = x * 2
        }
        """
        self.assert_transpilation(code, expected)

    def test_inline_set_comp(self):
        code = "s = {x * 2 for x in [1, 2, 3]}"
        expected = """
        mut s := map[int]bool{}
        for x in [1, 2, 3] {
            s[x * 2] = true
        }
        """
        self.assert_transpilation(code, expected)

    def test_inline_generator_exp(self):
        code = "g = (x * 2 for x in [1, 2, 3])"
        expected = """
        mut g := []int{cap: 3}
        for x in [1, 2, 3] {
            g << x * 2
        }
        """
        self.assert_transpilation(code, expected)

    def test_generator_exp_in_call(self):
        code = "sum(x * 2 for x in [1, 2, 3])"
        expected = """
        mut comp_1 := []int{cap: 3}
        for x in [1, 2, 3] {
            comp_1 << x * 2
        }
        sum(comp_1)
        """
        self.assert_transpilation(code, expected)
