import ast
from typing import TYPE_CHECKING, List, Set, Dict, Any, Tuple

class ClassMethodsHandler:
    def __init__(self, translator):
        self.translator = translator

    def extract_method_info(self, node: ast.ClassDef) -> Tuple[bool, bool, Set[str], Set[str]]:
        has_init, has_new = False, False
        static_methods, class_methods = set(), set()
        for child in node.body:
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if child.name == "__init__": has_init = True
                elif child.name == "__new__": has_new = True
                for decorator in child.decorator_list:
                    dec_name = ""
                    if isinstance(decorator, ast.Name): dec_name = decorator.id
                    elif isinstance(decorator, ast.Call) and isinstance(decorator.func, ast.Name): dec_name = decorator.func.id
                    elif isinstance(decorator, ast.Attribute): dec_name = decorator.attr
                    if dec_name in ("staticmethod", "abstractstaticmethod"): static_methods.add(child.name)
                    elif dec_name in ("classmethod", "abstractclassmethod"): class_methods.add(child.name)
        return has_init, has_new, static_methods, class_methods

    def separate_methods(self, body: List[ast.stmt]) -> Tuple[List[ast.FunctionDef | ast.AsyncFunctionDef], List[ast.stmt]]:
        methods, remaining_body = [], []
        for stmt in body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)): methods.append(stmt)
            else: remaining_body.append(stmt)
        return methods, remaining_body

    def rename_dunder_methods(self, methods: List[ast.FunctionDef | ast.AsyncFunctionDef], has_str: bool) -> None:
        for method in methods:
            if method.name == "__repr__":
                setattr(method, "original_name", "__repr__")
                setattr(method, "name", "repr" if has_str else "str")
            elif method.name == "__next__":
                setattr(method, "original_name", "__next__")
                method.name = "next"
            elif method.name == "__post_init__":
                setattr(method, "original_name", "__post_init__")
                method.name = "post_init"
            elif method.name == "__await__":
                setattr(method, "original_name", "__await__")
                method.name = "await_"
            elif method.name == "__iter__":
                setattr(method, "original_name", "__iter__")
                method.name = "iter"
            elif method.name == "__str__":
                setattr(method, "original_name", "__str__")
                method.name = "str"

    def has_method(self, methods: List[ast.FunctionDef | ast.AsyncFunctionDef], method_name: str) -> bool:
        return any(m.name == method_name or getattr(m, "original_name", "") == method_name for m in methods)

    def process_interface_methods(self, methods: List[ast.FunctionDef | ast.AsyncFunctionDef]) -> List[str]:
        interface_methods = []
        has_str = self.has_method(methods, "__str__")
        struct_name = self.translator.current_class or ""
        for method in methods:
            if method.name == "__init__": continue
            m_name = self.translator._sanitize_name(method.name)
            original_node_name = getattr(method, "original_name", method.name)
            if m_name == "__next__": m_name = "next"
            elif m_name == "__post_init__": m_name = "post_init"
            elif m_name == "__await__": m_name = "await_"
            elif m_name == "__iter__": m_name = "iter"
            elif m_name == "__str__": m_name = "str"
            elif m_name == "__repr__": m_name = "repr" if has_str else "str"

            is_m_classmethod = any(self.translator.decorator_processor.get_decorator_name(dec) in ("classmethod", "abstractclassmethod") for dec in method.decorator_list)
            m_args = []

            # Use same qualified name logic as generation.py
            prefix = ".".join(self.translator._scope_names)
            # When processing interface methods, we are inside the class scope
            # but _scope_names might already contain the class name.

            for arg in (getattr(method.args, 'posonlyargs', []) + method.args.args):
                if arg.arg == "self" or (is_m_classmethod and arg.arg == "cls"): continue

                arg_name = self.translator._sanitize_name(arg.arg)
                a_type = "int"
                try:
                    a_type = self.translator._map_type(ast.unparse(arg.annotation), struct_name) if arg.annotation else self.translator._map_type(self.translator.type_inference.type_map.get(arg_name, "int"), struct_name)
                except: pass

                # Check mutability
                is_mut = False
                if hasattr(self.translator, 'type_inference') and hasattr(self.translator.type_inference, 'mutability_map'):
                    # Match generation.py logic: prefix.method.arg
                    # In generation.py: prefix = ".".join(self._scope_names)
                    # For interface methods, we should build it based on struct_name
                    prefix_full = f"{struct_name}.{method.name}.{arg.arg}" if struct_name else f"{method.name}.{arg.arg}"
                    m_info = self.translator.type_inference.mutability_map.get(prefix_full)
                    if m_info:
                        is_mut = m_info.get("is_reassigned", False) or m_info.get("is_mutated", False)

                # Prepend & if it's a struct
                if self.translator._is_class_type(a_type):
                    a_type = f"&{a_type}"

                m_args.append(f"{'mut ' if is_mut else ''}{arg_name} {a_type}")

            m_ret = "void"
            if method.returns:
                try: m_ret = self.translator._map_type(ast.unparse(method.returns), struct_name, is_return=True)
                except: pass
            else:
                 ir = self.translator.type_inference.type_map.get(f"{method.name}@return")
                 if ir: m_ret = self.translator._map_type(ir, struct_name, is_return=True)

            # Prepend & for return type if it's a struct
            if self.translator._is_class_type(m_ret):
                m_ret = f"&{m_ret}"

            if original_node_name == "__next__" or m_name == "next":
                if m_ret != "void" and not m_ret.startswith("?"):
                    m_ret = f"?{m_ret}"

            interface_methods.append(f"    {m_name}({', '.join(m_args)}){'' if m_ret == 'void' else ' ' + m_ret}")
        return interface_methods

    def register_class_info(self, struct_name: str, has_init: bool, has_new: bool, static_methods: Set[str], class_methods: Set[str], has_factory: bool = False) -> None:
        if not hasattr(self.translator, "defined_classes"): self.translator.defined_classes = {}
        cur = self.translator.defined_classes.get(struct_name)
        if not cur or not (cur.get("has_init") or cur.get("has_new")):
            if has_factory: self.translator.defined_classes[struct_name] = {"has_init": True, "has_new": True, "static_methods": static_methods, "class_methods": class_methods}
            else:
                if cur: cur["has_init"] = has_init
                else: self.translator.defined_classes[struct_name] = {"has_init": has_init, "has_new": has_new, "static_methods": static_methods, "class_methods": class_methods}
