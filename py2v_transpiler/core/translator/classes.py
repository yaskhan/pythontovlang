import ast
from typing import List, Optional, Set
from py2v_transpiler.models.v_types import map_python_type_to_v
from .base import TranslatorBase

class ClassesMixin(TranslatorBase):
    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        # Map Python class to V struct
        # Store parent class name for nested classes
        parent_class = self.current_class
        parent_generics = self.current_class_generics.copy()
        parent_bases = self.current_class_bases.copy()
        
        # Generate struct name - prefix with parent class for nested classes
        if parent_class:
            struct_name = f"{parent_class}_{node.name}"
        else:
            struct_name = node.name
        
        self.current_class = struct_name
        self.current_class_generics = []
        self.current_class_bases = []
        self.current_class_is_unittest = False

        # Handle decorators
        decorators = []
        is_dataclass = False
        for decorator in node.decorator_list:
            if isinstance(decorator, ast.Call):
                 # Decorator with args: @dec(arg)
                 func = self.visit(decorator.func)
                 dec_args_list = []
                 for dec_arg in decorator.args:
                     dec_args_list.append(str(self.visit(dec_arg)))
                 for kw in decorator.keywords:
                     val = self.visit(kw.value)
                     dec_args_list.append(f"{kw.arg}={val}")
                 dec_str = f"{func}({', '.join(dec_args_list)})"
            else:
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
        added_fields: Set[str] = set() # Track added fields to prevent duplicates

        is_enum = False
        is_int_enum = False
        is_unittest = False
        is_protocol = False

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
                elif base_name == "Protocol":
                    is_protocol = True
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
        nested_classes = []

        # Check for docstring (emit as comment before struct?)
        # Or inside? V structs don't strictly have docstrings inside unless fields have them.
        # But we can emit a comment before the struct definition.
        # However, visit_ClassDef builds struct_def string.

        body = node.body
        doc_comment = ""
        if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant) and isinstance(body[0].value.value, str):
             doc = body[0].value.value.strip()
             lines = [f"// {line}" for line in doc.splitlines()]
             doc_comment = "\n".join(lines) + "\n"
             body = body[1:]

        for stmt in body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                methods.append(stmt)
            elif isinstance(stmt, ast.ClassDef):
                # Collect nested classes
                nested_classes.append(stmt)
            elif isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                # Class attribute with annotation -> struct field
                field_name = stmt.target.id

                if field_name in added_fields:
                    continue
                added_fields.add(field_name)

                field_type = "int" # default
                if stmt.annotation:
                    try:
                        type_str = ast.unparse(stmt.annotation)
                        field_type = map_python_type_to_v(type_str)
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
                         # Parse value
                         slots_list = []
                         if isinstance(stmt.value, (ast.List, ast.Tuple)):
                             for elt in stmt.value.elts:
                                 if isinstance(elt, ast.Constant) and isinstance(elt.value, str):
                                      slots_list.append(elt.value)
                         elif isinstance(stmt.value, ast.Constant) and isinstance(stmt.value.value, str):
                             slots_list.append(stmt.value.value)

                         for slot in slots_list:
                             if slot not in added_fields:
                                 fields.append(f"    {slot} int") # Default to int
                                 added_fields.add(slot)

        if is_dataclass:
            if not hasattr(self, 'dataclasses'):
                self.dataclasses = {}
            self.dataclasses[struct_name] = dataclass_field_order

        if is_unittest:
             self.current_class_is_unittest = True
             # Do NOT emit struct for unittest class, just methods
             if doc_comment:
                 # No place to put doc comment for unittest class as it has no struct
                 pass
             for method in methods:
                 self.visit(method)
        elif is_protocol:
             # Emit interface
             interface_def = ""
             if doc_comment:
                 interface_def += doc_comment
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
            if doc_comment:
                struct_def += doc_comment
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
                # Restore parent class context
                self.current_class = parent_class
                self.current_class_generics = parent_generics
                self.current_class_bases = parent_bases
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

        # Visit nested classes
        for nested_class in nested_classes:
            self.visit(nested_class)

        # Restore parent class context
        self.current_class = parent_class
        self.current_class_generics = parent_generics
        self.current_class_bases = parent_bases
        self.current_class_is_unittest = False
