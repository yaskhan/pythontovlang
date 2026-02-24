class VCodeEmitter:
    def emit_module(self, module_str: str) -> str:
        """Emits the final V code for a module."""
        return module_str

    def format_indent(self, level: int) -> str:
        """Returns the indentation string for the given level."""
        return "    " * level

    def map_builtin(self, py_name: str) -> str:
        """Maps a Python builtin name to its V equivalent."""
        # This will be used in conjunction with stdlib_map
        return py_name
