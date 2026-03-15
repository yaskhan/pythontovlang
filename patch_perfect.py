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
                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)

                    if is_mut and arg_name in ("x", "val"):
                        is_mut = False
                        if mut_info.get("is_mutated", False):
                            is_mut = True
                        if is_mut == False:
                            mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                            if len(args_names) - 1 in mut_idx:
                                is_mut = True"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
