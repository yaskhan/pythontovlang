import ast
from .base import TranslatorBase

class LiteralsMixin(TranslatorBase):
    def visit_Constant(self, node: ast.Constant) -> str:
        val = node.value
        if isinstance(val, str):
            # Check for backslashes to decide if raw string is beneficial
            # Python AST usually resolves escape sequences in string literals.
            # e.g. "a\nb" -> 'a\nb' (length 3, \n is one char)
            # r"a\nb" -> 'a\\nb' (length 4, \ and n)
            # If we see actual backslashes in the string value, it means they were escaped or raw.
            # If we output as V string, we need to escape them again if we want to preserve them.
            # Or we can use V raw string r'...' if possible.
            # V raw strings don't support escaping ' inside (r'\' is end of string?).
            # V raw string: r'hello\nworld' -> prints hello\nworld.
            # If val contains `\` (backslash char), we can use r'' to make it cleaner.
            # V raw strings r'...' or r"..." do not support escaping of the delimiter.
            # If string contains both ' and ", raw string might not be possible if it contains \.
            # But standard string with manual escaping is always safe.
            # Logic:
            # 1. If no backslash, standard string is fine (escapes handled by visit/literal).
            #    Wait, standard string generation `f"'{val}'"` might fail if val contains '.
            #    We should handle escaping of ' in standard strings too.
            # 2. If backslash exists, try raw string.
            #    If no ', use r'...'.
            #    If no ", use r"...".
            #    If both, fallback to standard string with heavy escaping.

            # Helper for standard string
            def to_standard_str(s):
                # Escape \ and '
                s = s.replace('\\', '\\\\').replace("'", "\\'")
                return f"'{s}'"

            if '\\' in val:
                 if "'" not in val:
                     return f"r'{val}'"
                 if '"' not in val:
                     return f'r"{val}"'
                 # Fallback
                 return to_standard_str(val)

            # No backslash, standard string but check quotes
            return to_standard_str(val)
        elif val is Ellipsis:
             return "/* ... */"
        elif isinstance(val, bool):
            return str(val).lower()
        elif isinstance(val, bytes):
            # Transpile bytes to V byte array [u8(0x..), ...]
            if not val:
                return "[]u8{}"
            elements = [f"u8(0x{b:02x})" for b in val]
            return f"[{', '.join(elements)}]"
        elif val is None:
            return "none"
        elif isinstance(val, bytes):
            elements = [f"u8(0x{b:02x})" for b in val]
            if not elements:
                return "[]u8{}"
            return f"[{', '.join(elements)}]"
        elif isinstance(val, complex):
            self.used_complex = True
            return f"py_complex({val.real}, {val.imag})"
        return str(val)

    def visit_List(self, node: ast.List) -> str:
        elements = [str(self.visit(elt)) for elt in node.elts]
        if not elements:
             return "[]int{}" # Placeholder for empty list
        return f"[{', '.join(elements)}]"

    def visit_Dict(self, node: ast.Dict) -> str:
        if not node.keys:
            # Empty dict
            return "map[string]int{}" # Default fallback

        pairs = []
        for k, v in zip(node.keys, node.values):
            if k:
                key_str = self.visit(k)
                val_str = self.visit(v)
                pairs.append(f"{key_str}: {val_str}")
        return f"map[string]int{{{', '.join(pairs)}}}"

    def visit_Set(self, node: ast.Set) -> str:
        # {1, 2} -> map[int]bool{1: true, 2: true}
        # Simplified assumption that elements are ints
        elements = []
        for elt in node.elts:
            val = self.visit(elt)
            elements.append(f"{val}: true")

        return f"map[int]bool{{{', '.join(elements)}}}"

    def visit_Tuple(self, node: ast.Tuple) -> str:
        # Translate Tuple (a, b) to Array [a, b]
        elements = [str(self.visit(elt)) for elt in node.elts]
        return f"[{', '.join(elements)}]"

    def visit_JoinedStr(self, node: ast.JoinedStr) -> str:
        parts = []
        for value in node.values:
            if isinstance(value, ast.Constant) and isinstance(value.value, str):
                val = value.value
                val = val.replace('\\', '\\\\')
                val = val.replace("'", "\\'")
                val = val.replace('\n', '\\n')
                val = val.replace('\r', '\\r')
                val = val.replace('\t', '\\t')
                parts.append(val)
            else:
                parts.append(str(self.visit(value)))

        return f"'{''.join(parts)}'"

    def visit_FormattedValue(self, node: ast.FormattedValue) -> str:
        val = self.visit(node.value)

        # Check for f-string debug expression: f"{x=}"
        # Python 3.8+ sets conversion=-1 (default), 115 ('s'), 114 ('r'), 97 ('a')
        # node.equal is available in 3.8+ if it was a debug expression
        is_debug = getattr(node, 'equal', False)

        if is_debug:
             # We need the source text of the expression
             expr_text = val
             # Try to unparse if ast.unparse is available (Py3.9+)
             if hasattr(ast, 'unparse'):
                 try:
                     expr_text = ast.unparse(node.value)
                 except:
                     pass

             # If format spec exists, append it? Python f"{x=:d}" -> "x=10"
             # V doesn't support "x=" syntax automatically.
             # We emit "x=${x}"
             pass # fall through to construction

        if isinstance(node.format_spec, ast.JoinedStr):
            spec_parts = []
            for v in node.format_spec.values:
                if isinstance(v, ast.Constant):
                    spec_parts.append(str(v.value))
                else:
                    # Best effort for dynamic format specs
                    spec_parts.append(str(self.visit(v)))
            spec = "".join(spec_parts)
            if is_debug:
                 return f"{expr_text}=${{{val}:{spec}}}"
            return f"${{{val}:{spec}}}"

        if is_debug:
             return f"{expr_text}=${{{val}}}"
        return f"${{{val}}}"
