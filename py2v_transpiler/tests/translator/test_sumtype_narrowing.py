import pytest
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor
import ast

def test_manual_narrowing_mock():
    source = """
def f(x: int | str):
    if isinstance(x, str):
        print(x.upper())
    else:
        print(x + 1)
"""
    tree = ast.parse(source)
    analyzer = TypeInference()
    
    # We must use EXACT line:col from the parsed AST
    # Based on previous runs:
    # Name x in x.upper() is at 4:14
    # Name x in x + 1 is at 6:14
    # BinOp x + 1 is at 6:14
    
    analyzer.type_map["x"] = "SumType_IntString"
    analyzer.location_map["4:14"] = "string"
    analyzer.location_map["6:14"] = "int"
    
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    
    print(v_code)
    assert "(x as string).to_upper()" in v_code
    assert "(x as int) + 1" in v_code

def test_attribute_narrowing_mock():
    source = """
def main() -> None:
    d = Data()
    d.value = "hello"
    print(d.value.upper())
"""
    tree = ast.parse(source)
    analyzer = TypeInference()
    
    # Based on previous run, d.value in d.value.upper() is at 5:10
    # The receiver d in d.value.upper() is at 5:10
    
    # Attribute(value=Name(id='d', ...), attr='value')
    # node.lineno=5, node.col_offset=10
    # node.value.lineno=5, node.value.col_offset=10
    
    # For narrowing d.value to string, we need to set location_map for the Attribute node itself
    # The Attribute node d.value is at position 5:10
    analyzer.location_map["5:10"] = "string"
    # Base type of d.value (for SumType detection)
    analyzer.type_map["d.value"] = "SumType_IntString"
    
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    
    print(v_code)
    assert "(d.value as string).to_upper()" in v_code

if __name__ == "__main__":
    pytest.main([__file__])