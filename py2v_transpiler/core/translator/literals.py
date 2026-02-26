import ast
import re as regex
from .base import TranslatorBase

class LiteralsMixin(TranslatorBase):
    def visit_Constant(self, node: ast.Constant) -> str:
        val = node.value
        if isinstance(val, str):
            # Check if this is a raw string (r"...")
            # In Python AST, raw strings are stored with their backslashes intact
            # We detect them by checking if the raw representation starts with 'r"'
            is_raw = False
            if hasattr(node, 'raw_value'):
                # Python 3.12+ might have this
                is_raw = True
            else:
                # Heuristic: check if string contains backslashes that look like
                # regex patterns or Windows paths
                # Common patterns: \d, \w, \s, \., \/, C:\, \\
                if '\\' in val and self._looks_like_raw_string(val):
                    is_raw = True
            
            if is_raw:
                # V raw strings use r'...' syntax
                # Escape single quotes only
                escaped = val.replace("'", "\\'")
                return f"r'{escaped}'"
            else:
                return f"'{val}'"
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
        elif isinstance(val, complex):
            self.used_complex = True
            return f"py_complex({val.real}, {val.imag})"
        return str(val)

    def _looks_like_raw_string(self, s: str) -> bool:
        """Heuristic to detect if a string should be a raw string in V."""
        # Common regex patterns
        regex_patterns = [r'\d', r'\w', r'\s', r'\S', r'\b', r'\B', 
                         r'\D', r'\W', r'\A', r'\Z', r'\.', r'\*',
                         r'\+', r'\?', r'\[', r'\]', r'\(', r'\)',
                         r'\|', r'\^', r'\$', r'\{', r'\}']
        # Windows path patterns
        path_patterns = [r'[A-Za-z]:\\', r'\\\\']
        
        for pattern in regex_patterns:
            if '\\' + pattern in s:
                return True
        for pattern in path_patterns:
            if regex.search(pattern, s):
                return True
        return False

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
        # Handle f-string debug expressions: f"{x=}"
        # In Python 3.8+, the conversion field can be 'r', 's', or 'a'
        # For debug expressions, we need to check if the value is a Name
        # and if there's an '=' in the original source
        # The AST doesn't directly tell us about debug expressions,
        # but we can detect them by checking the conversion field
        
        val = self.visit(node.value)
        
        # Check for debug expression (conversion == ord('=') which is 61)
        # Python uses CONVERSION_FMT constant for this
        if node.conversion == ord('='):
            # f"{x=}" -> 'x=<value>'
            # Get the expression as a string
            if hasattr(ast, 'unparse'):
                expr_str = ast.unparse(node.value)
            else:
                expr_str = val
            return f"'{expr_str}=${{{val}}}'"
        
        if isinstance(node.format_spec, ast.JoinedStr):
            spec_parts = []
            for v in node.format_spec.values:
                if isinstance(v, ast.Constant):
                    spec_parts.append(str(v.value))
                else:
                    # Best effort for dynamic format specs
                    spec_parts.append(str(self.visit(v)))
            spec = "".join(spec_parts)
            return f"${{{val}:{spec}}}"
        return f"${{{val}}}"
