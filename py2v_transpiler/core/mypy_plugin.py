from mypy.plugin import Plugin
from typing import Any, Dict, Callable, Optional
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
            self.checker = ctx.api
            if hasattr(ctx.context, 'line'):
                key = f"{ctx.context.line}:{ctx.context.column}"
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

                dataclass_metadata = None
                try:
                    from mypy.types import Instance
                    if isinstance(ctx.default_return_type, Instance):
                        type_info = ctx.default_return_type.type
                        if 'dataclass' in type_info.metadata:
                            dataclass_metadata = type_info.metadata['dataclass']
                            has_post_init = '__post_init__' in type_info.names

                            serializable_meta = {
                                "attributes": [],
                                "frozen": dataclass_metadata.get("frozen", False),
                                "has_post_init": has_post_init
                            }
                            for attr in dataclass_metadata.get("attributes", []):
                                serializable_meta["attributes"].append({
                                    "name": attr.name,
                                    "is_in_init": attr.is_in_init,
                                    "is_init_var": attr.is_init_var,
                                    "is_classvar": attr.is_classvar,
                                    "has_default": attr.has_default,
                                    "type": str(attr.type)
                                })
                            dataclass_metadata = serializable_meta
                except Exception:
                    pass

                sig_data = {
                    "args": args,
                    "return": str(ctx.default_return_type),
                    "is_class": is_class,
                    "has_init": has_init
                }
                if dataclass_metadata:
                    sig_data["dataclass_metadata"] = dataclass_metadata

                self.collected_sigs[fullname][key] = json.dumps(sig_data)

            return ctx.default_return_type
        return hook

    def get_method_hook(self, fullname: str):
        def hook(ctx):
            self.checker = ctx.api
            if hasattr(ctx.context, 'line'):
                key = f"{ctx.context.line}:{ctx.context.column}"
                self.collected_types[fullname][key] = str(ctx.default_return_type)

                # Also store call signature
                args = []
                for arg_list in ctx.arg_types:
                    for arg in arg_list:
                        args.append(str(arg))

                is_class = False
                has_init = False
                dataclass_metadata = None
                try:
                    from mypy.types import Instance
                    if isinstance(ctx.default_return_type, Instance):
                        type_info = ctx.default_return_type.type
                        is_class = type_info.fullname == fullname
                        has_init = '__init__' in type_info.names
                        if 'dataclass' in type_info.metadata:
                            dataclass_metadata = type_info.metadata['dataclass']
                            has_post_init = '__post_init__' in type_info.names

                            serializable_meta = {
                                "attributes": [],
                                "frozen": dataclass_metadata.get("frozen", False),
                                "has_post_init": has_post_init
                            }
                            for attr in dataclass_metadata.get("attributes", []):
                                serializable_meta["attributes"].append({
                                    "name": attr.name,
                                    "is_in_init": attr.is_in_init,
                                    "is_init_var": attr.is_init_var,
                                    "is_classvar": attr.is_classvar,
                                    "has_default": attr.has_default,
                                    "type": str(attr.type)
                                })
                            dataclass_metadata = serializable_meta
                except Exception:
                    pass

                sig_data = {
                    "args": args,
                    "return": str(ctx.default_return_type),
                    "is_class": is_class,
                    "has_init": has_init
                }
                if dataclass_metadata:
                    sig_data["dataclass_metadata"] = dataclass_metadata

                self.collected_sigs[fullname][key] = json.dumps(sig_data)

            return ctx.default_return_type
        return hook

    def get_attribute_hook(self, fullname: str):
        def hook(ctx):
             if hasattr(ctx.context, 'line'):
                 key = f"{ctx.context.line}:{ctx.context.column}"
                 self.collected_types[fullname][key] = str(ctx.default_attr_type)
             return ctx.default_attr_type
        return hook

    def report_config_data(self, ctx: Any) -> Any:
        global _global_collected_types, _global_collected_sigs, _global_collected_mutability

        # Collect types from checker's type_map for narrowing
        from mypy.nodes import NameExpr, MemberExpr, Var, FuncDef
        if self.checker and hasattr(self.checker, 'type_map'):
            for expr, typ in self.checker.type_map.items():
                if hasattr(expr, 'line'):
                    key = f"{expr.line}:{expr.column}"

                    name = None
                    fullname = None
                    if isinstance(expr, NameExpr):
                        name = expr.name
                        fullname = expr.fullname
                    elif isinstance(expr, MemberExpr):
                        name = expr.name
                        fullname = expr.fullname
                    elif isinstance(expr, Var):
                        name = expr.name
                        fullname = expr.fullname
                    elif hasattr(expr, 'name'):
                        name = getattr(expr, 'name')
                        fullname = getattr(expr, 'fullname', None)

                    if name:
                        # Store by multiple keys to increase hit rate
                        self.collected_types[name][key] = str(typ)
                        # Also store by line only for block-start heuristic
                        self.collected_types[name][f"{expr.line}:*"] = str(typ)
                        if fullname:
                            self.collected_types[fullname][key] = str(typ)
                            self.collected_types[fullname][f"{expr.line}:*"] = str(typ)

        # Collect types from all visited expressions if possible
        # This is more expensive but ensures we get narrowing for every variable usage
        if self.checker and hasattr(self.checker, 'visitor'):
             # Unfortunately mypy doesn't keep all expression types in a simple map always,
             # except for what's in self.checker.type_map which we already collected.
             pass

        # Try to find all variables in all modules to get their types
        for file_node in self._files_to_process:
            for name, sym in file_node.names.items():
                if sym.node and hasattr(sym.node, 'type') and sym.node.type:
                    key = f"{sym.node.line}:{sym.node.column}"
                    self.collected_types[sym.node.fullname or name][key] = str(sym.node.type)

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
            elif isinstance(node, (WhileStmt, ForStmt)):
                collect_vars(getattr(node, 'expr', None), collected, visited)
                collect_vars(getattr(node, 'index', None), collected, visited)
                collect_vars(node.body, collected, visited)
                collect_vars(node.else_body, collected, visited)
            elif isinstance(node, TryStmt):
                collect_vars(node.body, collected, visited)
                for h in node.handlers:
                    # Collect type of exception variable at handler start
                    if h.type:
                        collect_vars(h.type, collected, visited)
                    if h.name:
                        # In mypy, h.name is often a NameExpr
                        if isinstance(h.name, NameExpr):
                             # Try to get type from checker's type_map for this expression
                             if self.checker and hasattr(self.checker, 'type_map') and h.name in self.checker.type_map:
                                  typ = self.checker.type_map[h.name]
                                  self.collected_types[h.name.name][f"{h.line}:*"] = str(typ)
                                  # Also store with fullname if available
                                  if h.name.fullname:
                                       self.collected_types[h.name.fullname][f"{h.line}:*"] = str(typ)

                        collect_vars(h.name, collected, visited)

                    collect_vars(h.body, collected, visited)
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
