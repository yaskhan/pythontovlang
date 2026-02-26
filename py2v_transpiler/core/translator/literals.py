import ast
from .base import TranslatorBase

class LiteralsMixin(TranslatorBase):
    def visit_Constant(self, node: ast.Constant) -> str:
        val = node.value
        if isinstance(val, str):
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
        # Check for unpacking (*elt)
        has_star = any(isinstance(elt, ast.Starred) for elt in node.elts)

        if not has_star:
            elements = [str(self.visit(elt)) for elt in node.elts]
            if not elements:
                 return "[]int{}" # Placeholder for empty list
            return f"[{', '.join(elements)}]"
        else:
            # Unpacking logic: [1, *l, 2] -> py_list_concat([1], l, [2])
            # Divide into chunks of non-starred and starred
            args = []
            chunk = []

            def flush_chunk():
                if chunk:
                    # Emit chunk as array literal
                    elements = [str(c) for c in chunk]
                    args.append(f"[{', '.join(elements)}]")
                    chunk.clear()

            for elt in node.elts:
                if isinstance(elt, ast.Starred):
                    flush_chunk()
                    # Starred value: visit(elt.value)
                    val = self.visit(elt.value)
                    args.append(str(val))
                else:
                    chunk.append(self.visit(elt))

            flush_chunk()

            if not args:
                return "[]int{}"

            # Use helper
            self.used_builtins.add("unpacking") # Marker to emit helper if not present?
            # Actually, we need to register the helper explicitly in VNodeVisitor.
            return f"py_list_concat({', '.join(args)})"

    def visit_Dict(self, node: ast.Dict) -> str:
        # Check for unpacking (None key)
        has_unpacking = any(k is None for k in node.keys)

        if not has_unpacking:
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
        else:
            # Unpacking logic: {**d1, 'a': 1} -> py_dict_merge(d1, {'a': 1})
            # Divide into chunks
            args = []
            chunk_keys = []
            chunk_values = []

            def flush_chunk():
                if chunk_keys:
                    # Emit chunk as map literal
                    pairs = []
                    for k, v in zip(chunk_keys, chunk_values):
                        pairs.append(f"{k}: {v}")
                    args.append(f"map[string]int{{{', '.join(pairs)}}}") # Assuming string keys and int values for now... limitation
                    chunk_keys.clear()
                    chunk_values.clear()

            for k, v in zip(node.keys, node.values):
                if k is None:
                    flush_chunk()
                    # Unpacked dict: visit(v)
                    val = self.visit(v)
                    args.append(str(val))
                else:
                    chunk_keys.append(self.visit(k))
                    chunk_values.append(self.visit(v))

            flush_chunk()

            if not args:
                return "map[string]int{}"

            return f"py_dict_merge({', '.join(args)})"

    def visit_Set(self, node: ast.Set) -> str:
        # Check for unpacking (*elt)
        has_star = any(isinstance(elt, ast.Starred) for elt in node.elts)

        if not has_star:
            # {1, 2} -> map[int]bool{1: true, 2: true}
            elements = []
            for elt in node.elts:
                val = self.visit(elt)
                elements.append(f"{val}: true")

            return f"map[int]bool{{{', '.join(elements)}}}"
        else:
            # Unpacking in sets: {*s1, 3} -> py_set_merge(s1, {3})
            # Similar to list but merging maps?
            # Sets are maps in V.
            # We can use py_dict_merge but the values are always true.
            # Or py_set_merge.

            args = []
            chunk = []

            def flush_chunk():
                if chunk:
                    elements = [f"{c}: true" for c in chunk]
                    args.append(f"map[int]bool{{{', '.join(elements)}}}") # Assuming int
                    chunk.clear()

            for elt in node.elts:
                if isinstance(elt, ast.Starred):
                    flush_chunk()
                    val = self.visit(elt.value)
                    args.append(str(val))
                else:
                    chunk.append(self.visit(elt))

            flush_chunk()

            return f"py_dict_merge({', '.join(args)})" # Reuse dict merge as sets are maps

    def visit_Tuple(self, node: ast.Tuple) -> str:
        # Translate Tuple (a, b) to Array [a, b]
        # Treat same as List for unpacking
        # But visit_List handles [] logic. We can delegate?
        # Just copy logic.

        has_star = any(isinstance(elt, ast.Starred) for elt in node.elts)
        if not has_star:
            elements = [str(self.visit(elt)) for elt in node.elts]
            return f"[{', '.join(elements)}]"
        else:
            args = []
            chunk = []

            def flush_chunk():
                if chunk:
                    elements = [str(c) for c in chunk]
                    args.append(f"[{', '.join(elements)}]")
                    chunk.clear()

            for elt in node.elts:
                if isinstance(elt, ast.Starred):
                    flush_chunk()
                    val = self.visit(elt.value)
                    args.append(str(val))
                else:
                    chunk.append(self.visit(elt))

            flush_chunk()

            if not args:
                return "[]int{}"

            return f"py_list_concat({', '.join(args)})"

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
