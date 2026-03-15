import subprocess
subprocess.run(["git", "restore", "py2v_transpiler/core/analyzer.py"])

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# Wait... the ONLY reason I ever had to touch `analyzer.py` was because `TypeInference.visit_Assign` was setting `is_reassigned` globally.
# But `is_reassigned` globally is REQUIRED for local variables to become `mut x := 1`!
# Let me look at `py2v_transpiler/core/translator/variables_split/assignments.py`
#             if target.id in self.type_inference.mutability_map:
#                 mut_info = self.type_inference.mutability_map[target.id]
#                 is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)
#                 if is_mut:
#                      mut_prefix = "mut "

# So `is_reassigned` IS required to be true globally for normal variables!
# The problem is ONLY that `is_reassigned` leaking globally causes FALSE POSITIVES FOR FUNCTION PARAMETERS.
# That's it! Function parameters are special. Their mutability is explicitly tracked by `FunctionMutabilityScanner` (which sets `func_param_mutability`), AND `TypeInference.mutability_map[arg_name]` leaks.

# So ALL I need to do is tell `functions.py` to ignore `mut_info.get("is_reassigned")` from the global `mutability_map` ONLY for parameters, UNLESS it's explicitly tracked in `func_param_mutability`!
# Because if it's explicitly locally reassigned in this function, `func_param_mutability` will know it!
# Wait! What if it's NOT locally reassigned, but it's mutated (`is_mutated`) globally? We STILL need to pass it as `mut d map`!
# So we just ignore `is_reassigned` if it's not local!

search = """                mut_info = self.type_inference.mutability_map.get(arg_name)
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                if mut_info:
                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)"""

replace = """                mut_info = self.type_inference.mutability_map.get(arg_name)
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

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
