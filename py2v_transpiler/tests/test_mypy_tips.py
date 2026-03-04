
from py2v_transpiler.core.mypy_tips import get_mypy_tips

def test_get_mypy_tips_union_attr():
    mypy_output = "error_test.py:3: error: Item \"int\" of \"int | None\" has no attribute \"upper\"  [union-attr]"
    tips = get_mypy_tips(mypy_output)
    assert "[union-attr]" in tips
    assert "explicitly check the type" in tips

def test_get_mypy_tips_multiple_errors():
    mypy_output = """
    file.py:10: error: Incompatible types in assignment (expression has type "int", variable has type "str")  [assignment]
    file.py:20: error: Argument 1 to "foo" has incompatible type "str"; expected "int"  [arg-type]
    """
    tips = get_mypy_tips(mypy_output)
    assert "[assignment]" in tips
    assert "[arg-type]" in tips
    assert tips.count("- [") == 2

def test_get_mypy_tips_misc_typeform():
    mypy_output = "file.py:5: error: TypeForm is experimental  [misc]"
    tips = get_mypy_tips(mypy_output)
    assert "[misc]" in tips
    assert "Experimental feature 'TypeForm' detected" in tips

def test_get_mypy_tips_no_codes():
    mypy_output = "Some random error without a code"
    tips = get_mypy_tips(mypy_output)
    assert tips == ""

def test_get_mypy_tips_empty_input():
    assert get_mypy_tips("") == ""
    assert get_mypy_tips(None) == ""
