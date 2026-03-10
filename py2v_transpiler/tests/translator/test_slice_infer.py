from .utils import TranspilerTest

class TestSliceInfer(TranspilerTest):
    def test_slice_infer_type(self):
        self.assert_transpilation(
            """
            def test():
                l = [1, 2, 3]
                l[1:3] = [5, 6]
            """,
            """
            mut l := []int{cap: 3}
            l << 1
            l << 2
            l << 3
            l.delete_many(1, (3) - (1))
            l.insert_many(1, [5, 6])
            """
        )
