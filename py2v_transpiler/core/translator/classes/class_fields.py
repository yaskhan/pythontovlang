"""Handler for class fields extraction and processing."""

import ast
from typing import TYPE_CHECKING, List, Set, Dict, Any, Optional

if TYPE_CHECKING:
    pass


class ClassFieldsHandler:
    """Handles extraction and processing of class fields."""

    def __init__(self, translator):
        self.translator = translator

    def collect_mixin_fields(
        self,
        struct_name: str,
        added_fields: Set[str],
        is_main_struct: bool
    ) -> List[str]:
        """Collect fields from mixin classes."""
        fields: List[str] = []
        if not is_main_struct:
            return fields

        mixin_nodes = getattr(self.translator.type_inference, "mixin_nodes", {})
        for mixin_name in self.translator.type_inference.main_to_mixins[struct_name]:
            if mixin_name in mixin_nodes:
                mixin_node = mixin_nodes[mixin_name]
                for stmt in mixin_node.body:
                    if isinstance(stmt, ast.AnnAssign) and isinstance(
                        stmt.target, ast.Name
                    ):
                        field_name = self.translator._sanitize_name(stmt.target.id)
                        if field_name not in added_fields:
                            added_fields.add(field_name)
                            field_type = "int"
                            if stmt.annotation:
                                try:
                                    type_str = ast.unparse(stmt.annotation)
                                    field_type = self.translator._map_type(type_str, struct_name)
                                except Exception:
                                    if isinstance(stmt.annotation, ast.Name):
                                        field_type = stmt.annotation.id
                            if getattr(stmt, "value", None) is not None:
                                default_val = self.translator.visit(stmt.value)
                                fields.append(
                                    f"    {field_name} {field_type} = {default_val}"
                                )
                            else:
                                _ft = field_type
                                if _ft.startswith("fn (") or _ft.startswith("fn("):
                                    _ft += " = unsafe { nil }"
                                fields.append(f"    {field_name} {_ft}")
                    elif isinstance(stmt, ast.Assign):
                        for target in stmt.targets:
                            if (
                                isinstance(target, ast.Name)
                                and target.id != "__slots__"
                            ):
                                field_name = self.translator._sanitize_name(target.id)
                                if field_name not in added_fields:
                                    added_fields.add(field_name)
                                    field_type = self.translator._guess_type(stmt.value)
                                    default_val = self.translator.visit(stmt.value)
                                    fields.append(
                                        f"    {field_name} {field_type} = {default_val}"
                                    )
        return fields

    def get_dataclass_metadata(self, node: ast.ClassDef, struct_name: str) -> Optional[Dict[str, Any]]:
        """Extract dataclass metadata from type inference."""
        if not hasattr(self.translator.type_inference, "call_signatures"):
            return None

        for k, sig_data in self.translator.type_inference.call_signatures.items():
            if "dataclass_metadata" in sig_data:
                if (
                    k.startswith(f"{node.name}@")
                    or k.split("@")[0].endswith(f".{node.name}")
                    or k.startswith(f"{struct_name}@")
                ):
                    return sig_data["dataclass_metadata"]
        return None

    def get_namedtuple_metadata(self, node: ast.ClassDef, struct_name: str) -> Optional[Dict[str, Any]]:
        """Extract namedtuple metadata from type inference."""
        if not hasattr(self.translator.type_inference, "call_signatures"):
            return None

        for k, sig_data in self.translator.type_inference.call_signatures.items():
            if "namedtuple_metadata" in sig_data:
                if (
                    k.startswith(f"{node.name}@")
                    or k.split("@")[0].endswith(f".{node.name}")
                    or k.startswith(f"{struct_name}@")
                ):
                    return sig_data["namedtuple_metadata"]
        return None

    def process_namedtuple_fields(
        self,
        struct_name: str,
        namedtuple_metadata: Dict[str, Any],
        added_fields: Set[str]
    ) -> List[str]:
        """Process fields from namedtuple metadata."""
        fields: List[str] = []
        nt_fields = namedtuple_metadata.get("fields", [])
        nt_types = namedtuple_metadata.get("types", [])
        
        for i, field_name in enumerate(nt_fields):
            f_name = self.translator._sanitize_name(field_name)
            if f_name in added_fields:
                continue
            added_fields.add(f_name)
            
            raw_type = nt_types[i] if i < len(nt_types) else "Any"
            norm_typ = raw_type.replace("builtins.", "")
            try:
                field_type = self.translator._map_type(norm_typ, struct_name)
            except Exception:
                field_type = "Any"
                
            if field_type == "int" or norm_typ == "int":
                field_type = "int"
            elif field_type == "str" or norm_typ == "str":
                field_type = "string"
            elif field_type == "float" or norm_typ == "float":
                field_type = "f64"
            elif field_type == "bool" or norm_typ == "bool":
                field_type = "bool"
                
            _ft = field_type
            if _ft.startswith("fn (") or _ft.startswith("fn("):
                 _ft += " = unsafe { nil }"
            fields.append(f"    {f_name} {_ft}")
            
        return fields

    def collect_init_fields(
        self,
        node: ast.ClassDef,
        added_fields: Set[str],
        struct_name: str
    ) -> List[str]:
        """Collect fields from __init__ method."""
        fields: List[str] = []
        for stmt in node.body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)) and stmt.name == "__init__":
                if stmt.args.args:
                    init_self_name = stmt.args.args[0].arg
                    for sub_node in ast.walk(stmt):
                        if isinstance(sub_node, ast.Assign):
                            for target in sub_node.targets:
                                for t in ast.walk(target):
                                    if isinstance(t, ast.Attribute) and isinstance(t.value, ast.Name) and t.value.id == init_self_name:
                                        field_name = self.translator._sanitize_name(t.attr)
                                        if field_name not in added_fields:
                                            added_fields.add(field_name)
                                            f_type = "Any"
                                            if len(sub_node.targets) == 1 and isinstance(sub_node.targets[0], ast.Attribute):
                                                f_type = self.translator._guess_type(sub_node.value)
                                            _ft = f_type
                                            if _ft.startswith("fn (") or _ft.startswith("fn("):
                                                _ft += " = unsafe { nil }"
                                            fields.append(f"    {field_name} {_ft}")
                        elif isinstance(sub_node, ast.AnnAssign):
                            if isinstance(sub_node.target, ast.Attribute) and isinstance(sub_node.target.value, ast.Name) and sub_node.target.value.id == init_self_name:
                                field_name = self.translator._sanitize_name(sub_node.target.attr)
                                if field_name not in added_fields:
                                    added_fields.add(field_name)
                                    f_type = "Any"
                                    if sub_node.annotation:
                                        try:
                                            t_str = ast.unparse(sub_node.annotation)
                                            f_type = self.translator._map_type(t_str, struct_name)
                                        except Exception:
                                            pass
                                    _ft = f_type
                                    if _ft.startswith("fn (") or _ft.startswith("fn("):
                                        _ft += " = unsafe { nil }"
                                    fields.append(f"    {field_name} {_ft}")
        return fields

    def process_class_attributes(
        self,
        body: List[ast.stmt],
        struct_name: str,
        added_fields: Set[str],
        is_dataclass: bool,
        is_typed_dict: bool,
        dataclass_metadata: Optional[Dict[str, Any]],
        dataclass_field_order: List[str]
    ) -> List[str]:
        """Process class attribute declarations (AnnAssign and Assign)."""
        fields: List[str] = []
        readonly_fields = self.translator.readonly_fields if hasattr(self.translator, "readonly_fields") else {}
        current_access = None

        for stmt in body:
            if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                field_name = self.translator._sanitize_name(stmt.target.id)

                if field_name in added_fields:
                    continue

                # If we have perfect dataclass metadata, wait to emit fields later to avoid duplicates
                if is_dataclass and dataclass_metadata:
                    pass
                else:
                    added_fields.add(field_name)
                    field_type = "int"
                    is_readonly = False
                    if stmt.annotation:
                        try:
                            type_str = ast.unparse(stmt.annotation)
                            field_type = self.translator._map_type(type_str, struct_name)

                            if is_typed_dict:
                                if "ReadOnly[" in type_str or type_str.startswith("ReadOnly") or \
                                   "typing.ReadOnly[" in type_str or type_str.startswith("typing.ReadOnly") or \
                                   "typing_extensions.ReadOnly[" in type_str or type_str.startswith("typing_extensions.ReadOnly"):
                                    is_readonly = True
                                    readonly_fields.setdefault(struct_name, set()).add(field_name)
                        except Exception:
                            if isinstance(stmt.annotation, ast.Name):
                                field_type = stmt.annotation.id

                    if is_dataclass or is_typed_dict:
                        dataclass_field_order.append(field_name)

                    if is_typed_dict:
                        required_access = "pub:" if is_readonly else "pub mut:"
                        if current_access != required_access:
                            fields.append(required_access)
                            current_access = required_access

                    if stmt.value:
                        default_val = self.translator.visit(stmt.value)
                        fields.append(
                            f"    {field_name} {field_type} = {default_val}"
                        )
                        # Store for constant generation
                        if not hasattr(self.translator, 'defined_classes'):
                            self.translator.defined_classes = {}
                        if struct_name not in self.translator.defined_classes:
                            self.translator.defined_classes[struct_name] = {
                                'has_init': False, 'has_new': False,
                                'static_methods': set(), 'class_methods': set(),
                                'class_vars': []
                            }
                        if 'class_vars' not in self.translator.defined_classes[struct_name]:
                            self.translator.defined_classes[struct_name]['class_vars'] = []

                        self.translator.defined_classes[struct_name]['class_vars'].append({
                            'name': field_name,
                            'type': field_type,
                            'value': default_val
                        })
                    else:
                        _ft = field_type
                        if _ft.startswith("fn (") or _ft.startswith("fn("):
                            _ft += " = unsafe { nil }"
                        fields.append(f"    {field_name} {_ft}")

            elif isinstance(stmt, ast.Assign):
                for target in stmt.targets:
                    if isinstance(target, ast.Name):
                        if target.id == "__slots__":
                            slots_list = []
                            if isinstance(stmt.value, (ast.List, ast.Tuple)):
                                for elt in stmt.value.elts:
                                    if isinstance(elt, ast.Constant) and isinstance(
                                        elt.value, str
                                    ):
                                        slots_list.append(self.translator._sanitize_name(elt.value))
                            elif isinstance(stmt.value, ast.Constant) and isinstance(
                                stmt.value.value, str
                            ):
                                slots_list.append(self.translator._sanitize_name(stmt.value.value))

                            for slot in slots_list:
                                if slot not in added_fields:
                                    fields.append(f"    {slot} int")
                                    added_fields.add(slot)
                        else:
                            # Class variable
                            field_name = self.translator._sanitize_name(target.id)
                            if field_name in added_fields:
                                continue

                            added_fields.add(field_name)
                            field_type = self.translator._guess_type(stmt.value)
                            default_val = self.translator.visit(stmt.value)

                            # Add to fields list for struct definition
                            fields.append(f"    {field_name} {field_type} = {default_val}")

                            # Store for constant generation
                            if not hasattr(self.translator, "defined_classes"):
                                self.translator.defined_classes = {}
                            if struct_name not in self.translator.defined_classes:
                                self.translator.defined_classes[struct_name] = {
                                    "has_init": False, "has_new": False,
                                    "static_methods": set(), "class_methods": set(),
                                    "class_vars": []
                                }
                            if "class_vars" not in self.translator.defined_classes[struct_name]:
                                self.translator.defined_classes[struct_name]["class_vars"] = []

                            self.translator.defined_classes[struct_name]["class_vars"].append({
                                "name": field_name,
                                "type": field_type,
                                "value": default_val
                            })

        return fields

    def process_dataclass_fields(
        self,
        body: List[ast.stmt],
        struct_name: str,
        dataclass_metadata: Dict[str, Any],
        added_fields: Set[str],
        dataclass_field_order: List[str]
    ) -> List[str]:
        """Process fields from dataclass metadata."""
        fields: List[str] = []
        for attr in dataclass_metadata.get("attributes", []):
            if attr.get("is_classvar", False) or attr.get("is_init_var", False):
                continue

            is_init_var = attr.get("is_init_var", False)
            if is_init_var:
                continue

            field_name = self.translator._sanitize_name(attr["name"])
            if field_name in added_fields:
                continue
            added_fields.add(field_name)

            raw_type = attr.get("type", "Any")
            norm_typ = raw_type.replace("builtins.", "")
            try:
                field_type = self.translator._map_type(norm_typ, struct_name)
            except Exception:
                field_type = "Any"

            if field_type == "int" or norm_typ == "int":
                field_type = "int"
            elif field_type == "str" or norm_typ == "str":
                field_type = "string"
            elif field_type == "float" or norm_typ == "float":
                field_type = "f64"
            elif field_type == "bool" or norm_typ == "bool":
                field_type = "bool"

            has_default = attr.get("has_default", False)
            default_str = ""
            if has_default:
                for stmt in body:
                    if (
                        isinstance(stmt, ast.AnnAssign)
                        and isinstance(stmt.target, ast.Name)
                        and stmt.target.id == attr["name"]
                    ):
                        if stmt.value:
                            default_str = f" = {self.translator.visit(stmt.value)}"
                        break

            dataclass_field_order.append(field_name)
            _ft = field_type
            if not default_str and (_ft.startswith("fn (") or _ft.startswith("fn(")):
                _ft += " = unsafe { nil }"
            fields.append(f"    {field_name} {_ft}{default_str}")

        return fields

    def generate_dataclass_factory(
        self,
        struct_name: str,
        dataclass_metadata: Dict[str, Any],
        body: List[ast.stmt],
        has_post_init: bool
    ) -> Optional[str]:
        """Generate factory function for dataclasses with __post_init__."""
        if not has_post_init:
            return None

        init_fields = [attr for attr in dataclass_metadata.get("attributes", []) if attr.get("is_in_init")]
        factory_args = []
        struct_init_args = []
        post_init_args = []

        for attr in init_fields:
            raw_name = attr["name"]
            f_name = self.translator._sanitize_name(raw_name)
            raw_type = attr.get("type", "Any")
            norm_typ = raw_type.replace("builtins.", "")
            try:
                f_type = self.translator._map_type(norm_typ, struct_name)
            except Exception:
                f_type = "Any"

            if f_type == "int" or norm_typ == "int":
                f_type = "int"
            elif f_type == "str" or norm_typ == "str":
                f_type = "string"

            has_default = attr.get("has_default", False)
            default_expr = ""
            if has_default:
                for body_stmt in body:
                    if isinstance(body_stmt, ast.AnnAssign) and isinstance(body_stmt.target, ast.Name) and body_stmt.target.id == raw_name:
                        if body_stmt.value:
                            default_expr = f" = {self.translator.visit(body_stmt.value)}"
                        break
                    elif isinstance(body_stmt, ast.Assign):
                        for target in body_stmt.targets:
                            if isinstance(target, ast.Name) and target.id == raw_name:
                                default_expr = f" = {self.translator.visit(body_stmt.value)}"
                                break

            arg_str = f"{f_name} {f_type}{default_expr}"
            factory_args.append(arg_str)

            if not attr.get("is_init_var", False):
                struct_init_args.append(f"{f_name}: {f_name}")
            else:
                post_init_args.append(f_name)

        pub = "pub " if self.translator._is_exported(struct_name) else ""
        gen_str = f"[{', '.join(self.translator.current_class_generics)}]" if self.translator.current_class_generics else ""
        factory_name = self.translator._get_factory_name(struct_name)

        factory_code = [
            f"{pub}fn {factory_name}{gen_str}({', '.join(factory_args)}) {struct_name}{gen_str} {{",
            f"    mut self := {struct_name}{gen_str}{{{', '.join(struct_init_args)}}}",
            f"    self.post_init({', '.join(post_init_args)})",
            f"    return self",
            f"}}"
        ]
        return "\n".join(factory_code)
