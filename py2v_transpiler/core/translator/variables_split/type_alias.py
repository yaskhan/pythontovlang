import ast
from typing import Any
from ..base import TranslatorBase
from py2v_transpiler.models.v_types import map_python_type_to_v


class TypeAliasMixin(TranslatorBase):
    """Обработка type alias: visit_TypeAlias (PEP 613)"""
    
    def visit_TypeAlias(self, node: Any) -> None:
        name = self._sanitize_name(node.name.id)

        py_generics = []
        if hasattr(node, "type_params") and node.type_params:
            for param in node.type_params:
                # PEP 696 type defaults (param.default) are intentionally ignored since V doesn't support them
                if hasattr(param, 'name'):
                    name_attr = param.name
                    if isinstance(name_attr, str):
                        py_generics.append(name_attr)
                    elif hasattr(name_attr, 'id'):
                        py_generics.append(name_attr.id)

        generic_map = self._get_generic_map(py_generics)
        self.generic_scopes.append(generic_map)

        v_generics = self._get_all_active_v_generics()
        type_params_str = f"[{', '.join(v_generics)}]" if v_generics else ""

        if hasattr(ast, 'unparse'):
            val_str = ast.unparse(node.value)
            v_type = self._map_type(val_str, allow_union=True, register_sum_types=False)

            pub = "pub " if self._is_exported(node.name.id) else ""
            self.emitter.add_struct(f"{pub}type {name}{type_params_str} = {v_type}")
        else:
            self.output.append(f"{self._indent()}// TypeAlias {name} skipped (no ast.unparse)")

        self.generic_scopes.pop()
