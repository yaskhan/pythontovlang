"""Generic type parameter handling."""

from typing import Dict, List, TYPE_CHECKING, Set

if TYPE_CHECKING:
    from .base import TranslatorBase


class GenericsMixin:
    """Mixin for handling generic type parameters."""

    if TYPE_CHECKING:
        generic_scopes: List[Dict[str, str]]
        generic_variance: Dict[str, str]
        generic_defaults: Dict[str, str]

    def _get_generic_map(self, generic_names: List[str]) -> Dict[str, str]:
        """
        Generates a mapping from Python generic names to unique single-character
        V generic names.
        Example: ['T_co', 'S_contra'] -> {'T_co': 'T', 'S_contra': 'S'}
        """
        mapping = {}
        used_chars: Set[str] = set()
        for scope in self.generic_scopes:
            used_chars.update(scope.values())

        # Priority mapping: try to use the first uppercase letter
        for name in generic_names:
            clean = name.lstrip('_')
            if not clean:
                continue

            char = clean[0].upper()
            if char not in used_chars:
                mapping[name] = char
                used_chars.add(char)
            else:
                # Fallback: find next available uppercase letter
                for c in "TUVWXYZABCDEFGHIJKLMNOPQR":
                    if c not in used_chars:
                        mapping[name] = c
                        used_chars.add(c)
                        break
        return mapping

    def _get_combined_generic_map(self) -> Dict[str, str]:
        """Returns a merged dictionary of all active generic scopes."""
        combined = {}
        scopes = getattr(self, "generic_scopes", [])
        for scope in scopes:
            combined.update(scope)
        return combined

    def _get_all_active_v_generics(self) -> List[str]:
        """Returns all unique V generic names from all active scopes, in order."""
        all_v = []
        seen = set()
        for scope in self.generic_scopes:
            for v_gen in scope.values():
                if v_gen not in seen:
                    all_v.append(v_gen)
                    seen.add(v_gen)
        return all_v

    def _get_generics_with_variance_str(self, v_generics: List[str]) -> str:
        """
        Returns a V generic parameter string (e.g., [T, U]) with PEP 695 variance
        annotations preserved as comments and PEP 696 defaults.
        """
        if not v_generics:
            return ""

        v_gen_parts = []
        rev_map = {v: k for k, v in self._get_combined_generic_map().items()}
        for v_gen in v_generics:
            py_name = rev_map.get(v_gen)
            variance = self.generic_variance.get(py_name, "") if py_name else ""
            default = self.generic_defaults.get(py_name, "") if py_name else ""

            part = v_gen
            if variance:
                part += f" /* {variance} */"
            if default:
                part += f" /* = {default} */"
            v_gen_parts.append(part)
        return f"[{', '.join(v_gen_parts)}]"
