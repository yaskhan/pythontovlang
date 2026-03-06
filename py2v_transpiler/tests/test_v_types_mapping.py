from py2v_transpiler.models.v_types import map_python_type_to_v

def test_typing_any_mapping():
    assert map_python_type_to_v("typing.Any") == "Any"

def test_typing_list_mapping():
    assert map_python_type_to_v("typing.List[int]") == "[]int"
    assert map_python_type_to_v("typing.List[str]") == "[]string"
    assert map_python_type_to_v("typing.List") == "[]Any"

def test_typing_dict_mapping():
    assert map_python_type_to_v("typing.Dict[str, int]") == "map[string]int"
    assert map_python_type_to_v("typing.Dict") == "map[string]Any"

def test_typing_optional_mapping():
    assert map_python_type_to_v("typing.Optional[str]") == "?string"
    assert map_python_type_to_v("typing.Optional") == "?Any"

def test_typing_union_mapping():
    # Union is now enabled by default
    assert map_python_type_to_v("typing.Union[int, str]") == "int | string"
    assert map_python_type_to_v("typing.Union[int, str]", allow_union=False) == "Any"

def test_typing_noreturn_mapping():
    assert map_python_type_to_v("typing.NoReturn") == "void"

def test_typing_callable_mapping():
    assert map_python_type_to_v("typing.Callable[[int], str]") == "fn (int) string"
    assert map_python_type_to_v("typing.Callable") == "fn"
