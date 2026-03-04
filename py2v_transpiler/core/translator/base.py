import ast
import os
from typing import Any, List, Optional, Dict, Set
from py2v_transpiler.core.compatibility import CompatibilityLayer
from py2v_transpiler.core.generator import VCodeEmitter
from py2v_transpiler.stdlib_map.mapper import StdLibMapper
from py2v_transpiler.core.decorators import DecoratorProcessor
from py2v_transpiler.core.coroutines import CoroutineHandler

class TranslatorBase(ast.NodeVisitor):
    """
    Base class for VNodeVisitor and its mixins.
    Defines shared state and helper methods.
    """
    def _get_precedence(self, node: ast.AST) -> int:
        """
        Returns the standard Python operator precedence for AST nodes.
        Higher number means tighter binding. Atoms get 100.
        """
        op: Any = None
        if isinstance(node, ast.BinOp):
            op = type(node.op)
        elif isinstance(node, ast.BoolOp):
            op = type(node.op)
        elif isinstance(node, ast.Compare):
            op = type(node.ops[0])
        elif isinstance(node, ast.UnaryOp):
            op = type(node.op)
        else:
            return 100

        precedences = {
            ast.Or: 1, ast.And: 2, ast.Not: 3,
            ast.In: 4, ast.NotIn: 4, ast.Is: 4, ast.IsNot: 4, ast.Lt: 4, ast.LtE: 4, ast.Gt: 4, ast.GtE: 4, ast.NotEq: 4, ast.Eq: 4,
            ast.BitOr: 5, ast.BitXor: 6, ast.BitAnd: 7,
            ast.LShift: 8, ast.RShift: 8,
            ast.Add: 9, ast.Sub: 9,
            ast.Mult: 10, ast.MatMult: 10, ast.Div: 10, ast.FloorDiv: 10, ast.Mod: 10,
            ast.UAdd: 12, ast.USub: 12, ast.Invert: 12,
            ast.Pow: 13,
        }
        return precedences.get(op, 0)

    def _visit_with_parens(self, parent_node: ast.AST, child_node: ast.AST, is_right_operand: bool = False) -> str:
        """
        Visits the child_node and wraps the resulting string in parentheses if its
        operator precedence is lower than its parent's, or if it has the same precedence
        but is the right-hand operand (to preserve left-associativity correctness).
        """
        parent_prec = self._get_precedence(parent_node)
        child_prec = self._get_precedence(child_node)
        child_str = self.visit(child_node)  # type: ignore # Self has a visit method in ast.NodeVisitor

        needs_parens = False
        if child_prec < parent_prec:
            needs_parens = True
        elif child_prec == parent_prec and is_right_operand:
            # Check if they are the exact same kind of operation where right-associativity doesn't matter
            # like `a + (b + c)` -> `a + b + c`. Actually, for integers it might overflow differently,
            # but usually it's safe to flatten commutative/associative ops.
            # To be safe and strict, we generally parenthesize if it's the right operand of the same precedence,
            # unless it's a chained boolean operation of the same type (a and b and c).
            is_same_bool_op = (isinstance(parent_node, ast.BoolOp) and isinstance(child_node, ast.BoolOp) and type(parent_node.op) == type(child_node.op))
            # Also for Add/Mult we can usually flatten.
            is_same_comm_op = (isinstance(parent_node, ast.BinOp) and isinstance(child_node, ast.BinOp) and type(parent_node.op) == type(child_node.op) and type(parent_node.op) in (ast.Add, ast.Mult, ast.BitOr, ast.BitAnd, ast.BitXor))

            if not is_same_bool_op and not is_same_comm_op:
                needs_parens = True

        # Exception: `**` and unary operators.
        # In Python, `2 ** -1` is parsed as `Pow(2, USub(1))`.
        # Even though Pow > USub (13 > 12), Python doesn't require parentheses for the right operand
        # when it's a unary operator (e.g. `2**-1` is valid syntax).
        if needs_parens:
            if isinstance(parent_node, ast.BinOp) and isinstance(parent_node.op, ast.Pow) and isinstance(child_node, ast.UnaryOp):
                if is_right_operand:
                    needs_parens = False

        if needs_parens:
            return f"({child_str})"
        return str(child_str)

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
        self._indent_level: int = 0
        self.in_main: bool = True
        self.current_class: Optional[str] = None
        self.current_class_generics: List[str] = []
        self.current_class_bases: List[str] = []
        self.current_class_is_unittest: bool = False
        self._zip_counter: int = 0
        self.defined_classes: Dict[str, Dict[str, bool]] = {}
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
        self.generic_scopes: List[Dict[str, str]] = [] # Stack of PEP 695 generic mappings
        self.unique_id_counter: int = 0
        self.vexc_depth: int = 0
        self._local_vars_in_scope: Set[str] = set()
        self.fstring_quote_stack: List[str] = []
        self.current_module_name: str = "main"
        self.current_file_name: str = ""
        self.scc_files: Set[str] = set()
        self.module_all: Optional[List[str]] = None
        self.defined_top_level_symbols: Set[str] = set()
        self.warnings: List[str] = []

    def _indent(self) -> str:
        return "    " * self._indent_level

    def _is_collection_type(self, v_type: str) -> bool:
        return v_type.startswith("[]") or v_type.startswith("map[") or v_type == "string"

    def _is_numeric_type(self, v_type: str) -> bool:
        return v_type in ("int", "f64", "i64", "u32", "u64", "i8", "i16", "u8", "u16")

    def _wrap_bool(self, node: ast.expr, invert: bool = False, parent: Optional[ast.AST] = None, is_right_operand: bool = False) -> str:
        v_type = self._guess_type(node)

        # Determine base expression string
        if parent is not None:
             expr = self._visit_with_parens(parent, node, is_right_operand)
        else:
             expr = self.visit(node)

        if self._is_collection_type(v_type):
            op = "==" if invert else ">"
            return f"{expr}.len {op} 0"

        if self._is_numeric_type(v_type):
            op = "==" if invert else "!="
            return f"{expr} {op} 0"

        if v_type == "none":
            return "true" if invert else "false"

        if v_type == "bool":
            if invert:
                # Use _visit_with_parens with a dummy Not op to handle precedence correctly
                dummy_not = ast.UnaryOp(op=ast.Not(), operand=node)
                child_str = self._visit_with_parens(dummy_not, node, is_right_operand=True)
                return f"!{child_str}"
            return expr

        if invert:
             # For other types when inverting, we also want to handles precedence.
             dummy_not = ast.UnaryOp(op=ast.Not(), operand=node)
             child_str = self._visit_with_parens(dummy_not, node, is_right_operand=True)
             return f"!{child_str}"

        return expr

    def _get_scc_prefix(self, file_path: str) -> str:
        """Generates a consistent prefix for a file within an SCC."""
        # Use relative path without extension, replacing separators with underscores
        # to ensure uniqueness within a consolidated package.
        base = file_path.replace('.py', '').replace('/', '__').replace('\\', '__').replace('.', '__')
        if not base:
             base = "py_mod"
        return base

    def _is_top_level_symbol(self, name: str) -> bool:
        """Heuristic to check if a name refers to a top-level symbol (class/func/global)."""
        # In a real transpiler, this would check a pre-populated symbol table.
        # Here we check if it's NOT a method (which would have self.current_class set)
        # and NOT a known local variable.
        return not self.current_class and name not in self._local_vars_in_scope

    def _to_snake_case(self, name: str) -> str:
        """Converts CamelCase or UPPER_CASE to snake_case."""
        if not name: return name

        # Handle already separated names
        if '_' in name:
            return "_".join(self._to_snake_case(p) for p in name.split('_') if p)

        if name.isupper():
            return name.lower()

        res = []
        for i, char in enumerate(name):
            if char.isupper() and i > 0:
                # Underscore if previous was lowercase
                if name[i-1].islower():
                    res.append('_')
                # Or if next is lowercase (handling HTTPClient -> http_client)
                elif i + 1 < len(name) and name[i+1].islower():
                    res.append('_')
            res.append(char.lower())
        return "".join(res)

    def _get_generic_map(self, generic_names: List[str]) -> Dict[str, str]:
        """
        Generates a mapping from Python generic names to unique single-character V generic names.
        Example: ['T_co', 'S_contra'] -> {'T_co': 'T', 'S_contra': 'S'}
        """
        mapping = {}
        # We need to consider already used characters in outer scopes
        used_chars: Set[str] = set()
        for scope in self.generic_scopes:
            used_chars.update(scope.values())

        # Priority mapping: try to use the first uppercase letter
        for name in generic_names:
            # Strip underscores and get first letter
            clean = name.lstrip('_')
            if not clean:
                continue

            char = clean[0].upper()
            if char not in used_chars:
                mapping[name] = char
                used_chars.add(char)
            else:
                # Fallback: find next available uppercase letter
                for c in "TUVWXYZABCDEFGHIJKLMNOPQR":
                    if c not in used_chars:
                        mapping[name] = c
                        used_chars.add(c)
                        break
        return mapping

    def _get_combined_generic_map(self) -> Dict[str, str]:
        """Returns a merged dictionary of all active generic scopes."""
        combined = {}
        for scope in self.generic_scopes:
            combined.update(scope)
        return combined

    def _get_all_active_v_generics(self) -> List[str]:
        """Returns all unique V generic names from all active scopes, in order."""
        all_v = []
        seen = set()
        for scope in self.generic_scopes:
            for v_gen in scope.values():
                if v_gen not in seen:
                    all_v.append(v_gen)
                    seen.add(v_gen)
        return all_v

    def _sanitize_name(self, name: str, is_type: bool = False) -> str:
        """
        Sanitizes Python identifiers that collide with V lang reserved keywords
        or other files in the same SCC cluster.
        """
        # Ensure robustness against test classes and mock translators that do not fully initialize the base class.
        compatibility = getattr(self, 'compatibility', None)
        if compatibility and compatibility.is_v_reserved(name):
            if is_type:
                return name # Any is valid as a type in our transpiler model
            return f"py_{name}"

        if is_type:
            # V types (structs) must be Capitalized
            if name.startswith('_'):
                name = name.lstrip('_')
            if name and name[0].islower():
                name = name[0].upper() + name[1:]

        # Naming collision resolution for SCC flattened modules
        current_file_name = getattr(self, 'current_file_name', '')
        scc_files: set = getattr(self, 'scc_files', set())
        if current_file_name and len(scc_files) > 1 and not getattr(self, 'current_class', None):
            # If we are in a flattened SCC, prefix top-level names to avoid collisions.
            # BUT avoid double prefixing or prefixing builtins
            if not name.startswith("__") and name not in self._local_vars_in_scope:
                prefix = self._get_scc_prefix(current_file_name)
                # Check if already prefixed
                if not name.startswith(prefix + "__"):
                    return f"{prefix}__{name}"

        return name

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

    def _get_full_self_type(self, struct_name: Optional[str] = None) -> str:
        """
        Returns the full V type for 'Self', including generic parameters if the class is generic.
        Example: Builder -> Builder[T]
        """
        name = struct_name or self.current_class or "Self"
        if self.current_class_generics:
            gen_str = f"[{', '.join(self.current_class_generics)}]"
            return f"{name}{gen_str}"
        return name

    def _create_temp(self) -> str:
        self.unique_id_counter += 1
        return f"_aug_tmp_{self.unique_id_counter}"

    def _capture_value(self, node: ast.AST) -> tuple[str, list[str]]:
        """
        Captures an expression into a temporary variable if it's not simple (Name/Constant).
        Returns (expr_string, setup_statements).
        """
        if isinstance(node, (ast.Name, ast.Constant)):
            return self.visit(node), []

        tmp = self._create_temp()
        val_code = self.visit(node)
        return tmp, [f"{self._indent()}{tmp} := {val_code}"]

    def _capture_target(self, node: ast.AST) -> tuple[str, list[str]]:
        """
        Prepares a target for AugAssign by capturing its components.
        Recurses on L-value bases (Attribute, Subscript) to preserve reference path.
        Returns (new_target_string, setup_statements).
        """
        if isinstance(node, ast.Name):
            return self.visit(node), []

        elif isinstance(node, ast.Attribute):
            # Recurse on base if it's an L-value container (Name, Attribute, Subscript)
            # Otherwise capture value (Call, etc.)
            if isinstance(node.value, (ast.Name, ast.Attribute, ast.Subscript)):
                base_expr, base_setup = self._capture_target(node.value)
            else:
                base_expr, base_setup = self._capture_value(node.value)

            return f"{base_expr}.{node.attr}", base_setup

        elif isinstance(node, ast.Subscript):
            # Recurse on base if it's an L-value container
            if isinstance(node.value, (ast.Name, ast.Attribute, ast.Subscript)):
                base_expr, base_setup = self._capture_target(node.value)
            else:
                base_expr, base_setup = self._capture_value(node.value)

            idx_node = node.slice
            # Handle Py < 3.9 ast.Index
            if hasattr(ast, "Index") and isinstance(idx_node, getattr(ast, "Index")):
                 idx_node = idx_node.value

            idx_expr, idx_setup = self._capture_value(idx_node)
            return f"{base_expr}[{idx_expr}]", base_setup + idx_setup

        return self.visit(node), [] # Fallback


    def _check_experimental_type(self, type_str: str, node: ast.AST) -> None:
        """Checks if a type is experimental and warns if the flag is not set."""
        if "TypeForm" in type_str and not (self.config and self.config.experimental):
             self.warnings.append(f"Experimental feature 'TypeForm' used at line {getattr(node, 'lineno', '?')} without --experimental flag.")

    def _guess_type(self, node: ast.AST) -> str:
        if isinstance(node, ast.Constant):
             if isinstance(node.value, bool): return "bool"
             if isinstance(node.value, int): return "int"
             if isinstance(node.value, float): return "f64"
             if isinstance(node.value, str): return "string"
             if isinstance(node.value, complex): return "PyComplex"
             if node.value is None: return "int"
             return "int"
        elif isinstance(node, (ast.UnaryOp)):
            if isinstance(node.op, ast.Not):
                return "bool"
            return self._guess_type(node.operand)
        elif isinstance(node, (ast.BoolOp, ast.Compare)):
            return "bool"
        elif isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                fid = node.func.id
                if fid == "str": return "string"
                if fid == "int": return "int"
                if fid == "float": return "f64"
                if fid == "bool": return "bool"
                if fid == "len": return "int"
                if fid == "input": return "string"
                if fid in ("isinstance", "hasattr", "getattr", "setattr"): return "bool"
        elif isinstance(node, (ast.List, ast.Tuple)):
            if not node.elts:
                return "[]Any"
            element_types = set()
            for elt in node.elts:
                if isinstance(elt, ast.Starred):
                    element_types.add("Any")
                else:
                    element_types.add(self._guess_type(elt))
            if len(element_types) == 1:
                return f"[]{list(element_types)[0]}"
            return "[]Any"
        elif isinstance(node, ast.Dict):
            if not node.keys:
                return "map[string]Any"
            key_types = set()
            val_types = set()
            for k, v in zip(node.keys, node.values):
                if k is None: # Unpacking **expr
                    key_types.add("string")
                    val_types.add("Any")
                else:
                    key_types.add(self._guess_type(k))
                    val_types.add(self._guess_type(v))

            k_type = "string"
            if len(key_types) == 1:
                k_type = list(key_types)[0]
            elif len(key_types) > 1:
                k_type = "Any"

            v_type = "Any"
            if len(val_types) == 1:
                v_type = list(val_types)[0]

            return f"map[{k_type}]{v_type}"
        elif isinstance(node, ast.Name):
            # Check for location-based type mapping (from mypy plugin)
            if hasattr(node, 'lineno') and hasattr(node, 'col_offset'):
                loc_key = f"{node.id}@{node.lineno}:{node.col_offset}"
                if hasattr(self.type_inference, "type_map") and loc_key in self.type_inference.type_map:
                    return self.type_inference.type_map[loc_key]

            # Try to resolve via type inference
            inferred = self.type_inference.resolve_type(node)
            if inferred != "void":
                return inferred
            # Try to see if it's in our local map
            if hasattr(self.type_inference, "type_map") and node.id in self.type_inference.type_map:
                return self.type_inference.type_map[node.id]
            return "int" # Fallback
        elif isinstance(node, ast.Attribute):
            if isinstance(node.value, ast.Name):
                attr_name = f"{node.value.id}.{node.attr}"
                if hasattr(self.type_inference, "type_map") and attr_name in self.type_inference.type_map:
                    return self.type_inference.type_map[attr_name]
            return "Any"
        elif isinstance(node, ast.Subscript):
            if isinstance(node.value, ast.Attribute) and isinstance(node.value.value, ast.Name):
                if node.value.value.id == "sys" and node.value.attr == "argv":
                    return "string"
            elif isinstance(node.value, ast.Name):
                if node.value.id == "argv": # Common if from sys import argv
                    return "string"
            return "Any"
        elif isinstance(node, ast.BinOp):
            left = self._guess_type(node.left)
            right = self._guess_type(node.right)

            if isinstance(node.op, ast.Div):
                if left == "PyComplex" or right == "PyComplex": return "PyComplex"
                return "f64"

            # For Add/Sub/Mult/Mod/Pow, check operands
            if left.startswith("[]"): return left
            if right.startswith("[]"): return right
            if left == "string" or right == "string": return "string"
            if left == "PyComplex" or right == "PyComplex": return "PyComplex"
            if left == "f64" or right == "f64": return "f64"
            return "int"
        return "int"


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
