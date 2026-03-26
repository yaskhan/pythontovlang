import unittest
class MyTests(unittest.TestCase):
    def test_asserts(self):
        self.assertEqual(1, 1)
        self.assertTrue(True)
        self.assertFalse(False)
        self.assertNotEqual(1, 2)
        self.assertIn(1, [1])
        self.assertIsNone(None)
        self.assertIsNotNone(1)
