import pytest
import os
import subprocess
import tempfile
from py2v_transpiler.main import transpile_file
from py2v_transpiler.config import TranspilerConfig

def run_transpiler_on_code(code: str, strict_syntax_mode: bool = False, mypy_enabled: bool = False):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write(code)
        temp_py = f.name

    config = TranspilerConfig(strict_syntax_mode=strict_syntax_mode, mypy_enabled=mypy_enabled)

    try:
        # transpile_file might raise SyntaxError
        success = transpile_file(temp_py, config)
        return success
    finally:
        if os.path.exists(temp_py):
            os.remove(temp_py)
        temp_v = temp_py.replace('.py', '.v')
        if os.path.exists(temp_v):
            os.remove(temp_v)
        temp_helpers = temp_py.replace('.py', '_helpers.v')
        if os.path.exists(temp_helpers):
            os.remove(temp_helpers)

def test_generic_syntax_strict_mode():
    code = """
from typing import Generic, TypeVar
T = TypeVar("T")
class Box(Generic[T]):
    val: T
"""
    with pytest.raises(SyntaxError) as excinfo:
        run_transpiler_on_code(code, strict_syntax_mode=True)
    assert "Generic[T]" in str(excinfo.value)
    assert "Use PEP 695 syntax" in str(excinfo.value)

def test_pep695_syntax_strict_mode():
    # Only if python version >= 3.12
    import sys
    if sys.version_info < (3, 12):
        pytest.skip("PEP 695 requires Python 3.12+")

    code = """
class Box[T]:
    val: T
"""
    # Should not raise SyntaxError
    assert run_transpiler_on_code(code, strict_syntax_mode=True) == True

def test_implicit_any_assignment_strict_mode():
    # We need to simulate a case where _guess_type returns "Any"
    # and there is no annotation.
    # In my current implementation of _guess_type, ast.Attribute and ast.Subscript return "Any"
    code = """
import sys
x = sys.argv[0] # Inferred as string by _guess_type special case, let's try something else
class A:
    pass
a = A()
y = a.foo # Inferred as Any by _guess_type
"""
    with pytest.raises(SyntaxError) as excinfo:
        run_transpiler_on_code(code, strict_syntax_mode=True)
    assert "Explicit annotation required" in str(excinfo.value)
    assert "Any" in str(excinfo.value)

def test_explicit_any_assignment_strict_mode():
    code = """
from typing import Any
class A:
    pass
a = A()
y: Any = a.foo
"""
    # Should pass because it has explicit annotation
    # Wait, visit_AnnAssign doesn't check for strict mode's Any requirement yet.
    # Let's check if I should add it there too.
    # Requirement: "Require explicit annotations where mypy infers Any"
    # If they PROVIDE an explicit annotation (even if it is : Any), they fulfilled the "explicit annotation" requirement.
    assert run_transpiler_on_code(code, strict_syntax_mode=True) == True

def test_explicit_annotation_function_arg_strict_mode():
    code = """
def foo(x: int) -> int:
    return x
"""
    assert run_transpiler_on_code(code, strict_syntax_mode=True) == True

def test_implicit_any_function_return_strict_mode():
    code = """
def foo(x: int):
    return x
"""
    with pytest.raises(SyntaxError) as excinfo:
        run_transpiler_on_code(code, strict_syntax_mode=True)
    assert "Explicit return annotation required" in str(excinfo.value)

def test_implicit_any_function_arg_error_strict_mode():
    code = """
def foo(x) -> int:
    return 1
"""
    with pytest.raises(SyntaxError) as excinfo:
        run_transpiler_on_code(code, strict_syntax_mode=True)
    assert "Explicit annotation required for argument 'x'" in str(excinfo.value)
