# Fix analyzer instead! The root cause is `TypeInference.visit_Assign` blindly assigning `is_reassigned` to global variable name
# without checking if it's an existing variable or not, leaking mutability to OTHER functions' parameters.
# Mypy plugin correctly separates them by line/column, but `analyzer.py` drops the scope!
with open("py2v_transpiler/core/analyzer.py", "r") as f:
    content = f.read()

search = """            if isinstance(target, ast.Name):
                if target.id in self.mutability_map:
                    self.mutability_map[target.id]["is_reassigned"] = True
                else:
                    self.mutability_map[target.id] = {"is_reassigned": False, "is_final": False, "is_mutated": False}"""

replace = """            if isinstance(target, ast.Name):
                pass # DON'T DO THIS. IT LEAKS LOCALS GLOBALLY AND BREAKS PARAMS!
                # is_reassigned for local assignments is handled by `func_param_mutability` and `mypy_plugin.py` anyway.
                # If we must do it, only do it if the variable is already marked as mutated by Mypy (meaning it's a known global).
                # Actually, `func_param_mutability` catches local parameters being reassigned!
                # So we can safely remove this global leak!"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/analyzer.py", "w") as f:
    f.write(content)
