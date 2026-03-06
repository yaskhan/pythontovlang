import ast
from enum import Enum, auto
from typing import Optional

class VType(Enum):
    INT = auto()
    FLOAT = auto()
    STRING = auto()
    BOOL = auto()
    VOID = auto()
    LIST = auto()
    DICT = auto()
    TUPLE = auto()
    NONE = auto()
    UNKNOWN = auto()

def map_python_type_to_v(py_type: str, self_name: str = "Self", allow_union: bool = False, generic_map: Optional[dict[str, str]] = None) -> str:
    """Maps a Python type name to its V equivalent."""
    if not py_type:
        return 'void'

    # Strip surrounding quotes for forward references
    if (py_type.startswith("'") and py_type.endswith("'")) or \
       (py_type.startswith('"') and py_type.endswith('"')):
        py_type = py_type[1:-1]

    # Pre-process basic types to avoid overhead
    if py_type == 'int': return 'int'
    if py_type == 'float': return 'f64'
    if py_type == 'str': return 'string'
    if py_type == 'bool': return 'bool'
    if py_type == 'None': return 'none'
    if py_type == 'Any': return 'Any'
    if py_type == 'object': return 'Any' # Map object to Any
    if py_type == 'Self': return self_name
    if py_type == 'builtins.int': return 'int'
    if py_type == 'builtins.float': return 'f64'
    if py_type == 'builtins.str': return 'string'
    if py_type == 'builtins.bool': return 'bool'

    if generic_map and py_type in generic_map:
        return generic_map[py_type]

    try:
        # Use AST to parse complex types
        node = ast.parse(py_type, mode='eval').body
        return _map_ast_type(node, self_name, allow_union, generic_map)
    except SyntaxError:
        return py_type

