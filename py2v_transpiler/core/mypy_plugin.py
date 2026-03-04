from mypy.plugin import Plugin
from typing import Any, Dict
import json
from collections import defaultdict
import sys

# Global dictionary to store types without relying on the filesystem
# This is accessed from py2v_transpiler.core.analyzer
_global_collected_types: Dict[str, Dict[str, str]] = defaultdict(dict)
_global_collected_sigs: Dict[str, Dict[str, str]] = defaultdict(dict)

class VlangPlugin(Plugin):
    """Mypy plugin for py2v_transpiler to extract type information."""

    def __init__(self, options):
        super().__init__(options)
        self.collected_types: Dict[str, Dict[str, str]] = defaultdict(dict)
        self.collected_sigs: Dict[str, Dict[str, str]] = defaultdict(dict)

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
        global _global_collected_types, _global_collected_sigs
        # Update the module-level global dictionary
        for k, v in self.collected_types.items():
            _global_collected_types[k].update(v)

        for k, v in self.collected_sigs.items():
            _global_collected_sigs[k].update(v)

        return self.collected_types

def plugin(version: str):
    return VlangPlugin
