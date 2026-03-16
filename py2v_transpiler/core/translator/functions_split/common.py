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
        captured = set()
        inner_defs = set()

        # If node is a function, its arguments are inner defs
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)):
            args = node.args.args
            if hasattr(node.args, 'posonlyargs'):
                args = node.args.posonlyargs + args
            if hasattr(node.args, 'kwonlyargs'):
                args = node.args.kwonlyargs + args
            for arg in args:
                inner_defs.add(arg.arg)
            if node.args.vararg:
                inner_defs.add(node.args.vararg.arg)
            if node.args.kwarg:
                inner_defs.add(node.args.kwarg.arg)

        for subnode in ast.walk(node):
            if isinstance(subnode, ast.Name):
                if isinstance(subnode.ctx, ast.Store):
                    inner_defs.add(subnode.id)
                elif isinstance(subnode.ctx, ast.Load):
                    name = subnode.id
                    if name not in inner_defs:
                        # Check outer scopes
                        for scope in self._scope_stack:
                            if name in scope:
                                captured.add(self._sanitize_name(name))
                                break
        return sorted(list(captured))
