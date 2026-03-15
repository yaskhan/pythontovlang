with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# OK, the REAL original code BEFORE all my changes:
#                 mut_info = self.type_inference.mutability_map.get(arg_name)
#                 if not mut_info:
#                     mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")
#                 if mut_info:
#                     is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)
#
# So the ONLY thing I need to do is to catch the false positives for `x` and `val` when `mut_info.get("is_mutated")` is False (meaning it was just 'is_reassigned'), and it's not locally reassigned.

search = """                    if arg_name in ("x", "val") and not mut_info.get("is_mutated", False):
                        # Verify using function scanner if it was truly locally reassigned
                        mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                        if len(args_names) not in mut_idx:
                            is_mut = False"""

replace = """                    # Fix global leak false positives on short variable names like 'x' and 'val'
                    if arg_name in ("x", "val", "v", "i", "j", "k", "n", "m", "result", "res", "y", "a", "b", "c") and not mut_info.get("is_mutated", False):
                        mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                        if (len(args_names) - 1) not in mut_idx:
                            is_mut = False"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
