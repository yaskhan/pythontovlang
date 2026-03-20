"""Handler for special class types: Enum, Protocol, unittest."""

import ast
from typing import TYPE_CHECKING, List, Optional

if TYPE_CHECKING:
    pass


class SpecialClassesHandler:
    """Handles processing of special class types."""

    def __init__(self, translator):
        self.translator = translator

    def process_enum_body(
        self,
        node: ast.ClassDef,
        is_flag: bool
    ) -> List[str]:
        """Process Enum class body and return enum fields."""
        enum_fields = []
        _flag_counter = 0

        for stmt in node.body:
            if isinstance(stmt, ast.AnnAssign) and isinstance(
                stmt.target, ast.Name
            ):
                member_name = self.translator._sanitize_name(stmt.target.id.lower())
                if stmt.value:
                    is_auto = False
                    if isinstance(stmt.value, ast.Call):
                        if (
                            isinstance(stmt.value.func, ast.Name)
                            and stmt.value.func.id == "auto"
                        ):
                            is_auto = True
                        elif (
                            isinstance(stmt.value.func, ast.Attribute)
                            and stmt.value.func.attr == "auto"
                        ):
                            is_auto = True

                    if is_auto:
                        if is_flag:
                            val = f"1 << {_flag_counter}"
                            enum_fields.append(f"    {member_name} = {val}")
                            _flag_counter += 1
                        else:
                            enum_fields.append(f"    {member_name}")
                    else:
                        value = self.translator.visit(stmt.value)
                        enum_fields.append(f"    {member_name} = {value}")
                else:
                    enum_fields.append(f"    {member_name}")

            elif isinstance(stmt, ast.Assign):
                for target in stmt.targets:
                    if isinstance(target, ast.Name):
                        member_name = self.translator._sanitize_name(target.id.lower())

                        is_auto = False
                        if isinstance(stmt.value, ast.Call):
                            if (
                                isinstance(stmt.value.func, ast.Name)
                                and stmt.value.func.id == "auto"
                            ):
                                is_auto = True
                            elif (
                                isinstance(stmt.value.func, ast.Attribute)
                                and stmt.value.func.attr == "auto"
                            ):
                                is_auto = True

                        if is_auto:
                            if is_flag:
                                val = f"1 << {_flag_counter}"
                                enum_fields.append(f"    {member_name} = {val}")
                                _flag_counter += 1
                            else:
                                enum_fields.append(f"    {member_name}")
                        else:
                            value = self.translator.visit(stmt.value)
                            enum_fields.append(f"    {member_name} = {value}")

        if not enum_fields:
            if is_flag:
                enum_fields.append("    py_empty = 0")
            else:
                enum_fields.append("    py_empty")

        return enum_fields

    def generate_enum_definition(
        self,
        struct_name: str,
        enum_fields: List[str],
        is_flag: bool,
        is_int_enum: bool,
        is_exported: bool
    ) -> str:
        """Generate V enum definition."""
        pub = "pub " if is_exported else ""
        flag_attr = "@[flag]\n" if is_flag else ""

        enum_parts = [f"{flag_attr}{pub}enum {struct_name} {{\n"]
        if enum_fields:
            enum_parts.append("\n".join(enum_fields))
            enum_parts.append("\n")
        enum_parts.append("}")

        return "".join(enum_parts)

    def generate_interface_definition(
        self,
        struct_name: str,
        methods: List[ast.stmt],
        doc_comment: str,
        decorators: List[str],
        generics_str: str,
        is_exported: bool,
        source_mapping: bool,
        node: ast.ClassDef,
        fields: List[str] = None
    ) -> str:
        """Generate V interface definition."""
        interface_parts = []
        if source_mapping:
            interface_parts.append(f"// @line: {self.translator._get_source_info(node)}\n")
        if doc_comment:
            interface_parts.append(doc_comment)
        if decorators:
            interface_parts.append("\n".join(decorators) + "\n")

        pub = "pub " if is_exported else ""

        interface_parts.append(f"{pub}interface {struct_name}{generics_str} {{")
        if fields:
            # Modern V interfaces can have fields. We should sanitize them if they contain "mut" or "pub".
            clean_fields = []
            for field in fields:
                clean_field = field.replace('pub mut:', '').replace('pub:', '').replace('mut:', '').strip()
                if clean_field:
                    clean_fields.append(f"    {clean_field}")
            interface_parts.extend(clean_fields)
        
        interface_methods = self.translator.class_methods_handler.process_interface_methods(methods)
        interface_parts.extend(interface_methods)
        interface_parts.append("}")

        return "\n".join(interface_parts) + "\n"

    def extract_docstring(self, body: List[ast.stmt]) -> tuple[str, List[ast.stmt]]:
        """
        Extract docstring from class body.

        Returns:
            Tuple of (doc_comment, remaining body)
        """
        doc_comment = ""
        remaining_body = body

        if (
            body
            and isinstance(body[0], ast.Expr)
            and isinstance(body[0].value, ast.Constant)
            and isinstance(body[0].value.value, str)
        ):
            doc = body[0].value.value.strip()
            lines = doc.split("\n")
            doc_comment = "\n".join(lines) + "\n"
            remaining_body = body[1:]

        return doc_comment, remaining_body
