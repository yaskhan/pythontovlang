import ast
from typing import Any, List, Set, TYPE_CHECKING


class FunctionCommonMixin:
    if TYPE_CHECKING:
        type_vars: Set[str]
        constrained_typevars: Set[str]
        current_class_generics: List[str]
        _scope_stack: List[Set[str]]
        def _sanitize_name(self, name: str, is_type: bool = False) -> str: ...

    def _extract_implicit_generics(self, node: Any) -> List[str]:
        """
        Extract implicit generics by scanning argument and return annotations for known TypeVars.
        This is necessary for generic functions lacking PEP 695 type_params, common in older stubs.
        """
        implicit_generics = set()

        # Helper to scan AST node for known TypeVar names
        def scan_annotation(ann_node: ast.AST):
            for n in ast.walk(ann_node):
                if isinstance(n, ast.Name):
                    if n.id in self.type_vars:
                        implicit_generics.add(n.id)
                elif isinstance(n, ast.Attribute):
                    # For cases like typing.T
                    if n.attr in self.type_vars:
                        implicit_generics.add(n.attr)

        # Scan arguments
        args = getattr(node.args, "args", [])
        if hasattr(node.args, "posonlyargs"):
            args = node.args.posonlyargs + args
        if hasattr(node.args, "kwonlyargs"):
            args = args + node.args.kwonlyargs

        for arg in args:
            if getattr(arg, "annotation", None):
                scan_annotation(arg.annotation)

        if getattr(node.args, "vararg", None) and getattr(node.args.vararg, "annotation", None):
            scan_annotation(node.args.vararg.annotation)

        if getattr(node.args, "kwarg", None) and getattr(node.args.kwarg, "annotation", None):
            scan_annotation(node.args.kwarg.annotation)

        # Scan return annotation
        if getattr(node, "returns", None):
            scan_annotation(node.returns)

        # Filter out constrained typevars (they act as aliases, not true generics)
        valid_generics = set()
        for gen in implicit_generics:
            if gen not in getattr(self, "constrained_typevars", set()):
                valid_generics.add(gen)
        implicit_generics = valid_generics

        # Remove any generics that are already explicitly defined in class
        if self.current_class_generics:
            implicit_generics.difference_update(self.current_class_generics)

        # Return sorted list for determinism
        return sorted(list(implicit_generics))

    def _find_captured_vars(self, node: ast.AST) -> List[str]:
        captured: Set[str] = set()
        mutated: Set[str] = set()
        inner_defs: Set[str] = set()
        nonlocal_vars: Set[str] = set()

        # If node is a function, its arguments are inner defs
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)):
            args = node.args.args
            if hasattr(node.args, 'posonlyargs'):
                args = node.args.posonlyargs + args
            if hasattr(node.args, 'kwonlyargs'):
                args = args + node.args.kwonlyargs
            for arg in args:
                inner_defs.add(arg.arg)
            if node.args.vararg:
                inner_defs.add(node.args.vararg.arg)
            if node.args.kwarg:
                inner_defs.add(node.args.kwarg.arg)

        # First pass: find nonlocal/global declarations and inner definitions
        for subnode in ast.walk(node):
            if isinstance(subnode, (ast.Nonlocal, ast.Global)):
                nonlocal_vars.update(subnode.names)
            elif isinstance(subnode, ast.Name) and isinstance(subnode.ctx, ast.Store):
                # Only treat as inner def if NOT declared nonlocal/global
                if subnode.id not in nonlocal_vars:
                    inner_defs.add(subnode.id)

        # Second pass: find loads and check if they are from outer scopes
        # Also check stores to nonlocal variables
        for subnode in ast.walk(node):
            if isinstance(subnode, ast.Name):
                name = subnode.id
                is_store = isinstance(subnode.ctx, (ast.Store, ast.Del))

                # A variable is captured if:
                # 1. It is used (Load) and not defined in the current function
                # 2. It is declared nonlocal/global and stored to (Store/Del)
                if name in nonlocal_vars or (name not in inner_defs and isinstance(subnode.ctx, ast.Load)):
                    # Check outer scopes (from inner to outer)
                    # We iterate through scope_stack which should be [global, outer, inner]
                    # Actually _scope_stack is a list of sets.
                    for scope in reversed(self._scope_stack):
                        if name in scope:
                            sanitized = self._sanitize_name(name)
                            captured.add(sanitized)
                            if is_store or name in nonlocal_vars:
                                mutated.add(sanitized)
                            break
            elif isinstance(subnode, ast.AugAssign) and isinstance(subnode.target, ast.Name):
                name = subnode.target.id
                if name not in inner_defs:
                    for scope in reversed(self._scope_stack):
                        if name in scope:
                            sanitized = self._sanitize_name(name)
                            captured.add(sanitized)
                            mutated.add(sanitized)
                            break
            elif isinstance(subnode, ast.Call) and isinstance(subnode.func, ast.Attribute):
                # Check for mutating methods on captured objects
                mutating_methods = {"append", "extend", "insert", "pop", "remove", "clear", "update", "setdefault", "add", "discard"}
                if subnode.func.attr in mutating_methods and isinstance(subnode.func.value, ast.Name):
                    name = subnode.func.value.id
                    if name not in inner_defs:
                        for scope in reversed(self._scope_stack):
                            if name in scope:
                                sanitized = self._sanitize_name(name)
                                captured.add(sanitized)
                                # V's [mut x] capture is required if the object itself is mutated (e.g. array/map)
                                mutated.add(sanitized)
                                break

        result = []
        for name in sorted(list(captured)):
            # Handle the case where name might already have 'mut ' prefix from nested closures
            # But here sanitized name should be just the identifier.
            if name in mutated:
                result.append(f"mut {name}")
            else:
                result.append(name)
        return result
    def _is_empty_body(self, body: List[ast.stmt]) -> bool:
        """Check if a function body is effectively empty (pass, ..., NotImplementedError)."""
        for stmt in body:
            if isinstance(stmt, ast.Pass):
                continue
            if (
                isinstance(stmt, ast.Expr)
                and isinstance(stmt.value, ast.Constant)
            ):
                if stmt.value.value is Ellipsis or isinstance(stmt.value.value, str):
                    continue
            if isinstance(stmt, ast.Raise):
                if (
                    isinstance(stmt.exc, ast.Name)
                    and stmt.exc.id == "NotImplementedError"
                ):
                    continue
                if (
                    isinstance(stmt.exc, ast.Call)
                    and isinstance(stmt.exc.func, ast.Name)
                    and stmt.exc.func.id == "NotImplementedError"
                ):
                    continue
            return False
        return True
