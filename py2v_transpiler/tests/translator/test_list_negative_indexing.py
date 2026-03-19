
import pytest
from .utils import TranspilerTest

def list_operations(arr: list[int]) -> None:
    # 1. Negative indexing
    print("Last element:", arr[-1])
    print("Second to last:", arr[-2])

class TestListNegativeIndexing(TranspilerTest):
    def test_negative_indexing_transpilation(self):
        code = """
        def list_operations(arr: list[int]) -> None:
            print("Last element:", arr[-1])
            print("Second to last:", arr[-2])
        """
        # Fixed behavior: emits arr[arr.len - 1] and arr[arr.len - 2]
        # Note: functions are not exported by default unless configured or in __all__
        v_code = """
        fn list_operations(arr []int) {
            println('Last element: ${arr[arr.len - 1]}')
            println('Second to last: ${arr[arr.len - 2]}')
        }
        """
        self.assert_transpilation(code, v_code)

    def test_list_operations_python_edge_cases(self):
        # Verify that the function raises IndexError as expected in Python
        with pytest.raises(IndexError):
            list_operations([])

        with pytest.raises(IndexError):
            list_operations([1])

    def test_list_operations_python_happy_path(self, capsys):
        list_operations([10, 20, 30])
        captured = capsys.readouterr()
        assert "Last element: 30" in captured.out
        assert "Second to last: 20" in captured.out

    def test_negative_indexing_slicing_transpilation(self):
        code = """
        def slice_ops(arr: list[int]) -> None:
            print(arr[-2:])
            print(arr[:-1])
            print(arr[-3:-1])
        """
        v_code = """
        fn slice_ops(arr []int) {
            println('${arr[arr.len - 2..]}')
            println('${arr[..arr.len - 1]}')
            println('${arr[arr.len - 3..arr.len - 1]}')
        }
        """
        self.assert_transpilation(code, v_code)
