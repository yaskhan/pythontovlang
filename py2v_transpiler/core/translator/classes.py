import ast
from typing import List, Optional
from py2v_transpiler.models.v_types import map_python_type_to_v
from .base import TranslatorBase

class ClassesMixin(TranslatorBase):
    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        # Map Python class to V struct
        struct_name = node.name
        self.current_class = struct_name
        self.current_class_generics = []
        self.current_class_bases = []
        self.current_class_is_unittest = False

        # Handle decorators
        decorators = []
        for decorator in node.decorator_list:
            dec_str = self.visit(decorator)
            decorators.append(f"// @{dec_str}")

        # Extract fields from __init__ or class body annotations (simplified)
        fields = []

        is_enum = False
        is_int_enum = False
        is_unittest = False

        # Handle inheritance (bases)
        for base in node.bases:
            # Handle Enum
            if isinstance(base, ast.Name):
                if base.id == "Enum":
                    is_enum = True
                elif base.id == "IntEnum":
                    is_int_enum = True
                elif base.id == "TestCase":
                     # Check if it's likely unittest.TestCase
                     # Or check if base is Attribute unittest.TestCase
                     is_unittest = True

            elif isinstance(base, ast.Attribute):
                # Check for unittest.TestCase
                val = self.visit(base)
                if val == "unittest.TestCase" or (isinstance(base.value, ast.Name) and base.value.id == "unittest" and base.attr == "TestCase"):
                     is_unittest = True

            # Handle Generic[T]
            if isinstance(base, ast.Subscript):
                base_name = ""
                if isinstance(base.value, ast.Name):
                    base_name = base.value.id
                elif isinstance(base.value, ast.Attribute):
                    base_name = base.value.attr

                if base_name == "Generic":
                    # Extract type vars: Generic[T, U]
                    if isinstance(base.slice, ast.Tuple):
                        for elt in base.slice.elts:
                            if isinstance(elt, ast.Name):
                                self.current_class_generics.append(elt.id)
                    elif isinstance(base.slice, ast.Name):
                        self.current_class_generics.append(base.slice.id)
                    # Don't add Generic to fields
                    continue
                else:
                    # Regular generic base: Parent[T]
                    # Add to fields as embedded struct
                    type_str = ast.unparse(base)
                    v_type = map_python_type_to_v(type_str)
                    fields.append(f"    {v_type}")
                    self.current_class_bases.append(base_name)

            elif isinstance(base, ast.Name):
                if base.id != "Generic":
                    fields.append(f"    {base.id}")
                    self.current_class_bases.append(base.id)
            elif isinstance(base, ast.Attribute):
                val = self.visit(base)
                fields.append(f"    {val}")
                self.current_class_bases.append(base.attr)

        methods = []

        for stmt in node.body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                methods.append(stmt)
            elif isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                # Class attribute with annotation -> struct field
                field_name = stmt.target.id
                field_type = "int" # default
                if stmt.annotation:
                    try:
                        type_str = ast.unparse(stmt.annotation)
                        field_type = map_python_type_to_v(type_str)
                    except Exception:
                        if isinstance(stmt.annotation, ast.Name):
                            field_type = stmt.annotation.id
                fields.append(f"    {field_name} {field_type}")

        if is_unittest:
             self.current_class_is_unittest = True
             # Do NOT emit struct for unittest class, just methods
             for method in methods:
                 self.visit(method)
        else:
            struct_def = ""
            if decorators:
                struct_def += "\n".join(decorators) + "\n"

            if is_int_enum:
                # Transpile to V enum
                enum_fields = []
                for stmt in node.body:
                    if isinstance(stmt, ast.Assign):
                        for target in stmt.targets:
                            if isinstance(target, ast.Name):
                                # snake_case conversion for member
                                member_name = target.id.lower()
                                value = self.visit(stmt.value)
                                enum_fields.append(f"    {member_name} = {value}")

                struct_def += f"enum {struct_name} {{\n" + "\n".join(enum_fields) + "\n}"
                self.emitter.add_struct(struct_def)
                # Skip method generation for simple enums for now
                return

            generics_str = ""
            if self.current_class_generics:
                # Sanitize: _T -> T
                sanitized = [g.lstrip('_') for g in self.current_class_generics]
                self.current_class_generics = sanitized
                generics_str = f"[{', '.join(sanitized)}]"

            struct_def += f"struct {struct_name}{generics_str} {{\n" + "\n".join(fields) + "\n}"
            self.emitter.add_struct(struct_def)

            # Visit methods to generate them as functions
            for method in methods:
                self.visit(method)

        self.current_class = None
        self.current_class_generics = []
        self.current_class_bases = []
        self.current_class_is_unittest = False
