import re

with open("py2v_transpiler/core/analyzer.py", "r") as f:
    content = f.read()

# Let's inspect where `is_reassigned` gets set globally in `analyzer.py`.
# It's here:
#            if isinstance(target, ast.Name):
#                if target.id in self.mutability_map:
#                    self.mutability_map[target.id]["is_reassigned"] = True
#                else:
#                    self.mutability_map[target.id] = {"is_reassigned": False, "is_final": False, "is_mutated": False}

search = """            if isinstance(target, ast.Name):
                if target.id in self.mutability_map:
                    self.mutability_map[target.id]["is_reassigned"] = True
                else:
                    self.mutability_map[target.id] = {"is_reassigned": False, "is_final": False, "is_mutated": False}"""

replace = """            if isinstance(target, ast.Name):
                pass
                # self.mutability_map[target.id]["is_reassigned"] = True
                # Wait, doing `pass` here broke tests earlier. Why?
                # Because if the name wasn't already in `mutability_map`, it wouldn't get the `{"is_reassigned": False, ...}` dictionary!
                # Then later lookups might crash or miss it?
                # Let's initialize it but NOT set `is_reassigned: True` globally!

                if target.id not in self.mutability_map:
                    self.mutability_map[target.id] = {"is_reassigned": False, "is_final": False, "is_mutated": False}"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/analyzer.py", "w") as f:
    f.write(content)
