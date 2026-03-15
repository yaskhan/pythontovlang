with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# Let's completely revert to the ORIGINAL `py2v_transpiler/core/translator/functions.py` logic, but ADD a simple check to skip checking `mut_info.get("is_reassigned", False)` for global variables! Wait, `get_value(x=None)` is fixed if we just don't use `is_reassigned` for global variables. But `val` in `test_generics` is an argument, and `is_reassigned` might be True globally.

search = """                # The real fix:
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

replace = """                # 1. Try exact scope first
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
content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
