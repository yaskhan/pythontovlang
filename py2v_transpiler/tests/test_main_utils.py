import unittest
from unittest.mock import patch, mock_open
from py2v_transpiler.main import GlobalHelpers
import sys
from io import StringIO

class TestMainUtils(unittest.TestCase):
    def test_global_helpers_write_success(self):
        helpers = GlobalHelpers()
        helpers.imports = ["os"]

        m = mock_open()
        with patch("builtins.open", m):
            with patch("sys.stdout", new=StringIO()) as fake_out:
                helpers.write("test_helpers.v")

                m.assert_called_once_with("test_helpers.v", "w", encoding="utf-8")
                handle = m()
                handle.write.assert_called()
                self.assertIn("Generated global helpers: test_helpers.v", fake_out.getvalue())

    def test_global_helpers_write_error(self):
        helpers = GlobalHelpers()

        # Mock open to raise an exception
        with patch("builtins.open", side_effect=IOError("Permission denied")):
            with patch("sys.stdout", new=StringIO()) as fake_out:
                helpers.write("forbidden_path.v")

                output = fake_out.getvalue()
                self.assertIn("Error writing global helpers to forbidden_path.v: Permission denied", output)

if __name__ == "__main__":
    unittest.main()
