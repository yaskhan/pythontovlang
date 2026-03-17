"""Main class definition handler."""

import ast
import re
from typing import Any, Dict, List, Optional, Set, TYPE_CHECKING

if TYPE_CHECKING:
    pass


class ClassDefinitionHandler:
    """Handles the main class definition logic."""

    def __init__(self, translator):
        self.translator = translator
        self.class_stack: List[str] = []

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        """Main entry point for visiting a class definition."""
        from py2v_transpiler.pydantic_support.detector import PydanticDetector
        from py2v_transpiler.pydantic_support.model_processor import PydanticModelProcessor

        # Handle Pydantic models
        if PydanticDetector.is_pydantic_model(node):
            processor: PydanticModelProcessor = PydanticModelProcessor(self.translator)
            processor.process_model(node)
            return

        # Initialize class stack for nested classes
        if not self.class_stack:
            self.class_stack = []

        sanitized_name = self.translator._sanitize_name(node.name, is_type=True)

        if not self.class_stack:
            self.translator.defined_top_level_symbols.add(node.name)

        self.class_stack.append(sanitized_name)
        self.translator._scope_names.append(node.name)
        struct_name = self.translator._sanitize_name("_".join(self.class_stack), is_type=True)

        # Pre-register class definition
        has_init, has_new, static_methods, class_methods = self.translator.class_methods_handler.extract_method_info(node)

        if not hasattr(self.translator, "defined_classes"):
            self.translator.defined_classes = {}
        self.translator.defined_classes[struct_name] = {
            "has_init": has_init,
            "has_new": has_new,
            "static_methods": static_methods,
            "class_methods": class_methods
        }

        # Save previous state
        prev_class = self.translator.current_class
        prev_generics = self.translator.current_class_generics
        prev_generic_map = getattr(self.translator, "current_class_generic_map", {})
        prev_bases = self.translator.current_class_bases
        prev_generic_bases = self.translator.current_class_generic_bases
        prev_is_unittest = self.translator.current_class_is_unittest

        self.translator.current_class = struct_name
        self.translator.current_class_generics = []
        self.translator.current_class_generic_map = {}
        self.translator.current_class_bases = []
        self.translator.current_class_generic_bases = {}
        self.translator.current_class_is_unittest = False

        # Process type parameters (generics)
        py_generics = []
        added_variance_keys = []
        added_default_keys = []
        if hasattr(node, "type_params") and node.type_params:
            for param in node.type_params:
                if hasattr(param, "name"):
                    name = param.name
                    if hasattr(name, "id"):
                        name = name.id

                    if isinstance(name, str):
                        py_generics.append(name)
                        variance = getattr(param, "variance", 0)
                        if variance == 1:
                            self.translator.generic_variance[name] = "+"
                            added_variance_keys.append(name)
                        elif variance == 2:
                            self.translator.generic_variance[name] = "-"
                            added_variance_keys.append(name)

                        default_node = getattr(param, "default", None)
                        if default_node:
                            try:
                                default_str = ast.unparse(default_node)
                                v_default = self.translator._map_type(default_str, struct_name)
                                self.translator.generic_defaults[name] = v_default
                                added_default_keys.append(name)
                            except Exception:
                                pass
            self.translator.type_params_map[struct_name] = list(py_generics)

        # Extract type vars from bases
        for base in node.bases:
            if isinstance(base, ast.Subscript):
                py_gen = []
                if isinstance(base.slice, ast.Tuple):
                    for elt in base.slice.elts:
                        if isinstance(elt, ast.Name):
                            py_gen.append(elt.id)
                        elif isinstance(elt, ast.Starred) and isinstance(
                            elt.value, ast.Name
                        ):
                            py_gen.append(elt.value.id)
                elif isinstance(base.slice, ast.Name):
                    py_gen.append(base.slice.id)
                elif isinstance(base.slice, ast.Starred) and isinstance(
                    base.slice.value, ast.Name
                ):
                    py_gen.append(base.slice.value.id)

                is_generic_base = False
                if isinstance(base.value, ast.Name) and base.value.id == "Generic":
                    is_generic_base = True
                elif isinstance(base.value, ast.Attribute) and base.value.attr == "Generic":
                    is_generic_base = True

                for g in py_gen:
                    if (is_generic_base or g in self.translator.type_vars) and g not in py_generics:
                        py_generics.append(g)

        if py_generics:
            self.translator.current_class_generic_map.update(self.translator._get_generic_map(py_generics))

        # Push class generic scope
        self.translator.generic_scopes.append(self.translator.current_class_generic_map)
        self.translator.current_class_generics = self.translator._get_all_active_v_generics()

        # Process decorators
        decorators, is_dataclass, is_deprecated, is_disjoint_base, deprecated_message = \
            self.translator.class_decorator_handler.process_decorators(node)
        metaclass_decorators = self.translator.class_decorator_handler.process_metaclass(node)
        decorators.extend(metaclass_decorators)

        # Check if mixin or main struct
        is_mixin = struct_name in getattr(self.translator.type_inference, "mixin_to_main", {})
        is_main_struct = struct_name in getattr(
            self.translator.type_inference, "main_to_mixins", {}
        )

        # Initialize fields collection
        fields: List[Any] = []
        dataclass_field_order: List[str] = []
        added_fields: Set[str] = set()

        # Collect mixin fields first
        if is_main_struct:
            mixin_fields = self.translator.class_fields_handler.collect_mixin_fields(
                struct_name, added_fields, is_main_struct
            )
            fields.extend(mixin_fields)

        # Get dataclass metadata
        dataclass_metadata = None
        self.translator.current_class_body = node.body
        if is_dataclass:
            dataclass_metadata = self.translator.class_fields_handler.get_dataclass_metadata(node, struct_name)

        # Process bases and inheritance
        (
            base_fields,
            current_class_bases,
            is_enum,
            is_int_enum,
            is_flag,
            is_unittest,
            is_protocol,
            is_named_tuple,
            is_typed_dict
        ) = self.translator.class_bases_handler.process_bases(node, struct_name)
        self.translator.current_class_bases = current_class_bases
        fields.extend(base_fields)

        # Check for abstract base class
        is_abc = self.translator.class_bases_handler.is_abstract_base_class(node, struct_name)
        if is_abc:
            is_protocol = True
            self.translator.known_interfaces.add(struct_name)

        # Initialize readonly_fields
        if not hasattr(self.translator, "readonly_fields"):
            self.translator.readonly_fields = {}

        if is_typed_dict:
            self.translator.readonly_fields[struct_name] = set()

        # Extract docstring
        doc_comment, body = self.translator.special_classes_handler.extract_docstring(node.body)

        # Check for __post_init__
        has_post_init = False
        if is_dataclass and dataclass_metadata:
            has_post_init = dataclass_metadata.get("has_post_init", False)

        # Separate methods from body and handle nested classes
        methods = []
        remaining_body = []
        for stmt in body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                methods.append(stmt)
            elif isinstance(stmt, ast.ClassDef):
                # Nested class: visit it recursively
                self.translator.visit(stmt)
            else:
                remaining_body.append(stmt)
        body = remaining_body

        # Process class attributes
        attr_fields = self.translator.class_fields_handler.process_class_attributes(
            body, struct_name, added_fields, is_dataclass, is_typed_dict,
            dataclass_metadata, dataclass_field_order
        )
        fields.extend(attr_fields)

        # Process dataclass fields from metadata
        if is_dataclass and dataclass_metadata:
            dc_fields = self.translator.class_fields_handler.process_dataclass_fields(
                body, struct_name, dataclass_metadata, added_fields, dataclass_field_order
            )
            fields.extend(dc_fields)

        # Register dataclass
        if is_dataclass or is_typed_dict:
            if not hasattr(self.translator, "dataclasses"):
                self.translator.dataclasses = {}
            self.translator.dataclasses[struct_name] = dataclass_field_order

        # Generate factory function for dataclasses with __post_init__
        if is_dataclass and has_post_init and dataclass_metadata:
            factory_code = self.translator.class_fields_handler.generate_dataclass_factory(
                struct_name, dataclass_metadata, body, has_post_init
            )
            if factory_code:
                self.translator.emitter.add_function(factory_code)
                self.translator.class_methods_handler.register_class_info(
                    struct_name, True, True, static_methods, class_methods, has_factory=True
                )

        # Handle unittest classes
        if is_unittest:
            self.translator.current_class_is_unittest = True
            for method in methods:
                self.translator.visit(method)

        # Handle Protocol/Interface
        elif is_protocol:
            generics_str = self.translator._get_generics_with_variance_str(self.translator.current_class_generics)
            is_exported = self.translator._is_exported(node.name)
            source_mapping = getattr(self.translator.config, 'source_mapping', False)

            interface_def = self.translator.special_classes_handler.generate_interface_definition(
                struct_name, methods, doc_comment, decorators, generics_str,
                is_exported, source_mapping, node
            )
            self.translator.emitter.add_struct(interface_def)

            # If also a mixin, visit methods
            if is_mixin:
                has_str_mixin = self.translator.class_methods_handler.has_method(methods, "__str__")
                if has_str_mixin:
                    for method in methods:
                        if method.name == "__repr__":
                            method.name = "repr"
                for method in methods:
                    self.translator.visit(method)

        # Handle mixin classes
        elif is_mixin:
            has_str_mixin = self.translator.class_methods_handler.has_method(methods, "__str__")
            for method in methods:
                if method.name == "__repr__":
                    setattr(method, "original_name", "__repr__")
                    if has_str_mixin:
                        setattr(method, "name", "repr")
                    else:
                        setattr(method, "name", "str")
            for method in methods:
                self.translator.visit(method)

        # Handle Enum classes
        elif is_enum or is_int_enum or is_flag:
            enum_fields = self.translator.special_classes_handler.process_enum_body(node, is_flag)
            is_exported = self.translator._is_exported(node.name)
            enum_def = self.translator.special_classes_handler.generate_enum_definition(
                struct_name, enum_fields, is_flag, is_int_enum, is_exported
            )
            self.translator.emitter.add_struct(enum_def)
            # Skip method generation for simple enums
            self._cleanup_and_restore(
                node, prev_class, prev_generics, prev_generic_map,
                prev_bases, prev_generic_bases, prev_is_unittest,
                added_variance_keys, added_default_keys, has_init,
                static_methods, class_methods
            )
            return

        # Handle regular classes
        else:
            # Collect fields from __init__
            init_fields = self.translator.class_fields_handler.collect_init_fields(node, added_fields, struct_name)
            fields.extend(init_fields)

            # Generate struct definition
            struct_parts = []
            if doc_comment:
                struct_parts.append(doc_comment)

            if getattr(self.translator.config, 'source_mapping', False):
                struct_parts.append(f"// @line: {self.translator._get_source_info(node)}\n")

            if is_deprecated:
                if deprecated_message:
                    struct_parts.append(f"@[deprecated: '{deprecated_message}']\n")
                else:
                    struct_parts.append("@[deprecated]\n")

            if is_disjoint_base:
                struct_parts.append("@[disjoint_base]\n")

            if decorators:
                struct_parts.append("\n".join(decorators) + "\n")

            generics_str = self.translator._get_generics_with_variance_str(self.translator.current_class_generics)
            pub = "pub " if self.translator._is_exported(node.name) else ""

            struct_parts.append(f"{pub}struct {struct_name}{generics_str} {{\n")
            if fields:
                struct_parts.append("\n".join(fields))
                struct_parts.append("\n")
            struct_parts.append("}")
            self.translator.emitter.add_struct("".join(struct_parts))

            # Emit class variables as constants
            class_vars = self.translator.defined_classes.get(struct_name, {}).get("class_vars", [])
            for var in class_vars:
                v_name = f"{struct_name}_{var['name']}"
                self.translator.emitter.add_constant(f"pub {v_name} = {var.get('value')}")

            # Rename dunder methods
            has_str = self.translator.class_methods_handler.has_method(methods, "__str__")
            self.translator.class_methods_handler.rename_dunder_methods(methods, has_str)

            # Visit methods
            for method in methods:
                self.translator.visit(method)

        # Pop class generic scope
        self.translator.generic_scopes.pop()

        self._cleanup_and_restore(
            node, prev_class, prev_generics, prev_generic_map,
            prev_bases, prev_generic_bases, prev_is_unittest,
            added_variance_keys, added_default_keys, has_init,
            static_methods, class_methods
        )

    def _cleanup_and_restore(
        self,
        node: ast.ClassDef,
        prev_class,
        prev_generics,
        prev_generic_map,
        prev_bases,
        prev_generic_bases,
        prev_is_unittest,
        added_variance_keys: List[str],
        added_default_keys: List[str],
        has_init: bool,
        static_methods: Set[str],
        class_methods: Set[str]
    ) -> None:
        """Clean up and restore previous state."""
        # Clean up variance and defaults scope
        for k in added_variance_keys:
            if k in self.translator.generic_variance:
                del self.translator.generic_variance[k]
        for k in added_default_keys:
            if k in self.translator.generic_defaults:
                del self.translator.generic_defaults[k]

        # Restore previous state
        self.class_stack.pop()
        self.translator._scope_names.pop()
        self.translator.current_class = prev_class
        self.translator.current_class_generics = prev_generics
        self.translator.current_class_generic_map = prev_generic_map
        self.translator.current_class_bases = prev_bases
        self.translator.current_class_generic_bases = prev_generic_bases
        self.translator.current_class_is_unittest = prev_is_unittest

        # Register class info
        self.translator.class_methods_handler.register_class_info(
            self.translator.current_class, has_init, False, static_methods, class_methods
        )
