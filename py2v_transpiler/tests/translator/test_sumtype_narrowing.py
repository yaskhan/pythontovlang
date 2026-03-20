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
    print(
        d.value.upper()
    )
"""
    tree = ast.parse(source)
    analyzer = TypeInference()
    
    # d.value in d.value.upper() is now at line 6
    # Indentation 8 spaces + 'd' (col 8) + '.' (col 9) + 'value' (col 10)
    # So 'd.value' as an attribute starts at 6:8 or 6:10.
    # In VNodeVisitor, _guess_type for Attribute node uses its own lineno:col_offset.
    # We found earlier that for print(d.value.upper()), it's 6:8 for d.value and 6:8 for d.
    # Wait, let's use a unique column by adding spaces!
    source = """
def main() -> None:
    d = Data()
    d.value = "hello"
    print(
        (d).value.upper()
    )
"""
    tree = ast.parse(source)
    # (d).value is at line 6, col 8.
    analyzer.location_map["6:8"] = "string"
    analyzer.type_map["d.value"] = "SumType_IntString"
    
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    
    print(v_code)
    assert "(d.value as string).to_upper()" in v_code

if __name__ == "__main__":
    pytest.main([__file__])