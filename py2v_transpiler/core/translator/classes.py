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
        is_deprecated = False
        deprecated_message: Optional[str] = None
        
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
                 
                 # Check for @deprecated("message")
                 if (func == "deprecated" or func == "warnings.deprecated") and dec_args_list:
                     is_deprecated = True
                     # Extract message from first positional argument
                     msg = dec_args_list[0].strip("'\"")
                     deprecated_message = msg
            else:
                 dec_str = self.visit(decorator)
                 # Check for @deprecated without args (rare but possible)
                 if dec_str == "deprecated":
                     is_deprecated = True

            decorators.append(f"// @{dec_str}")
            if dec_str.startswith("dataclass") or dec_str.startswith("dataclasses.dataclass"):
                is_dataclass = True

        # Support for Metaclasses (emit comment)
        for keyword in node.keywords:
            if keyword.arg == "metaclass":
                meta_val = self.visit(keyword.value)
                decorators.append(f"// Metaclass: {meta_val}")

        # Check if it's a mixin or main struct
        is_mixin = struct_name in getattr(self.type_inference, 'mixin_to_main', {})
        is_main_struct = struct_name in getattr(self.type_inference, 'main_to_mixins', {})

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

        # If this is a main struct, collect fields from its mixins first
        if is_main_struct:
            mixin_nodes = getattr(self.type_inference, 'mixin_nodes', {})
            for mixin_name in self.type_inference.main_to_mixins[struct_name]:
                if mixin_name in mixin_nodes:
                    mixin_node = mixin_nodes[mixin_name]
                    for stmt in mixin_node.body:
                        if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                            field_name = self._sanitize_name(stmt.target.id)
                            if field_name not in added_fields:
                                added_fields.add(field_name)
                                field_type = "int"
                                if stmt.annotation:
                                    try:
                                        type_str = ast.unparse(stmt.annotation)
                                        field_type = map_python_type_to_v(type_str, self_name=struct_name)
                                    except Exception:
                                        if isinstance(stmt.annotation, ast.Name):
                                            field_type = stmt.annotation.id
                                if getattr(stmt, 'value', None) is not None:
                                    default_val = self.visit(stmt.value) # type: ignore
                                    fields.append(f"    {field_name} {field_type} = {default_val}")
                                else:
                                    fields.append(f"    {field_name} {field_type}")
                        elif isinstance(stmt, ast.Assign):
                            for target in stmt.targets:
                                if isinstance(target, ast.Name) and target.id != "__slots__":
                                    field_name = self._sanitize_name(target.id)
                                    if field_name not in added_fields:
                                        added_fields.add(field_name)
                                        # Infer type from value
                                        field_type = self._guess_type(stmt.value)
                                        default_val = self.visit(stmt.value)
                                        fields.append(f"    {field_name} {field_type} = {default_val}")

        # If it's a dataclass, try to find perfectly inferred metadata from mypy
        dataclass_metadata = None
        if is_dataclass and hasattr(self.type_inference, 'call_signatures'):
            # Look for the constructor signature which contains the metadata
            for k, sig_data in self.type_inference.call_signatures.items():
                if "dataclass_metadata" in sig_data:
                    # check if it matches this class name
                    # signatures keys are usually "module.ClassName@line:col" or "ClassName@line:col"
                    if k.startswith(f"{node.name}@") or k.split('@')[0].endswith(f".{node.name}") or k.startswith(f"{struct_name}@"):
                        dataclass_metadata = sig_data["dataclass_metadata"]
                        break

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

        # Init readonly_fields
        if not hasattr(self, 'readonly_fields'):
            self.readonly_fields = {}

        # Handle inheritance (bases)
        is_flag = False
        for base in node.bases:
            # Helper to check if a name refers to an Enum type
            def is_enum_type(name: str) -> tuple[bool, bool, bool]:
                """Returns (is_enum, is_int_enum, is_flag)"""
                # First check imported symbols (e.g., from enum import Enum)
                # This is more specific than just checking the name
                if name in self.imported_symbols:
                    full_name = self.imported_symbols[name]
                    if full_name in ("enum.Enum", "enum.IntEnum", "enum.Flag", "enum.IntFlag"):
                        if full_name == "enum.Enum":
                            return (True, False, False)
                        elif full_name == "enum.IntEnum":
                            return (True, True, False)
                        elif full_name == "enum.Flag":
                            return (True, False, True)
                        elif full_name == "enum.IntFlag":
                            return (True, True, True)
                
                # Check direct names (when Enum is not imported or built-in)
                if name in ("Enum", "IntEnum", "Flag", "IntFlag"):
                    if name == "Enum":
                        return (True, False, False)
                    elif name == "IntEnum":
                        return (True, True, False)
                    elif name == "Flag":
                        return (True, False, True)
                    elif name == "IntFlag":
                        return (True, True, True)
                return (False, False, False)
            
            # Handle Enum - check both ast.Name and ast.Attribute
            base_name = ""
            if isinstance(base, ast.Name):
                base_name = base.id
            elif isinstance(base, ast.Attribute):
                base_name = base.attr
            
            is_enum_result = is_enum_type(base_name)
            if is_enum_result[0]:
                is_enum = is_enum_result[0] or is_enum
                is_int_enum = is_enum_result[1] or is_int_enum
                is_flag = is_enum_result[2] or is_flag
            elif isinstance(base, ast.Name):
                if base.id == "TestCase":
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
                val = self.visit(base)
                if val == "unittest.TestCase":
                     is_unittest = True
                elif val == "typing.Protocol":
                     is_protocol = True
                elif val == "typing.NamedTuple":
                     is_named_tuple = True
                elif val in ("typing.TypedDict", "TypedDict"):
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
                    if base_name not in self.known_interfaces and base_name not in getattr(self.type_inference, 'mixin_to_main', {}):
                        type_str = ast.unparse(base)
                        v_type = map_python_type_to_v(type_str)
                        fields.append(f"    {v_type}")
                    self.current_class_bases.append(base_name)

            elif isinstance(base, ast.Name):
                if base.id not in ("Generic", "Protocol", "NamedTuple", "TypedDict", "object", "ABC"):
                    if base.id not in self.known_interfaces and base.id not in getattr(self.type_inference, 'mixin_to_main', {}):
                        fields.append(f"    {base.id}")
                    self.current_class_bases.append(base.id)
            elif isinstance(base, ast.Attribute):
                val = self.visit(base)
                # Skip TypedDict in fields (check for typing.TypedDict or just TypedDict)
                if val not in ("TypedDict", "typing.TypedDict", "builtins.object", "ABC"):
                    if base.attr not in self.known_interfaces and base.attr not in getattr(self.type_inference, 'mixin_to_main', {}):
                        fields.append(f"    {val}")
                if val != "builtins.object":
                    self.current_class_bases.append(base.attr)

        if is_typed_dict:
            self.readonly_fields[struct_name] = set()

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

                # If we have perfect dataclass metadata, wait to emit fields later to avoid duplicates
                if is_dataclass and dataclass_metadata:
                    # just collect it in added_fields for processing later if needed
                    pass
                else:
                    added_fields.add(field_name)
                    field_type = "int" # default
                    if stmt.annotation:
                        try:
                            type_str = ast.unparse(stmt.annotation)
                            field_type = map_python_type_to_v(type_str, self_name=struct_name)
                        except Exception:
                            if isinstance(stmt.annotation, ast.Name):
                                field_type = stmt.annotation.id

                    if is_typed_dict:
                        # Check for ReadOnly in annotation
                        if stmt.annotation:
                            try:
                                ann_str = ast.unparse(stmt.annotation)
                                if "ReadOnly[" in ann_str or ann_str.startswith("ReadOnly"):
                                    self.readonly_fields[struct_name].add(field_name)
                            except Exception:
                                pass

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

        if is_dataclass and dataclass_metadata:
            # Emit fields purely from mypy's evaluation
            for attr in dataclass_metadata.get('attributes', []):
                # mypy filters out ClassVar, but tracks InitVar.
                # Usually InitVar shouldn't be a struct field unless we keep it for reference.
                # Let's emit InitVars and regular fields, or just regular fields if `is_in_init`?
                # Actually, standard python dataclasses don't store InitVar on the instance!
                # V structs shouldn't have them either if they are just InitVars.
                # mypy's metadata: 'is_init_var': True/False
                is_init_var = attr.get('is_init_var', False)
                if is_init_var:
                    continue

                field_name = self._sanitize_name(attr['name'])
                if field_name in added_fields:
                    continue
                added_fields.add(field_name)

                # Mypy gives types like 'builtins.int', map them to V
                raw_type = attr.get('type', 'Any')
                norm_typ = raw_type.replace("builtins.", "")
                try:
                    field_type = map_python_type_to_v(norm_typ)
                except Exception:
                    field_type = "Any"

                # Fallback cleanups
                if field_type == "int" or norm_typ == "int": field_type = "int"
                elif field_type == "str" or norm_typ == "str": field_type = "string"
                elif field_type == "float" or norm_typ == "float": field_type = "f64"
                elif field_type == "bool" or norm_typ == "bool": field_type = "bool"

                # For defaults, we might need to find the node again to evaluate the value,
                # but V allows initializing without explicit defaults in struct definition if zero-init is fine.
                # If it has a default, we ideally want to fetch it.
                has_default = attr.get('has_default', False)
                default_str = ""
                if has_default:
                    # Scan body for the exact assignment to get the default expression
                    for stmt in body:
                        if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name) and stmt.target.id == attr['name']:
                            if stmt.value:
                                default_str = f" = {self.visit(stmt.value)}"
                            break

                dataclass_field_order.append(field_name)
                fields.append(f"    {field_name} {field_type}{default_str}")


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

        elif is_mixin:
            # Mixin struct is not emitted, but we still generate its methods
            # They will map to the main class in visit_FunctionDef
            if doc_comment:
                # Add doc comment to emitter's globals or functions?
                pass

            has_str = any(m.name == "__str__" for m in methods)
            if has_str:
                for method in methods:
                    if method.name == "__repr__":
                        method.name = "repr"

            for method in methods:
                self.visit(method)
        else:
            struct_def = ""
            if doc_comment:
                struct_def += doc_comment
            
            # PEP 702: Add [deprecated] attribute for @warnings.deprecated decorator
            if is_deprecated:
                if deprecated_message:
                    struct_def += f"[deprecated: '{deprecated_message}']\n"
                else:
                    struct_def += "[deprecated]\n"

            if decorators:
                struct_def += "\n".join(decorators) + "\n"

            if is_enum or is_int_enum or is_flag:
                # Transpile to V enum or flag enum
                enum_fields = []
                _flag_counter = 0 # Track shift for auto() in flags

                for stmt in node.body:
                    # Handle annotated members: RED: int = 1
                    if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                        member_name = self._sanitize_name(stmt.target.id.lower())
                        if stmt.value:
                            # Check for auto()
                            is_auto = False
                            if isinstance(stmt.value, ast.Call):
                                if isinstance(stmt.value.func, ast.Name) and stmt.value.func.id == "auto":
                                    is_auto = True
                                elif isinstance(stmt.value.func, ast.Attribute) and stmt.value.func.attr == "auto":
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
                        else:
                            # No value, just annotation - skip or use counter
                            enum_fields.append(f"    {member_name}")
                    
                    # Handle unannotated members: RED = 1
                    elif isinstance(stmt, ast.Assign):
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
