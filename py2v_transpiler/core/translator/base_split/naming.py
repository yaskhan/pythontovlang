from typing import Optional, TYPE_CHECKING, Any, Set, Dict, List
import re

if TYPE_CHECKING:
    from py2v_transpiler.core.compatibility import CompatibilityLayer


class NamingMixin:
    """Mixin for naming utilities and identifier sanitization."""

    if TYPE_CHECKING:
        compatibility: "CompatibilityLayer"
        current_file_name: str
        scc_files: Set[str]
        current_class: Optional[str]
        type_inference: Any
        class_hierarchy: Dict[str, List[str]]
        current_class_generics: List[str]

        def _get_scc_prefix(self, file_path: str) -> str: ...

    def _to_snake_case(self, name: str) -> str:
        """Converts CamelCase or UPPER_CASE to snake_case. Preserves internal markers."""
        if not name or name == "_":
            return name

        # Preserve internal markers used for generics/mangling
        if "__py2v_gen" in name:
            return name

        # Handle UPPER_CASE constants
        if name.isupper():
            return name

        # Handle already separated names
        if '_' in name:
            parts = [self._to_snake_case(p) for p in name.split('_') if p]
            return "_".join(parts) if parts else "_"

        res = []
        for i, char in enumerate(name):
            if char.isupper() and i > 0:
                if name[i - 1].islower():
                    res.append('_')
                elif i + 1 < len(name) and name[i + 1].islower():
                    res.append('_')
            res.append(char.lower())
        return "".join(res)

    def _get_factory_name(self, struct_name: str) -> str:
        """Returns a snake_case factory name for a given struct name."""
        base_name = struct_name.split('[')[0]
        sanitized = self._to_snake_case(base_name)
        
        is_split_base = False
        hierarchy = getattr(self.type_inference, 'class_hierarchy', {})
        for derived, bases in hierarchy.items():
            if base_name in bases:
                is_split_base = True
                break
        
        if is_split_base:
            return f"new_{sanitized}_impl"
            
        return f"new_{sanitized}"

    def _sanitize_name(self, name: str, is_type: bool = False) -> str:
        """
        Sanitizes Python identifiers for V compliance.
        Types: PascalCase. Others: snake_case.
        """
        if not name:
            return name

        # Reserved types in V should be preserved as-is
        if name in ("int", "string", "bool", "f64", "f32", "i64", "byte", "rune", "void", "Any", "none", "i8", "i16", "i32", "u16", "u32", "u64"):
            return name

        # Internal markers are preserved as-is
        if "__py2v_gen" in name:
            return name

        # V compliance: no leading underscores (except single '_')
        # Leading underscores are moved to the end to maintain uniqueness
        prefix_count = 0
        while name.startswith('_') and name != "_":
            prefix_count += 1
            name = name[1:]
        
        if not name:
            return "_" * prefix_count

        if is_type:
            # PascalCase for types
            parts = [p[0].upper() + p[1:] if p else "" for p in name.split('_') if p]
            res = "".join(parts) if parts else (name[0].upper() + name[1:])
            # V structs cannot have underscores.
            res = res.replace("_", "")
            res += "_" * prefix_count
            
            compatibility = getattr(self, 'compatibility', None)
            if compatibility and compatibility.is_v_reserved(res):
                 return f"Py{res}"
            return res

        # Others: snake_case
        sanitized = self._to_snake_case(name)
        sanitized += "_" * prefix_count

        compatibility = getattr(self, 'compatibility', None)
        if compatibility and compatibility.is_v_reserved(sanitized):
            return f"py_{sanitized}"

        # SCC collision
        current_file_name = getattr(self, 'current_file_name', '')
        scc_files: set = getattr(self, 'scc_files', set())
        if current_file_name and len(scc_files) > 1 and not getattr(self, 'current_class', None):
            if not sanitized.startswith("py_") and sanitized not in self._local_vars_in_scope:
                prefix = self._get_scc_prefix(current_file_name)
                prefix = self._to_snake_case(prefix)
                if not sanitized.startswith(prefix + "__"):
                    return f"{prefix}__{sanitized}"

        return sanitized

    @property
    def _local_vars_in_scope(self) -> Set[str]:
        """Returns all local variables in the current function scope."""
        return getattr(self, "_scope_stack", [set()])[-1]

    def _mangle_name(self, name: str, class_name: Optional[str]) -> str:
        """
        Implements Python's name mangling rules for private attributes.
        Returns a name without leading underscores for V compatibility.
        """
        if class_name and name.startswith("__") and not name.endswith("__"):
            # Use original class name for mangling, sanitized for type
            s_class = self._sanitize_name(class_name, is_type=True)
            s_class = s_class.rstrip('_')
            s_name = self._sanitize_name(name)
            return f"{s_class}_{s_name}"
        return name

    def _find_defining_class_for_static_method(
        self,
        class_name: str,
        method_name: str
    ) -> Optional[str]:
        """Finds the class in the hierarchy where the static/class method is defined."""
        visited = set()
        stack = [class_name]
        while stack:
            curr = stack.pop()
            if curr in visited:
                continue
            visited.add(curr)

            # Check defined classes in translator first
            info = getattr(self, "defined_classes", {}).get(curr, {})
            if (
                method_name in info.get("static_methods", set()) or
                method_name in info.get("class_methods", set())
            ):
                return curr

            # Check analyzer if available
            if hasattr(self, "type_inference"):
                if method_name in self.type_inference.static_methods.get(curr, set()) or \
                   method_name in self.type_inference.class_methods.get(curr, set()):
                    return curr

            if curr in getattr(self, "class_hierarchy", {}):
                stack.extend(self.class_hierarchy[curr])
        return None

    def _get_full_self_type(self, struct_name: Optional[str] = None) -> str:
        """
        Returns the full V type for 'Self', including generic parameters.
        """
        name = struct_name or getattr(self, "current_class", None) or "Self"
        generics = getattr(self, "current_class_generics", [])
        if generics:
            gen_str = f"[{', '.join(generics)}]"
            return f"{name}{gen_str}"
        return name
    def _find_defining_class_for_class_var(
        self,
        class_name: str,
        var_name: str
    ) -> Optional[str]:
        """Finds the class in the hierarchy where the class variable is defined."""
        visited = set()
        stack = [class_name]
        while stack:
            curr = stack.pop()
            if curr in visited:
                continue
            visited.add(curr)

            info = getattr(self, "defined_classes", {}).get(curr, {})
            class_vars = info.get("class_vars", [])
            for var in class_vars:
                if var["name"] == var_name:
                    return curr

            if curr in getattr(self, "class_hierarchy", {}):
                stack.extend(self.class_hierarchy[curr])
        return None
