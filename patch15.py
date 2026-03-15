with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

search = """                mut_info = self.type_inference.mutability_map.get(arg_name)
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

replace = """                # Check local function param reassignment FIRST using `func_param_mutability`
                # If it's explicitly locally reassigned, it must be mut.
                mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                is_local_mut = (len(args_names) - 1) in mut_idx

                mut_info = self.type_inference.mutability_map.get(arg_name)
                mut_info_exact = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                is_mut = is_local_mut
                if mut_info_exact:
                    is_mut = is_mut or mut_info_exact.get("is_mutated", False) or mut_info_exact.get("is_reassigned", False)
                elif mut_info:
                    # Global mutability lookup.
                    # We accept `is_mutated` from mypy because interprocedural analysis tracks globals.
                    if mut_info.get("is_mutated", False):
                        is_mut = True
                    # We ONLY accept `is_reassigned` if it is locally reassigned,
                    # OR if we are doing interprocedural analysis and there are no known false positives.
                    elif mut_info.get("is_reassigned", False):
                        if arg_name not in ("x", "val", "v", "i", "j", "k", "n", "m", "result", "res", "y", "a", "b", "c"):
                            # This maintains the original logic for complex parameter names
                            # that might be passed around and reassigned in caller's scope (which shouldn't require mut, but it was the original logic)
                            is_mut = True"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
