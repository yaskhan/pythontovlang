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

def map_python_type_to_v(py_type: str) -> str:
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

    try:
        # Use AST to parse complex types
        node = ast.parse(py_type, mode='eval').body
        return _map_ast_type(node)
    except SyntaxError:
        return py_type

def _map_ast_type(node: ast.AST) -> str:
    if isinstance(node, ast.Name):
        return _map_basic_type(node.id)

    elif isinstance(node, ast.Constant):
        if node.value is None:
            return 'none'
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
        mapped_args = [_map_ast_type(arg) for arg in args]

        if value_id in ('List', 'list', 'Set', 'set', 'Sequence'):
            if mapped_args:
                return f"[]{mapped_args[0]}"
            return "[]int" # fallback
        elif value_id in ('Dict', 'dict'):
            if len(mapped_args) >= 2:
                return f"map[{mapped_args[0]}]{mapped_args[1]}"
            return "map[string]int" # fallback
        elif value_id == 'Optional':
            if mapped_args:
                return f"?{mapped_args[0]}"
            return "?int"
        elif value_id == 'Union':
            # Check for None to map to Optional
            non_none = [t for t in mapped_args if t != 'none']
            if len(non_none) == 1 and len(mapped_args) > 1:
                return f"?{non_none[0]}"
            return " | ".join(mapped_args)
        elif value_id == 'Callable':
            # Callable[[Arg1, Arg2], Ret]
            # slice is typically Tuple(elts=[List(args), Ret])
            if len(args) == 2:
                arg_list_node = args[0]
                ret_node = args[1]

                arg_types = []
                # arg_list_node should be ast.List
                if isinstance(arg_list_node, ast.List):
                    arg_types = [_map_ast_type(a) for a in arg_list_node.elts]

                ret_type = _map_ast_type(ret_node)
                return f"fn ({', '.join(arg_types)}) {ret_type}"
            return "fn" # fallback

        # Default generic mapping: Name[T]
        return f"{value_id}[{', '.join(mapped_args)}]"

    elif isinstance(node, ast.BinOp):
        # A | B (Python 3.10+ Union)
        if isinstance(node.op, ast.BitOr):
            left = _map_ast_type(node.left)
            right = _map_ast_type(node.right)
            if left == 'none':
                return f"?{right}"
            if right == 'none':
                return f"?{left}"
            return f"{left} | {right}"

    return "void"

def _map_basic_type(name: str) -> str:
    mapping = {
        'int': 'int',
        'float': 'f64',
        'str': 'string',
        'bool': 'bool',
        'None': 'none',
        'Any': 'any',
        'list': '[]int',
        'dict': 'map[string]int',
        'tuple': '[]int',
    }
    return mapping.get(name, name)
