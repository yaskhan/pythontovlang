import ast
from typing import Any
from ..base import TranslatorBase
from py2v_transpiler.models.v_types import map_python_type_to_v


class TypeAliasMixin(TranslatorBase):
    """Обработка type alias: visit_TypeAlias (PEP 613)"""
    
    def visit_TypeAlias(self, node: Any) -> None:
        name = self._sanitize_name(node.name.id)
        type_params = ""

        # Safe access to ast.TypeVar for Py < 3.12 compatibility
        TypeVar = getattr(ast, 'TypeVar', type(None))

        if node.type_params:
            # Handle generics [T, U]
            params = []
            for param in node.type_params:
                # PEP 696 type defaults (param.default) are intentionally ignored since V doesn't support them
                if hasattr(param, 'name'):
                    name_attr = param.name
                    if isinstance(name_attr, str):
                        params.append(name_attr)
                    elif hasattr(name_attr, 'id'):
                        params.append(name_attr.id)
                elif isinstance(param, TypeVar):
                    params.append(param.name)
                # Basic support for TypeVar only for now
            if params:
                type_params = f"[{', '.join(params)}]"

        if hasattr(ast, 'unparse'):
            val_str = ast.unparse(node.value)
            v_type = map_python_type_to_v(val_str, allow_union=True)
            self.emitter.add_struct(f"type {name}{type_params} = {v_type}")
        else:
            self.output.append(f"{self._indent()}// TypeAlias {name} skipped (no ast.unparse)")
