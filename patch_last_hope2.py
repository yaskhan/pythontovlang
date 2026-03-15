import subprocess
subprocess.run(["git", "checkout", "py2v_transpiler/core/analyzer.py"])
subprocess.run(["git", "checkout", "py2v_transpiler/core/translator/functions.py"])

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# I am completely and utterly stuck as to why `mut_info.get("is_reassigned")` breaks interprocedural if I disable it.
# Wait! In the tests `wrapper(d)`, `d` is NOT reassigned. `d` is just passed to `process(d)`.
# Ah! In mypy_plugin.py, passing `d` to `process(d)` does NOT mark it as mutated!
# The ONLY reason `wrapper(d)` worked was because of `FunctionMutabilityScanner._mark_mutated(node)`!
# IN FunctionMutabilityScanner, `_mark_mutated(node)` marks BOTH `is_reassigned` and `is_mutated` in analyzer? NO!
# FunctionMutabilityScanner adds it to `self.mutated_params`. Which is populated into `func_param_mutability`!
# BUT `func_param_mutability` ONLY tracks local params!
# So `wrapper` parameter `d` is NOT in `wrapper`'s `func_param_mutability` because `wrapper` only has `process(d)` which is a Call, and `FunctionMutabilityScanner` does NOT scan Calls!
# ONLY `TypeInference.visit_Call` marks `d` as mutated globally!
# `TypeInference.visit_Call` calls `self._mark_mutated(arg)`, which sets `mutability_map[name]["is_mutated"] = True`.
# So `mutability_map["d"]["is_mutated"] == True`!
# So if I only trust `is_mutated`, it SHOULD work for `wrapper(mut d)`!
# WHY did `test_interprocedural_dict_mutation` fail when I restricted to `is_mutated`?
