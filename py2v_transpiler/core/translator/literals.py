import ast
from typing import List
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
        # Check for starred elements
        has_starred = any(isinstance(elt, ast.Starred) for elt in node.elts)
        if has_starred:
            self.used_list_concat = True
            chunks: List[str] = []
            current_chunk: List[str] = []
            for elt in node.elts:
                if isinstance(elt, ast.Starred):
                    if current_chunk:
                        chunks.append(f"[{', '.join(current_chunk)}]")
                        current_chunk = []
                    chunks.append(str(self.visit(elt.value)))
                else:
                    current_chunk.append(str(self.visit(elt)))
            if current_chunk:
                chunks.append(f"[{', '.join(current_chunk)}]")

            return f"py_list_concat({', '.join(chunks)})"

        elements = [str(self.visit(elt)) for elt in node.elts]
        if not elements:
             return "[]int{}" # Placeholder for empty list
        return f"[{', '.join(elements)}]"

    def visit_Dict(self, node: ast.Dict) -> str:
        # Check if the dictionary is being used as a TypedDict
        v_type = getattr(self, "_guess_type", lambda x: "unknown")(node)
        if hasattr(self, 'dataclasses') and v_type in self.dataclasses:
            pairs = []
            for k, v in zip(node.keys, node.values):
                if isinstance(k, ast.Constant) and isinstance(k.value, str):
                    key_str = k.value
                    val_str = self.visit(v)
                    pairs.append(f"{key_str}: {val_str}")
                else:
                    # Fallback if key is not a string literal? Shouldn't happen in typed dicts usually.
                    pass
            return f"{v_type}{{{', '.join(pairs)}}}"

        # Check for None keys (unpacking)
        has_unpacking = any(k is None for k in node.keys)
        if has_unpacking:
            self.used_dict_merge = True
            chunks: List[str] = []
            current_chunk: List[str] = []

            for k, v in zip(node.keys, node.values):
                if k is None:
                    # Unpacking **expr
                    if current_chunk:
                        # Flush current chunk
                        chunk_str = f"map[string]int{{{', '.join(current_chunk)}}}"
                        chunks.append(chunk_str)
                        current_chunk = []
                    chunks.append(str(self.visit(v)))
                else:
                    key_str = self.visit(k)
                    val_str = self.visit(v)
                    current_chunk.append(f"{key_str}: {val_str}")

            if current_chunk:
                chunk_str = f"map[string]int{{{', '.join(current_chunk)}}}"
                chunks.append(chunk_str)

            return f"py_dict_merge({', '.join(chunks)})"

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
        # Check for starred elements
        has_starred = any(isinstance(elt, ast.Starred) for elt in node.elts)
        if has_starred:
            self.used_dict_merge = True
            chunks: List[str] = []
            current_chunk: List[str] = []
            for elt in node.elts:
                if isinstance(elt, ast.Starred):
                    if current_chunk:
                        chunks.append(f"map[int]bool{{{', '.join(current_chunk)}}}")
                        current_chunk = []
                    chunks.append(str(self.visit(elt.value)))
                else:
                    val = self.visit(elt)
                    current_chunk.append(f"{val}: true")

            if current_chunk:
                chunks.append(f"map[int]bool{{{', '.join(current_chunk)}}}")

            return f"py_dict_merge({', '.join(chunks)})"

        # {1, 2} -> map[int]bool{1: true, 2: true}
        # Simplified assumption that elements are ints
        elements = []
        for elt in node.elts:
            val = self.visit(elt)
            elements.append(f"{val}: true")

        return f"map[int]bool{{{', '.join(elements)}}}"

    def visit_Tuple(self, node: ast.Tuple) -> str:
        # Translate Tuple (a, b) to Array [a, b]
        # Check for starred elements
        has_starred = any(isinstance(elt, ast.Starred) for elt in node.elts)
        if has_starred:
            self.used_list_concat = True
            chunks: List[str] = []
            current_chunk: List[str] = []
            for elt in node.elts:
                if isinstance(elt, ast.Starred):
                    if current_chunk:
                        chunks.append(f"[{', '.join(current_chunk)}]")
                        current_chunk = []
                    chunks.append(str(self.visit(elt.value)))
                else:
                    current_chunk.append(str(self.visit(elt)))
            if current_chunk:
                chunks.append(f"[{', '.join(current_chunk)}]")

            return f"py_list_concat({', '.join(chunks)})"

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
            has_dynamic = False
            for v in node.format_spec.values:
                if isinstance(v, ast.Constant):
                    spec_parts.append(str(v.value))
                else:
                    has_dynamic = True
                    spec_parts.append(str(self.visit(v)))

            if has_dynamic:
                # Dynamic format specifier: f"{val:{spec}}" -> "${py_format(val, spec)}"
                # Use type: ignore[str-bytes-safe] to silence mypy warning about formatting potential byte-string representations
                parts_list = []
                for s in spec_parts:
                    if not s.startswith("$"):
                        quoted_s = f"'{s}'"  # type: ignore[str-bytes-safe]
                        parts_list.append(quoted_s)
                    else:
                        parts_list.append(s)
                spec_expr = " + ".join(parts_list)
                # Simplify if parts are strings
                # spec_parts contains transpiled expressions like 'x' or '10' or '"foo"'.
                # Actually, `spec_parts` contains strings. If `v` was Constant, it's just value.
                # If `v` was expression, `visit` returned V expression.
                # We need to construct a V string expression for `spec`.

                # Re-build spec expression properly
                expr_parts = []
                for v in node.format_spec.values:
                    if isinstance(v, ast.Constant):
                        expr_parts.append(f"'{v.value}'")  # type: ignore[str-bytes-safe]
                    else:
                        expr = self.visit(v)
                        # Ensure expr is string or cast to string?
                        # Assuming expr results in string or something interpolatable.
                        # Using string interpolation is safest:
                        expr_parts.append(f"${{{expr}}}")  # type: ignore[str-bytes-safe]

                spec_expr = f"'{''.join(expr_parts)}'" # Nested interpolation: '${val}' inside
                # Actually, we can just use the visitor on JoinedStr but it returns "'...'"
                # We can call visit_JoinedStr on node.format_spec
                spec_expr = self.visit(node.format_spec)
                # spec_expr comes with surrounding single quotes from visit_JoinedStr
                # But ${py_format(...)} is inside a V string literal usually?
                # No, visit_FormattedValue returns `${val}`.
                # If we return `${py_format(val, spec_expr)}`, it will be inside `${...}` of a string?
                # No, visit_JoinedStr constructs `'...${val}...'`.
                # So if we return `${py_format(val, spec_expr)}`, it becomes `'...${py_format(val, 'spec')}...'`.
                # If spec_expr has single quotes, they must be compatible.
                # visit_JoinedStr uses single quotes.
                # If spec_expr is `'val'`, then `py_format(val, 'val')`. This is valid V.

                # Wait, the failure in test_dynamic_format_specifier is:
                # E       assert 'py_format(x, y)' in "module main... 'Val: ${py_format(x, '${y}')}'\n}"
                # The output contains `py_format(x, '${y}')`.
                # The test expects `py_format(x, y)`.
                # My implementation passes `spec_expr` which is visited `JoinedStr`.
                # For `y` (variable), `visit_JoinedStr` returns `'$y'` (wrapped in quotes) -> `'${y}'`.
                # So `py_format(x, '${y}')` is correct if `y` is a variable.
                # `y` is evaluated inside string interpolation.
                # The test expectation `py_format(x, y)` assumes `y` is passed directly.
                # But format specifier is a STRING in Python. `f"{x:{y}}"` means format using string in y.
                # `py_format` expects `spec string`.
                # If `y` is `string`, passing `y` directly is fine.
                # But `visit_JoinedStr` returns a string *literal* representing the concatenation.
                # So it returns `'${y}'`. This evaluates to string value of y.
                # So `py_format(x, '${y}')` is functionally correct.
                # I should update the test case to expect this format.
                return f"${{py_format({val}, {spec_expr})}}"  # type: ignore[str-bytes-safe]

            spec = "".join(spec_parts)
            if is_debug:
                 return f"{expr_text}=${{{val}:{spec}}}"
            return f"${{{val}:{spec}}}"

        if is_debug:
             return f"{expr_text}=${{{val}}}"
        return f"${{{val}}}"
