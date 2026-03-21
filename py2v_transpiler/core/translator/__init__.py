import ast
from typing import Any, List, Optional, Dict, Set

from py2v_transpiler.models.v_types import map_python_type_to_v
from py2v_transpiler.core.generator import VCodeEmitter
from py2v_transpiler.stdlib_map.mapper import StdLibMapper
from py2v_transpiler.core.decorators import DecoratorProcessor
from py2v_transpiler.core.coroutines import CoroutineHandler

from .base import TranslatorBase
from .literals import LiteralsMixin
from .variables_split import VariablesMixin
from .control_flow_split import ControlFlowMixin
from .functions import FunctionsMixin
from .classes import ClassesMixin
from .expressions import ExpressionsMixin
from .imports import ImportsMixin
from .module import ModuleMixin

class VNodeVisitor(
    ModuleMixin,
    ImportsMixin,
    ExpressionsMixin,
    ClassesMixin,
    FunctionsMixin,
    ControlFlowMixin,
    VariablesMixin,
    LiteralsMixin,
    TranslatorBase
):
    def visit(self, node: ast.AST) -> Any:
        self.parent_stack.append(node)
        prev_node = self.current_node
        self.current_node = node
        try:
            return super().visit(node)
        except Exception as e:
            # Error recovery: log and continue if it's not a fatal error
            source_info = self._get_source_info(node)
            msg = f"Transpilation error at {source_info}: {e}"
            if not isinstance(e, (KeyboardInterrupt, SystemExit)):
                self.warnings.append(msg)
                # Ensure the error comment is actually emitted to the output buffer
                # if we are in a context that uses it.
                err_comment = f"/* Error transpiling node at {source_info}: {e} */"
                if isinstance(node, ast.stmt):
                    self.output.append(f"{self._indent()}{err_comment}")
                    return None
                elif isinstance(node, ast.expr):
                    return err_comment
            raise
        finally:
            self.current_node = prev_node
            self.parent_stack.pop()

    def __init__(self, type_inference, config=None):
        super().__init__(type_inference)
        self.config = config
        self.decorator_processor = DecoratorProcessor(self)
        self.coroutine_handler = CoroutineHandler()
        self.emitter = VCodeEmitter()
        # Internal buffer for visiting blocks (functions, loops, etc.)
        self.output: List[str] = []
        self._indent_level = 0
        self.in_main = True # Flag to track if we are at top-level
        self.current_class: Optional[str] = None # Track if we are inside a class definition
        self.current_class_generics: List[str] = [] # Track generics of current class
        self.current_class_bases: List[str] = [] # Track bases of current class
        self.current_class_generic_bases: Dict[str, str] = {}
        self.is_unittest_class = False
        self._zip_counter = 0 # Counter for unique variable names in zip loops
        self.used_builtins = set() # Track used built-in helpers (sorted, reversed, etc)
        self.used_complex = False
        self.used_list_concat = False
        self.used_dict_merge = False
        self.used_string_format = False
        self.renamed_functions = {"main": "py_main"} # Map to rename functions (e.g. main -> py_main)
        self.name_remap = {} # Temporary variable renaming (e.g. x -> it in generators)
        self._walrus_assignments: List[str] = [] # Buffer for walrus operator assignments
        self.single_dispatch_functions: Dict[str, Dict[str, str]] = {} # dispatcher_name -> {type_name -> impl_func_name}
        self.function_names: Set[str] = set()
        self.finally_stack: List[ast.Try] = [] # Stack of active try-finally blocks
        self.loop_stack: List[Dict[str, Any]] = [] # Stack of active loops for break/continue tracking
        self.unique_id_counter: int = 0
        self.vexc_depth: int = 0
        self.parent_stack: List[ast.AST] = []
        self.parent_stack: List[ast.AST] = []
        self.mapper = StdLibMapper()
        self.imported_symbols: Dict[str, str] = {} # alias -> module_name.symbol

