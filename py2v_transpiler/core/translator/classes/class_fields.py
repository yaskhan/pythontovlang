"""Class field and attribute processing."""

import ast
from typing import Any, Dict, List, Optional, Set, TYPE_CHECKING

if TYPE_CHECKING:
    from ..base import TranslatorBase


class ClassFieldsMixin:
    """Mixin for processing class fields and attributes."""

    if TYPE_CHECKING:
        def visit(self, node: ast.AST) -> str: ...
        def _guess_type(self, node: ast.AST) -> str: ...
        def _map_type(self, type_str: str, struct_name: Optional[str] = None) -> str: ...
        def _sanitize_name(self, name: str, is_type: bool = False) -> str: ...
        def _is_exported(self, name: str) -> bool: ...
        def _get_factory_name(self, struct_name: str) -> str: ...
        def _get_source_info(self, node: Optional[ast.AST] = None) -> str: ...
        def _get_generics_with_variance_str(self, generics: List[str]) -> str: ...
        current_class_generics: List[str]
        readonly_fields: Dict[str, Set[str]]
        defined_classes: Dict[str, Dict[str, Any]]
        config: Any
        emitter: Any
        type_inference: Any
        class_methods_handler: Any
        special_classes_handler: Any
        translator: Any


    def _should_strip_init(self, field_type: str, default_val: str) -> bool:
        if not default_val: return False
        if default_val == "none": return True
        if "Any(NoneType{})" in default_val: return True
        if "unsafe { nil }" in default_val: return True
        return False

    def _is_field_mutated(self, struct_name: str, field_name: str, orig_name: str = "") -> bool:
        if not hasattr(self.translator, 'type_inference') or not hasattr(self.translator.type_inference, 'mutability_map'):
            return False

        # We need the original Python class name for the map lookup if possible
        # But struct_name is already sanitized.
        # However, the analyzer uses the original name in the map.
        # We might need to track original class names too.
        # For now, let's try to match with what we have.

        base_struct_name = struct_name.replace("_Impl", "")

        # Check both the name provided (usually sanitized) and the original name
        names_to_check = [field_name]
        if orig_name and orig_name != field_name:
            names_to_check.append(orig_name)

        for name in names_to_check:
            qualified = f"{base_struct_name}.{name}"
            m_info = self.translator.type_inference.mutability_map.get(qualified)
            if m_info and m_info.get("is_mutated"):
                return True

            # Also check unqualified (for fields that might not be qualified in map)
            m_info = self.translator.type_inference.mutability_map.get(name)
            if m_info and m_info.get("is_mutated"):
                return True

        return False

    def _get_field_def_info(self, name: str, field_type: str, struct_name: str, default_val: str = "", orig_name: str = "") -> Dict[str, Any]:
        is_mutated = self._is_field_mutated(struct_name, name, orig_name=orig_name)
        if default_val and not self._should_strip_init(field_type, default_val):
            field_def = f"    {name} {field_type} = {default_val}"
        else:
            field_def = f"    {name} {field_type}"
        return {"name": name, "orig_name": orig_name or name, "def": field_def, "is_mutated": is_mutated}

    def collect_mixin_fields(
            self,
            struct_name: str,
            added_fields: Set[str],
            is_main_struct: bool
        ) -> List[Dict[str, Any]]:
        """Collect fields from mixin classes."""
        fields: List[Dict[str, Any]] = []
        if not is_main_struct:
            return fields

        mixin_nodes = getattr(self.translator.type_inference, "mixin_nodes", {})
        if not hasattr(self.translator.type_inference, "main_to_mixins"):
            return fields

        for mixin_name in self.translator.type_inference.main_to_mixins.get(struct_name, []):
            if mixin_name in mixin_nodes:
                mixin_node = mixin_nodes[mixin_name]
                for stmt in mixin_node.body:
                    if isinstance(stmt, ast.AnnAssign) and isinstance(
                        stmt.target, ast.Name
                    ):
                        orig_name = stmt.target.id
                        field_name = self.translator._sanitize_name(orig_name)
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
                            default_val = ""
                            if getattr(stmt, "value", None) is not None:
                                default_val = self.translator.visit(stmt.value)
                            fields.append(self._get_field_def_info(field_name, field_type, struct_name, default_val, orig_name))
                    elif isinstance(stmt, ast.Assign):
                        for target in stmt.targets:
                            if isinstance(target, ast.Name):
                                orig_name = target.id
                                field_name = self.translator._sanitize_name(orig_name)
                                if field_name not in added_fields:
                                    added_fields.add(field_name)
                                    field_type = self.translator._guess_type(stmt.value)
                                    field_type = self.translator._map_type(field_type, struct_name)
                                    default_val = self.translator.visit(stmt.value)
                                    fields.append(self._get_field_def_info(field_name, field_type, struct_name, default_val, orig_name))
        return fields

    def collect_init_fields(
        self,
        node: ast.ClassDef,
        added_fields: Set[str],
        struct_name: str
    ) -> List[Dict[str, Any]]:
        """Collect fields from __init__ method."""
        fields: List[Dict[str, Any]] = []
        for stmt in node.body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)) and stmt.name == "__init__":
                if stmt.args.args:
                    init_self_name = stmt.args.args[0].arg
                    # Build arg name to annotation map for __init__
                    arg_type_map = {}
                    for arg in stmt.args.args[1:]: # Skip self
                        if arg.annotation:
                            try:
                                arg_type_map[arg.arg] = ast.unparse(arg.annotation)
                            except:
                                pass

                    for sub_node in ast.walk(stmt):
                        if isinstance(sub_node, ast.Assign):
                            for target in sub_node.targets:
                                for t in ast.walk(target):
                                    if isinstance(t, ast.Attribute) and isinstance(t.value, ast.Name) and t.value.id == init_self_name:
                                        orig_name = t.attr
                                        field_name = self.translator._sanitize_name(orig_name)
                                        if field_name not in added_fields:
                                            added_fields.add(field_name)
                                            f_type = "Any"
                                            if len(sub_node.targets) == 1 and isinstance(sub_node.targets[0], ast.Attribute):
                                                if isinstance(sub_node.value, ast.Name) and sub_node.value.id in arg_type_map:
                                                    f_type = arg_type_map[sub_node.value.id]
                                                else:
                                                    f_type = self.translator._guess_type(sub_node.value)

                                            if f_type == "Any":
                                                prefix = ".".join(self.translator._scope_names)
                                                f_type = self.translator.type_inference.type_map.get(f"{prefix}.{t.attr}",
                                                           self.translator.type_inference.type_map.get(t.attr, "Any"))
                                            is_optional = False
                                            if isinstance(sub_node.value, ast.Constant) and sub_node.value.value is None:
                                                is_optional = True

                                            f_type = self.translator._map_type(f_type, struct_name)
                                            if is_optional and not f_type.startswith("?") and f_type != "Any":
                                                f_type = "?" + f_type
                                            _ft = f_type
                                            fields.append(self._get_field_def_info(field_name, _ft, struct_name, orig_name=orig_name))
                        elif isinstance(sub_node, ast.AnnAssign):
                            if isinstance(sub_node.target, ast.Attribute) and isinstance(sub_node.target.value, ast.Name) and sub_node.target.value.id == init_self_name:
                                orig_name = sub_node.target.attr
                                field_name = self.translator._sanitize_name(orig_name)
                                if field_name not in added_fields:
                                    added_fields.add(field_name)
                                    f_type = "Any"
                                    if sub_node.annotation:
                                        try:
                                            t_str = ast.unparse(sub_node.annotation)
                                            f_type = self.translator._map_type(t_str, struct_name)
                                        except Exception:
                                            pass

                                    if f_type == "Any":
                                        prefix = ".".join(self.translator._scope_names)
                                        f_type = self.translator.type_inference.type_map.get(f"{prefix}.{sub_node.target.attr}",
                                                   self.translator.type_inference.type_map.get(sub_node.target.attr, "Any"))
                                        if f_type != "Any":
                                            f_type = self.translator._map_type(f_type, struct_name)
                                    is_optional = False
                                    if hasattr(sub_node, "value") and isinstance(sub_node.value, ast.Constant) and sub_node.value.value is None:
                                        is_optional = True

                                    if is_optional and not f_type.startswith("?") and f_type != "Any":
                                        f_type = "?" + f_type
                                    _ft = f_type
                                    fields.append(self._get_field_def_info(field_name, _ft, struct_name, orig_name=orig_name))
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
    ) -> List[Dict[str, Any]]:
        """Process class attribute declarations (AnnAssign and Assign)."""
        fields: List[Dict[str, Any]] = []
        readonly_fields = self.translator.readonly_fields if hasattr(self.translator, "readonly_fields") else {}
        current_access = None

        for stmt in body:
            if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                orig_name = stmt.target.id
                field_name = self.translator._sanitize_name(orig_name)

                if field_name in added_fields:
                    continue

                # If we have perfect dataclass metadata, wait to emit fields later to avoid duplicates
                if is_dataclass and dataclass_metadata:
                    pass
                else:
                    added_fields.add(field_name)
                    field_type = "int"
                    is_readonly = False
                    raw_type = ""
                    if stmt.annotation:
                        try:
                            raw_type = ast.unparse(stmt.annotation)
                            field_type = self.translator._map_type(raw_type, struct_name)

                            if is_typed_dict:
                                if "ReadOnly[" in raw_type or raw_type.startswith("ReadOnly") or \
                                   "typing.ReadOnly[" in raw_type or raw_type.startswith("typing.ReadOnly") or \
                                   "typing_extensions.ReadOnly[" in raw_type or raw_type.startswith("typing_extensions.ReadOnly"):
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
                            fields.append({"name": "", "def": required_access, "is_mutated": False})
                            current_access = required_access

                    default_val = ""
                    if stmt.value:
                        default_val = self.translator.visit(stmt.value)

                    # Establish the rule: move to Meta struct ONLY if explicitly annotated with typing.ClassVar
                    is_class_var = "ClassVar[" in raw_type or raw_type.startswith("ClassVar") or \
                                   "typing.ClassVar[" in raw_type or raw_type.startswith("typing.ClassVar")

                    if is_class_var:
                        # Store for Meta struct generation
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
                            'value': default_val or "none"
                        })
                    else:
                        # Instance field
                        fields.append(self._get_field_def_info(field_name, field_type, struct_name, default_val, orig_name=orig_name))

            elif isinstance(stmt, ast.Assign):
                for target in stmt.targets:
                    if isinstance(target, ast.Name):
                        if target.id == "__slots__":
                            slots_list = []
                            if isinstance(stmt.value, (ast.List, ast.Tuple)):
                                for elt in stmt.value.elts:
                                    if isinstance(elt, ast.Constant) and isinstance(elt.value, str):
                                        slots_list.append(self.translator._sanitize_name(elt.value))
                            elif isinstance(stmt.value, ast.Constant) and isinstance(stmt.value.value, str):
                                slots_list.append(self.translator._sanitize_name(stmt.value.value))

                            for slot in slots_list:
                                if slot not in added_fields:
                                    fields.append(self._get_field_def_info(slot, "int", struct_name))
                                    added_fields.add(slot)
                        elif (
                            not isinstance(stmt.value, ast.Call)
                            or not isinstance(stmt.value.func, ast.Name)
                            or stmt.value.func.id not in ("TypeVar", "ParamSpec", "TypeVarTuple")
                            and target.id != "__slots__"
                        ):
                            orig_name = target.id
                            field_name = self.translator._sanitize_name(orig_name)
                            if field_name in added_fields:
                                continue

                            added_fields.add(field_name)
                            field_type = self.translator._guess_type(stmt.value)
                            field_type = self.translator._map_type(field_type, struct_name)
                            default_val = self.translator.visit(stmt.value)

                            # Store for Meta struct generation
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
    ) -> List[Dict[str, Any]]:
        fields: List[Dict[str, Any]] = []
        for attr in dataclass_metadata.get("attributes") or []:
            orig_name = attr["name"]
            field_name = self.translator._sanitize_name(orig_name)
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

            # Try to find default value
            default_val = ""
            for stmt in body:
                if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name) and stmt.target.id == attr["name"]:
                    if stmt.value:
                        default_val = self.translator.visit(stmt.value)
                    break
                elif isinstance(stmt, ast.Assign):
                    for target in stmt.targets:
                        if isinstance(target, ast.Name) and target.id == attr["name"]:
                            default_val = self.translator.visit(stmt.value)
                            break

            is_classvar = attr.get("is_classvar", False) or \
                          "ClassVar[" in raw_type or raw_type.startswith("ClassVar") or \
                          "typing.ClassVar[" in raw_type or raw_type.startswith("typing.ClassVar")

            if is_classvar:
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
                    "value": default_val or "none"
                })
                continue

            if attr.get("is_init_var", False):
                continue

            if field_name in added_fields:
                continue
            added_fields.add(field_name)

            dataclass_field_order.append(field_name)
            fields.append(self._get_field_def_info(field_name, field_type, struct_name, default_val, orig_name=orig_name))
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
            f"{pub}fn {factory_name}{gen_str}({', '.join(factory_args)}) &{struct_name}{gen_str} {{",
            f"    mut self := &{struct_name}{gen_str}{{{', '.join(struct_init_args)}}}",
            f"    self.post_init({', '.join(post_init_args)})",
            f"    return self",
            f"}}"
        ]
        return "\n".join(factory_code)

    def get_namedtuple_metadata(self, node: ast.ClassDef, struct_name: str) -> Optional[Dict[str, Any]]:
        """Extract namedtuple metadata from call signatures."""
        for k, sig_data in self.translator.type_inference.call_signatures.items():
            if "namedtuple_metadata" in sig_data:
                if (
                    k.startswith(f"{node.name}@")
                    or k.split("@")[0].endswith(f".{node.name}")
                    or k.startswith(f"{struct_name}@")
                ):
                    return sig_data["namedtuple_metadata"]
        return None

    def get_dataclass_metadata(self, node: ast.ClassDef, struct_name: str) -> Optional[Dict[str, Any]]:
        """Extract dataclass metadata from call signatures."""
        for k, sig_data in self.translator.type_inference.call_signatures.items():
            if "dataclass_metadata" in sig_data:
                if (
                    k.startswith(f"{node.name}@")
                    or k.split("@")[0].endswith(f".{node.name}")
                    or k.startswith(f"{struct_name}@")
                ):
                    return sig_data["dataclass_metadata"]
        return None

    def process_namedtuple_fields(
        self,
            struct_name: str,
        namedtuple_metadata: Dict[str, Any],
        added_fields: Set[str]
    ) -> List[Dict[str, Any]]:
        """Process fields from namedtuple metadata."""
        fields: List[Dict[str, Any]] = []
        nt_fields = namedtuple_metadata.get("fields", [])
        nt_types = namedtuple_metadata.get("types", [])

        for i, field_name in enumerate(nt_fields):
            orig_name = field_name
            f_name = self.translator._sanitize_name(orig_name)
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
            fields.append(self._get_field_def_info(f_name, _ft, struct_name, orig_name=orig_name))

        return fields

class ClassFieldsHandler(ClassFieldsMixin):
    def __init__(self, translator):
        self.translator = translator
