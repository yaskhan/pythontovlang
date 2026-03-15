import subprocess
subprocess.run(["git", "checkout", "py2v_transpiler/core/analyzer.py"])
subprocess.run(["git", "checkout", "py2v_transpiler/core/translator/functions.py"])

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# Let's fix JUST the scoped mutability, but keep the fallback as long as it isn't `is_reassigned`.

search = """                mut_info = self.type_inference.mutability_map.get(arg_name)
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                if mut_info:
                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)"""

replace = """                mut_info_exact = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")
                mut_info_global = self.type_inference.mutability_map.get(arg_name)

                is_mut = False
                if mut_info_exact:
                    is_mut = mut_info_exact.get("is_reassigned", False) or mut_info_exact.get("is_mutated", False)
                elif mut_info_global:
                    # We check global fallback to support interprocedural analysis from MyPy plugin.
                    # But MyPy's 'is_reassigned' flag globally means SOME variable with this name was reassigned,
                    # which breaks short parameter names like 'x' or 'val'.
                    # Mypy sets 'is_mutated' when an object is modified (e.g. dict['a'] = 1, lst.append()).
                    # So we ONLY trust 'is_mutated' from the global fallback.
                    is_mut = mut_info_global.get("is_mutated", False)

                # Verify local reassignment using the function scanner
                mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                if (len(args_names) - 1) in mut_idx:
                    is_mut = True"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
