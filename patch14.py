with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# Ah! Interprocedural is FAILING now. Let's trace back my FIRST patch!
# My very first patch was replacing:
#                 mut_info = self.type_inference.mutability_map.get(arg_name)
#                 if not mut_info:
#                     mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")
# WITH:
#                 mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")
#                 if not mut_info:
#                     mut_info = self.type_inference.mutability_map.get(arg_name)
#
# THAT was the patch that broke interprocedural! Because `mut_info_exact` (from node.name.arg_name) doesn't have `is_mutated` in mypy interprocedural tracking! Mypy only tracks `arg_name`.
# So when it finds `mut_info_exact`, it stops looking, and `is_mutated` is False!
# I need to restore the ORIGINAL lookup order, OR combine them!

search = """                mut_info = self.type_inference.mutability_map.get(arg_name)
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                if mut_info:
                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)

                    # Fix global leak false positives on short variable names like 'x' and 'val'
                    if arg_name in ("x", "val", "v", "i", "j", "k", "n", "m", "result", "res", "y", "a", "b", "c") and not mut_info.get("is_mutated", False):
                        mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                        if (len(args_names) - 1) not in mut_idx:
                            is_mut = False"""

replace = """                mut_info = self.type_inference.mutability_map.get(arg_name)
                mut_info_exact = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                is_reassigned = False
                is_mutated = False

                if mut_info:
                     is_reassigned = is_reassigned or mut_info.get("is_reassigned", False)
                     is_mutated = is_mutated or mut_info.get("is_mutated", False)
                if mut_info_exact:
                     is_reassigned = is_reassigned or mut_info_exact.get("is_reassigned", False)
                     is_mutated = is_mutated or mut_info_exact.get("is_mutated", False)

                is_mut = is_reassigned or is_mutated

                # Global leak protection for `is_reassigned`
                if is_mut and not is_mutated:
                     # Check if it was TRULY reassigned locally in this function
                     mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                     if (len(args_names) - 1) not in mut_idx:
                         is_mut = False"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
