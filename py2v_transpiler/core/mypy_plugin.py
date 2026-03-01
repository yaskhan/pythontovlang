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

                sig_data = {
                    "args": args,
                    "return": str(ctx.default_return_type)
                }
                self.collected_sigs[fullname][key] = json.dumps(sig_data)

            return ctx.default_return_type
        return hook

    def get_method_hook(self, fullname: str):
        def hook(ctx):
            if hasattr(ctx.context, 'line'):
                key = f"{ctx.context.line}:{ctx.context.column}"
                self.collected_types[fullname][key] = str(ctx.default_return_type)

                args = []
                for arg_list in ctx.arg_types:
                    for arg in arg_list:
                        args.append(str(arg))

                sig_data = {
                    "args": args,
                    "return": str(ctx.default_return_type)
                }
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
