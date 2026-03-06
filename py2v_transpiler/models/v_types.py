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

def map_python_type_to_v(py_type: str, self_name: str = "Self", allow_union: bool = True, generic_map: Optional[dict[str, str]] = None) -> str:
    """Maps a Python type name to its V equivalent."""
    if not py_type:
        return 'void'

    # Handle leading * for TypeVarTuple in annotations
    if py_type.startswith('*') and not py_type.startswith('**'):
        py_type = py_type[1:]

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

def _map_ast_type(node: ast.AST, self_name: str = "Self", allow_union: bool = True, generic_map: Optional[dict[str, str]] = None) -> str:
    if isinstance(node, ast.Name):
        if node.id == "Self":
            return self_name
        if generic_map and node.id in generic_map:
            return generic_map[node.id]
        return _map_basic_type(node.id)

    elif isinstance(node, ast.Attribute):
        # Handle typing.Any etc.
        full_name = ""
        curr: ast.AST = node
        parts = []
        while isinstance(curr, ast.Attribute):
            parts.append(curr.attr)
            curr = curr.value
        if isinstance(curr, ast.Name):
            if generic_map and curr.id in generic_map:
                # ParamSpec: P.args / P.kwargs
                v_gen = generic_map[curr.id]
                if node.attr == 'args':
                    return v_gen
                if node.attr == 'kwargs':
                    return "map[string]Any"

            parts.append(curr.id)
            full_name = ".".join(reversed(parts))

            # More aggressive stripping for attributes
            basic = _map_basic_type(full_name)
            if basic == full_name:
                if full_name.startswith('typing.'):
                    return _map_basic_type(full_name[7:])
                if full_name.startswith('typing_extensions.'):
                    return _map_basic_type(full_name[18:])
                if full_name.startswith('builtins.'):
                    return _map_basic_type(full_name[9:])
            return basic
        return _map_basic_type(node.attr)

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

    elif isinstance(node, ast.Starred):
        return _map_ast_type(node.value, self_name, allow_union, generic_map)

    elif isinstance(node, ast.Subscript):
        # Handle List[T], Dict[K,V], Optional[T], etc.
        value_id = ''
        if isinstance(node.value, ast.Name):
            value_id = node.value.id
        elif isinstance(node.value, ast.Attribute):
            # Also handle typing.List etc.
            curr_val: ast.AST = node.value
            parts = []
            while isinstance(curr_val, ast.Attribute):
                parts.append(curr_val.attr)
                curr_val = curr_val.value
            if isinstance(curr_val, ast.Name):
                parts.append(curr_val.id)
                full_name = ".".join(reversed(parts))
                if full_name.startswith("typing.") or full_name.startswith("typing_extensions."):
                    value_id = node.value.attr
                else:
                    value_id = full_name
            else:
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
            # Deduplicate while preserving order
            unique_args = []
            for arg in mapped_args:
                if arg not in unique_args:
                    unique_args.append(arg)
            mapped_args = unique_args

            # If Any is in there, the whole union is effectively Any
            if "Any" in mapped_args:
                return "Any"

            # Check for None to map to Optional
            non_none = [t for t in mapped_args if t != 'none']
            if len(non_none) == 1 and len(mapped_args) > 1:
                return f"?{non_none[0]}"

            if allow_union:
                # Deduplicate while preserving order
                unique_args = []
                for arg in mapped_args:
                    if arg not in unique_args:
                        unique_args.append(arg)
                return " | ".join(unique_args)
            return "Any"

        elif value_id in ('Callable', 'typing.Callable'):
            # Callable[[Arg1, Arg2], Ret]
            # V function types: fn (Arg1, Arg2) Ret
            if len(args) == 2:
                arg_list_node = args[0]
                ret_node = args[1]

                arg_types = []
                if isinstance(arg_list_node, ast.List):
                    arg_types = [_map_ast_type(a, self_name, allow_union, generic_map) for a in arg_list_node.elts]
                elif isinstance(arg_list_node, ast.Name) and generic_map and arg_list_node.id in generic_map:
                    # ParamSpec: Callable[P, Ret]
                    # We usually map P to empty args if it represents the whole signature
                    # and we don't have concrete args.
                    # But the test expects `fn ()`.
                    arg_types = []
                elif isinstance(arg_list_node, ast.Constant) and arg_list_node.value is Ellipsis:
                    arg_types = ["..."]
                elif isinstance(arg_list_node, ast.Name):
                    # ParamSpec: Callable[P, Ret]
                    arg_types = [_map_ast_type(arg_list_node, self_name, allow_union, generic_map)]

                ret_type = _map_ast_type(ret_node, self_name, allow_union, generic_map)
                if ret_type == "none": ret_type = "void"

                return f"fn ({', '.join(arg_types)}) {ret_type}"

            if len(args) == 1 and isinstance(args[0], ast.Constant) and args[0].value is Ellipsis:
                return "fn (...)"

            return "fn"

        elif value_id == 'Literal':
            # Literal[1] -> int, Literal['a'] -> string
            if args:
                lit_arg = args[0]
                if isinstance(lit_arg, ast.Constant):
                    if isinstance(lit_arg.value, int): return 'int'
                    if isinstance(lit_arg.value, float): return 'f64'
                    if isinstance(lit_arg.value, str): return 'string'
                    if isinstance(lit_arg.value, bool): return 'bool'
            return 'string' # default?

        elif value_id == 'Type':
            # Type[C] -> C
            if mapped_args:
                return mapped_args[0]
            return 'Any'

        elif value_id == 'TypeForm':
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
            left_type = _map_ast_type(node.left, self_name, allow_union, generic_map)
            right_type = _map_ast_type(node.right, self_name, allow_union, generic_map)
            if left_type == 'none':
                return f"?{right_type}"
            if right_type == 'none':
                return f"?{left_type}"
            if allow_union:
                return f"{left_type} | {right_type}"
            return "Any"

    return "void"

