from py2v_transpiler.tests.test_v2_features import transpile
code = """
class Data:
    def __init__(self):
        self.val = 0

def modify(obj: Data) -> None:
    obj.val = 1

def wrapper(obj: Data) -> None:
    modify(obj)
"""
v_code = transpile(code)
print(v_code)
