with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# Ah! `visit_Call` calls `self._mark_mutated(arg)`, which sets `is_mutated: True` on the argument name.
# Because mypy's `mutability_map` might not catch interprocedural calls easily, `analyzer.py` propagates it by checking `func_param_mutability` and marking `arg` (which could be `d`, `l`, `obj`) as mutated!
# The ONLY issue is that `is_reassigned` leaks globally. `is_mutated` is what we really want!
# But wait! Why does `test_generics` fail? Because `is_mutated` is True for `val`.
# Let's check why `val` has `is_mutated: True` globally!

search = """                    # Fix global leak false positives on short variable names like 'x' and 'val'
                    if arg_name in ("x", "val") and not mut_info.get("is_mutated", False):
                        # Verify using function scanner if it was truly locally reassigned
                        mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                        if len(args_names) not in mut_idx:
                            is_mut = False"""

replace = """                    # Fix global leak false positives on short variable names
                    if not mut_info.get("is_mutated", False):
                        # If it's ONLY 'is_reassigned', we must check if it was truly locally reassigned
                        mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                        # Fix index: args_names has just been appended with `arg_name`, so its length is > 0
                        arg_index = len(args_names) - 1
                        if arg_index not in mut_idx:
                            is_mut = False"""
content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
