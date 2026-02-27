import ast
from enum import Enum, auto

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

def map_python_type_to_v(py_type: str, self_name: str = "Self", allow_union: bool = False) -> str:
    """Maps a Python type name to its V equivalent."""
    if not py_type:
        return 'void'

    # Pre-process basic types to avoid overhead
    if py_type == 'int': return 'int'
    if py_type == 'float': return 'f64'
    if py_type == 'str': return 'string'
    if py_type == 'bool': return 'bool'
    if py_type == 'None': return 'none'
    if py_type == 'Any': return 'any'
    if py_type == 'object': return 'any' # Map object to any
    if py_type == 'Self': return self_name

    try:
        # Use AST to parse complex types
        node = ast.parse(py_type, mode='eval').body
        return _map_ast_type(node, self_name, allow_union)
    except SyntaxError:
        return py_type

def _map_ast_type(node: ast.AST, self_name: str = "Self", allow_union: bool = False) -> str:
    if isinstance(node, ast.Name):
        if node.id == "Self":
            return self_name
        return _map_basic_type(node.id)

    elif isinstance(node, ast.Constant):
        if node.value is None:
            return 'none'
        if node.value is Ellipsis:
            return '...'
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
        mapped_args = [_map_ast_type(arg, self_name, allow_union) for arg in args]

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

        elif value_id == 'Tuple':
            # Tuple[int, ...] -> []int
            if len(mapped_args) == 2 and mapped_args[1] == '...':
                return f"[]{mapped_args[0]}"

            # Tuple[int, int] -> []int (if all same)
            first = mapped_args[0] if mapped_args else 'any'
            if all(arg == first for arg in mapped_args):
                return f"[]{first}"

            # Tuple[int, str] -> []any
            return "[]any"

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
            return "any"

        elif value_id == 'Callable':
            # Callable[[Arg1, Arg2], Ret]
            if len(args) == 2:
                arg_list_node = args[0]
                ret_node = args[1]

                arg_types = []
                if isinstance(arg_list_node, ast.List):
                    arg_types = [_map_ast_type(a, self_name, allow_union) for a in arg_list_node.elts]

                ret_type = _map_ast_type(ret_node, self_name, allow_union)
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
            return 'any'

        elif value_id in ('Final', 'ClassVar', 'Annotated'):
            # Strip
            if mapped_args:
                return mapped_args[0]
            return 'any'

        elif value_id == 'Required':
            if mapped_args:
                return mapped_args[0]
            return 'any'

        elif value_id == 'NotRequired':
            if mapped_args:
                return f"?{mapped_args[0]}"
            return '?any'

        elif value_id == 'TypeGuard':
            return 'bool'

        # Default generic mapping: Name[T]
        return f"{value_id}[{', '.join(mapped_args)}]"

    elif isinstance(node, ast.BinOp):
        # A | B (Python 3.10+ Union)
        if isinstance(node.op, ast.BitOr):
            left = _map_ast_type(node.left, self_name, allow_union)
            right = _map_ast_type(node.right, self_name, allow_union)
            if left == 'none':
                return f"?{right}"
            if right == 'none':
                return f"?{left}"
            if allow_union:
                return f"{left} | {right}"
            return "any"

    return "void"

def _map_basic_type(name: str) -> str:
    mapping = {
        'int': 'int',
        'float': 'f64',
        'str': 'string',
        'bool': 'bool',
        'None': 'none',
        'Any': 'any',
        'object': 'any', # Map object to any
        'list': '[]int',
        'dict': 'map[string]int',
        'tuple': '[]int',
        'set': 'map[int]bool',
        'IO': 'os.File',
        'TextIO': 'os.File',
        'BinaryIO': 'os.File',
        'NoReturn': 'void',
    }
    return mapping.get(name, name)