def _map_basic_type(name: str) -> str:
    # Strip typing. prefix
    if name.startswith('typing.'):
        name = name[7:]
    if name.startswith('typing_extensions.'):
        name = name[18:]

    mapping = {
        'int': 'int',
        'float': 'f64',
        'str': 'string',
        'bytes': '[]u8',
        'bool': 'bool',
        'None': 'none',
        'Any': 'Any',
        'object': 'Any', # Map object to Any
        'list': '[]int',
        'dict': 'map[string]int',
        'tuple': '[]int',
        'set': 'map[int]bool',
        'memoryview': '[]u8',
        'bytearray': '[]u8',
        'IO': 'os.File',
        'TextIO': 'os.File',
        'BinaryIO': 'os.File',
        'StringIO': 'strings.Builder',
        'io.StringIO': 'strings.Builder',
        'six.moves.StringIO': 'strings.Builder',
        'NoReturn': 'void',
        'List': '[]Any',
        'Dict': 'map[string]Any',
        'Tuple': '[]Any',
        'Set': 'map[string]bool',
        'Optional': '?Any',
        'Union': 'Any',
        'Callable': 'fn',
        'Sequence': '[]Any',
        'Iterable': '[]Any',
        'Mapping': 'map[string]Any',
        'typing.Any': 'Any',
        'typing.List': '[]Any',
        'typing.Dict': 'map[string]Any',
        'typing.Tuple': '[]Any',
        'typing.Set': 'map[string]bool',
        'typing.Optional': '?Any',
        'typing.Union': 'Any',
        'typing.Callable': 'fn',
        'typing_extensions.Callable': 'fn',
        'typing_extensions.Union': 'Any',
        'typing.NoReturn': 'void',
        'typing.Sequence': '[]Any',
        'typing.Iterable': '[]Any',
        'typing.Mapping': 'map[string]Any',
        'builtins.int': 'int',
        'builtins.float': 'f64',
        'builtins.str': 'string',
        'builtins.bool': 'bool',
        'builtins.bytes': '[]u8',
        'builtins.object': 'Any',
        'LiteralString': 'string',
        'typing.LiteralString': 'string',
        'typing_extensions.LiteralString': 'string',
        'bytearray': '[]u8',
        'memoryview': '[]u8',
        'TypeForm': 'Any',
        'typing.TypeForm': 'Any',
        'typing_extensions.TypeForm': 'Any',
        'Final': 'Any',
        'typing.Final': 'Any',
        'ClassVar': 'Any',
        'typing.ClassVar': 'Any',
    }
    return mapping.get(name, name)
