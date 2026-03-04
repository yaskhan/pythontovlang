from py2v_transpiler.models.v_types import map_python_type_to_v
print(f"Literal['a', 'b'] -> {map_python_type_to_v(\"Literal['a', 'b']\")}")
print(f"Literal[1, 2] -> {map_python_type_to_v('Literal[1, 2]')}")
