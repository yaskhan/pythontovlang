with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# I need to restore the exact logic but simply prevent `mut_info` falling back to `arg_name` when it's just 'is_reassigned'.
# Actually, the problem in test_generics is that `val` is inferred as mutated because the global fallback `val` is mutated.
# The `val` in `Base.__init__` is NOT mutated. It's just read and assigned to `self.val`.
# Let's see what happens if I revert to the original but add a condition for `arg_name` fallback.

original_search = """                mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")
                if mut_info:
                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)
                elif hasattr(self.type_inference, 'func_param_mutability'):
                    # Fallback to function parameter mutability index tracked by analyzer
                    mut_idx = self.type_inference.func_param_mutability.get(node.name, [])
                    try:
                         # Since args_names list is populated in order
                         arg_index = len(args_names) - 1
                         if arg_index in mut_idx:
                              is_mut = True
                    except Exception:
                         pass

                if not is_mut and hasattr(self.type_inference, 'mutability_map'):
                    # Fallback to pure arg_name ONLY if it's explicitly tracked as mutated in mypy plugin
                    # Note: We must be careful not to pick up reassignments from other functions.
                    mut_info_global = self.type_inference.mutability_map.get(arg_name)
                    if mut_info_global and mut_info_global.get("is_mutated") and not mut_info_global.get("is_reassigned"):
                        # Only apply global if explicitly marked as mutated, but not just reassigned
                        # This prevents variables reassigned elsewhere from marking parameters as mut.
                        is_mut = True"""

replace = """                mut_info = self.type_inference.mutability_map.get(arg_name)
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")

                # Check func param explicitly mapped
                mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                is_idx_mut = (len(args_names) - 1) in mut_idx

                if mut_info:
                    is_mut = mut_info.get("is_mutated", False)
                    # We only consider 'is_reassigned' if it's explicitly tracked per-function or if it's not a global leak
                    # Global leak usually only happens for `arg_name` lookup instead of `node.name.arg_name`
                    if not is_mut:
                        if mut_info.get("is_reassigned", False):
                             # To avoid global leaks (like `x` in test_none_type), we only accept 'is_reassigned'
                             # if it's explicitly confirmed by `is_idx_mut` or if we fetched it using the scoped name `f"{node.name}.{arg_name}"`
                             # Since we checked `arg_name` first in the original code, we can't be sure!
                             # Let's fix the check order:
                             pass

                # The real fix:
                # 1. Try exact scope first
                mut_info_exact = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")
                if mut_info_exact:
                    is_mut = mut_info_exact.get("is_reassigned", False) or mut_info_exact.get("is_mutated", False)
                elif is_idx_mut:
                    is_mut = True
                else:
                    # 2. Try global, but ONLY accept "is_mutated" because "is_reassigned" is highly prone to global leak across functions
                    mut_info_global = self.type_inference.mutability_map.get(arg_name)
                    if mut_info_global:
                         is_mut = mut_info_global.get("is_mutated", False)"""

content = content.replace(original_search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
