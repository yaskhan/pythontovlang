from typing import Optional, TYPE_CHECKING, Any, Set, Dict, List

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
        """Converts CamelCase or UPPER_CASE to snake_case and strips leading underscores."""
        if not name:
            return name

        if name == "_":
            return "_"

        # Strip leading underscores for V compliance
        # (V does not allow identifiers starting with underscore except for single '_')
        name = name.lstrip('_')
        if not name:
            return "_"

        # Handle already separated names
        if '_' in name:
            parts = [self._to_snake_case(p) for p in name.split('_') if p]
            return "_".join(parts) if parts else "_"

        if name.isupper():
            return name.lower()

        res = []
        for i, char in enumerate(name):
            if char.isupper() and i > 0:
                # Underscore if previous was lowercase
                if name[i - 1].islower():
                    res.append('_')
                # Or if next is lowercase (handling HTTPClient -> http_client)
                elif i + 1 < len(name) and name[i + 1].islower():
                    res.append('_')
            res.append(char.lower())
        return "".join(res)

    def _get_factory_name(self, struct_name: str) -> str:
        """Returns a snake_case factory name for a given struct name."""
        # Strip generic parameters if present (e.g. Box[int] -> Box)
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
        Sanitizes Python identifiers that collide with V lang reserved keywords
        or other files in the same SCC cluster. Enforces V naming conventions.
        """
        if not name:
            return name

        if is_type:
            # V types (structs) must be PascalCase and no leading underscore
            name = name.lstrip('_')
            if not name:
                 return "UnderscoreType" # Fallback

            # Convert snake_case or already PascalCase to proper PascalCase
            parts = [p[0].upper() + p[1:] if len(p) > 1 else p.upper() for p in name.split('_') if p]
            if not parts:
                name = name[0].upper() + name[1:] if name else ""
            else:
                name = "".join(parts)

            # Handle reserved type names
            if name == "Any":
                return "Any"

            compatibility = getattr(self, 'compatibility', None)
            if compatibility and compatibility.is_v_reserved(name):
                 return f"Py{name}"

            return name

        # For variables, functions, methods: use snake_case and no leading underscore
        if name != "_":
            name = self._to_snake_case(name)

        compatibility = getattr(self, 'compatibility', None)
        if compatibility and compatibility.is_v_reserved(name):
            return f"py_{name}"

        # Naming collision resolution for SCC flattened modules
        current_file_name = getattr(self, 'current_file_name', '')
        scc_files: set = getattr(self, 'scc_files', set())
        if current_file_name and len(scc_files) > 1 and not getattr(self, 'current_class', None):
            if not name.startswith("__") and name not in self._local_vars_in_scope:
                prefix = self._get_scc_prefix(current_file_name)
                # Note: prefix should also be snake_case without leading underscore
                prefix = self._to_snake_case(prefix)
                if not name.startswith(prefix + "__"):
                    return f"{prefix}__{name}"

        return name

    @property
    def _local_vars_in_scope(self) -> Set[str]:
        """Returns all local variables in the current function scope."""
        # This is typically provided by TranslatorStateMixin but accessed here
        return getattr(self, "_scope_stack", [set()])[-1]

    def _mangle_name(self, name: str, class_name: Optional[str]) -> str:
        """
        Implements Python's name mangling rules for private attributes.
        Returns a snake_case name without leading underscores for V compatibility.
        Instead of __ClassName_attr, we use ClassName_attr or class_name_attr.
        """
        if class_name and name.startswith("__") and not name.endswith("__"):
            # Use a V-safe format: {sanitized_class}_{sanitized_name}
            # Both will be snake_case
            s_class = self._to_snake_case(class_name)
            s_name = self._to_snake_case(name)
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
                if method_name in self.type_inference.static_methods.get(curr, set()):
                    return curr
                if method_name in self.type_inference.class_methods.get(curr, set()):
                    return curr

            if curr in self.class_hierarchy:
                stack.extend(self.class_hierarchy[curr])
        return None

    def _get_full_self_type(self, struct_name: Optional[str] = None) -> str:
        """
        Returns the full V type for 'Self', including generic parameters.
        Example: Builder -> Builder[T]
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

            if curr in self.class_hierarchy:
                stack.extend(self.class_hierarchy[curr])
        return None