def _map_ast_type(node: ast.AST, self_name: str = "Self", allow_union: bool = False, generic_map: Optional[dict[str, str]] = None) -> str:
    if isinstance(node, ast.Name):
        if node.id == "Self":
            return self_name
        if generic_map and node.id in generic_map:
            return generic_map[node.id]
        return _map_basic_type(node.id)

    elif isinstance(node, ast.Constant):
        if node.value is None:
            return 'none'
        if node.value is Ellipsis:
            return '...'
        if isinstance(node.value, str):
            try:
                inner_node = ast.parse(node.value, mode='eval').body
                return _map_ast_type(inner_node, self_name, allow_union, generic_map)
            except SyntaxError:
                return node.value
        return str(node.value)

    elif isinstance(node, ast.Subscript):
        # Handle List[T], Dict[K,V], Optional[T], etc.
        value_id = ''
        if isinstance(node.value, ast.Name):
            value_id = node.value.id
        elif isinstance(node.value, ast.Attribute):
            value_id = node.value.attr

        slice_node = node.slice

        args = []
        if isinstance(slice_node, ast.Tuple):
            args = slice_node.elts
        else:
            args = [slice_node]

        # Helper to map args, handling nested types
        mapped_args = [_map_ast_type(arg, self_name, allow_union, generic_map) for arg in args]

        if value_id in ('List', 'list', 'Sequence', 'MutableSequence', 'Iterable', 'Iterator'):
            if mapped_args:
                return f"[]{mapped_args[0]}"
            return "[]int" # fallback

        elif value_id in ('Set', 'set', 'FrozenSet', 'MutableSet', 'AbstractSet'):
            if mapped_args:
                return f"map[{mapped_args[0]}]bool"
            return "map[int]bool" # fallback

        elif value_id in ('Dict', 'dict', 'Mapping', 'MutableMapping'):
            if len(mapped_args) >= 2:
                return f"map[{mapped_args[0]}]{mapped_args[1]}"
            return "map[string]int" # fallback

        elif value_id in ('IO', 'TextIO'):
            if len(mapped_args) >= 1 and mapped_args[0] == 'string':
                return "&strings.Builder"
            return "os.File"

        elif value_id == 'Tuple':
            # Tuple[int, ...] -> []int
            if len(mapped_args) == 2 and mapped_args[1] == '...':
                return f"[]{mapped_args[0]}"

            # Tuple[int, int] -> []int (if all same)
            first = mapped_args[0] if mapped_args else 'Any'
            if all(arg == first for arg in mapped_args):
                return f"[]{first}"

            # Tuple[int, str] -> []Any
            return "[]Any"

        elif value_id == 'Optional':
            if mapped_args:
                return f"?{mapped_args[0]}"
            return "?int"

        elif value_id == 'Union':
            # Check for None to map to Optional
            non_none = [t for t in mapped_args if t != 'none']
            if len(non_none) == 1 and len(mapped_args) > 1:
                return f"?{non_none[0]}"
            if allow_union:
                return " | ".join(mapped_args)
            return "Any"

        elif value_id == 'Callable':
            # Callable[[Arg1, Arg2], Ret]
            if len(args) == 2:
                arg_list_node = args[0]
                ret_node = args[1]

                arg_types = []
                if isinstance(arg_list_node, ast.List):
                    arg_types = [_map_ast_type(a, self_name, allow_union, generic_map) for a in arg_list_node.elts]

                ret_type = _map_ast_type(ret_node, self_name, allow_union, generic_map)
                return f"fn ({', '.join(arg_types)}) {ret_type}"
            return "fn"

        elif value_id == 'Literal':
            # Literal[1] -> int, Literal['a'] -> string
            if args:
                arg = args[0]
                if isinstance(arg, ast.Constant):
                    if isinstance(arg.value, int): return 'int'
                    if isinstance(arg.value, float): return 'f64'
                    if isinstance(arg.value, str): return 'string'
                    if isinstance(arg.value, bool): return 'bool'
            return 'string' # default?

        elif value_id == 'Type':
            # Type[C] -> C
            if mapped_args:
                return mapped_args[0]
            return 'Any'

        elif value_id in ('Final', 'ClassVar', 'Annotated', 'ReadOnly'):
            # Strip
            if mapped_args:
                return mapped_args[0]
            return 'Any'

        elif value_id == 'Required':
            if mapped_args:
                return mapped_args[0]
            return 'Any'

        elif value_id == 'NotRequired':
            if mapped_args:
                return f"?{mapped_args[0]}"
            return '?Any'

        elif value_id in ('TypeGuard', 'TypeIs'):
            return 'bool'

        # Default generic mapping: Name[T]
        return f"{value_id}[{', '.join(mapped_args)}]"

    elif isinstance(node, ast.BinOp):
        # A | B (Python 3.10+ Union)
        if isinstance(node.op, ast.BitOr):
            left = _map_ast_type(node.left, self_name, allow_union, generic_map)
            right = _map_ast_type(node.right, self_name, allow_union, generic_map)
            if left == 'none':
                return f"?{right}"
            if right == 'none':
                return f"?{left}"
            if allow_union:
                return f"{left} | {right}"
            return "Any"

    return "void"

def _map_basic_type(name: str) -> str:
    mapping = {
        'int': 'int',
        'float': 'f64',
        'str': 'string',
        'bool': 'bool',
        'None': 'none',
        'Any': 'Any',
        'object': 'Any', # Map object to Any
        'list': '[]int',
        'dict': 'map[string]int',
        'tuple': '[]int',
        'set': 'map[int]bool',
        'IO': 'os.File',
        'TextIO': 'os.File',
        'BinaryIO': 'os.File',
        'StringIO': 'strings.Builder',
        'io.StringIO': 'strings.Builder',
        'six.moves.StringIO': 'strings.Builder',
        'NoReturn': 'void',
        'builtins.int': 'int',
        'builtins.float': 'f64',
        'builtins.str': 'string',
        'builtins.bool': 'bool',
        'LiteralString': 'string',
        'typing.LiteralString': 'string',
        'typing_extensions.LiteralString': 'string',
    }
    return mapping.get(name, name)
