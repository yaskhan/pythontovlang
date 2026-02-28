from mypy.plugin import Plugin
from typing import Any, Dict
import json
from collections import defaultdict

_global_collected_types: Dict[str, Dict[str, str]] = defaultdict(dict)

class VlangPlugin(Plugin):
    """Mypy plugin for py2v_transpiler to extract type information."""

    def __init__(self, options):
        super().__init__(options)
        self.collected_types = defaultdict(dict)

    def _process_call(self, ctx, key, fullname):
        self.collected_types[fullname][key] = str(ctx.default_return_type)
        if hasattr(ctx, 'api') and hasattr(ctx.api, 'expr_checker'):
            try:
                callee_type = ctx.api.expr_checker.accept(ctx.context.callee)
                if hasattr(callee_type, 'arg_types'):
                    proto_args = {}
                    for i, arg_type in enumerate(callee_type.arg_types):
                        if hasattr(arg_type, 'type') and getattr(arg_type.type, 'is_protocol', False):
                            proto_args[str(i)] = arg_type.type.name
                    if proto_args:
                        self.collected_types[fullname][f"{key}_proto_args"] = json.dumps(proto_args)
            except Exception:
                pass

    def get_function_hook(self, fullname: str):
        def hook(ctx):
            if hasattr(ctx.context, 'line'):
                key = f"{ctx.context.line}:{ctx.context.column}"
                self._process_call(ctx, key, fullname)
            return ctx.default_return_type
        return hook

    def get_method_hook(self, fullname: str):
        def hook(ctx):
            if hasattr(ctx.context, 'line'):
                key = f"{ctx.context.line}:{ctx.context.column}"
                self._process_call(ctx, key, fullname)
            return ctx.default_return_type
        return hook

    def report_config_data(self, ctx: Any) -> Any:
        global _global_collected_types
        # Update the module-level global dictionary
        for k, v in self.collected_types.items():
            _global_collected_types[k].update(v)

        return self.collected_types

def plugin(version: str):
    return VlangPlugin
