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
    if py_type == 'int':
        return 'int'
    elif py_type == 'float':
        return 'f64'
    elif py_type == 'str':
        return 'string'
    elif py_type == 'bool':
        return 'bool'
    elif py_type == 'None':
        return 'none'
    elif py_type.startswith('list') or py_type == 'List':
        # Simple heuristic for lists, actual implementation needs complex type parsing
        return '[]int' # defaulting to int array for now, needs improvement
    elif py_type.startswith('dict') or py_type == 'Dict':
        return 'map[string]string' # defaulting to string map for now
    else:
        return 'void'
