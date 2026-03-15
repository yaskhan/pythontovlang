with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

search = """                # 1. Try exact scope first
                mut_info_exact = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")
                if mut_info_exact:
                    is_mut = mut_info_exact.get("is_reassigned", False) or mut_info_exact.get("is_mutated", False)
                elif is_idx_mut:
                    is_mut = True
                else:
                    mut_info_global = self.type_inference.mutability_map.get(arg_name)
                    if mut_info_global:
                         is_mut = mut_info_global.get("is_reassigned", False) or mut_info_global.get("is_mutated", False)

                         # BUT prevent global leak! If this is a known false positive, we skip it.
                         # E.g., 'x' in 'test_none_ternary' or 'val' in 'test_generics'
                         if arg_name in ('x', 'val') and not mut_info_global.get("is_mutated"):
                             is_mut = False

                         # What if we just fix `is_mut` for the case where it's a parameter by checking if the function contains any assignment to it?
                         # The `FunctionMutabilityScanner` already tracked all reassigned params in `func_param_mutability`!
                         # So if `is_idx_mut` is False, the parameter is DEFINITELY NOT reassigned locally!!!
                         # So if `is_idx_mut` is False, we should ONLY trust `is_mutated` from global!
                         if not is_idx_mut and not mut_info_global.get("is_mutated"):
                             is_mut = False"""

# The fix: The `is_reassigned` flag means "the variable was reassigned a new value" (e.g., `x = 5`).
# The `is_mutated` flag means "the variable's contents were mutated" (e.g., `x.append(5)`, `x.val = 5`).
# For V interprocedural `mut`, we need `mut` if the caller mutates the object (`is_mutated`) or if the parameter is passed to another function as `mut`.
# Mypy tracks if a function parameter is mutated in `mutability_map[param_name]`.
# If it's just reassigned LOCALLY (`is_reassigned`), we don't necessarily need `mut` for the caller, but V requires `mut` for locally reassigned parameters.
# HOWEVER, `FunctionMutabilityScanner` already checks LOCAL reassignment via `func_param_mutability` (`is_idx_mut`).
# So if `is_idx_mut` is FALSE, then `is_reassigned` from `mutability_map[arg_name]` is guaranteed to be a GLOBAL LEAK from another function!
# Therefore, if `is_idx_mut` is False, we MUST ignore `mut_info_global.get("is_reassigned")`.
# We only respect `mut_info_global.get("is_mutated")`!

replace = """                # Check local reassignment explicitly from analyzer
                mut_idx = getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, [])
                is_idx_mut = (len(args_names) - 1) in mut_idx

                # Try global scope because mypy plugin doesn't scope variables
                mut_info_global = self.type_inference.mutability_map.get(arg_name)

                if mut_info_global:
                     # 1. Check if the object is mutated (e.g., methods called, attributes changed)
                     is_mut = mut_info_global.get("is_mutated", False)

                     # 2. Check if the variable is reassigned locally.
                     # We MUST use `is_idx_mut` to verify this because `is_reassigned` from mypy might be a global leak.
                     if is_idx_mut:
                          is_mut = True
                elif is_idx_mut:
                     is_mut = True"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
