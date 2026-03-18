<<<<<<< SEARCH
            return f"{left} {op_str} {right}"

        parts = []
=======
            if isinstance(op, (ast.Lt, ast.LtE, ast.Gt, ast.GtE)):
                right_type = self._guess_type(node.comparators[0])
                if (left_type.startswith("map[") and left_type.endswith("]bool")) and                    (right_type.startswith("map[") and right_type.endswith("]bool")):
                    if isinstance(op, ast.Lt):
                        self.used_builtins.add("py_set_strict_subset")
                        return f"py_set_strict_subset({left}, {right})"
                    elif isinstance(op, ast.LtE):
                        self.used_builtins.add("py_set_subset")
                        return f"py_set_subset({left}, {right})"
                    elif isinstance(op, ast.Gt):
                        self.used_builtins.add("py_set_strict_subset")
                        return f"py_set_strict_subset({right}, {left})"
                    elif isinstance(op, ast.GtE):
                        self.used_builtins.add("py_set_subset")
                        return f"py_set_subset({right}, {left})"

            return f"{left} {op_str} {right}"

        parts = []
>>>>>>> REPLACE
