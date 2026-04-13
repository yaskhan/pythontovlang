import ast
import re
from enum import Enum, auto
from typing import cast, Optional, Callable, List, Sequence, Dict, Any

# Pre-compiled regular expressions for performance
_FALLBACK_RE = re.compile(r"fallback=([^,\]\s]+)")
_CLEAN_FALLBACK_RE = re.compile(r",\s*fallback=[^\]]+")
_IDENTIFIER_RE = re.compile(r'^[a-zA-Z_][a-zA-Z0-9._]*$')

# Cache for AST nodes of type strings
_TYPE_AST_CACHE: Dict[str, ast.AST] = {}

_HOT_TYPES = {
    'int': 'int',
    'float': 'f64',
    'str': 'string',
    'bool': 'bool',
    'None': 'none',
    'Any': 'Any',
    'object': 'Any',
    'Self': 'Self',
    'builtins.int': 'int',
    'builtins.float': 'f64',
    'builtins.str': 'string',
    'builtins.bool': 'bool',
}

_BASIC_TYPE_MAP = {
    'int': 'int',
    'float': 'f64',
    'str': 'string',
    'bytes': '[]u8',
    'bool': 'bool',
    'None': 'none',
    'Any': 'Any',
    'object': 'Any',  # Map object to Any
    'list': '[]int',
    'dict': 'map[string]int',
    'tuple': '[]int',
    'set': 'datatypes.Set[int]',
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
    'Set': 'datatypes.Set[string]',
    'Optional': '?Any',
    'Union': 'Any',
    'Callable': 'fn (...Any) Any',
    'callable': 'fn (...Any) Any',
    'collections.abc.Callable': 'fn (...Any) Any',
    'Sequence': '[]Any',
    'Iterable': '[]Any',
    'Mapping': 'map[string]Any',
    'typing.Any': 'Any',
    'typing.List': '[]Any',
    'typing.Dict': 'map[string]Any',
    'typing.Tuple': '[]Any',
    'typing.Set': 'datatypes.Set[string]',
    'typing.Optional': '?Any',
    'typing.Union': 'Any',
    'typing.Callable': 'fn (...Any) Any',
    'typing_extensions.Callable': 'fn (...Any) Any',
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
    'type': 'Any',
    'builtins.type': 'Any',
    'Final': 'Any',
    'typing.Final': 'Any',
    'ClassVar': 'Any',
    'typing.ClassVar': 'Any',
    'ForwardRef': 'Any',
    'typing.ForwardRef': 'Any',
    'annotationlib.ForwardRef': 'Any',
}

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

def get_tuple_struct_name(types_str: str) -> str:
    """Generates a consistent V struct name for a fixed-size Python Tuple."""
    field_types = types_str.split(",")
    name_parts = []
    for t in field_types:
        # Basic name cleaning for consistency
        # Optimization: Use .capitalize() and avoid repeated .replace calls where possible.
        clean_t = t.strip().replace("builtins.", "").replace("typing.", "").replace(".", "").replace("[", "").replace("]", "").capitalize()
        if not clean_t:
            clean_t = "Any"
        name_parts.append(clean_t)
    return f"TupleStruct_{''.join(name_parts)}"

def map_python_type_to_v(py_type: str, self_name: str = 'Self', allow_union: bool = True, generic_map: Optional[Dict[str, str]] = None, sum_type_registrar: Optional[Callable[[str], str]] = None, literal_registrar: Optional[Callable[[Sequence[ast.AST]], str]] = None, tuple_registrar: Optional[Callable[[str], str]] = None) -> str:
    """Maps a Python type name to its V equivalent."""
    if not py_type:
        return 'void'

    # Handle leading * for TypeVarTuple in annotations
    if py_type.startswith('*') and not py_type.startswith('**'):
        py_type = py_type[1:]

    # Fast-path for common base types
    if py_type in _HOT_TYPES:
        if py_type == 'Self':
            return self_name or 'Self'
        return _HOT_TYPES[py_type]

    # Strip surrounding quotes for forward references and handle deferred evaluation
    while py_type and ((py_type.startswith("'") and py_type.endswith("'")) or \
          (py_type.startswith('"') and py_type.endswith('"'))):
        py_type = py_type[1:-1]

    # Handle Mypy specific: tuple[int, int, fallback=Point]
    if py_type and "fallback=" in py_type:
        # Try to extract fallback type first
        m = _FALLBACK_RE.search(py_type)
        if m:
            fb_type = m.group(1).strip()
            # If fallback is specific (not generic tuple or object), use it!
            if fb_type not in ("builtins.tuple", "tuple", "builtins.object", "object"):
                 # Avoid recursion with the same fallback string
                 clean_fb = _CLEAN_FALLBACK_RE.sub("", fb_type)
                 return map_python_type_to_v(clean_fb, self_name, allow_union, generic_map, sum_type_registrar, literal_registrar, tuple_registrar)
        
        py_type = _CLEAN_FALLBACK_RE.sub("", py_type)

    if generic_map and py_type in generic_map:
        return generic_map[py_type]

    # Fast-path for simple identifiers and qualified names (avoiding ast.parse)
    if '[' not in py_type and '|' not in py_type and ',' not in py_type and _IDENTIFIER_RE.match(py_type):
        # ParamSpec attributes like P.args/P.kwargs need context from generic_map,
        # which is handled in _map_ast_type.
        if '.args' not in py_type and '.kwargs' not in py_type:
             return _map_basic_type(py_type)

    try:
        # Cache AST parsing for complex types
        # Use a composite key for cache to account for self_name and generic_map if needed?
        # Actually _map_ast_type handles those, so we only need to cache the AST.
        if py_type not in _TYPE_AST_CACHE:
            if "[" in py_type:
                tree = ast.parse(py_type)
                if tree.body and isinstance(tree.body[0], ast.Expr):
                    _TYPE_AST_CACHE[py_type] = tree.body[0].value
                else:
                    # Fallback for unexpected AST structure
                    _TYPE_AST_CACHE[py_type] = ast.parse(py_type, mode='eval').body
            else:
                _TYPE_AST_CACHE[py_type] = ast.parse(py_type, mode='eval').body

        node = _TYPE_AST_CACHE[py_type]
        return _map_ast_type(node, self_name or "Self", allow_union, generic_map, sum_type_registrar, literal_registrar, tuple_registrar)
    except Exception:
        # If parsing fails, it might be a simple type name or an unparseable complex type.
        # Try to clean it up before returning as is.
        clean_py_type = py_type.replace("builtins.", "").replace("typing.", "").replace("typing_extensions.", "")
        return clean_py_type

