from mypy.plugin import Plugin
from typing import Any, Dict, Callable, Optional, Sequence
import json
from collections import defaultdict
import sys

# Global dictionary to store types without relying on the filesystem
# This is accessed from py2v_transpiler.core.analyzer
_global_collected_types: Dict[str, Dict[str, str]] = defaultdict(dict)
_global_collected_sigs: Dict[str, Dict[str, str]] = defaultdict(dict)
_global_collected_mutability: Dict[str, Dict[str, Any]] = defaultdict(dict)

class VlangPlugin(Plugin):
    """Mypy plugin for py2v_transpiler to extract type information."""

    def __init__(self, options):
        super().__init__(options)
        self.collected_types: Dict[str, Dict[str, str]] = defaultdict(dict)
        self.collected_sigs: Dict[str, Dict[str, str]] = defaultdict(dict)
        self.collected_mutability: Dict[str, Dict[str, Any]] = defaultdict(dict)
        self._files_to_process = []
        self.checker: Any = None

    def get_additional_deps(self, file: Any) -> Any:
        self._files_to_process.append(file)
        return []

    def get_function_hook(self, fullname: str):
        def hook(ctx):
             return self._hook(ctx, fullname)
        return hook

    def get_method_hook(self, fullname: str):
        def hook(ctx):
             return self._hook(ctx, fullname)
        return hook

    def _hook(self, ctx, fullname: str):
        if not self.checker:
             self.checker = ctx.api
        if hasattr(ctx.context, 'line'):
            key = f"{ctx.context.line}:{ctx.context.column}"
            # Store under both fullname and short name for flexibility
            short_name = fullname.split('.')[-1]
            self.collected_types[fullname][key] = str(ctx.default_return_type)

            # Also store call signature
            args = []
            for arg_list in ctx.arg_types:
                for arg in arg_list:
                    args.append(str(arg))

            is_class = False
            has_init = False
            try:
                from mypy.types import Instance
                if isinstance(ctx.default_return_type, Instance):
                    type_info = ctx.default_return_type.type
                    is_class = type_info.fullname == fullname
                    has_init = '__init__' in type_info.names
            except Exception:
                pass

            sig_data = {
                "args": args,
                "return": str(ctx.default_return_type),
                "is_class": is_class,
                "has_init": has_init
            }

            self.collected_sigs[fullname][key] = json.dumps(sig_data)
            self.collected_sigs[short_name][key] = json.dumps(sig_data)
            # Direct location-based lookup
            self.collected_sigs[key][key] = json.dumps(sig_data)

        return ctx.default_return_type

    def get_attribute_hook(self, fullname: str):
        def hook(ctx):
             if hasattr(ctx.context, 'line'):
                 key = f"{ctx.context.line}:{ctx.context.column}"
                 self.collected_types[fullname][key] = str(ctx.default_attr_type)
             return ctx.default_attr_type
        return hook

    def report_config_data(self, ctx: Any) -> Any:
        global _global_collected_types, _global_collected_sigs, _global_collected_mutability

        # Collect types from checker's type_map for narrowing and calls
        from mypy.nodes import NameExpr, MemberExpr, Var, FuncDef, CallExpr, ListExpr, DictExpr, SetExpr, TupleExpr
        if self.checker and hasattr(self.checker, 'type_map'):
            for expr, typ in self.checker.type_map.items():
                if hasattr(expr, 'line'):
                    key = f"{expr.line}:{expr.column}"
                    # print(f"DEBUG PLUGIN: processing expr {type(expr)} at {key} with type {typ}")

                    if isinstance(expr, (CallExpr, ListExpr, DictExpr, SetExpr, TupleExpr)):
                        # Store by location for direct lookup
                        self.collected_types[key][key] = str(typ)

                    if isinstance(expr, CallExpr):
                        from mypy.types import Instance
                        # For CallExpr, the type in type_map is the return type
                        # We want to record this instantiation
                        if isinstance(typ, Instance):
                            type_info = typ.type
                            fullname_cls = type_info.fullname
                            short_name_cls = type_info.name

                            sig_data = {
                                "args": [], # difficult to recover from type_map easily
                                "return": str(typ),
                                "is_class": True, # heuristic: if return type is Instance and we are at CallExpr, it's likely a class call
                                "has_init": '__init__' in type_info.names
                            }
                            self.collected_sigs[fullname_cls][key] = json.dumps(sig_data)
                            self.collected_sigs[short_name_cls][key] = json.dumps(sig_data)
                            self.collected_sigs[key][key] = json.dumps(sig_data)

                    name: Optional[str] = None
                    fullname_node: Optional[str] = None
                    if isinstance(expr, NameExpr):
                        name = expr.name
                        fullname_node = expr.fullname
                    elif isinstance(expr, MemberExpr):
                        name = expr.name
                        fullname_node = expr.fullname
                    elif isinstance(expr, Var):
                        name = expr.name
                        fullname_node = expr.fullname
                    elif hasattr(expr, 'name'):
                        name = getattr(expr, 'name')
                        fullname_node = getattr(expr, 'fullname', None)

                    if name:
                        # Store by multiple keys to increase hit rate
                        self.collected_types[name][key] = str(typ)
                        # Also store by line only for block-start heuristic
                        self.collected_types[name][f"{expr.line}:*"] = str(typ)
                        if fullname_node:
                            self.collected_types[fullname_node][key] = str(typ)
                            self.collected_types[fullname_node][f"{expr.line}:*"] = str(typ)

        # Collect mutability info from processed files
        from mypy.nodes import Var, FuncDef, Block, AssignmentStmt, NameExpr, MypyFile

        def collect_vars(node, collected, visited=None):
            if visited is None:
                visited = set()
            if node is None or id(node) in visited:
                return
            visited.add(id(node))

            if isinstance(node, Var):
                key = f"{node.line}:{node.column}"
                collected[node.fullname][key] = {
                    "is_reassigned": getattr(node, "is_reassigned", False),
                    "is_final": node.is_final
                }
                # Also collect its base type here
                if node.type:
                    self.collected_types[node.fullname][key] = str(node.type)

            # Manual traversal
            from mypy.nodes import IfStmt, WhileStmt, ForStmt, TryStmt, ClassDef, MemberExpr
            if isinstance(node, MypyFile):
                for name, sym in node.names.items():
                    collect_vars(sym.node, collected, visited)
            elif isinstance(node, ClassDef):
                if node.info:
                    for name, sym in node.info.names.items():
                        collect_vars(sym.node, collected, visited)
                for stmt in node.defs.body:
                    collect_vars(stmt, collected, visited)
            elif isinstance(node, FuncDef):
                for arg in node.arguments:
                    collect_vars(arg.variable, collected, visited)
                collect_vars(node.body, collected, visited)
            elif isinstance(node, Block):
                for stmt in node.body:
                    collect_vars(stmt, collected, visited)
            elif isinstance(node, IfStmt):
                for e in node.expr: collect_vars(e, collected, visited)
                for b in node.body: collect_vars(b, collected, visited)
                collect_vars(node.else_body, collected, visited)
            elif isinstance(node, WhileStmt):
                collect_vars(node.expr, collected, visited)
                collect_vars(node.body, collected, visited)
                collect_vars(node.else_body, collected, visited)
            elif isinstance(node, ForStmt):
                collect_vars(node.expr, collected, visited)
                collect_vars(node.index, collected, visited)
                # If the index is a NameExpr, it might have a narrowed type within the body
                if isinstance(node.index, NameExpr):
                    # In mypy, ForStmt.index_type can store the inferred type of the loop variable
                    index_type = getattr(node, "index_type", None)
                    if index_type:
                        self.collected_types[node.index.name][f"{node.body.line}:*"] = str(index_type)
                        if node.index.fullname:
                            self.collected_types[node.index.fullname][f"{node.body.line}:*"] = str(index_type)

                collect_vars(node.body, collected, visited)
                collect_vars(node.else_body, collected, visited)
            elif isinstance(node, TryStmt):
                collect_vars(node.body, collected, visited)
                for h in node.handlers:
                    # Collect type of exception variable at handler start
                    h_type = getattr(h, 'type', None)
                    if h_type:
                        collect_vars(h_type, collected, visited)
                    h_name = getattr(h, 'name', None)
                    if h_name:
                        # In mypy, h.name is often a NameExpr
                        if isinstance(h_name, NameExpr):
                             # Try to get type from checker's type_map for this expression
                             if self.checker and hasattr(self.checker, 'type_map') and h_name in self.checker.type_map:
                                  typ = self.checker.type_map[h_name]
                                  self.collected_types[h_name.name][f"{getattr(h, 'line', -1)}:*"] = str(typ)
                                  # Also store with fullname if available
                                  if h_name.fullname:
                                       self.collected_types[h_name.fullname][f"{getattr(h, 'line', -1)}:*"] = str(typ)

                        collect_vars(h_name, collected, visited)

                    h_body = getattr(h, 'body', None)
                    if h_body:
                        collect_vars(h_body, collected, visited)
                collect_vars(node.else_body, collected, visited)
                collect_vars(node.finally_body, collected, visited)
            elif isinstance(node, AssignmentStmt):
                for lvalue in node.lvalues:
                    collect_vars(lvalue, collected, visited)
                collect_vars(node.rvalue, collected, visited)
            elif isinstance(node, NameExpr):
                collect_vars(node.node, collected, visited)
            elif isinstance(node, MemberExpr):
                collect_vars(node.expr, collected, visited)
                collect_vars(node.node, collected, visited)

        for file_node in self._files_to_process:
            collect_vars(file_node, self.collected_mutability)

        # Update the module-level global dictionary
        for k, v in self.collected_types.items():
            _global_collected_types[k].update(v)

        for k, v in self.collected_sigs.items():
            _global_collected_sigs[k].update(v)

        for k, v in self.collected_mutability.items():
            _global_collected_mutability[k].update(v)

        return self.collected_types

def plugin(version: str):
    return VlangPlugin
