import ast
from typing import Any, List, Optional, Dict, Set
from py2v_transpiler.core.generator import VCodeEmitter
from py2v_transpiler.stdlib_map.mapper import StdLibMapper
from py2v_transpiler.core.decorators import DecoratorProcessor
from py2v_transpiler.core.coroutines import CoroutineHandler

class TranslatorBase(ast.NodeVisitor):
    """
    Base class for VNodeVisitor and its mixins.
    Defines shared state and helper methods.
    """
    def __init__(self, type_inference: Any) -> None:
        self.type_inference = type_inference
        # These will be initialized in VNodeVisitor.__init__
        self.decorator_processor: DecoratorProcessor
        self.coroutine_handler: CoroutineHandler
        self.emitter: VCodeEmitter
        self.mapper: StdLibMapper

        self.output: List[str] = []
        self._indent_level: int = 0
        self.in_main: bool = True
        self.current_class: Optional[str] = None
        self.current_class_generics: List[str] = []
        self.current_class_bases: List[str] = []
        self.current_class_is_unittest: bool = False
        self._zip_counter: int = 0
        self.defined_classes: Dict[str, bool] = {}
        self.used_builtins: Set[str] = set()
        self.used_complex: bool = False
        self.used_list_concat: bool = False
        self.used_dict_merge: bool = False
        self.used_string_format: bool = False
        self.dataclasses: Dict[str, List[str]] = {}
        self.global_vars: Set[str] = set()
        self.renamed_functions: Dict[str, str] = {"main": "py_main"}
        self.name_remap: Dict[str, str] = {}
        self._walrus_assignments: List[str] = []
        self.imported_modules: Dict[str, str] = {}
        self.imported_symbols: Dict[str, str] = {}
        self.single_dispatch_functions: Dict[str, Dict[str, str]] = {} # dispatcher_name -> {type_name -> impl_func_name}
        self.known_interfaces: Set[str] = set()
        self.class_hierarchy: Dict[str, List[str]] = {} # class_name -> list of direct base names
        self.function_names: Set[str] = set()
        self.overloaded_signatures: Dict[str, List[Dict[str, Any]]] = {} # func_name -> list of overload signatures
        self.finally_stack: List[ast.Try] = [] # Stack of active try-finally blocks
        self.loop_stack: List[Dict[str, Any]] = [] # Stack of active loops for break/continue tracking
        self.unique_id_counter: int = 0
        self.vexc_depth: int = 0

    def _indent(self) -> str:
        return "    " * self._indent_level

    def _mangle_name(self, name: str, class_name: Optional[str]) -> str:
        """
        Implements Python's name mangling rules for private attributes.
        If name starts with __ (and not ends with __) and class_name is provided,
        it becomes _ClassName__name.
        """
        if class_name and name.startswith("__") and not name.endswith("__"):
            # Strip leading underscores from class name for cleaner mangling if needed
            stripped_cls = class_name.lstrip('_')
            return f"__{stripped_cls}_{name.lstrip('_')}"
        return name

    def _guess_type(self, node: ast.AST) -> str:
        if isinstance(node, ast.Constant):
             if isinstance(node.value, bool): return "bool"
             if isinstance(node.value, int): return "int"
             if isinstance(node.value, float): return "f64"
             if isinstance(node.value, str): return "string"
             if isinstance(node.value, complex): return "PyComplex"
             return "int"
        elif isinstance(node, ast.Name):
            # Try to resolve via type inference
            inferred = self.type_inference.resolve_type(node)
            if inferred != "void":
                return inferred
            # Try to see if it's in our local map
            if hasattr(self.type_inference, "type_map") and node.id in self.type_inference.type_map:
                return self.type_inference.type_map[node.id]
            return "int" # Fallback
        elif isinstance(node, ast.BinOp):
            if isinstance(node.op, ast.Div):
                left = self._guess_type(node.left)
                right = self._guess_type(node.right)
                if left == "PyComplex" or right == "PyComplex": return "PyComplex"
                return "f64"
            # For Add/Sub/Mult/Mod/Pow, check operands
            left = self._guess_type(node.left)
            right = self._guess_type(node.right)
            if left == "PyComplex" or right == "PyComplex": return "PyComplex"
            if left == "f64" or right == "f64": return "f64"
            if left == "string" or right == "string": return "string"
            return "int"
        elif isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                fid = node.func.id
                if fid == "str": return "string"
                if fid == "int": return "int"
                if fid == "float": return "f64"
                if fid == "bool": return "bool"
                if fid == "len": return "int"

        return "int"


    def _infer_generator_types(self, gen: ast.comprehension) -> None:
        """Infers types of loop variables from the generator and updates type_map."""
        iter_node = gen.iter
        target_node = gen.target

        # Handle simple range
        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name) and iter_node.func.id == "range":
            if isinstance(target_node, ast.Name):
                self.type_inference.type_map[target_node.id] = "int"

        # Handle list literal
        elif isinstance(iter_node, ast.List):
            if iter_node.elts:
                elt_type = self._guess_type(iter_node.elts[0])
                if isinstance(target_node, ast.Name):
                    self.type_inference.type_map[target_node.id] = elt_type

        # Handle zip
        elif isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name) and iter_node.func.id == "zip":
            if isinstance(target_node, ast.Tuple):
                for i, arg in enumerate(iter_node.args):
                    if i < len(target_node.elts):
                        t_elt = target_node.elts[i]
                        if isinstance(t_elt, ast.Name):
                            # Guess type of the argument (list literal, etc)
                            if isinstance(arg, ast.List) and arg.elts:
                                arg_type = self._guess_type(arg.elts[0])
                                self.type_inference.type_map[t_elt.id] = arg_type
                            elif isinstance(arg, ast.Call) and isinstance(arg.func, ast.Name) and arg.func.id == "range":
                                self.type_inference.type_map[t_elt.id] = "int"
