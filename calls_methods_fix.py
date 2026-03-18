<<<<<<< SEARCH
        # list.pop() / dict.pop()
        elif attr == "pop":
            obj_type = self._guess_type(func_node.value)
            if obj_type.startswith("map[") and obj_type.endswith("]bool"):
                return self._handle_set_methods(node, func_node, args)

            obj_type = self._guess_type(func_node.value)
            obj = self.visit(func_node.value)
            if obj_type.startswith("[]"):
=======
        # list.pop() / dict.pop()
        elif attr == "pop":
            obj_type = self._guess_type(func_node.value)
            if obj_type.startswith("map[") and obj_type.endswith("]bool"):
                return self._handle_set_methods(node, func_node, args)

            obj = self.visit(func_node.value)
            if obj_type.startswith("[]"):
>>>>>>> REPLACE
<<<<<<< SEARCH
        # list.remove()
        elif attr == "remove" and len(args) == 1:
            obj_type = self._guess_type(func_node.value)
            if obj_type.startswith("map[") and obj_type.endswith("]bool"):
                return self._handle_set_methods(node, func_node, args)

            obj_type = self._guess_type(func_node.value)
            if obj_type.startswith("[]") or obj_type == "Any":
=======
        # list.remove()
        elif attr == "remove" and len(args) == 1:
            obj_type = self._guess_type(func_node.value)
            if obj_type.startswith("map[") and obj_type.endswith("]bool"):
                return self._handle_set_methods(node, func_node, args)

            if obj_type.startswith("[]") or obj_type == "Any":
>>>>>>> REPLACE
<<<<<<< SEARCH
        elif attr == "remove" and len(args) == 1:
            obj_type = self._guess_type(func_node.value)
            if obj_type.startswith("map[") and obj_type.endswith("]bool"):
                return self._handle_set_methods(node, func_node, args)

            self.used_builtins.add("py_set_remove")
            return f"py_set_remove(mut {obj}, {args[0]})"
=======
        elif attr == "remove" and len(args) == 1:
            self.used_builtins.add("py_set_remove")
            return f"py_set_remove(mut {obj}, {args[0]})"
>>>>>>> REPLACE
