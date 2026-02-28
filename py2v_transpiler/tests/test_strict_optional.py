import os
import pytest
from py2v_transpiler.models.v_types import map_python_type_to_v, _strict_optional_loaded
import py2v_transpiler.models.v_types as v_types

@pytest.fixture(autouse=True)
def reset_strict_optional_cache():
    # Reset the cache before each test
    v_types._strict_optional_loaded = False
    v_types._STRICT_OPTIONAL_CACHE = True
    yield
    # Cleanup any stray files
    if os.path.exists("mypy.ini"):
        os.remove("mypy.ini")
    if os.path.exists("pyproject.toml"):
        os.remove("pyproject.toml")
    v_types._strict_optional_loaded = False
    v_types._STRICT_OPTIONAL_CACHE = True

def test_strict_optional_true_default():
    # By default, it should be true
    assert map_python_type_to_v("int | None") == "?int"
    assert map_python_type_to_v("Optional[int]") == "?int"
    assert map_python_type_to_v("Union[int, None]") == "?int"

def test_strict_optional_false_mypy_ini():
    with open("mypy.ini", "w") as f:
        f.write("[mypy]\nstrict_optional = False\n")
    v_types._strict_optional_loaded = False

    assert map_python_type_to_v("int | None") == "Any"
    assert map_python_type_to_v("Optional[int]") == "Any"
    assert map_python_type_to_v("Union[int, None]") == "Any"

def test_strict_optional_false_pyproject_toml():
    with open("pyproject.toml", "w") as f:
        f.write("[tool.mypy]\nstrict_optional = false\n")
    v_types._strict_optional_loaded = False

    assert map_python_type_to_v("int | None") == "Any"
    assert map_python_type_to_v("Optional[int]") == "Any"
    assert map_python_type_to_v("Union[int, None]") == "Any"

def test_strict_optional_true_pyproject_toml():
    with open("pyproject.toml", "w") as f:
        f.write("[tool.mypy]\nstrict_optional = true\n")
    v_types._strict_optional_loaded = False

    assert map_python_type_to_v("int | None") == "?int"
    assert map_python_type_to_v("Optional[int]") == "?int"
    assert map_python_type_to_v("Union[int, None]") == "?int"
