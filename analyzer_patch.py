<<<<<<< SEARCH
        elif isinstance(node, ast.Dict):
            if not node.keys:
                return "map[string]Any"
            key_types = set()
            val_types = set()
            for k, v in zip(node.keys, node.values):
                if k:
                    key_types.add(self._guess_node_type(k))
                if v:
                    val_types.add(self._guess_node_type(v))

            k_type = "string"
            if len(key_types) == 1:
                k_type = list(key_types)[0]
            elif len(key_types) > 1:
                k_type = "Any"

            v_type = "Any"
            if len(val_types) == 1:
                v_type = list(val_types)[0]

            return f"map[{k_type}]{v_type}"
        return "Any"
=======
        elif isinstance(node, ast.Dict):
            if not node.keys:
                return "map[string]Any"
            key_types = set()
            val_types = set()
            for k, v in zip(node.keys, node.values):
                if k:
                    key_types.add(self._guess_node_type(k))
                if v:
                    val_types.add(self._guess_node_type(v))

            k_type = "string"
            if len(key_types) == 1:
                k_type = list(key_types)[0]
            elif len(key_types) > 1:
                k_type = "Any"

            v_type = "Any"
            if len(val_types) == 1:
                v_type = list(val_types)[0]

            return f"map[{k_type}]{v_type}"
        elif isinstance(node, ast.Set):
            if not node.elts:
                return "map[string]bool"
            element_types = set()
            for elt in node.elts:
                element_types.add(self._guess_node_type(elt))
            if len(element_types) == 1:
                return f"map[{list(element_types)[0]}]bool"
            return "map[string]bool"
        return "Any"
>>>>>>> REPLACE
