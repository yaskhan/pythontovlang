with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# Let's see what the original logic was before I started patching.
# The original code:
#                mut_info = self.type_inference.mutability_map.get(arg_name)
#                if not mut_info:
#                    mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")
#                if mut_info:
#                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)
# This checked global FIRST. That's why interprocedural worked!
# Because mypy plugin collected globals like `d`, `l`, `obj` when they were passed to other functions.
# Mypy plugin does NOT scope variables by function name! It just stores `d`, `l`, `obj`.
# So to make interprocedural mutation work, we MUST check `arg_name` globally.
# BUT, we want to prevent false positives like `x` in `test_none_ternary`.
# Why did `x` trigger? Because `x` was reassigned (`x = y`) in `test_none_assignment`.
# This made `mut_info.get("is_reassigned")` True.
# How about `val` in `test_generics`? Why did it trigger? Because `self.val = val` in `Base.__init__`. Wait, in `self.val = val`, `target` is `self.val`. So `self` is mutated. Why would `val` be mutated? Let's check.
