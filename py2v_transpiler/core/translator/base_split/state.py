"""Translator state initialization and basic utilities."""

import ast
from typing import Any, Dict, List, Optional, Set, Tuple, TYPE_CHECKING

from py2v_transpiler.core.compatibility import CompatibilityLayer
from py2v_transpiler.core.generator import VCodeEmitter
from py2v_transpiler.stdlib_map.mapper import StdLibMapper
from py2v_transpiler.core.decorators import DecoratorProcessor
from py2v_transpiler.core.coroutines import CoroutineHandler


class TranslatorStateMixin:
    """Mixin for translator state initialization and basic utilities."""

    if TYPE_CHECKING:
        def _guess_type(self, node: ast.AST) -> str: ...
        def visit(self, node: ast.AST) -> str: ...

    current_assignment_type: Optional[str] = None

    def __init__(self, type_inference: Any) -> None:
        self.type_inference = type_inference
        self.compatibility = CompatibilityLayer()

        # These will be initialized in VNodeVisitor.__init__
        self.decorator_processor: DecoratorProcessor
        self.coroutine_handler: CoroutineHandler
        self.emitter: VCodeEmitter
        self.mapper: StdLibMapper
        self.config: Optional[Any] = None

        self.output: List[str] = []
        self.known_v_types: Dict[str, str] = {}
        self._indent_level: int = 0
        self.in_main: bool = True
        self.current_class: Optional[str] = None
        self.current_class_generics: List[str] = []
        self.current_class_bases: List[str] = []
        self.current_class_generic_bases: Dict[str, str] = {}
        self.current_class_is_unittest: bool = False
        self._zip_counter: int = 0
        self.defined_classes: Dict[str, Dict[str, Any]] = {}
        self.used_builtins: Set[str] = set()
        self.used_complex: bool = False
        self.used_list_concat: bool = False
        self.used_dict_merge: bool = False
        self.used_string_format: bool = False
        self.dataclasses: Dict[str, List[str]] = {}
        self._generated_sum_types: Dict[str, str] = {}
        self._generated_literal_enums: Dict[str, str] = {}
        self._literal_enum_values: Dict[str, Dict[Any, str]] = {}
        self.global_vars: Set[str] = set()
        self.renamed_functions: Dict[str, str] = {"main": "py_main"}
        self.name_remap: Dict[str, str] = {}
        self._walrus_assignments: List[str] = []
        self.imported_modules: Dict[str, str] = {}
        self.imported_symbols: Dict[str, str] = {}
        # dispatcher_name -> {type_name -> impl_func_name}
        self.single_dispatch_functions: Dict[str, Dict[str, str]] = {}
        self.known_interfaces: Set[str] = set()
        # class_name -> list of direct base names
        self.class_hierarchy: Dict[str, List[str]] = {}
        # (class_name, property_name)
        self.property_setters: Set[Tuple[str, str]] = set()
        self.function_names: Set[str] = set()
        # func_name -> list of overload signatures
        self.overloaded_signatures: Dict[str, List[Dict[str, Any]]] = {}
        # name -> list of type parameter names
        self.type_params_map: Dict[str, List[str]] = {}
        # Python generic name -> variance modifier (+/-)
        self.generic_variance: Dict[str, str] = {}
        # Python generic name -> default type
        self.generic_defaults: Dict[str, str] = {}
        # Stack of active try-finally blocks
        self.finally_stack: List[ast.Try] = []
        # Stack of active loops for break/continue tracking
        self.loop_stack: List[Dict[str, Any]] = []
        # Stack of PEP 695 generic mappings
        self.generic_scopes: List[Dict[str, str]] = []
        self.unique_id_counter: int = 0
        self.vexc_depth: int = 0
        self._scope_stack: List[Set[str]] = []
        self.fstring_quote_stack: List[str] = []
        self.current_module_name: str = "main"
        self.current_file_name: str = ""
        self.scc_files: Set[str] = set()
        self.module_all: Optional[List[str]] = None
        self.defined_top_level_symbols: Set[str] = set()
        self.warnings: List[str] = []
        self.type_vars: Set[str] = set()
        self.constrained_typevars: Set[str] = set()
        self.current_function_return_type: Optional[str] = None
        self.in_pydantic_validator: bool = False
        self.current_node: Optional[ast.AST] = None

    def _get_source_info(self, node: Optional[ast.AST] = None) -> str:
        """Returns formatted source information for the given node or current_node."""
        n = node or self.current_node
        if n is None:
            return f"{self.current_file_name}:?:?"

        lineno = getattr(n, 'lineno', '?')
        col = getattr(n, 'col_offset', '?')
        return f"{self.current_file_name}:{lineno}:{col}"

    def _indent(self) -> str:
        return "    " * self._indent_level

    def _create_temp(self) -> str:
        self.unique_id_counter += 1
        return f"py_aug_tmp_{self.unique_id_counter}"

    def _is_literal_string_expr(self, node: ast.AST) -> bool:
        """
        Checks if an expression is a literal string, literal concatenation,
        or f-string without non-literal variables.
        """
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return True
        if isinstance(node, ast.JoinedStr):
            return all(self._is_literal_string_expr(v) for v in node.values)
        if isinstance(node, ast.FormattedValue):
            return self._is_literal_string_expr(node.value)
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
            return self._is_literal_string_expr(node.left) and self._is_literal_string_expr(node.right)
        if isinstance(node, ast.Name):
            if hasattr(self.type_inference, "type_map") and node.id in self.type_inference.type_map:
                v_type = self.type_inference.type_map[node.id]
                return v_type == "LiteralString"
        return False

    def _get_scc_prefix(self, file_path: str) -> str:
        """Generates a consistent prefix for a file within an SCC."""
        base = file_path.replace('.py', '').replace('/', '__').replace('\\', '__').replace('.', '__')
        if not base:
            base = "py_mod"
        return base

    @property
    def _local_vars_in_scope(self) -> Set[str]:
        """Returns all local variables in the current function scope."""
        if not self._scope_stack:
            return set()
        return self._scope_stack[-1]

    def _is_top_level_symbol(self, name: str) -> bool:
        """Heuristic to check if a name refers to a top-level symbol."""
        if self.current_class:
            return False
        for scope in self._scope_stack:
            if name in scope:
                return False
        return True

    def _is_exported(self, name: str) -> bool:
        """Checks if a symbol should be marked as public in V."""
        if not getattr(self, 'config', None):
            return False

        config = self.config
        if config and hasattr(config, 'include_all_symbols') and config.include_all_symbols:
            return not name.startswith('_')

        if self.module_all is not None:
            return name in self.module_all

        return not name.startswith('_')

    def _check_experimental_type(self, type_str: str, node: ast.AST) -> None:
        """Checks if a type is experimental and warns if the flag is not set."""
        if "TypeForm" in type_str and not (self.config and self.config.experimental):
            self.warnings.append(
                f"Experimental feature 'TypeForm' used at line {getattr(node, 'lineno', '?')} without --experimental flag."
            )

    def _collect_assigned_vars(self, nodes: List[ast.stmt]) -> Set[str]:
        """Collects names of all variables assigned in a list of statements."""
        assigned: Set[str] = set()
        for node in nodes:
            for child in ast.walk(node):
                if isinstance(child, ast.Assign):
                    for target in child.targets:
                        if isinstance(target, ast.Name):
                            assigned.add(target.id)
                        elif isinstance(target, (ast.Tuple, ast.List)):
                            for elt in target.elts:
                                if isinstance(elt, ast.Name):
                                    assigned.add(elt.id)
                elif isinstance(child, ast.AnnAssign):
                    if isinstance(child.target, ast.Name):
                        assigned.add(child.target.id)
                elif isinstance(child, ast.AugAssign):
                    if isinstance(child.target, ast.Name):
                        assigned.add(child.target.id)
        return assigned

    def _infer_generator_types(self, gen: ast.comprehension) -> None:
        """Infers types of loop variables from the generator and updates type_map."""
        iter_node = gen.iter
        target_node = gen.target

        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name) and iter_node.func.id == "range":
            if isinstance(target_node, ast.Name):
                self.type_inference.type_map[target_node.id] = "int"

        elif isinstance(iter_node, ast.List):
            if iter_node.elts:
                elt_type = self._guess_type(iter_node.elts[0])
                if isinstance(target_node, ast.Name):
                    self.type_inference.type_map[target_node.id] = elt_type

        elif isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name) and iter_node.func.id == "zip":
            if isinstance(target_node, ast.Tuple):
                for i, arg in enumerate(iter_node.args):
                    if i < len(target_node.elts):
                        t_elt = target_node.elts[i]
                        if isinstance(t_elt, ast.Name):
                            if isinstance(arg, ast.List) and arg.elts:
                                arg_type = self._guess_type(arg.elts[0])
                                self.type_inference.type_map[t_elt.id] = arg_type
                            elif isinstance(arg, ast.Call) and isinstance(arg.func, ast.Name) and arg.func.id == "range":
                                self.type_inference.type_map[t_elt.id] = "int"
