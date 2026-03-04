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
            alias_defaults = {}
            for param in node.type_params:
                param_name = ""
                if hasattr(param, 'name'):
                    name_attr = param.name
                    if isinstance(name_attr, str):
                        param_name = name_attr
                    elif hasattr(name_attr, 'id'):
                        param_name = name_attr.id
                elif isinstance(param, TypeVar):
                    param_name = param.name

                if param_name:
                    params.append(param_name)
                    # Extract PEP 696 default
                    default_v_type = self._extract_type_param_default(param)
                    if default_v_type:
                        alias_defaults[param_name] = default_v_type

            self.generic_info[node.name.id] = {
                'params': params,
                'defaults': alias_defaults
            }

            if params:
                type_params = f"[{', '.join(params)}]"

        if hasattr(ast, 'unparse'):
            val_str = ast.unparse(node.value)
            v_type = self._map_python_type_to_v(val_str, allow_union=True)
            self.emitter.add_struct(f"type {name}{type_params} = {v_type}")
        else:
            self.output.append(f"{self._indent()}// TypeAlias {name} skipped (no ast.unparse)")
