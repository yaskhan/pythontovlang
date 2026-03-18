<<<<<<< SEARCH
        # dict.get() / update() / setdefault()
        elif attr == "update":
            obj_type = self._guess_type(func_node.value)
            # Heuristic to avoid collision with hashlib
            if obj_type in ("PyHashSha256", "PyHashMd5"):
                 return None

            # Additional heuristic: hashlib objects usually start with 'h'
            if obj_type == "Any" and isinstance(func_node.value, ast.Name) and func_node.value.id.startswith("h"):
                 return None

            return self._handle_dict_update(node, func_node, args)

        elif attr == "setdefault":
            return self._handle_dict_setdefault(node, func_node, args)

        elif attr == "get":
            return self._handle_dict_get(node, func_node, args)

        return None
=======
        # dict.get() / update() / setdefault()
        elif attr == "update":
            obj_type = self._guess_type(func_node.value)
            # Heuristic to avoid collision with hashlib
            if obj_type in ("PyHashSha256", "PyHashMd5"):
                 return None

            # Additional heuristic: hashlib objects usually start with 'h'
            if obj_type == "Any" and isinstance(func_node.value, ast.Name) and func_node.value.id.startswith("h"):
                 return None

            if obj_type.startswith("map[") and obj_type.endswith("]bool"):
                return self._handle_set_methods(node, func_node, args)

            return self._handle_dict_update(node, func_node, args)

        elif attr == "setdefault":
            return self._handle_dict_setdefault(node, func_node, args)

        elif attr == "get":
            return self._handle_dict_get(node, func_node, args)

        # Set methods
        elif attr in ("add", "discard", "union", "intersection", "difference", "symmetric_difference",
                    "intersection_update", "difference_update", "symmetric_difference_update",
                    "issubset", "issuperset", "isdisjoint"):
            return self._handle_set_methods(node, func_node, args)

        return None

    def _handle_set_methods(self, node: ast.Call, func_node: ast.Attribute, args: list) -> str | None:
        """Handle set methods."""
        attr = func_node.attr
        obj_type = self._guess_type(func_node.value)
        if not (obj_type.startswith("map[") and obj_type.endswith("]bool")) and obj_type != "Any":
             return None

        obj = self.visit(func_node.value)

        if attr == "add" and len(args) == 1:
            return f"{obj}[{args[0]}] = true"
        elif attr == "discard" and len(args) == 1:
            return f"{obj}.delete({args[0]})"
        elif attr == "remove" and len(args) == 1:
            self.used_builtins.add("py_set_remove")
            return f"py_set_remove(mut {obj}, {args[0]})"
        elif attr == "pop" and len(args) == 0:
            self.used_builtins.add("py_set_pop")
            return f"py_set_pop(mut {obj})"
        elif attr == "union" and len(args) >= 1:
            self.used_builtins.add("py_set_union")
            res = obj
            for arg in args:
                res = f"py_set_union({res}, {arg})"
            return res
        elif attr == "intersection" and len(args) >= 1:
            self.used_builtins.add("py_set_intersection")
            res = obj
            for arg in args:
                res = f"py_set_intersection({res}, {arg})"
            return res
        elif attr == "difference" and len(args) >= 1:
            self.used_builtins.add("py_set_difference")
            res = obj
            for arg in args:
                res = f"py_set_difference({res}, {arg})"
            return res
        elif attr == "symmetric_difference" and len(args) == 1:
            self.used_builtins.add("py_set_xor")
            return f"py_set_xor({obj}, {args[0]})"
        elif attr == "update" and len(args) >= 1:
            self.used_builtins.add("py_set_update")
            res = ""
            for i, arg in enumerate(args):
                call = f"py_set_update(mut {obj}, {arg})"
                if i == 0: res = call
                else: res = f"({res}, {call})" # Nested calls for multiple args
            return res
        elif attr == "intersection_update" and len(args) >= 1:
            self.used_builtins.add("py_set_intersection_update")
            res = ""
            for i, arg in enumerate(args):
                call = f"py_set_intersection_update(mut {obj}, {arg})"
                if i == 0: res = call
                else: res = f"({res}, {call})"
            return res
        elif attr == "difference_update" and len(args) >= 1:
            self.used_builtins.add("py_set_difference_update")
            res = ""
            for i, arg in enumerate(args):
                call = f"py_set_difference_update(mut {obj}, {arg})"
                if i == 0: res = call
                else: res = f"({res}, {call})"
            return res
        elif attr == "symmetric_difference_update" and len(args) == 1:
            self.used_builtins.add("py_set_xor_update")
            return f"py_set_xor_update(mut {obj}, {args[0]})"
        elif attr == "issubset" and len(args) == 1:
            self.used_builtins.add("py_set_subset")
            return f"py_set_subset({obj}, {args[0]})"
        elif attr == "issuperset" and len(args) == 1:
            self.used_builtins.add("py_set_subset")
            return f"py_set_subset({args[0]}, {obj})"
        elif attr == "isdisjoint" and len(args) == 1:
            self.used_builtins.add("py_set_isdisjoint")
            return f"py_set_isdisjoint({obj}, {args[0]})"

        return None
>>>>>>> REPLACE
