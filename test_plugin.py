from mypy.plugin import Plugin, ClassDefContext
from typing import Callable, Optional
import json

class TestPlugin(Plugin):
    def get_class_decorator_hook(self, fullname: str) -> Optional[Callable[[ClassDefContext], None]]:
        if fullname == "dataclasses.dataclass":
            return self.dataclass_hook
        return None

    def dataclass_hook(self, ctx: ClassDefContext) -> None:
        try:
            print(f"DATACLASS HOOK RUN: {ctx.cls.info.fullname}")
            import py2v_transpiler.core.mypy_plugin as m_p
            # Can we get the attributes here from mypy's built in dataclasses plugin?
            # actually we don't have to if we get it from get_function_hook
            # but getting it from class hook might be necessary for types without instances.
            # Does mypy attach metadata in get_class_decorator_hook?
            if 'dataclass' in ctx.cls.info.metadata:
                print("FOUND DATACLASS METADATA IN CLASS HOOK")
        except Exception as e:
            print("ERROR", e)

def plugin(version: str):
    return TestPlugin
