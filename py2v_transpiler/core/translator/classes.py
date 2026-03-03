import ast
from typing import List, Optional, Set
from py2v_transpiler.models.v_types import map_python_type_to_v
from .base import TranslatorBase

class ClassesMixin(TranslatorBase):
    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        # Map Python class to V struct
        # Handle nested classes by prefixing with parent class name
        if not hasattr(self, 'class_stack'):
            self.class_stack = []

        self.class_stack.append(self._sanitize_name(node.name))
        struct_name = self._sanitize_name("_".join(self.class_stack))

        # Pre-register class definition to allow class instantiation inside its own methods
        has_init = False
        for child in node.body:
            if isinstance(child, ast.FunctionDef) and child.name == "__init__":
                has_init = True
                break
        if not hasattr(self, 'defined_classes'):
            self.defined_classes = {}
        self.defined_classes[struct_name] = has_init

        # Save previous state to restore later (for nesting)
        prev_class = self.current_class
        prev_generics = self.current_class_generics
        prev_bases = self.current_class_bases
        prev_is_unittest = self.current_class_is_unittest

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
        is_named_tuple = False
        is_typed_dict = False

        # Record direct bases for class hierarchy
        direct_bases = []
        for base in node.bases:
            if isinstance(base, ast.Name):
                direct_bases.append(base.id)
            elif isinstance(base, ast.Attribute):
                direct_bases.append(base.attr)
        self.class_hierarchy[struct_name] = direct_bases

        def is_descendant_of(cls_name: str, target: str) -> bool:
            visited = set()
            stack = [cls_name]
            while stack:
                curr = stack.pop()
                if curr in visited:
                    continue
                visited.add(curr)
                if curr == target:
                    return True
                if curr in self.class_hierarchy:
                    stack.extend(self.class_hierarchy[curr])
            return False

        # Check if the class is an abstract base class
        # (has ABC in hierarchy AND contains @abstractmethod or no concrete methods)
        has_abstract_method = False
        has_concrete_method = False
        for stmt in node.body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                is_abstract_stmt = False
                for dec in stmt.decorator_list:
                    if isinstance(dec, ast.Name) and dec.id == "abstractmethod":
                        is_abstract_stmt = True
                    elif isinstance(dec, ast.Attribute) and dec.attr == "abstractmethod":
                        is_abstract_stmt = True

                if is_abstract_stmt:
                    has_abstract_method = True
                else:
                    # Check if it's practically empty (pass, ..., raise NotImplementedError)
                    is_empty = True
                    for body_stmt in stmt.body:
                        if isinstance(body_stmt, ast.Pass):
                            continue
                        if isinstance(body_stmt, ast.Expr) and isinstance(body_stmt.value, ast.Constant) and body_stmt.value.value is Ellipsis:
                            continue
                        if isinstance(body_stmt, ast.Expr) and isinstance(body_stmt.value, ast.Constant) and isinstance(body_stmt.value.value, str):
                            continue # Docstring
                        if isinstance(body_stmt, ast.Raise):
                            if isinstance(body_stmt.exc, ast.Name) and body_stmt.exc.id == "NotImplementedError":
                                continue
                            if isinstance(body_stmt.exc, ast.Call) and isinstance(body_stmt.exc.func, ast.Name) and body_stmt.exc.func.id == "NotImplementedError":
                                continue
                        is_empty = False
                        break

                    if not is_empty:
                        has_concrete_method = True

        is_abc = False
        if is_descendant_of(struct_name, "ABC"):
            if has_abstract_method or not has_concrete_method:
                is_abc = True
        elif has_abstract_method:
            is_abc = True

        if is_abc:
            is_protocol = True
            self.known_interfaces.add(struct_name)

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
                elif base.id == "TypedDict":
                     is_typed_dict = True
                elif base.id == "ABC":
                     pass

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
                elif val == "typing.TypedDict" or val == "TypedDict":
                     is_typed_dict = True
                elif base.attr == "ABC":
                     pass

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
                    # Add to fields as embedded struct if not an interface
                    if base_name not in self.known_interfaces:
                        type_str = ast.unparse(base)
                        v_type = map_python_type_to_v(type_str)
                        fields.append(f"    {v_type}")
                    self.current_class_bases.append(base_name)

            elif isinstance(base, ast.Name):
                if base.id not in ("Generic", "Protocol", "NamedTuple", "TypedDict", "object", "ABC"):
                    if base.id not in self.known_interfaces:
                        fields.append(f"    {base.id}")
                    self.current_class_bases.append(base.id)
            elif isinstance(base, ast.Attribute):
                val = self.visit(base)
                # Skip TypedDict in fields (check for typing.TypedDict or just TypedDict)
                if val not in ("TypedDict", "typing.TypedDict", "builtins.object", "ABC"):
                    if base.attr not in self.known_interfaces:
                        fields.append(f"    {val}")
                if val != "builtins.object":
                    self.current_class_bases.append(base.attr)

        methods = []

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
                # Nested class: visit it recursively
                # The stack is currently set to parent class name.
                # So visiting it will push Parent_Child.
                self.visit(stmt)
            elif isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                # Class attribute with annotation -> struct field
                field_name = self._sanitize_name(stmt.target.id)

                if field_name in added_fields:
                    continue
                added_fields.add(field_name)

                field_type = "int" # default
                if stmt.annotation:
                    try:
                        type_str = ast.unparse(stmt.annotation)
                        field_type = map_python_type_to_v(type_str, self_name=struct_name)
                    except Exception:
                        if isinstance(stmt.annotation, ast.Name):
                            field_type = stmt.annotation.id

                if is_dataclass or is_typed_dict:
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
                                      slots_list.append(self._sanitize_name(elt.value))
                         elif isinstance(stmt.value, ast.Constant) and isinstance(stmt.value.value, str):
                             slots_list.append(self._sanitize_name(stmt.value.value))

                         for slot in slots_list:
                             if slot not in added_fields:
                                 fields.append(f"    {slot} int") # Default to int
                                 added_fields.add(slot)

        if is_dataclass or is_typed_dict:
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
                 m_name = self._sanitize_name(method.name)
                 m_args = []
                 for arg in method.args.args:
                     if arg.arg == 'self': continue
                     a_name = self._sanitize_name(arg.arg)
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
                                member_name = self._sanitize_name(target.id.lower())

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

            has_str = any(m.name == "__str__" for m in methods)
            if has_str:
                for method in methods:
                    if method.name == "__repr__":
                        method.name = "repr"

            # Visit methods to generate them as functions
            for method in methods:
                self.visit(method)

        # Restore previous state
        self.class_stack.pop()
        self.current_class = prev_class
        self.current_class_generics = prev_generics
        self.current_class_bases = prev_bases
        self.current_class_is_unittest = prev_is_unittest

        # Ensure we output the nested struct definition at the top level
        # visit_ClassDef doesn't return string, it appends to self.emitter.
        # But wait, self.visit(method) appends to self.emitter? No, self.visit returns string for methods?
        # Methods are visited via visit_FunctionDef.
        # visit_FunctionDef returns string? No, it appends to self.output usually?
        # No, visit_FunctionDef in functions.py does:
        # self.output = ...
        # self.emitter.add_function(...)

        # The struct definition is added via self.emitter.add_struct(struct_def) inside visit_ClassDef.
        # The issue with nested classes test failure:
        # Expected:
        # struct Outer {}
        # struct Outer_Inner {}
        # Got:
        # struct Outer {}

        # Why is Outer_Inner missing?
        # Because we visit nested statements in `body`.
        # `for stmt in body: ... self.visit(stmt)` (Wait, looking at code...)
        # In `visit_ClassDef`, we iterate `body`.
        # `for stmt in body: if isinstance(stmt, (FunctionDef...)): methods.append`.
        # `elif isinstance(stmt, AnnAssign)...`
        # `elif isinstance(stmt, Assign)...`
        # We DO NOT explicitly visit other statements like nested ClassDef!
        # Standard Python `ast.NodeVisitor` visits children if we call generic_visit, but we override `visit_ClassDef`.
        # We need to manually visit nested classes.

        has_init = False
        for method in methods:
            if method.name == "__init__":
                has_init = True
                break

        if not hasattr(self, 'defined_classes'):
            self.defined_classes = {}
        self.defined_classes[struct_name] = has_init

        # Ensure we output the nested struct definition at the top level
        # visit_ClassDef processes body elements via iteration.
        # The iteration logic in visit_ClassDef handles methods, AnnAssign, Assign.
        # We added handling for nested ClassDef in the loop above.
