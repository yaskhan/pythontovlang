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
        is_dataclass = False
        for decorator in node.decorator_list:
            dec_str = self.visit(decorator)
            decorators.append(f"// @{dec_str}")
            if dec_str.startswith("dataclass") or dec_str.startswith("dataclasses.dataclass"):
                is_dataclass = True

        # Support for Metaclasses (emit comment)
        for keyword in node.keywords:
            if keyword.arg == "metaclass":
                meta_val = self.visit(keyword.value)
                decorators.append(f"// Metaclass: {meta_val}")

        # Extract fields from __init__ or class body annotations (simplified)
        fields = []
        dataclass_field_order = []

        is_enum = False
        is_int_enum = False
        is_unittest = False
        is_protocol = False
        is_named_tuple = False

        # Handle inheritance (bases)
        is_flag = False
        for base in node.bases:
            # Handle Enum
            if isinstance(base, ast.Name):
                if base.id == "Enum":
                    is_enum = True
                elif base.id == "IntEnum":
                    is_int_enum = True
                elif base.id == "Flag":
                    is_enum = True
                    is_flag = True
                elif base.id == "TestCase":
                     # Check if it's likely unittest.TestCase
                     # Or check if base is Attribute unittest.TestCase
                     is_unittest = True
                elif base.id == "Protocol":
                     is_protocol = True
                elif base.id == "NamedTuple":
                     is_named_tuple = True

            elif isinstance(base, ast.Attribute):
                # Check for unittest.TestCase
                val = self.visit(base)
                if val == "unittest.TestCase" or (isinstance(base.value, ast.Name) and base.value.id == "unittest" and base.attr == "TestCase"):
                     is_unittest = True
                elif val == "enum.Flag":
                    is_enum = True
                    is_flag = True
                elif val == "typing.Protocol":
                     is_protocol = True
                elif val == "typing.NamedTuple":
                     is_named_tuple = True

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
                if base.id != "Generic" and base.id != "Protocol" and base.id != "NamedTuple":
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
                        field_type = map_python_type_to_v(type_str, self_name=struct_name)
                    except Exception:
                        if isinstance(stmt.annotation, ast.Name):
                            field_type = stmt.annotation.id

                if is_dataclass:
                    dataclass_field_order.append(field_name)
                    if stmt.value:
                        default_val = self.visit(stmt.value)
                        fields.append(f"    {field_name} {field_type} = {default_val}")
                    else:
                        fields.append(f"    {field_name} {field_type}")
                else:
                    fields.append(f"    {field_name} {field_type}")
            elif isinstance(stmt, ast.Assign):
                 # Check for __slots__
                 for target in stmt.targets:
                     if isinstance(target, ast.Name) and target.id == "__slots__":
                         # Parse value list
                         if isinstance(stmt.value, (ast.List, ast.Tuple)):
                             for elt in stmt.value.elts:
                                 if isinstance(elt, ast.Constant) and isinstance(elt.value, str):
                                      fields.append(f"    {elt.value} int") # Default to int

        if is_dataclass:
            if not hasattr(self, 'dataclasses'):
                self.dataclasses = {}
            self.dataclasses[struct_name] = dataclass_field_order

        if is_unittest:
             self.current_class_is_unittest = True
             # Do NOT emit struct for unittest class, just methods
             for method in methods:
                 self.visit(method)
        elif is_protocol:
             # Emit interface
             interface_def = ""
             if decorators:
                 interface_def += "\n".join(decorators) + "\n"

             generics_str = ""
             if self.current_class_generics:
                sanitized = [g.lstrip('_') for g in self.current_class_generics]
                self.current_class_generics = sanitized
                generics_str = f"[{', '.join(sanitized)}]"

             interface_def += f"interface {struct_name}{generics_str} {{\n"
             # Emit method signatures
             for method in methods:
                 # Manual extraction:
                 m_name = method.name
                 m_args = []
                 for arg in method.args.args:
                     if arg.arg == 'self': continue
                     a_name = arg.arg
                     a_type = "int"
                     if arg.annotation:
                          try:
                               type_str = ast.unparse(arg.annotation)
                               a_type = map_python_type_to_v(type_str, self_name=struct_name)
                          except: pass
                     m_args.append(f"{a_name} {a_type}")

                 m_ret = "void"
                 if method.returns:
                      try:
                           type_str = ast.unparse(method.returns)
                           m_ret = map_python_type_to_v(type_str, self_name=struct_name)
                      except: pass

                 if m_ret == "void":
                      interface_def += f"    {m_name}({', '.join(m_args)})\n"
                 else:
                      interface_def += f"    {m_name}({', '.join(m_args)}) {m_ret}\n"

             interface_def += "}"
             self.emitter.add_struct(interface_def)

        else:
            struct_def = ""
            if decorators:
                struct_def += "\n".join(decorators) + "\n"

            if is_int_enum or (is_enum and is_flag):
                # Transpile to V enum or flag enum
                enum_fields = []
                _flag_counter = 0 # Track shift for auto() in flags

                for stmt in node.body:
                    if isinstance(stmt, ast.Assign):
                        for target in stmt.targets:
                            if isinstance(target, ast.Name):
                                # snake_case conversion for member
                                member_name = target.id.lower()

                                # Check for auto()
                                is_auto = False
                                if isinstance(stmt.value, ast.Call):
                                    if isinstance(stmt.value.func, ast.Name) and stmt.value.func.id == "auto":
                                        is_auto = True
                                    elif isinstance(stmt.value.func, ast.Attribute) and stmt.value.func.attr == "auto":
                                         # enum.auto()
                                        is_auto = True

                                if is_auto:
                                    if is_flag:
                                        val = f"1 << {_flag_counter}"
                                        enum_fields.append(f"    {member_name} = {val}")
                                        _flag_counter += 1
                                    else:
                                        enum_fields.append(f"    {member_name}")
                                else:
                                    value = self.visit(stmt.value)
                                    enum_fields.append(f"    {member_name} = {value}")

                flag_attr = "[flag]\n" if is_flag else ""
                struct_def += f"{flag_attr}enum {struct_name} {{\n" + "\n".join(enum_fields) + "\n}"
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
