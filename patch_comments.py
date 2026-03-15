with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# Let me clean up my comments in the file before I commit.
search = """                    # Protect common short variable names from global namespace pollution
                    if is_mut and arg_name in ("x", "val"):
                        # If it was just reassigned (not mutated), check if it was reassigned LOCALLY
                        if not mut_info.get("is_mutated", False):
                            mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                            if len(args_names) - 1 not in mut_idx:
                                is_mut = False"""

replace = """                    # Protect parameters from global `is_reassigned` leaks caused by unrelated functions
                    # sharing the same variable name. We only trust `is_reassigned` if the parameter is
                    # explicitly verified as locally reassigned by the `func_param_mutability` analyzer.
                    if is_mut and not mut_info.get("is_mutated", False):
                        mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                        if len(args_names) - 1 not in mut_idx:
                            is_mut = False"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
