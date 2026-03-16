"""Main file for handling function calls.

This file imports and combines all specialized call handling modules.
"""

import ast
import re
from typing import List, Any

from ..base import TranslatorBase
from .calls_builtin import BuiltinCallsMixin
from .calls_methods import MethodCallsMixin
from .calls_special import SpecialCallsMixin
from .calls_classes import ClassCallsMixin
from .calls_overloads import OverloadCallsMixin
from .calls_generators import GeneratorCallsMixin
from .calls_print import PrintCallsMixin


class CallsMixin(
    BuiltinCallsMixin,
    MethodCallsMixin,
    SpecialCallsMixin,
    ClassCallsMixin,
    OverloadCallsMixin,
    GeneratorCallsMixin,
    PrintCallsMixin,
    TranslatorBase
):
    """Mixin for handling Python AST function calls."""

    def visit_Call(self, node: ast.Call) -> str:
        """Main method for handling function calls."""

        # === Stage 1: Extract function info ===
        func_name_str_lookup, fullname_lookup = self._extract_func_info(node)
        loc_key = f"{getattr(node, 'lineno', 0)}:{getattr(node, 'col_offset', 0)}"

        # Get call signature from type inference
        call_sig = self._get_call_signature(func_name_str_lookup, loc_key)

        # === Stage 2: Process arguments ===
        args = self._process_call_args(node, call_sig)

        # === Stage 3: Process keyword arguments ===
        keyword_args, original_keyword_append = self._process_keywords(node, call_sig, args)

        # === Stage 4: Resolve module and function name ===
        module_name, func_name = self._resolve_module_and_func(node, func_name_str_lookup)

        # === Stage 5: Handle special cases by module/function ===
        result = self._handle_special_cases(
            node, module_name, func_name, func_name_str_lookup, args, call_sig
        )
        if result:
            return result

        # === Stage 6: Handle via mapper ===
        if module_name and func_name:
            result = self._handle_via_mapper(node, module_name, func_name, args)
            if result:
                return result

        # === Stage 7: Handle overloads ===
        result = self._handle_overloads(node, call_sig, args)
        if result:
            return result

        # === Stage 8: Handle SCC calls ===
        result = self._handle_scc_call(node, node.func, func_name_str_lookup, args)
        if result:
            return result

        # === Stage 9: Handle typing.assert_type and assert_never ===
        original_id = node.func.id if isinstance(node.func, ast.Name) else None
        result = self._handle_typing_assert_functions(
            node, func_name_str_lookup, original_id, args
        )
        if result:
            return result

        # === Stage 10: Handle built-in type cast functions ===
        result = self._handle_builtin_type_cast(node, str(func_name_str_lookup), original_id, args)
        if result:
            return result

        # === Stage 11: Handle object methods ===
        result = self._handle_object_method_call(node, node.func, func_name_str_lookup, args)
        if result:
            return result

        # === Stage 12: Handle classes and dataclass ===
        result = self._handle_dataclass_call(node, func_name_str_lookup, args, call_sig)
        if result:
            return result

        result = self._handle_class_call(node, node.func, func_name_str_lookup, args, call_sig)
        if result:
            return result

        # === Stage 13: Handle iterators and generators ===
        result = self._handle_iterator_functions(node, func_name_str_lookup, args)
        if result:
            return result

        result = self._handle_generator_call(node, func_name_str_lookup, args)
        if result:
            return result

        # === Stage 14: Handle print/input ===
        if func_name_str_lookup == "print":
            result = self._handle_print_call(node, args)
            if result:
                return result

        if func_name_str_lookup == "input":
            result = self._handle_input_call(node, args)
            if result:
                return result

        # === Stage 15: Handle unittest.main() ===
        if module_name == "unittest" and func_name == "main":
            return "// unittest.main() ignored"

        # === Stage 16: Fallback - standard handling ===
        return self._handle_fallback_call(node, func_name_str_lookup, args, call_sig)

    def _extract_func_info(self, node: ast.Call) -> tuple:
        """Extract function info for lookup."""
        func_name_str_lookup = ""
        fullname_lookup = ""
        
        if isinstance(node.func, ast.Name):
            func_name_str_lookup = node.func.id
            if func_name_str_lookup in getattr(self, 'imported_symbols', {}):
                fullname_lookup = self.imported_symbols[func_name_str_lookup]
        elif isinstance(node.func, ast.Subscript):
            # Handle UserDict[T]()
            if isinstance(node.func.value, ast.Name):
                func_name_str_lookup = node.func.value.id
                # Store full subscript for visit_Call generic params extraction if needed
                # But ClassCallsMixin._handle_class_call already handles stripping [
                # Wait, if we return just the name here, visit_Call will use it for lookup.
                # Actually, ClassCallsMixin._handle_class_call expects the full string or handles it.
                # Let's see: node.func is passed to _handle_class_call too.
                pass
        elif isinstance(node.func, ast.Attribute):
            func_name_str_lookup = node.func.attr
            if isinstance(node.func.value, ast.Name):
                if node.func.value.id in getattr(self, 'imported_modules', {}):
                    fullname_lookup = f"{self.imported_modules[node.func.value.id]}.{node.func.attr}"
        
        return func_name_str_lookup, fullname_lookup

    def _get_call_signature(self, func_name_str: str, loc_key: str) -> dict | None:
        """Get call signature from type inference."""
        call_sig = None

        if hasattr(self.type_inference, "call_signatures"):
            # Try specific location-based keys first
            potential_keys = [loc_key, f"{func_name_str}@{loc_key}"]

            for pk in potential_keys:
                if pk in self.type_inference.call_signatures:
                    call_sig = self.type_inference.call_signatures[pk]
                    break

            if not call_sig:
                for k, v in self.type_inference.call_signatures.items():
                    if k.endswith(f".{func_name_str}@{loc_key}") or k.endswith(f"@{loc_key}"):
                        if func_name_str in k:
                            call_sig = v
                            break

            if not call_sig:
                call_sig = self.type_inference.call_signatures.get(func_name_str)

        return call_sig

    def _process_call_args(self, node: ast.Call, call_sig: dict | None) -> list:
        """Process positional call arguments."""
        args = []

        for i, arg in enumerate(node.args):
            old_type = self.current_assignment_type

            if call_sig and "args" in call_sig and i < len(call_sig["args"]):
                arg_typ_str = call_sig["args"][i]
                norm_typ = arg_typ_str.replace("builtins.", "")
                try:
                    v_arg_type = self._map_type(norm_typ)
                    self.current_assignment_type = v_arg_type
                except:
                    pass

            val = self.visit(arg)
            if val is not None:
                args.append(str(val))
            else:
                args.append("/* unknown */")

            self.current_assignment_type = old_type

        return args

    def _process_keywords(self, node: ast.Call, call_sig: dict | None, args: list) -> tuple:
        """Process keyword arguments."""
        keyword_args = {}
        original_keyword_append = []

        for keyword in node.keywords:
            if keyword.arg is None:
                # **kwargs call -> pass dict as arg
                val = self.visit(keyword.value)
                args.append(str(val))
            else:
                kw_val_str = str(self.visit(keyword.value))
                keyword_args[keyword.arg] = kw_val_str
                original_keyword_append.append((keyword.arg, kw_val_str))

        # Check if we should inject defaults
        is_dataclass = call_sig and "dataclass_metadata" in call_sig if call_sig else False

        if call_sig and "arg_names" in call_sig and "defaults" in call_sig and not is_dataclass:
            arg_names = call_sig["arg_names"]
            defaults = call_sig["defaults"]

            # Fill positional arguments that are missing
            for i in range(len(args), len(arg_names)):
                arg_name = arg_names[i]
                if arg_name in keyword_args:
                    args.append(keyword_args.pop(arg_name))
                elif arg_name in defaults:
                    val_node = defaults[arg_name]
                    val = str(self.visit(val_node))
                    args.append(val)

        return keyword_args, original_keyword_append

    def _resolve_module_and_func(self, node: ast.Call, func_name_str: str) -> tuple:
        """Resolve module and function name."""
        module_name = None
        func_name = None
        func_node = node.func

        # Resolve qualified name
        qualified_name_parts = self._get_qualified_name_parts(func_node)

        if qualified_name_parts:
            module_name, func_name = self._lookup_module(qualified_name_parts)

        # Fallback for Attribute calls
        if not module_name and isinstance(func_node, ast.Attribute):
            if isinstance(func_node.value, ast.Name) and func_node.value.id in getattr(self, 'imported_modules', {}):
                module_name = self.imported_modules[func_node.value.id]
                func_name = func_node.attr

        # Fallback for Name calls
        if not module_name and isinstance(func_node, ast.Name):
            module_name, func_name = self._resolve_name_call(func_node, func_name_str)

        return module_name, func_name

    def _get_qualified_name_parts(self, func_node: ast.AST) -> List[str]:
        """Extract qualified function name."""
        qualified_name_parts = []
        curr = func_node

        while isinstance(curr, ast.Attribute):
            qualified_name_parts.append(curr.attr)
            curr = curr.value

        if isinstance(curr, ast.Name):
            qualified_name_parts.append(curr.id)
            qualified_name_parts.reverse()

        return qualified_name_parts

    def _lookup_module(self, qualified_name_parts: List[str]) -> tuple:
        """Lookup module by qualified name."""
        full_qualified_parts = qualified_name_parts[:]

        if qualified_name_parts and qualified_name_parts[0] in getattr(self, 'imported_symbols', {}):
            full_name = self.imported_symbols[qualified_name_parts[0]]
            full_qualified_parts = full_name.split(".") + qualified_name_parts[1:]

        for i in range(len(full_qualified_parts), 0, -1):
            prefix = ".".join(full_qualified_parts[:i])

            # Check original module names
            if getattr(self, "mapper", None) and hasattr(self.mapper, "mappings") and prefix in self.mapper.mappings:
                return prefix, ".".join(full_qualified_parts[i:])

            # Check aliases and SCC modules
            if prefix in getattr(self, 'imported_modules', {}):
                return self.imported_modules[prefix], ".".join(full_qualified_parts[i:])
            elif prefix in getattr(self, 'imported_modules', {}).values():
                return prefix, ".".join(full_qualified_parts[i:])

        # Special case for os.path
        if qualified_name_parts and qualified_name_parts[0] == "os" and len(qualified_name_parts) > 1 and qualified_name_parts[1] == "path":
            return "os", ".".join(qualified_name_parts[1:])

        return None, None

    def _resolve_name_call(self, func_node: ast.Name, func_name_str: str) -> tuple:
        """Resolve module for name call."""
        module_name = None
        func_name = None

        if func_name_str in getattr(self, 'imported_symbols', {}):
            full_name = self.imported_symbols[func_name_str]
            parts = full_name.split(".")
            if len(parts) > 1:
                module_name = ".".join(parts[:-1])
                func_name = parts[-1]
            else:
                func_name = parts[0]
        elif func_name_str == "open":
            module_name = "os"
            func_name = "open"
        elif func_name_str in ("hasattr", "getattr", "setattr", "delattr", "eval", "exec", "compile", "type", "super"):
            module_name = "builtins"
            func_name = func_name_str

        return module_name, func_name

    def _handle_special_cases(self, node: ast.Call, module_name: str | None,
                               func_name: str | None, func_name_str: str,
                               args: list, call_sig: dict | None) -> str | None:
        """Handle special cases."""
        
        # six module
        if module_name == "six":
            return self._handle_six_module(str(func_name), node)
        
        # os.open
        if module_name == "os" and func_name == "open":
            self.emitter.add_import("os")
            return self._handle_os_open(node, args)
        
        # builtins
        if module_name == "builtins":
            return self._handle_special_builtin(node, module_name, func_name, args)
        
        # functools.partial
        if module_name == "functools" and func_name == "partial":
            return self._handle_functools_partial(node, args)
        
        # threading.Lock
        result = self._handle_threading_lock(node, node.func)
        if result:
            return result
        
        # super() calls
        if isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Call):
            result = self._handle_super_call(node, node.func, args)
            if result:
                return result
        
        # BaseClass.__init__
        if isinstance(node.func, ast.Attribute) and node.func.attr == "__init__":
            result = self._handle_base_class_init(node, node.func, args)
            if result:
                return result
        
        # unittest assertions
        result = self._handle_unittest_assertions(node, node.func, args)
        if result:
            return result
        
        # object.__new__
        result = self._handle_object_new(node, node.func)
        if result:
            return result
        
        return None

    def _handle_via_mapper(self, node: ast.Call, module_name: str, func_name: str, args: list) -> str | None:
        """Handle call via mapper."""

        # typing.cast
        if module_name == "typing" and func_name == "cast":
            return self._handle_typing_cast(node, args)

        mapped = self.mapper.get_mapping(module_name, func_name, args) if hasattr(self, 'mapper') and self.mapper else None

        if mapped:
            v_imports = self.mapper.get_imports(module_name) if hasattr(self, 'mapper') else []
            if v_imports:
                for imp in v_imports:
                    self.emitter.add_import(imp)
            return mapped

        return None

    def _handle_overloads(self, node: ast.Call, call_sig: dict | None, args: list) -> str | None:
        """Handle overloads."""

        lookup_name = ""
        is_class = False

        if isinstance(node.func, ast.Name):
            lookup_name = node.func.id
            if lookup_name.startswith("py_"):
                for orig_id in ("int", "float", "bool", "str", "map", "filter"):
                    if f"py_{orig_id}" == lookup_name:
                        lookup_name = orig_id
                        break
        elif isinstance(node.func, ast.Attribute):
            lookup_name = node.func.attr

        if call_sig and "is_class" in call_sig:
            is_class = call_sig["is_class"]
        elif hasattr(self, 'defined_classes') and lookup_name in self.defined_classes:
            is_class = True

        resolved_name = self._handle_overloaded_function(
            node, node.func, self.visit(node.func), lookup_name, args, call_sig, is_class
        )
        if resolved_name:
             # Check if callee expects mutable arguments
             final_args_list = self._process_mutated_args(lookup_name, args, call_sig)
             return f"{resolved_name}({', '.join(final_args_list)})"
        return None

    def _handle_fallback_call(self, node: ast.Call, func_name_str: str,
                               args: list, call_sig: dict | None) -> str:
        """Fallback call handling."""

        func_name_str = self.visit(node.func)

        # Handle renaming
        if func_name_str in getattr(self, 'renamed_functions', {}):
            func_name_str = self.renamed_functions[func_name_str]

        original_id = node.func.id if isinstance(node.func, ast.Name) else None
        if original_id and f"py_{original_id}" == func_name_str and original_id in ("map", "filter"):
            func_name_str = original_id

        # Handle isinstance
        if func_name_str == "isinstance":
            result = self._handle_isinstance(node, args)
            if result:
                return result

        # Handle assert_never
        if func_name_str == "assert_never":
            result = self._handle_assert_never(func_name_str, args)
            if result:
                return result

        # Handle assert_type
        if func_name_str == "assert_type":
            result = self._handle_assert_type(node, func_name_str, args)
            if result:
                return result

        # Handle len
        if func_name_str in ("len", "py_len"):
            result = self._handle_len_function(node, func_name_str, args)
            if result:
                return result

        # Handle round
        if func_name_str == "round":
            result = self._handle_round_function(node, func_name_str, args)
            if result:
                return result

        # Check if callee expects mutable arguments
        final_args_list = self._process_mutated_args(func_name_str, args, call_sig)

        return f"{func_name_str}({', '.join(final_args_list)})"

    def _process_mutated_args(self, func_name_str: str, args: list, call_sig: dict | None) -> list:
        """Process mutated arguments."""
        final_args_list = []
        mutated_indices = []

        if func_name_str in getattr(getattr(self, 'type_inference', None), "func_param_mutability", {}):
            mutated_indices = self.type_inference.func_param_mutability[func_name_str]

        for i, arg_str in enumerate(args):
            if i in mutated_indices:
                if not arg_str.startswith("mut "):
                    if re.match(r'^[a-zA-Z_][a-zA-Z0-9._]*$', arg_str):
                        final_args_list.append(f"mut {arg_str}")
                    else:
                        final_args_list.append(arg_str)
                else:
                    final_args_list.append(arg_str)
            else:
                # Re-check for string literals that should be enum members
                final_args_list.append(arg_str)

        return final_args_list
