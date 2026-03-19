from .utils import TranspilerTest

class TestIdiomaticIterators(TranspilerTest):
    def test_custom_iterator_interface(self):
        self.assert_transpilation(
            """
            class MyIter:
                def __init__(self, data: list[int]):
                    self.data = data
                    self.idx = 0
                def __iter__(self):
                    return self
                def __next__(self) -> int:
                    if self.idx >= len(self.data):
                        raise StopIteration
                    res = self.data[self.idx]
                    self.idx += 1
                    return res
            """,
            """
            fn (self MyIter) iter() MyIter {
                return self
            }
            fn (self MyIter) next() ?int {
                if self.idx >= self.data.len {
                    return none
                }
                res := py_subscript(self.data, self.idx)
                self.idx += 1
                return res
            }
            """
        )

    def test_builtin_iter_next_transpilation(self):
        self.assert_transpilation(
            """
            data = [1, 2, 3]
            it = iter(data)
            val1 = next(it)
            val2 = next(it, 0)
            """,
            """
            it := py_iter(data)
            val1 := (it.next() or { panic('StopIteration') })
            val2 := (it.next() or { 0 })
            """
        )

    def test_iterator_consumption_helpers(self):
        self.assert_transpilation(
            """
            def consume(it):
                l = list(it)
                s = set(it)
                t = tuple(it)
            """,
            """
            fn consume(it Any) {
                l := py_list_from_iter<[]Any>(it)
                s := py_set_from_iter<map[string]bool>(it)
                t := py_list_from_iter<[]Any>(it)
            }
            """
        )
