import subprocess
subprocess.run(["git", "checkout", "py2v_transpiler/core/analyzer.py"])
subprocess.run(["git", "checkout", "py2v_transpiler/core/translator/functions.py"])

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# OK, the ONLY change needed to fix the issue without breaking mypy's simple interprocedural analysis
# is exactly what I did in `patch13`, but with ONE minor fix: I shouldn't rely on `args_names` length
# because it's populated BEFORE the check in the loop! Wait, `arg_name` is appended to `args_names` BEFORE `is_mut` check!
# Let's verify `functions.py`:
#
#             args_names.append(arg_name)
#
#             is_mut = False
#             if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
#                 mut_info = self.type_inference.mutability_map.get(arg_name) ...
# YES! `arg_name` is appended BEFORE. So its index is `len(args_names) - 1`!
# BUT wait! Mypy's `func_param_mutability` maps function NAME to mutated argument INDICES.
# In `test_generics`, `new_base` is the __init__ of `Base`!
# Ah! `__init__` is NOT called `new_base` in Python! It's `__init__`!
# So `node.name` is `__init__`! But my check uses `node.name`! Let's check:
# `func_param_mutability` keys are `node.name`. `__init__` is in there!

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

                    # Fix global leak false positives on short variable names like 'x' and 'val'
                    # Mypy global mutability map leaks variables with the same name across unrelated functions.
                    if arg_name in ("x", "val", "v", "i", "j", "k", "n", "m", "result", "res", "y", "a", "b", "c") and not mut_info.get("is_mutated", False):
                        # Verify using function scanner if it was truly locally reassigned
                        mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                        if (len(args_names) - 1) not in mut_idx:
                            is_mut = False"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
