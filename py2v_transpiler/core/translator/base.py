import ast
import os
from typing import Any, List, Optional, Dict, Set, Tuple, Sequence
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
    current_assignment_type: Optional[str] = None

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
        self.single_dispatch_functions: Dict[str, Dict[str, str]] = {} # dispatcher_name -> {type_name -> impl_func_name}
        self.known_interfaces: Set[str] = set()
        self.class_hierarchy: Dict[str, List[str]] = {} # class_name -> list of direct base names
        self.property_setters: Set[Tuple[str, str]] = set() # (class_name, property_name)
        self.function_names: Set[str] = set()
        self.overloaded_signatures: Dict[str, List[Dict[str, Any]]] = {} # func_name -> list of overload signatures
        self.type_params_map: Dict[str, List[str]] = {} # name -> list of type parameter names
        self.finally_stack: List[ast.Try] = [] # Stack of active try-finally blocks
        self.loop_stack: List[Dict[str, Any]] = [] # Stack of active loops for break/continue tracking
        self.generic_scopes: List[Dict[str, str]] = [] # Stack of PEP 695 generic mappings
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
        self.current_function_return_type: Optional[str] = None
        self.in_pydantic_validator: bool = False
        self.current_assignment_type: Optional[str] = None
        self.current_node: Optional[ast.AST] = None

    def _get_source_info(self, node: Optional[ast.AST] = None) -> str:
        """Returns formatted source information for the given node or current_node."""
        n = node or self.current_node
        if n is None:
            return f"{self.current_file_name}:?:?"

        lineno = getattr(n, 'lineno', '?')
        col = getattr(n, 'col_offset', '?')
        return f"{self.current_file_name}:{lineno}:{col}"

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
            # Check if this name refers to a variable known to be LiteralString
            if hasattr(self.type_inference, "type_map") and node.id in self.type_inference.type_map:
                v_type = self.type_inference.type_map[node.id]
                return v_type == "LiteralString"
        return False

    def _indent(self) -> str:
        return "    " * self._indent_level

    def _is_collection_type(self, v_type: str) -> bool:
        return v_type.startswith("[]") or v_type.startswith("map[") or v_type == "string" or v_type == "LiteralString"

    def _is_clonable_collection(self, v_type: str) -> bool:
        """Checks if a V type is a collection that requires .clone() for mutable assignment."""
        return v_type.startswith("[]") or v_type.startswith("map[")

    def _is_string_type(self, v_type: str) -> bool:
        return v_type == "string" or v_type == "LiteralString"

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
            if isinstance(node, (ast.Call, ast.Name, ast.Attribute)):
                 # Ensure bool result for complex types that might map to 0/1 in V if incorrectly handled
                 return f"{expr}"
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

    @property
    def _local_vars_in_scope(self) -> Set[str]:
        """Returns all local variables in the current function scope."""
        if not self._scope_stack:
            return set()
        return self._scope_stack[-1]

    def _is_top_level_symbol(self, name: str) -> bool:
        """Heuristic to check if a name refers to a top-level symbol (class/func/global)."""
        # In a real transpiler, this would check a pre-populated symbol table.
        # Here we check if it's NOT a method (which would have self.current_class set)
        # and NOT a known local variable.
        if self.current_class:
            return False
        # Check if it's in ANY local scope in the stack
        for scope in self._scope_stack:
            if name in scope:
                return False
        return True

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

    def _get_factory_name(self, struct_name: str) -> str:
        """Returns a snake_case factory name for a given struct name."""
        # Strip generic parameters if present (e.g. Box[int] -> Box)
        base_name = struct_name.split('[')[0]
        return f"new_{self._to_snake_case(base_name)}"

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

    def _find_defining_class_for_static_method(self, class_name: str, method_name: str) -> Optional[str]:
        """Finds the class in the hierarchy where the static/class method is defined."""
        visited = set()
        stack = [class_name]
        while stack:
            curr = stack.pop()
            if curr in visited:
                continue
            visited.add(curr)

            # Check defined classes in translator first
            info = getattr(self, "defined_classes", {}).get(curr, {})
            if method_name in info.get("static_methods", set()) or method_name in info.get("class_methods", set()):
                return curr

            # Check analyzer if available
            if hasattr(self, "type_inference"):
                if method_name in self.type_inference.static_methods.get(curr, set()):
                    return curr
                if method_name in self.type_inference.class_methods.get(curr, set()):
                    return curr

            if curr in self.class_hierarchy:
                stack.extend(self.class_hierarchy[curr])
        return None

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

    def _register_literal_enum(self, nodes: Sequence[ast.AST]) -> str:
        """
        Registers a V enum for a Python Literal type.
        Returns the name of the generated enum.
        """
        values: List[Any] = []
        for node in nodes:
            if isinstance(node, ast.Constant):
                values.append(node.value)
            elif (isinstance(node, ast.UnaryOp) and
                  isinstance(node.op, ast.USub) and
                  isinstance(node.operand, ast.Constant) and
                  isinstance(node.operand.value, (int, float))):
                # We know it's int or float here
                val = node.operand.value
                values.append(-val)
            else:
                # Fallback to string if not a simple constant
                values.append(str(node))

        # Check if all values are of the same basic type
        val_types = {type(v) for v in values}
        base_v_type = "string"
        if len(val_types) == 1:
            t = list(val_types)[0]
            if t == int: base_v_type = "int"
            elif t == float: base_v_type = "f64"
            elif t == bool: base_v_type = "bool"
            elif t == str: base_v_type = "string"

        # Create a stable key for this literal combination
        # Sort values to ensure Literal["a", "b"] and Literal["b", "a"] share the same enum
        sorted_values = sorted([str(v) for v in values])
        key = f"Literal_{base_v_type}_{'_'.join(sorted_values)}"

        if key in self._generated_literal_enums:
            return self._generated_literal_enums[key]

        # Generate unique name
        enum_name = f"LiteralEnum_{len(self._generated_literal_enums)}"

        # Build enum body and value mapping
        enum_lines = [f"pub enum {enum_name} {{"]
        val_map: Dict[Any, str] = {}
        used_member_names: Set[str] = set()

        for i, val in enumerate(values):
            # Sanitize member name
            member_name = str(val).lower().replace(' ', '_').replace('-', '_').replace('.', '_')
            if not member_name or not member_name[0].isalpha():
                member_name = f"val_{i}"

            # Avoid duplicate member names in enum
            base_member = member_name
            counter = 1
            while member_name in used_member_names:
                member_name = f"{base_member}_{counter}"
                counter += 1

            used_member_names.add(member_name)
            enum_lines.append(f"    {member_name}")
            val_map[val] = member_name

        enum_lines.append("}")
        self.emitter.add_struct("\n".join(enum_lines))

        # Add .str() method to the enum to get back the original value
        str_lines = [f"pub fn (e {enum_name}) str() string {{", "    match e {"]
        for val, member in val_map.items():
            if isinstance(val, bytes):
                hex_val = val.hex()
                str_lines.append(f"        .{member} {{ return '{hex_val}' }}")
            elif isinstance(val, (int, float, bool, str)):
                str_val = str(val)
                str_lines.append(f"        .{member} {{ return '{str_val}' }}")
            else:
                # Fallback for complex/None/etc
                str_val = str(val)
                str_lines.append(f"        .{member} {{ return '{str_val}' }}")
        str_lines.append("    }")
        str_lines.append("}")
        self.emitter.add_struct("\n".join(str_lines))

        self._generated_literal_enums[key] = enum_name
        self._literal_enum_values[enum_name] = val_map
        return enum_name

    def _register_sum_type(self, v_union_type: str) -> str:
        """
        Normalizes a V union type, generates a named sum type if not already exists,
        and returns its name (including generic args if applicable).
        """
        parts = [p.strip() for p in v_union_type.split('|')]
        if len(parts) <= 1:
            return v_union_type

        parts.sort()
        normalized = " | ".join(parts)

        if normalized in self._generated_sum_types:
            return self._generated_sum_types[normalized]

        # Generate a name: SumType_Part1Part2
        def clean(s: str) -> str:
            # Map V types to CamelCase-friendly strings
            m = {
                'int': 'Int', 'string': 'String', 'bool': 'Bool', 'f64': 'F64',
                'i64': 'I64', 'u32': 'U32', 'u64': 'U64', 'i8': 'I8', 'i16': 'I16',
                'u8': 'U8', 'u16': 'U16', 'Any': 'Any', 'void': 'Void', 'none': 'None'
            }
            res = m.get(s, s).replace('[]', 'Array').replace('map', 'Map')
            return "".join(c for c in res if c.isalnum() or c == '_')

        type_name = "SumType_" + "".join(clean(p) for p in parts)

        # Avoid collisions
        base_name = type_name
        counter = 1
        while any(v == type_name for v in self._generated_sum_types.values()):
            type_name = f"{base_name}_{counter}"
            counter += 1

        # Identify active generics used in the union
        active_v_generics = self._get_all_active_v_generics()
        used_generics = [g for g in active_v_generics if g in parts or any(f"[{g}]" in p for p in parts) or any(f"{g} " in p for p in parts)]

        gen_decl = f"[{', '.join(used_generics)}]" if used_generics else ""
        gen_args = f"[{', '.join(used_generics)}]" if used_generics else ""

        pub = "pub " if self.config and getattr(self.config, 'include_all_symbols', False) else ""

        llm_comment = "//##LLM@@ Please review this generated sum type. If a semantically identical sum type already exists, replace this definition and its usages with the existing one, and give it a more meaningful name."
        self.emitter.add_struct(f"{llm_comment}\n{pub}type {type_name}{gen_decl} = {normalized}")

        result = f"{type_name}{gen_args}"
        self._generated_sum_types[normalized] = result
        return result

    def _map_type(self, type_str: str, struct_name: Optional[str] = None, allow_union: bool = True, register_sum_types: bool = True, is_return: bool = False) -> str:
        """
        Centralized type mapping that performs map_python_type_to_v
        followed by imported_symbols and SCC-based re-mapping.
        """
        from py2v_transpiler.models.v_types import map_python_type_to_v

        registrar = self._register_sum_type if register_sum_types else None
        lit_registrar = self._register_literal_enum

        v_type = map_python_type_to_v(
            type_str,
            self_name=self._get_full_self_type(struct_name),
            generic_map=self._get_combined_generic_map(),
            allow_union=allow_union,
            sum_type_registrar=registrar,
            literal_registrar=lit_registrar
        )

        if "map[Any]" in v_type:
            v_type = v_type.replace("map[Any]", "map[string]")
            # Note: We do not inject output.append here because _map_type is frequently
            # called within inline expression generation (e.g., function signatures, casts).
            # Injecting comments directly into self.output here can generate syntactically
            # invalid V code by breaking statements in the middle. We handle fallback
            # detection and comment generation strictly at the statement-level generators
            # (e.g., assignment, explicit set/dict calls).

        if is_return and v_type == "none":
            return "void"

        # Centralize LiteralString to string mapping
        if v_type == "LiteralString":
            v_type = "string"

        # Skip re-mapping for basic V types to prevent Any -> typing.Any
        basic_v_types = (
            'Any', 'int', 'string', 'bool', 'void', 'none', 'f64', 'i64', 'u32', 'u64', 'i8', 'i16', 'u8', 'u16',
            'Final', 'ClassVar', 'LiteralString', 'Self'
        )
        if v_type in basic_v_types:
            return v_type

        # Adjust type for imported symbols (aliasing)
        if v_type in self.imported_symbols:
            v_type = self.imported_symbols[v_type]
        elif "." in v_type:
            # Check if it is module.Type
            parts = v_type.split(".")
            module_prefix = ".".join(parts[:-1])
            typename = parts[-1]
            # Match against SCC files
            scc_file = next(
                (
                    f
                    for f in self.scc_files
                    if module_prefix.endswith(
                        f.replace(".py", "").replace("/", ".").replace("\\", ".")
                    )
                ),
                None,
            )
            if scc_file:
                prefix = self._get_scc_prefix(scc_file)
                v_type = f"{prefix}__{typename}"

        return v_type

    def _create_temp(self) -> str:
        self.unique_id_counter += 1
        return f"py_aug_tmp_{self.unique_id_counter}"

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
             if isinstance(node.value, bytes): return "[]u8"
             if isinstance(node.value, complex): return "PyComplex"
             if node.value is None: return "Any"
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
                if fid in self.defined_classes:
                    return fid
                if fid == "str":
                    if node.args and self._is_literal_string_expr(node.args[0]):
                        return "LiteralString"
                    return "string"
                if fid == "int": return "int"
                if fid == "float": return "f64"
                if fid == "bool": return "bool"
                if fid == "len": return "int"
                if fid == "print": return "None"
                if fid == "input": return "string"
                if fid == "open": return "os.File"
                if fid in ("bytearray", "memoryview", "bytes"): return "[]u8"
                if fid in ("isinstance", "hasattr", "getattr", "setattr"): return "bool"
                if fid in ("bytes", "bytearray", "memoryview"): return "[]u8"
                if fid in ("set", "frozenset"):
                    if node.args:
                        arg_type = self._guess_type(node.args[0])
                        if arg_type.startswith("[]"):
                            return f"map[{arg_type[2:]}]bool"
                    return "map[string]bool"

                # Check inferred return type
                inferred_ret = self.type_inference.type_map.get(f"{fid}@return")
                if isinstance(inferred_ret, str):
                    return inferred_ret

            elif isinstance(node.func, ast.Attribute) and node.func.attr == "bytes":
                return "[]u8"
            elif isinstance(node.func, ast.Attribute) and node.func.attr == "open" and isinstance(node.func.value, ast.Name) and node.func.value.id == "os":
                return "os.File"
            elif isinstance(node.func, ast.Attribute) and node.func.attr in ("exists", "isfile", "isdir"):
                # Handle os.path.exists or from os import path; path.exists
                curr = node.func.value
                parts = [node.func.attr]
                while isinstance(curr, ast.Attribute):
                    parts.append(curr.attr)
                    curr = curr.value
                if isinstance(curr, ast.Name):
                    parts.append(curr.id)

                parts.reverse()
                full_name = ".".join(parts)
                if full_name in ("os.path.exists", "os.path.isfile", "os.path.isdir"):
                    return "bool"

                # Check for path.exists if 'from os import path' was used
                if len(parts) >= 2 and parts[-2] == "path" and parts[-1] in ("exists", "isfile", "isdir"):
                    return "bool"
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
        elif isinstance(node, ast.Set):
            if not node.elts:
                return "map[string]bool"
            element_types = set()
            for elt in node.elts:
                if isinstance(elt, ast.Starred):
                    element_types.add("Any")
                else:
                    element_types.add(self._guess_type(elt))
            if len(element_types) == 1:
                t = list(element_types)[0]
                if t == "Any":
                    return "map[string]bool"
                return f"map[{t}]bool"
            return "map[string]bool"
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

            if k_type == "Any":
                k_type = "string"

            v_type = "Any"
            if len(val_types) == 1:
                v_type = list(val_types)[0]
            elif len(val_types) > 1:
                v_type = "Any"

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
            if left == "LiteralString" and right == "LiteralString": return "LiteralString"
            if self._is_string_type(left) or self._is_string_type(right): return "string"
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
