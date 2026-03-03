import ast
from py2v_transpiler.core.analyzer import TypeInference

def test_dict_inference_self_attribute():
    code = """
class Node:
    def __init__(self):
        self.children = {}

    def add(self):
        self.children["a"] = Node()

head = Node()
head.children["a"] = Node()
dict1 = {}
dict1["a"] = Node()
"""
    tree = ast.parse(code)
    ti = TypeInference()
    ti.analyze(tree)

    assert ti.type_map.get("self.children") == "map[string]Node"
    assert ti.type_map.get("head.children") == "map[string]Node"
    assert ti.type_map.get("dict1") == "map[string]Node"
