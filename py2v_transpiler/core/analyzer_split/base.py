import ast
from typing import Dict, Any, List


class TypeInferenceBase(ast.NodeVisitor):
    _scope_names: List[str]
    def __init__(self):
        self.type_map: Dict[str, str] = {}
        self.raw_type_map: Dict[str, str] = {}
        self.mutability_map: Dict[str, Dict[str, Any]] = {}
        self.func_param_mutability: Dict[str, List[int]] = {}
        self.location_map: Dict[str, str] = {}
        self.call_signatures: Dict[str, Dict[str, Any]] = {}
        self.mixin_to_main: Dict[str, list[str]] = {}
        self.main_to_mixins: Dict[str, list[str]] = {}
        self.mixin_nodes: Dict[str, ast.ClassDef] = {}
        self.static_methods: Dict[str, set[str]] = {}
        self.class_methods: Dict[str, set[str]] = {}
        self.is_abc: Dict[str, bool] = {}
        self.class_hierarchy: Dict[str, List[str]] = {}
        self.explicit_any_types: set[str] = set()
        self._scope_names = []

    def _get_base_node(self, node: ast.AST) -> ast.AST:
        curr = node
        while isinstance(curr, ast.Subscript):
            curr = curr.value
        return curr
