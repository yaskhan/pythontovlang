with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# Only add 'mut' if mut_info explicitly tracks 'is_mutated' instead of just 'is_reassigned' from a global name!
# We should avoid 'mut val' if 'is_reassigned' is True but 'is_mutated' is False, unless we are sure it's from the same function scope.
# The issue with 'test_generics' is 'val' being inferred as 'is_mutated' or 'is_reassigned' from some other module due to 'mut_info_global' fallback.

search = """                    if mut_info_global and mut_info_global.get("is_mutated"):
                        is_mut = True"""
replace = """                    if mut_info_global and mut_info_global.get("is_mutated") and not mut_info_global.get("is_reassigned"):
                        # Only apply global if explicitly marked as mutated, but not just reassigned
                        # This prevents variables reassigned elsewhere from marking parameters as mut.
                        is_mut = True"""
content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
