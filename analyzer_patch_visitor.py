<<<<<<< SEARCH
                if isinstance(node.value, (ast.List, ast.Dict)):
                    inferred = self._infer_collection_type(node.value)
                    if target.id not in self.type_map or self.type_map[target.id] == "Any":
                        self.type_map[target.id] = inferred
=======
                if isinstance(node.value, (ast.List, ast.Dict, ast.Set)):
                    inferred = self._infer_collection_type(node.value)
                    if target.id not in self.type_map or self.type_map[target.id] == "Any":
                        self.type_map[target.id] = inferred
>>>>>>> REPLACE
