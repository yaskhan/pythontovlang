with open("py2v_transpiler/core/analyzer.py", "r") as f:
    content = f.read()

search = """            if isinstance(target, ast.Name):
                if target.id in self.mutability_map:
                    self.mutability_map[target.id]["is_reassigned"] = True
                else:
                    self.mutability_map[target.id] = {"is_reassigned": False, "is_final": False, "is_mutated": False}"""

replace = """            if isinstance(target, ast.Name):
                if target.id in self.mutability_map:
                    # self.mutability_map[target.id]["is_reassigned"] = True
                    pass
                else:
                    self.mutability_map[target.id] = {"is_reassigned": False, "is_final": False, "is_mutated": False}"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/analyzer.py", "w") as f:
    f.write(content)