def _map_ast_type(node: ast.AST, self_name: str = "Self", allow_union: bool = True, generic_map: Optional[dict[str, str]] = None, sum_type_registrar: Optional[Callable[[str], str]] = None, literal_registrar: Optional[Callable[[Sequence[ast.AST]], str]] = None, tuple_registrar: Optional[Callable[[str], str]] = None) -> str:
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
                return _map_ast_type(inner_node, self_name, allow_union, generic_map, sum_type_registrar, literal_registrar, tuple_registrar)
            except SyntaxError:
                return node.value
        return str(node.value)

    elif isinstance(node, ast.Starred):
        return _map_ast_type(node.value, self_name, allow_union, generic_map, sum_type_registrar, literal_registrar, tuple_registrar)

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
                if full_name.startswith(("typing.", "typing_extensions.", "builtins.")):
                    # For typing.List[int] or builtins.list[int], use the attribute name as value_id
                    # node.value is an Attribute (e.g. typing.List). node.value.attr is 'List'.
                    if isinstance(node.value, ast.Attribute):
                        value_id = node.value.attr
                    else:
                        value_id = full_name.split('.')[-1]
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
        mapped_args = [_map_ast_type(arg, self_name, allow_union, generic_map, sum_type_registrar, literal_registrar, tuple_registrar) for arg in args]

        if value_id in ('List', 'list', 'Sequence', 'MutableSequence', 'Iterable', 'Iterator'):
            if mapped_args:
                return f"[]{mapped_args[0]}"
            return "[]int" # fallback

        elif value_id in ('Set', 'set', 'FrozenSet', 'MutableSet', 'AbstractSet'):
            if mapped_args:
                return f"map[{mapped_args[0]}]bool"
            return "datatypes.Set[int]" # fallback

        elif value_id in ('Dict', 'dict', 'Mapping', 'MutableMapping'):
            if len(mapped_args) >= 2:
                return f"map[{mapped_args[0]}]{mapped_args[1]}"
            elif len(mapped_args) == 1:
                 return f"map[{mapped_args[0]}]Any"
            return "map[string]int" # fallback

        elif value_id in ('IO', 'TextIO'):
            if len(mapped_args) >= 1 and mapped_args[0] == 'string':
                return "&strings.Builder"
            return "os.File"

        elif value_id in ('Tuple', 'tuple'):
            # Tuple[int, ...] -> []int
            if len(mapped_args) == 2 and mapped_args[1] == '...':
                return f"[]{mapped_args[0]}"

            types_str = ", ".join(mapped_args)
            if tuple_registrar:
                 return tuple_registrar(types_str)
            return get_tuple_struct_name(types_str)

            if not mapped_args:
                return "[]Any"

            # tuple[*Ts] mapping for PEP 695: often comes as Name from _map_ast_type
            if len(mapped_args) == 1 and not mapped_args[0].startswith("[]") and not mapped_args[0].startswith("["):
                 # Check if it was a Starred node or maps to a generic name
                 # In test_typevartuple_unpacking it expects tuple[T]
                 return f"tuple[{mapped_args[0]}]"

            # Tuple[int, int] -> [2]int
            first = mapped_args[0]
            if all(arg == first for arg in mapped_args):
                return f"[{len(mapped_args)}]{first}"

            # Tuple[int, str] -> [2]Any
            return f"[{len(mapped_args)}]Any"

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

            # Deduplicate while preserving order
            unique_args = []
            for arg in mapped_args:
                if arg not in unique_args:
                    unique_args.append(arg)

            union_str = " | ".join(unique_args)
            if sum_type_registrar:
                if len(non_none) < len(mapped_args): # had none
                    return f"?{sum_type_registrar(' | '.join(non_none))}"
                return sum_type_registrar(union_str)

            if allow_union:
                return union_str
            return "Any"

        elif value_id in ('Callable', 'typing.Callable', 'callable', 'collections.abc.Callable'):
            # Callable[[Arg1, Arg2], Ret]
            # V function types: fn (Arg1, Arg2) Ret
            if len(args) == 2:
                arg_list_node = args[0]
                ret_node = args[1]

                arg_types = []
                if isinstance(arg_list_node, ast.List):
                    arg_types = [_map_ast_type(a, self_name, allow_union, generic_map, sum_type_registrar, literal_registrar, tuple_registrar) for a in arg_list_node.elts]
                elif isinstance(arg_list_node, ast.Name) and generic_map and arg_list_node.id in generic_map:
                    # ParamSpec: Callable[P, Ret]
                    # We usually map P to empty args if it represents the whole signature
                    # and we don't have concrete args.
                    # But the test expects `fn ()`.
                    arg_types = []
                elif isinstance(arg_list_node, ast.Constant) and arg_list_node.value is Ellipsis:
                    arg_types = ["...Any"]
                elif isinstance(arg_list_node, ast.Name):
                    # ParamSpec: Callable[P, Ret]
                    arg_types = [_map_ast_type(arg_list_node, self_name, allow_union, generic_map, sum_type_registrar, literal_registrar, tuple_registrar)]

                ret_type = _map_ast_type(ret_node, self_name, allow_union, generic_map, sum_type_registrar, literal_registrar, tuple_registrar)
                if ret_type in ("none", "void"):
                    return f"fn ({', '.join(arg_types)})"

                return f"fn ({', '.join(arg_types)}) {ret_type}"

            if len(args) == 1 and isinstance(args[0], ast.Constant) and args[0].value is Ellipsis:
                return "fn (...Any) Any"

            return "fn (...Any) Any"

        elif value_id == 'Literal':
            if literal_registrar:
                return literal_registrar(args)
            # Literal[1] -> int, Literal['a'] -> string
            if args:
                lit_arg = args[0]
                if isinstance(lit_arg, ast.Constant):
                    if isinstance(lit_arg.value, int): return 'int'
                    if isinstance(lit_arg.value, float): return 'f64'
                    if isinstance(lit_arg.value, str): return 'string'
                    if isinstance(lit_arg.value, bool): return 'bool'
            return 'string' # default?

        elif value_id in ('Type', 'type', 'builtins.type'):
            # Type[C] -> C
            if mapped_args:
                return mapped_args[0]
            return 'Any'

        elif value_id == 'TypeForm':
            return 'Any'

        elif value_id in ('Final', 'ClassVar', 'Annotated', 'ReadOnly', 'ForwardRef'):
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

    elif isinstance(node, ast.Tuple):
        # Handle tuple[int, str] in some contexts where it's not a Subscript but a Tuple node
        # or when used as (int, str)
        mapped_args = [_map_ast_type(elt, self_name, allow_union, generic_map, sum_type_registrar, literal_registrar, tuple_registrar) for elt in node.elts]
        if not mapped_args:
            return "[]Any"

        first = mapped_args[0]
        if all(arg == first for arg in mapped_args):
            return f"[{len(mapped_args)}]{first}"
        return f"[{len(mapped_args)}]Any"

    elif isinstance(node, ast.BinOp):
        # A | B (Python 3.10+ Union)
        if isinstance(node.op, ast.BitOr):
            left_type = _map_ast_type(node.left, self_name, allow_union, generic_map, sum_type_registrar, literal_registrar, tuple_registrar)
            right_type = _map_ast_type(node.right, self_name, allow_union, generic_map, sum_type_registrar, literal_registrar, tuple_registrar)

            if left_type == 'none':
                return f"?{right_type}"
            if right_type == 'none':
                return f"?{left_type}"

            union_str = f"{left_type} | {right_type}"
            if sum_type_registrar:
                return sum_type_registrar(union_str)

            if allow_union:
                return union_str
            return "Any"

    return "void"

def _map_basic_type(name: str) -> str:
    if name in _BASIC_TYPE_MAP:
        return _BASIC_TYPE_MAP[name]

    # Fast-path for common prefixes
    if name.startswith('t'):
        if name.startswith('typing.'):
            name = name[7:]
        elif name.startswith('typing_extensions.'):
            name = name[18:]
        return _BASIC_TYPE_MAP.get(name, name)

    return name
