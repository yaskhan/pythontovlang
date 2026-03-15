with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# In V, primitive types cannot be 'mut'. And 'val' in 'test_generics' is 'T'.
# wait, 'is_mut' was previously picking it up. But the test checks "fn new_base[T](val T) Base[T]".
# Why is it "fn new_base[T](mut val T) Base[T]" now?
# Because `new_base` has `self.val = val` in `init` ? No, `self.val` is not `val`. `val` is not reassigned.
# Ah, `val` is an argument, and `FunctionMutabilityScanner` checks assignments.
# `FunctionMutabilityScanner.visit_Assign` sees `self.val = val`.
# Target is `self.val` (Attribute), and `_mark_mutated` processes `target.value` which is `self`!!!
# Wait, `FunctionMutabilityScanner._mark_mutated` marks `self`. But why is `val` marked as mutated?

search = """                    if mut_info_global and mut_info_global.get("is_mutated") and not mut_info_global.get("is_reassigned"):
                        # Only apply global if explicitly marked as mutated, but not just reassigned
                        # This prevents variables reassigned elsewhere from marking parameters as mut.
                        is_mut = True"""

replace = """                    if mut_info_global and mut_info_global.get("is_mutated"):
                        # If a global var is mutated, only apply if we are reasonably sure
                        # Wait, what if we just drop this global fallback entirely for parameters?
                        # `is_mut` already checks `self.type_inference.func_param_mutability` and `f"{node.name}.{arg_name}"`.
                        pass"""
content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
