"""Handling class calls, dataclass, super(), unittest assertions."""

import ast
import re
from typing import Any, List, Optional, Dict, TYPE_CHECKING


class ClassCallsMixin:
    if TYPE_CHECKING:
        def visit(self, node: ast.AST) -> Any: ...
        def _map_type(
            self,
            type_str: str,
            struct_name: Optional[str] = None,
            allow_union: bool = True,
            register_sum_types: bool = True,
            is_return: bool = False
        ) -> str: ...
        def _get_factory_name(self, class_name: str) -> str: ...
        def _sanitize_name(self, name: str, is_type: bool = False) -> str: ...
        defined_classes: Dict[str, Dict[str, Any]]
        dataclasses: Dict[str, List[str]]
        current_class_bases: List[str]
        current_class_generic_bases: Dict[str, str]
        current_class: Optional[str]
        current_class_body: List[ast.AST]
    def _handle_class_call(self, node: ast.Call, func_node: ast.AST, func_name_str: str,
                           args: list, call_sig: dict | None) -> str | None:
        """Handle class instantiation calls."""
        
        # Determine if this is a class instantiation
        is_class = False
        has_factory = False
        lookup_name = func_name_str or ""
        
        # Check if it was sanitized
        if lookup_name.startswith("py_"):
            for orig_id in ("int", "float", "bool", "str", "map", "filter"):
                if f"py_{orig_id}" == lookup_name:
                    lookup_name = orig_id
                    break
        
        # Strip generics for class lookup (e.g. UserDict[T] -> UserDict)
        base_lookup_name = re.sub(r'\[.*\]', '', lookup_name)
        
        if not (call_sig and "is_class" in call_sig) and \
           not (hasattr(self, 'defined_classes') and base_lookup_name in self.defined_classes):
             # Fallback: check if the visited name is a class (e.g. cls -> UserDict[T])
             visited_name = self.visit(func_node)
             v_base_name = re.sub(r'\[.*\]', '', visited_name)
             if hasattr(self, 'defined_classes') and v_base_name in self.defined_classes:
                  lookup_name = visited_name
                  base_lookup_name = v_base_name
                  func_name_str = visited_name

        if call_sig and "is_class" in call_sig:
            is_class = call_sig["is_class"]
            has_factory = call_sig.get("has_init", False) or call_sig.get("has_new", False)
        elif hasattr(self, 'defined_classes') and base_lookup_name in self.defined_classes:
            is_class = True
            class_info = self.defined_classes[base_lookup_name]
            has_factory = class_info.get("has_init", False) or class_info.get("has_new", False)
            if lookup_name in self.defined_classes:
                func_name_str = lookup_name
        
        if not is_class:
            return None
        
        # Handle monomorphization (explicit generic types)
        generic_params = ""
        if call_sig and "return" in call_sig:
            v_ret_type = self._map_type(call_sig["return"])
            if "[" in v_ret_type and v_ret_type.endswith("]"):
                generic_params = "[" + v_ret_type.split("[", 1)[1]
        
        if not generic_params and isinstance(func_node, ast.Subscript):
            try:
                # Handle UserDict[T]
                slice_str = ast.unparse(func_node.slice)
                generic_params = f"[{slice_str}]"
            except:
                pass

        if has_factory:
            factory_name = self._get_factory_name(base_lookup_name) # Use base name for factory
            return f"{factory_name}{generic_params}({', '.join(args)})"
        else:
            # Use full func_name_str if it already contains generics, or combine base and generic_params
            if "[" in func_name_str:
                return f"{func_name_str}{{{', '.join(args)}}}"
            return f"{func_name_str}{generic_params}{{{', '.join(args)}}}"

    def _handle_dataclass_call(self, node: ast.Call, func_name_str: str, args: list,
                               call_sig: dict | None) -> str | None:
        """Handle dataclass constructor calls."""

        dataclass_metadata = None
        if call_sig and "dataclass_metadata" in call_sig:
            dataclass_metadata = call_sig["dataclass_metadata"]

        if dataclass_metadata:
            return self._build_dataclass_init(node, func_name_str, args, dataclass_metadata)

        # Fallback to simple dataclass handling
        if hasattr(self, 'dataclasses') and func_name_str in self.dataclasses:
            field_order = self.dataclasses[func_name_str]
            struct_args = []
            # Map positional args
            for i, arg_val in enumerate(args):
                if i < len(field_order):
                    struct_args.append(f"{field_order[i]}: {arg_val}")
            # Map keyword args
            for keyword in node.keywords:
                if keyword.arg:
                    kw_val_str = str(self.visit(keyword.value))
                    struct_args.append(f"{self._sanitize_name(keyword.arg)}: {kw_val_str}")

            return f"{func_name_str}{{{', '.join(struct_args)}}}"

        return None

    def _build_dataclass_init(self, node: ast.Call, func_name_str: str, args: list,
                              dataclass_metadata: dict) -> str:
        """Build dataclass initialization considering init fields."""

        factory_args = []
        init_fields = [attr for attr in dataclass_metadata.get('attributes', [])
                       if attr.get('is_in_init')]
        has_post_init = dataclass_metadata.get("has_post_init", False)

        struct_args = []

        # Map positional args
        for i, arg_val in enumerate(args):
            if i < len(init_fields):
                field_name = self._sanitize_name(init_fields[i]['name'])
                if not init_fields[i].get('is_init_var', False):
                    struct_args.append(f"{field_name}: {arg_val}")
                factory_args.append(arg_val)

        # Map keyword args
        for keyword in node.keywords:
            if keyword.arg:
                kw_val_str = str(self.visit(keyword.value))
                field_name = self._sanitize_name(keyword.arg)

                is_init_var = False
                for attr in init_fields:
                    if attr['name'] == keyword.arg:
                        is_init_var = attr.get('is_init_var', False)
                        break

                if not is_init_var:
                    struct_args.append(f"{field_name}: {kw_val_str}")
                factory_args.append(f"{field_name}: {kw_val_str}")

        if has_post_init:
            final_factory_args = self._build_post_init_args(node, args, init_fields)
            factory_name = self._get_factory_name(func_name_str)
            return f"{factory_name}({', '.join(final_factory_args)})"

        return f"{func_name_str}{{{', '.join(struct_args)}}}"

    def _build_post_init_args(self, node: ast.Call, args: list, init_fields: list) -> list:
        """Build arguments for post_init."""
        final_factory_args = []

        # First, fill with positional args provided in the call
        for i in range(len(args)):
            final_factory_args.append(args[i])

        # Then, fill remaining from keywords if they match attribute names
        for i in range(len(args), len(init_fields)):
            field_name = init_fields[i]['name']
            found_kw = False

            for keyword in node.keywords:
                if keyword.arg == field_name:
                    final_factory_args.append(str(self.visit(keyword.value)))
                    found_kw = True
                    break

            if not found_kw:
                # Try to find default from body
                later_provided = False
                for j in range(i + 1, len(init_fields)):
                    later_field = init_fields[j]['name']
                    for kw in node.keywords:
                        if kw.arg == later_field:
                            later_provided = True
                            break
                    if later_provided:
                        break

                if later_provided and init_fields[i].get('has_default'):
                    found_default_val = False
                    for body_stmt in getattr(self, "current_class_body", []):
                        if isinstance(body_stmt, ast.AnnAssign) and \
                           isinstance(body_stmt.target, ast.Name) and \
                           body_stmt.target.id == field_name:
                            if body_stmt.value:
                                final_factory_args.append(str(self.visit(body_stmt.value)))
                                found_default_val = True
                            break
                        elif isinstance(body_stmt, ast.Assign):
                            for target in body_stmt.targets:
                                if isinstance(target, ast.Name) and target.id == field_name:
                                    final_factory_args.append(str(self.visit(body_stmt.value)))
                                    found_default_val = True
                                    break
                        if found_default_val:
                            break

        return final_factory_args

    def _handle_super_call(self, node: ast.Call, func_node: ast.AST, args: list) -> str | None:
        """Handle super().method() and super(Class, self).method()."""
        if not isinstance(func_node, ast.Attribute):
            return None
        
        if not isinstance(func_node.value, ast.Call):
            return None
        
        is_super = False
        if isinstance(func_node.value.func, ast.Name) and func_node.value.func.id == "super":
            is_super = True
        
        if not is_super:
            return None
        
        method_name = func_node.attr
        if not self.current_class_bases:
            return f"/* super().{method_name} call without known parent */"
        
        parent = self.current_class_bases[0]
        field_name = self.current_class_generic_bases.get(parent) or self._sanitize_name(parent, is_type=True)
        
        if method_name == "__init__":
            factory_name = self._get_factory_name(parent)
            return f"self.{field_name} = {factory_name}({', '.join(args)})"
        
        return f"self.{field_name}.{method_name}({', '.join(args)})"

    def _handle_base_class_init(self, node: ast.Call, func_node: ast.AST, args: list) -> str | None:
        """Handle BaseClass.__init__(self, ...)."""
        if not isinstance(func_node, ast.Attribute):
            return None

        if func_node.attr != "__init__":
            return None

        if not isinstance(func_node.value, ast.Name):
            return None

        class_name = func_node.value.id
        if not self.current_class_bases or class_name not in self.current_class_bases:
            return None

        if len(args) < 1 or args[0] != "self":
            return None

        base_args = args[1:]
        factory_name = self._get_factory_name(class_name)
        field_name = self.current_class_generic_bases.get(class_name) or self._sanitize_name(class_name, is_type=True)

        return f"self.{field_name} = {factory_name}({', '.join(base_args)})"

    def _handle_unittest_assertions(self, node: ast.Call, func_node: ast.AST, args: list) -> str | None:
        """Handle unittest assertions: assertEqual, assertTrue, etc."""
        is_self_assertion = False

        if isinstance(func_node, ast.Attribute) and func_node.attr.startswith("assert"):
            if isinstance(func_node.value, ast.Name) and func_node.value.id == "self":
                is_self_assertion = True

        if not is_self_assertion or not isinstance(func_node, ast.Attribute):
            return None

        assertion = func_node.attr

        if assertion == "assertEqual" and len(args) == 2:
            return f"assert {args[0]} == {args[1]}"
        elif assertion == "assertNotEqual" and len(args) == 2:
            return f"assert {args[0]} != {args[1]}"
        elif assertion == "assertTrue" and len(args) == 1:
            return f"assert {args[0]}"
        elif assertion == "assertFalse" and len(args) == 1:
            return f"assert !({args[0]})"
        elif assertion == "assertIn" and len(args) == 2:
            return f"assert {args[0]} in {args[1]}"
        elif assertion == "assertNotIn" and len(args) == 2:
            return f"assert {args[0]} !in {args[1]}"
        elif assertion == "assertIsNone" and len(args) == 1:
            return f"assert {args[0]} == none"
        elif assertion == "assertIsNotNone" and len(args) == 1:
            return f"assert {args[0]} != none"
        elif assertion == "assertIs" and len(args) == 2:
            return f"assert {args[0]} == {args[1]}"
        elif assertion == "assertIsNot" and len(args) == 2:
            return f"assert {args[0]} != {args[1]}"

        return None

    def _handle_object_new(self, node: ast.Call, func_node: ast.AST) -> str | None:
        """Handle object.__new__(cls)."""
        if not isinstance(func_node, ast.Attribute):
            return None
        
        if func_node.attr != "__new__":
            return None
        
        receiver = self.visit(func_node.value)
        if receiver in ("object", "super()") or receiver == getattr(self, 'current_class', None):
            if self.current_class:
                return f"{self.current_class}{{}}"
        
        return None

    def visit_TypeVar(self, node: Any) -> str:
        return self._sanitize_name(node.name)

    def visit_ParamSpec(self, node: Any) -> str:
        return self._sanitize_name(node.name)

    def visit_TypeVarTuple(self, node: Any) -> str:
        return self._sanitize_name(node.name)
