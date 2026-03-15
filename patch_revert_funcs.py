import subprocess
subprocess.run(["git", "checkout", "py2v_transpiler/core/translator/functions.py"])

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

search = """            args_names.append(arg_name)

            is_mut = False
            if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                # Heuristic: check for both arg_name and func_name.arg_name
                mut_info = self.type_inference.mutability_map.get(arg_name)
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                if mut_info:
                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)"""

replace = """            args_names.append(arg_name)

            is_mut = False
            if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                # Heuristic: check for both arg_name and func_name.arg_name
                mut_info = self.type_inference.mutability_map.get(arg_name)
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                if mut_info:
                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)

                if arg_name in ("x", "val"):
                    if mut_info and mut_info.get("is_mutated", False):
                        pass
                    else:
                        mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                        if (len(args_names) - 1) not in mut_idx:
                            is_mut = False"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
