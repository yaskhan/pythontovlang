from mypy.plugin import Plugin
from typing import Any, Dict
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

    def get_additional_deps(self, file: Any) -> Any:
        self._files_to_process.append(file)
        return []

    def get_function_hook(self, fullname: str):
        def hook(ctx):
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
                            # Use a specific hook to ensure metadata is captured
                            # Actually, we can just attach it to sig_data and it should work if it's serializable
                            dataclass_metadata = type_info.metadata['dataclass']
                            # Check for __post_init__
                            has_post_init = '__post_init__' in type_info.names

                            # Mypy's metadata might contain non-serializable objects (like SymTableNode)
                            # We need to extract only what we need.
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

    def report_config_data(self, ctx: Any) -> Any:
        global _global_collected_types, _global_collected_sigs, _global_collected_mutability

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

            # Manual traversal to avoid TypeError: interpreted classes cannot inherit from compiled traits
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
                for h in node.handlers: collect_vars(h.body, collected, visited)
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
