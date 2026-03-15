with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

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
