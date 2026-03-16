"""Handler for class base types and inheritance."""

import ast
from typing import TYPE_CHECKING, List, Tuple

if TYPE_CHECKING:
    pass


class ClassBasesHandler:
    """Handles processing of class base types and inheritance."""

    def __init__(self, translator):
        self.translator = translator

    def is_enum_type(self, name: str) -> Tuple[bool, bool, bool]:
        """
        Check if a name refers to an Enum type.

        Returns:
            Tuple of (is_enum, is_int_enum, is_flag)
        """
        if name in self.translator.imported_symbols:
            full_name = self.translator.imported_symbols[name]
            if full_name in (
                "enum.Enum",
                "enum.IntEnum",
                "enum.Flag",
                "enum.IntFlag",
            ):
                if full_name == "enum.Enum":
                    return (True, False, False)
                elif full_name == "enum.IntEnum":
                    return (True, True, False)
                elif full_name == "enum.Flag":
                    return (True, False, True)
                elif full_name == "enum.IntFlag":
                    return (True, True, True)

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

    def process_bases(
        self,
        node: ast.ClassDef,
        struct_name: str
    ) -> Tuple[List[str], List[str], bool, bool, bool, bool, bool, bool]:
        """
        Process class base types.

        Returns:
            Tuple of (fields, current_class_bases, is_enum, is_int_enum, is_flag,
                     is_unittest, is_protocol, is_named_tuple, is_typed_dict)
        """
        fields = []
        current_class_bases = []
        is_enum = False
        is_int_enum = False
        is_flag = False
        is_unittest = False
        is_protocol = False
        is_named_tuple = False
        is_typed_dict = False
        direct_bases = []

        for base in node.bases:
            base_name = ""
            if isinstance(base, ast.Name):
                base_name = base.id
            elif isinstance(base, ast.Attribute):
                base_name = base.attr

            is_enum_result = self.is_enum_type(base_name)
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
                val = self.translator.visit(base)
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

            if isinstance(base, ast.Subscript):
                base_name = ""
                if isinstance(base.value, ast.Name):
                    base_name = base.value.id
                elif isinstance(base.value, ast.Attribute):
                    base_name = base.value.attr

                if base_name in ("Generic", "Protocol"):
                    if base_name == "Protocol":
                        is_protocol = True
                    continue
                else:
                    if (
                        base_name not in self.translator.known_interfaces
                        and base_name
                        not in getattr(self.translator.type_inference, "mixin_to_main", {})
                    ):
                        type_str = ast.unparse(base)
                        v_type = self.translator._map_type(type_str)
                        if not (v_type.startswith("[]") or v_type.startswith("map[")):
                            num_params = 0
                            if isinstance(base.slice, ast.Tuple):
                                num_params = len(base.slice.elts)
                            else:
                                num_params = 1

                            if num_params > 1:
                                field_name = f"base_{base_name}"
                                fields.append(f"pub mut:\n    {field_name} {v_type}")
                                self.translator.current_class_generic_bases[base_name] = field_name
                            else:
                                fields.append(f"    {v_type}")

                    self.translator.current_class_generic_bases.setdefault(base_name, None)
                    current_class_bases.append(base_name)

            elif isinstance(base, ast.Name):
                if base.id not in (
                    "Generic",
                    "Protocol",
                    "NamedTuple",
                    "TypedDict",
                    "object",
                    "ABC",
                ):
                    if base.id not in self.translator.known_interfaces and base.id not in getattr(
                        self.translator.type_inference, "mixin_to_main", {}
                    ):
                        sanitized_base = self.translator._sanitize_name(base.id, is_type=True)
                        fields.append(f"    {sanitized_base}")
                    current_class_bases.append(base.id)
                direct_bases.append(base.id)
            elif isinstance(base, ast.Attribute):
                val = self.translator.visit(base)
                if val not in (
                    "TypedDict",
                    "typing.TypedDict",
                    "builtins.object",
                    "ABC",
                ):
                    if (
                        base.attr not in self.translator.known_interfaces
                        and base.attr
                        not in getattr(self.translator.type_inference, "mixin_to_main", {})
                    ):
                        fields.append(f"    {val}")
                if val != "builtins.object":
                    current_class_bases.append(base.attr)
                direct_bases.append(base.attr)

            if isinstance(base, (ast.Name, ast.Attribute)):
                if base_name or (isinstance(base, ast.Attribute) and base.attr):
                    name_to_add = base.id if isinstance(base, ast.Name) else base.attr
                    if name_to_add not in direct_bases:
                        direct_bases.append(name_to_add)

        self.translator.class_hierarchy[struct_name] = direct_bases
        return (
            fields,
            current_class_bases,
            is_enum,
            is_int_enum,
            is_flag,
            is_unittest,
            is_protocol,
            is_named_tuple,
            is_typed_dict
        )

    def is_descendant_of(self, cls_name: str, target: str) -> bool:
        """Check if a class is a descendant of another class."""
        visited = set()
        stack = [cls_name]
        while stack:
            curr = stack.pop()
            if curr in visited:
                continue
            visited.add(curr)
            if curr == target:
                return True
            if curr in self.translator.class_hierarchy:
                stack.extend(self.translator.class_hierarchy[curr])
        return False

    def is_abstract_base_class(self, node: ast.ClassDef, struct_name: str) -> bool:
        """Check if the class is an abstract base class."""
        has_abstract_method = False
        has_concrete_method = False

        for stmt in node.body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                is_abstract_stmt = False
                for dec in stmt.decorator_list:
                    if isinstance(dec, ast.Name) and dec.id == "abstractmethod":
                        is_abstract_stmt = True
                    elif (
                        isinstance(dec, ast.Attribute) and dec.attr == "abstractmethod"
                    ):
                        is_abstract_stmt = True

                if is_abstract_stmt:
                    has_abstract_method = True
                else:
                    is_empty = True
                    for body_stmt in stmt.body:
                        if isinstance(body_stmt, ast.Pass):
                            continue
                        if (
                            isinstance(body_stmt, ast.Expr)
                            and isinstance(body_stmt.value, ast.Constant)
                            and body_stmt.value.value is Ellipsis
                        ):
                            continue
                        if (
                            isinstance(body_stmt, ast.Expr)
                            and isinstance(body_stmt.value, ast.Constant)
                            and isinstance(body_stmt.value.value, str)
                        ):
                            continue
                        if isinstance(body_stmt, ast.Raise):
                            if (
                                isinstance(body_stmt.exc, ast.Name)
                                and body_stmt.exc.id == "NotImplementedError"
                            ):
                                continue
                            if (
                                isinstance(body_stmt.exc, ast.Call)
                                and isinstance(body_stmt.exc.func, ast.Name)
                                and body_stmt.exc.func.id == "NotImplementedError"
                            ):
                                continue
                        is_empty = False
                        break

                    if not is_empty:
                        has_concrete_method = True

        is_abc = False
        if self.is_descendant_of(struct_name, "ABC"):
            if has_abstract_method or not has_concrete_method:
                is_abc = True
        elif has_abstract_method:
            is_abc = True

        if hasattr(self.translator.type_inference, "is_abc") and isinstance(
            self.translator.type_inference.is_abc, dict
        ):
            is_abc = self.translator.type_inference.is_abc.get(struct_name, is_abc)

        return is_abc
