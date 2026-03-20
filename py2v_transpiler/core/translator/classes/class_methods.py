"""Handler for class methods processing."""

import ast
from typing import TYPE_CHECKING, List, Set, Dict, Any, Tuple

if TYPE_CHECKING:
    pass


class ClassMethodsHandler:
    """Handles processing of class methods."""

    def __init__(self, translator):
        self.translator = translator

    def extract_method_info(
        self,
        node: ast.ClassDef
    ) -> Tuple[bool, bool, Set[str], Set[str]]:
        """
        Extract method information from class body.

        Returns:
            Tuple of (has_init, has_new, static_methods, class_methods)
        """
        has_init = False
        has_new = False
        static_methods = set()
        class_methods = set()

        for child in node.body:
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if child.name == "__init__":
                    has_init = True
                elif child.name == "__new__":
                    has_new = True

                for decorator in child.decorator_list:
                    dec_name = ""
                    if isinstance(decorator, ast.Name):
                        dec_name = decorator.id
                    elif isinstance(decorator, ast.Call):
                        if isinstance(decorator.func, ast.Name):
                            dec_name = decorator.func.id
                    elif isinstance(decorator, ast.Attribute):
                        dec_name = decorator.attr

                    if dec_name in ("staticmethod", "abstractstaticmethod"):
                        static_methods.add(child.name)
                    elif dec_name in ("classmethod", "abstractclassmethod"):
                        class_methods.add(child.name)

        return has_init, has_new, static_methods, class_methods

    def separate_methods(
        self,
        body: List[ast.stmt]
    ) -> Tuple[List[ast.FunctionDef | ast.AsyncFunctionDef], List[ast.stmt]]:
        """
        Separate methods from other class body statements.

        Returns:
            Tuple of (methods list, remaining body statements)
        """
        methods: List[ast.FunctionDef | ast.AsyncFunctionDef] = []
        remaining_body = []

        for stmt in body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                methods.append(stmt)
            else:
                remaining_body.append(stmt)

        return methods, remaining_body

    def rename_dunder_methods(self, methods: List[ast.FunctionDef | ast.AsyncFunctionDef], has_str: bool) -> None:
        """Rename dunder methods to V-compatible names."""
        for method in methods:
            if method.name == "__repr__":
                setattr(method, "original_name", "__repr__")
                if has_str:
                    setattr(method, "name", "repr")
                else:
                    setattr(method, "name", "str")
            elif method.name == "__next__":
                method.name = "next"
            elif method.name == "__post_init__":
                method.name = "post_init"
            elif method.name == "__await__":
                method.name = "await_"
            elif method.name == "__iter__":
                method.name = "iter"
            elif method.name == "__str__":
                method.name = "str"

    def has_method(self, methods: List[ast.FunctionDef | ast.AsyncFunctionDef], method_name: str) -> bool:
        """Check if a method exists in the methods list."""
        return any(m.name == method_name for m in methods)

    def process_interface_methods(
        self,
        methods: List[ast.FunctionDef | ast.AsyncFunctionDef]
    ) -> List[str]:
        """Process methods for interface definition."""
        interface_methods = []
        has_str = self.has_method(methods, "__str__")

        for method in methods:
            if method.name == "__init__":
                continue
            m_name = self.translator._sanitize_name(method.name)
            if m_name == "__next__":
                m_name = "next"
            elif m_name == "__post_init__":
                m_name = "post_init"
            elif m_name == "__await__":
                m_name = "await_"
            elif m_name == "__iter__":
                m_name = "iter"
            elif m_name == "__str__":
                m_name = "str"
            elif m_name == "__repr__":
                m_name = "str" if not has_str else "repr"

            is_m_classmethod = False
            for dec in method.decorator_list:
                d_name = self.translator.decorator_processor.get_decorator_name(dec)
                if d_name in ("classmethod", "abstractclassmethod"):
                    is_m_classmethod = True
                    break

            m_args = []
            all_args = getattr(method.args, 'posonlyargs', []) + method.args.args
            for arg in all_args:
                if arg.arg == "self":
                    continue
                if is_m_classmethod and arg.arg == "cls":
                    continue
                a_name = self.translator._sanitize_name(arg.arg)
                a_type = "int"
                if arg.annotation:
                    try:
                        type_str = ast.unparse(arg.annotation)
                        a_type = self.translator._map_type(type_str)
                    except Exception:
                        pass
                else:
                    # Try type inference for arg
                    inferred_arg = self.translator.type_inference.type_map.get(arg.arg)
                    if not inferred_arg:
                         # Try with method prefix if possible, though arg name is usually enough in local context
                         pass
                    if inferred_arg:
                         a_type = self.translator._map_type(inferred_arg)

                m_args.append(f"{a_name} {a_type}")

            m_ret = "void"
            if method.returns:
                try:
                    type_str = ast.unparse(method.returns)
                    m_ret = self.translator._map_type(type_str)
                except Exception:
                    pass
            else:
                 # Try type inference for return type
                 # Heuristic: method_name@return
                 inferred_ret = self.translator.type_inference.type_map.get(f"{method.name}@return")
                 if inferred_ret:
                      m_ret = self.translator._map_type(inferred_ret)

            if m_ret == "void":
                interface_methods.append(f"    {m_name}({', '.join(m_args)})")
            else:
                interface_methods.append(f"    {m_name}({', '.join(m_args)}) {m_ret}")

        return interface_methods

    def register_class_info(
        self,
        struct_name: str,
        has_init: bool,
        has_new: bool,
        static_methods: Set[str],
        class_methods: Set[str],
        has_factory: bool = False
    ) -> None:
        """Register class information in defined_classes."""
        if not hasattr(self.translator, "defined_classes"):
            self.translator.defined_classes = {}

        current_info = self.translator.defined_classes.get(struct_name)
        if not current_info or not (current_info.get("has_init") or current_info.get("has_new")):
            if has_factory:
                self.translator.defined_classes[struct_name] = {
                    "has_init": True,
                    "has_new": True,
                    "static_methods": static_methods,
                    "class_methods": class_methods
                }
            else:
                if current_info:
                    current_info["has_init"] = has_init
                else:
                    self.translator.defined_classes[struct_name] = {
                        "has_init": has_init,
                        "has_new": has_new,
                        "static_methods": static_methods,
                        "class_methods": class_methods
                    }
