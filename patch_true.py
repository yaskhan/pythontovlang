# Ah! I see `val = float('3.14')`, `val = bool(1)`, `val = d.pop("b")`, `val = d.setdefault("b", 2)`, `val = 3.14159`
# These are ALL global reassignment leaks!!!
# AND `val` in `test_generics` was marked `is_reassigned: True` because in ANOTHER module it was reassigned!

# The core problem: The `TypeInference` class stores variables in `mutability_map` with ONLY their `target.id`.
# BUT, mypy plugin *also* stores them. In mypy plugin, `visit_assignment_stmt` does `_mark_mutated(lvalue)` which marks `is_mutated: True` for the target!
# WAIT! Mypy plugin `_mark_mutated` marks `is_mutated: True`.
# And mypy plugin `visit_var` marks `is_reassigned: True` if the mypy node has `is_reassigned`!

# So IF we want to drop `is_reassigned` entirely, we could do:
# `is_mut = mut_info.get("is_mutated", False)` for global variables, and ONLY use `func_param_mutability` for `is_reassigned`.

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

search = """                mut_info = self.type_inference.mutability_map.get(arg_name)
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                if mut_info:
                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)

                    if is_mut and arg_name in ("x", "val", "d", "l", "obj"):
                         # Check if the global mutability was a false positive for generic names like `x`
                         # We only clear it if we are sure it wasn't tracked as mutated by mypy
                         # Mypy correctly tracks `is_mutated` when a var is passed and modified.
                         # It ONLY fails when it's `is_reassigned` in some other function.
                         if not mut_info.get("is_mutated", False):
                              mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                              if len(args_names) - 1 not in mut_idx:
                                   is_mut = False"""

replace = """                mut_info = self.type_inference.mutability_map.get(arg_name)
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                if mut_info:
                    # `is_reassigned` comes from local variables in ANY function being assigned (e.g. x = 5)
                    # `is_mutated` comes from mypy plugin seeing method calls that mutate (e.g. data['key'] = 5, lst.append())
                    # Because variables aren't scoped by function in `mutability_map`, `is_reassigned` leaks globally
                    # and causes false positive `mut` parameters.
                    # We ONLY trust `is_mutated` globally. We trust `is_reassigned` ONLY if verified locally.

                    is_mut = mut_info.get("is_mutated", False)
                    if mut_info.get("is_reassigned", False) and not is_mut:
                        # Verify local reassignment using the function scanner
                        mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                        if (len(args_names) - 1) in mut_idx:
                            is_mut = True"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
