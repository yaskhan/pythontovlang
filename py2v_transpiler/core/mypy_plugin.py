from mypy.plugin import Plugin
from typing import Any
import json
from collections import defaultdict

class VlangPlugin(Plugin):
    """Mypy plugin for py2v_transpiler to extract type information."""

    def __init__(self, options):
        super().__init__(options)
        self.collected_types = defaultdict(dict)

    def get_function_hook(self, fullname: str):
        def hook(ctx):
            if hasattr(ctx.context, 'line'):
                key = f"{ctx.context.line}:{ctx.context.column}"
                self.collected_types[fullname][key] = str(ctx.default_return_type)
            return ctx.default_return_type
        return hook

    def get_method_hook(self, fullname: str):
        def hook(ctx):
            if hasattr(ctx.context, 'line'):
                key = f"{ctx.context.line}:{ctx.context.column}"
                self.collected_types[fullname][key] = str(ctx.default_return_type)
            return ctx.default_return_type
        return hook

    def report_config_data(self, ctx: Any) -> Any:
        try:
            with open("types_for_vlang.json", "w") as f:
                json.dump(dict(self.collected_types), f, indent=2)
        except Exception:
            pass
        return self.collected_types

def plugin(version: str):
    return VlangPlugin
