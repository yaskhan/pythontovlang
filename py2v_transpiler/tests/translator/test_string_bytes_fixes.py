import unittest
from py2v_transpiler.tests.translator.utils import TranspilerTest

class TestStringBytesFixes(unittest.TestCase, TranspilerTest):
    def test_string_iteration(self):
        source = """
        def iterate(s: str):
            for ch in s:
                print(ch)
        """
        expected = """
        for ch_u8 in s {
            ch := ch_u8.ascii_str()
            println('${ch}')
        }
        """
        self.assert_transpilation(source, expected)

    def test_string_enumerate(self):
        source = """
        def iterate_enum(s: str):
            for i, ch in enumerate(s):
                print(i, ch)
        """
        expected = """
        for i, ch_u8 in s {
            ch := ch_u8.ascii_str()
            println('${i} ${ch}')
        }
        """
        self.assert_transpilation(source, expected)

    def test_bytes_conversion(self):
        source = """
        def to_bytes(msg: str):
            b1 = bytes(msg, "utf8")
            b2 = bytes(msg, encoding="utf-8")
            print(b1, b2)
        """
        expected = """
        b1 := msg.bytes()
        b2 := msg.bytes()
        """
        self.assert_transpilation(source, expected)

    def test_int_conversion(self):
        source = """
        import sys
        def to_int():
            val = int(sys.argv[1])
            return val
        """
        # Note: os.args is used when sys.argv is encountered
        expected = """
        val := py_subscript(os.args, 1).int()
        """
        self.assert_transpilation(source, expected)

if __name__ == "__main__":
    unittest.main()
