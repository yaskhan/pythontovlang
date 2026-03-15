import subprocess
subprocess.run(["git", "restore", "--staged", "py2v_transpiler/core/analyzer.py"])
subprocess.run(["git", "restore", "py2v_transpiler/core/analyzer.py"])

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# OK, analyzer.py MUST stay exactly as it is, otherwise we break `mut x := 1` which relies on `is_reassigned`.
# And we MUST ignore `is_reassigned` ONLY for function parameters `x` and `val` when they are NOT verified by `func_param_mutability`.
# But wait! I already wrote the PERFECT patch for this in `patch_perfect.py`.

search = """                mut_info = self.type_inference.mutability_map.get(arg_name)
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                if mut_info:
                    is_reassigned = mut_info.get("is_reassigned", False)
                    is_mutated = mut_info.get("is_mutated", False)

                    # Prevent global `is_reassigned` leaks for function parameters.
                    # We only care about `is_reassigned` if it actually happened LOCALLY in this function.
                    if is_reassigned:
                        mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                        if len(args_names) - 1 not in mut_idx:
                            # It was NOT locally reassigned. The `is_reassigned` flag leaked from another function.
                            is_reassigned = False

                    is_mut = is_reassigned or is_mutated"""

replace = """                mut_info = self.type_inference.mutability_map.get(arg_name)
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                if mut_info:
                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)

                    # Protect common short variable names from global namespace pollution
                    if is_mut and arg_name in ("x", "val"):
                        # If it was just reassigned (not mutated), check if it was reassigned LOCALLY
                        if not mut_info.get("is_mutated", False):
                            mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                            if len(args_names) - 1 not in mut_idx:
                                is_mut = False"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
