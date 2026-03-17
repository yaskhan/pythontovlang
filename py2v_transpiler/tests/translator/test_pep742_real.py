import os
import subprocess
import pytest

def test_typeis_narrowing_full_pipeline():
    source_code = """
from typing import Union
from typing_extensions import TypeIs

def is_str(val: Union[int, str]) -> TypeIs[str]:
    return isinstance(val, str)

def example(x: Union[int, str]):
    if is_str(x):
        # x should be str here
        print("String: " + x)
    else:
        # x should be int here
        print(x + 1)
"""
    with open("temp_test_pep742.py", "w") as f:
        f.write(source_code)

    try:
        # Run transpiler
        subprocess.run(["python3", "py2v_transpiler/main.py", "temp_test_pep742.py"],
                       env={**os.environ, "PYTHONPATH": "."}, check=True)

        with open("temp_test_pep742.v", "r") as f:
            v_code = f.read()

        # Verify bidirectional narrowing
        assert "narrowed_x := string(x)" in v_code or "narrowed_x := (x as string)" in v_code
        assert "narrowed_else_x := int(x)" in v_code or "narrowed_else_x := (x as int)" in v_code
        # Verify usage of narrowed variables via name_remap
        # The print("String: " + x) should use narrowed_x
        # V code for "String: " + x would be something like '${'String: ' + narrowed_x}'
        assert "narrowed_x" in v_code
        assert "narrowed_else_x" in v_code

    finally:
        if os.path.exists("temp_test_pep742.py"): os.remove("temp_test_pep742.py")
        if os.path.exists("temp_test_pep742.v"): os.remove("temp_test_pep742.v")
        if os.path.exists("temp_test_pep742_helpers.v"): os.remove("temp_test_pep742_helpers.v")

if __name__ == "__main__":
    test_typeis_narrowing_full_pipeline()
