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
                 if "'" not in val and getattr(self, 'fstring_quote_stack', [])[-1:] != ["'"]:
                     return f"r'{val}'"
                 if '"' not in val and getattr(self, 'fstring_quote_stack', [])[-1:] != ['"']:
                     return f'r"{val}"'
                 # Fallback
                 return to_standard_str(val)

            # No backslash, standard string but check quotes
            if getattr(self, 'fstring_quote_stack', []):
                outer_quote = self.fstring_quote_stack[-1]
                inner_quote = '"' if outer_quote == "'" else "'"
                if inner_quote not in val:
                    return f"{inner_quote}{val}{inner_quote}"

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
        v_type = self._guess_type(node)
        # Check for starred elements
        has_starred = any(isinstance(elt, ast.Starred) for elt in node.elts)
        if has_starred:
            self.used_list_concat = True
            chunks: List[str] = []
            current_chunk: List[str] = []
            for elt in node.elts:
                if isinstance(elt, ast.Starred):
                    if current_chunk:
                        if v_type == "[]Any":
                            chunks.append(f"[{', '.join([f'Any({e})' for e in current_chunk])}]")
                        else:
                            chunks.append(f"[{', '.join(current_chunk)}]")
                        current_chunk = []
                    chunks.append(str(self.visit(elt.value)))
                else:
                    current_chunk.append(str(self.visit(elt)))
            if current_chunk:
                if v_type == "[]Any":
                    chunks.append(f"[{', '.join([f'Any({e})' for e in current_chunk])}]")
                else:
                    chunks.append(f"[{', '.join(current_chunk)}]")

            return f"py_list_concat({', '.join(chunks)})"

        elements = [str(self.visit(elt)) for elt in node.elts]
        if not elements:
             return f"{v_type}{{}}"

        if v_type == "[]Any":
             return f"[{', '.join([f'Any({e})' for e in elements])}]"

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
                        chunk_str = f"{v_type}{{{', '.join(current_chunk)}}}"
                        chunks.append(chunk_str)
                        current_chunk = []
                    chunks.append(str(self.visit(v)))
                else:
                    key_str = self.visit(k)
                    val_str = self.visit(v)
                    current_chunk.append(f"{key_str}: {val_str}")

            if current_chunk:
                chunk_str = f"{v_type}{{{', '.join(current_chunk)}}}"
                chunks.append(chunk_str)

            return f"py_dict_merge({', '.join(chunks)})"

        if not node.keys:
            # Empty dict
            return f"{v_type}{{}}"

        pairs = []
        is_any_val = v_type.endswith("Any")
        is_any_key = "map[Any]" in v_type

        for k, v in zip(node.keys, node.values):
            if k:
                key_str = self.visit(k)
                if is_any_key:
                    key_str = f"Any({key_str})"
                val_str = self.visit(v)
                if is_any_val:
                    val_str = f"Any({val_str})"
                pairs.append(f"{key_str}: {val_str}")
        return f"{v_type}{{{', '.join(pairs)}}}"

    def visit_Set(self, node: ast.Set) -> str:
        v_type = self._guess_type(node)
        # Check for starred elements
        has_starred = any(isinstance(elt, ast.Starred) for elt in node.elts)
        if has_starred:
            self.used_dict_merge = True
            chunks: List[str] = []
            current_chunk: List[str] = []
            is_any = "map[Any]" in v_type
            for elt in node.elts:
                if isinstance(elt, ast.Starred):
                    if current_chunk:
                        chunk_els = [f"Any({e})" if is_any else e for e in current_chunk]
                        chunks.append(f"{v_type}{{{', '.join([f'{e}: true' for e in chunk_els])}}}")
                        current_chunk = []
                    chunks.append(str(self.visit(elt.value)))
                else:
                    val = self.visit(elt)
                    current_chunk.append(val)

            if current_chunk:
                chunk_els = [f"Any({e})" if is_any else e for e in current_chunk]
                chunks.append(f"{v_type}{{{', '.join([f'{e}: true' for e in chunk_els])}}}")

            return f"py_dict_merge({', '.join(chunks)})"

        elements = []
        is_any = "map[Any]" in v_type
        for elt in node.elts:
            val = self.visit(elt)
            if is_any:
                val = f"Any({val})"
            elements.append(f"{val}: true")

        if not elements:
            return f"{v_type}{{}}"

        return f"{v_type}{{{', '.join(elements)}}}"

    def visit_Tuple(self, node: ast.Tuple) -> str:
        # Translate Tuple (a, b) to Array [a, b]
        v_type = self._guess_type(node)
        # Check for starred elements
        has_starred = any(isinstance(elt, ast.Starred) for elt in node.elts)
        if has_starred:
            self.used_list_concat = True
            chunks: List[str] = []
            current_chunk: List[str] = []
            for elt in node.elts:
                if isinstance(elt, ast.Starred):
                    if current_chunk:
                        if v_type == "[]Any":
                            chunks.append(f"[{', '.join([f'Any({e})' for e in current_chunk])}]")
                        else:
                            chunks.append(f"[{', '.join(current_chunk)}]")
                        current_chunk = []
                    chunks.append(str(self.visit(elt.value)))
                else:
                    current_chunk.append(str(self.visit(elt)))
            if current_chunk:
                if v_type == "[]Any":
                    chunks.append(f"[{', '.join([f'Any({e})' for e in current_chunk])}]")
                else:
                    chunks.append(f"[{', '.join(current_chunk)}]")

            return f"py_list_concat({', '.join(chunks)})"

        elements = [str(self.visit(elt)) for elt in node.elts]
        if not elements:
            return f"{v_type}{{}}"

        if v_type == "[]Any":
             return f"[{', '.join([f'Any({e})' for e in elements])}]"

        return f"[{', '.join(elements)}]"

    def visit_JoinedStr(self, node: ast.JoinedStr) -> str:
        # Determine the delimiter based on nesting level
        # This helps support Python 3.12+ relaxed quoting while staying V-compatible
        current_quote = self.fstring_quote_stack[-1] if self.fstring_quote_stack else None
        next_quote = '"' if current_quote == "'" else "'"
        self.fstring_quote_stack.append(next_quote)

        parts = []
        for value in node.values:
            if isinstance(value, ast.Constant) and isinstance(value.value, str):
                val = value.value
                val = val.replace('\\', '\\\\')
                # Escape the chosen delimiter
                if next_quote == "'":
                    val = val.replace("'", "\\'")
                else:
                    val = val.replace('"', '\\"')
                val = val.replace('\n', '\\n')
                val = val.replace('\r', '\\r')
                val = val.replace('\t', '\\t')
                parts.append(val)
            else:
                parts.append(str(self.visit(value)))

        self.fstring_quote_stack.pop()
        return f"{next_quote}{''.join(parts)}{next_quote}"

    def visit_FormattedValue(self, node: ast.FormattedValue) -> str:
        val = self.visit(node.value)

        # Python conversion: !s (115), !r (114), !a (97)
        if node.conversion == 114:
            self.used_builtins.add("py_repr")
            val = f"py_repr({val})"
        elif node.conversion == 97:
            self.used_builtins.add("py_ascii")
            val = f"py_ascii({val})"
        elif node.conversion == 115:
            # s is default for most things in V interpolation but for safety:
            val = f"({val}).str()"

        # Check for f-string debug expression: f"{x=}"
        is_debug = getattr(node, 'equal', False)

        expr_text = ""
        if is_debug:
             if hasattr(ast, 'unparse'):
                 try:
                     expr_text = ast.unparse(node.value)
                 except:
                     expr_text = val
             else:
                 expr_text = val

        if isinstance(node.format_spec, ast.JoinedStr):
            spec_parts = []
            has_dynamic = False
            for v in node.format_spec.values:
                if isinstance(v, ast.Constant):
                    spec_parts.append(str(v.value))
                else:
                    has_dynamic = True

            if has_dynamic:
                # Dynamic format specifier: f"{val:{spec}}" -> "${py_format(val, spec)}"
                spec_expr = self.visit(node.format_spec)
                self.used_builtins.add("py_format")
                return f"${{py_format({val}, {spec_expr})}}"

            spec = "".join(spec_parts)

            # Check if V supports this spec directly
            # V supports: [flags][width][.precision][type]
            # Supported types: d, i, o, x, X, f, F, e, E, g, G, s, p, c
            # Python supports more: alignment (<, >, ^, =), sign (+, -, space), #, 0, width, grouping (_ ,), .precision, type

            needs_py_format = False
            if '^' in spec or '=' in spec: # Center or pad-after-sign
                needs_py_format = True
            elif ',' in spec or '_' in spec: # Grouping
                needs_py_format = True
            # V doesn't support fill character other than '0' for numbers
            if spec and not spec[0].isdigit() and spec[0] not in '<>+- .':
                 needs_py_format = True

            if needs_py_format:
                self.used_builtins.add("py_format")
                if is_debug:
                     return f"{expr_text}=${{py_format({val}, '{spec}')}}"
                return f"${{py_format({val}, '{spec}')}}"

            if is_debug:
                 return f"{expr_text}=${{{val}:{spec}}}"
            return f"${{{val}:{spec}}}"

        if is_debug:
             return f"{expr_text}=${{{val}}}"
        return f"${{{val}}}"
