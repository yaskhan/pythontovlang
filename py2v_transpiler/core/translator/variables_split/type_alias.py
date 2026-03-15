import ast
from typing import Any
from ..base import TranslatorBase
from py2v_transpiler.models.v_types import map_python_type_to_v


class TypeAliasMixin(TranslatorBase):
    """Обработка type alias: visit_TypeAlias (PEP 613)"""
    
    def visit_TypeAlias(self, node: Any) -> None:
        name = self._sanitize_name(node.name.id)

        py_generics = []
        added_variance_keys = []
        if hasattr(node, "type_params") and node.type_params:
            for param in node.type_params:
                # PEP 696 type defaults (param.default) are intentionally ignored since V doesn't support them
                if hasattr(param, 'name'):
                    name_attr = param.name
                    if hasattr(name_attr, 'id'):
                        name_attr = name_attr.id

                    if isinstance(name_attr, str):
                        py_generics.append(name_attr)
                        # Extract variance (Python 3.13+)
                        variance = getattr(param, "variance", 0)
                        if variance == 1:
                            self.generic_variance[name_attr] = "+"
                            added_variance_keys.append(name_attr)
                        elif variance == 2:
                            self.generic_variance[name_attr] = "-"
                            added_variance_keys.append(name_attr)
            self.type_params_map[name] = list(py_generics)

        generic_map = self._get_generic_map(py_generics)
        self.generic_scopes.append(generic_map)

        v_generics = self._get_all_active_v_generics()
        type_params_str = self._get_generics_with_variance_str(v_generics)

        if getattr(self.config, 'source_mapping', False):
            self.emitter.add_struct(f"// @line: {self._get_source_info(node)}")

        if hasattr(ast, 'unparse'):
            val_str = ast.unparse(node.value)
            v_type = self._map_type(val_str, allow_union=True, register_sum_types=False)

            pub = "pub " if self._is_exported(node.name.id) else ""
            self.emitter.add_struct(f"{pub}type {name}{type_params_str} = {v_type}")
        else:
            self.output.append(f"{self._indent()}// TypeAlias {name} skipped (no ast.unparse)")

        self.generic_scopes.pop()

        # Clean up variance scope
        for k in added_variance_keys:
            if k in self.generic_variance:
                del self.generic_variance[k]
