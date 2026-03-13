import ast
from typing import List
from .base import TranslatorBase

class LiteralsMixin(TranslatorBase):
    def visit_Constant(self, node: ast.Constant) -> str:
        val = node.value

        # Check if we are assigning to a LiteralEnum
        target_type = self.current_assignment_type
        if target_type and target_type in self._literal_enum_values:
            val_map = self._literal_enum_values[target_type]
            if val in val_map:
                return f".{val_map[val]}"

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
            assignment_type = getattr(self, "current_assignment_type", None)
            if assignment_type == "Any":
                return "Any(NoneType{})"
            elif assignment_type and isinstance(assignment_type, str) and assignment_type.startswith("map[") and assignment_type.endswith("]Any"):
                return "Any(NoneType{})"
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
             v_type = self.current_assignment_type or "[]Any"
             if v_type.startswith("?[]"):
                 v_type = v_type[1:]
             elif not v_type.startswith("[]"):
                 v_type = "[]Any"
             return f"{v_type}{{}}"

        if "none" in elements:
             v_type = self.current_assignment_type or "[]?Any"
             base_type = "?Any"
             if v_type.startswith("[]?"):
                 base_type = v_type[2:]
             elif v_type.startswith("?[]?"):
                 base_type = v_type[3:]
             elif v_type.startswith("[]") and not v_type.startswith("[]?"):
                 base_type = f"?{v_type[2:]}"

             mapped_elements: List[str] = []
             for element in elements:
                 if element != "none":
                     mapped_elements.append(f"{base_type}({element})")
                 else:
                     mapped_elements.append(element)
             return f"[{', '.join(mapped_elements)}]"

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
                        chunk_str = f"{{{', '.join(current_chunk)}}}"
                        chunks.append(chunk_str)
                        current_chunk = []
                    chunks.append(str(self.visit(v)))
                else:
                    key_str = self.visit(k)
                    val_str = self.visit(v)
                    current_chunk.append(f"{key_str}: {val_str}")

            if current_chunk:
                chunk_str = f"{{{', '.join(current_chunk)}}}"
                chunks.append(chunk_str)

            return f"py_dict_merge({', '.join(chunks)})"

        if not node.keys:
            # Empty dict
            v_type = self.current_assignment_type or "map[string]Any"
            if not v_type.startswith("map["):
                # If current_assignment_type is e.g. a struct or union,
                # we should fallback to map[string]Any only if it's truly a dict literal.
                v_type = "map[string]Any"
            return f"{v_type}{{}}"

        pairs = []
        for k, v in zip(node.keys, node.values):
            if k:
                key_str = self.visit(k)
                val_str = self.visit(v)
                if "Any" in v_type and not v_type.startswith("SumType"):
                     val_str = f"({val_str} as Any)"
                pairs.append(f"{key_str}: {val_str}")

        # In modern V, map literals with elements should NOT have the type prefix
        # unless it is ambiguous, but usually {key: val} is enough if context type is known.
        # However, map[string]Any requires explicit casts for values.
        return f"{{{', '.join(pairs)}}}"

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
                        chunks.append(f"{{{', '.join(current_chunk)}}}")
                        current_chunk = []
                    chunks.append(str(self.visit(elt.value)))
                else:
                    val = self.visit(elt)
                    current_chunk.append(f"{val}: true")

            if current_chunk:
                chunks.append(f"{{{', '.join(current_chunk)}}}")

            return f"py_dict_merge({', '.join(chunks)})"

        # {1, 2} -> {1: true, 2: true}
        elements = []
        for elt in node.elts:
            val = self.visit(elt)
            elements.append(f"{val}: true")

        v_type = self._guess_type(node)
        if "Any" in v_type and not v_type.startswith("SumType"):
            return f"{v_type}{{{', '.join(elements)}}}"

        return f"{{{', '.join(elements)}}}"

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

        # Use fixed-size array literal if type is known to be fixed-size array
        v_type = self.current_assignment_type or ""
        if v_type.startswith("[") and "]" in v_type and not v_type.startswith("[]"):
             return f"{v_type}{{{', '.join(elements)}}}"

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
