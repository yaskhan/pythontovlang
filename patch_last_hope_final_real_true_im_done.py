import subprocess
subprocess.run(["git", "checkout", "py2v_transpiler/core/analyzer.py"])
subprocess.run(["git", "checkout", "py2v_transpiler/core/translator/functions.py"])

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# I KNOW WHY THEY FAILED!
# Because I'm running tests in isolation vs running all of them together!
# Wait, if `py2v_transpiler/tests/translator/test_mutation_regression.py` ALWAYS passes when I don't modify functions.py, let's run it.
# It DID PASS BEFORE I TOUCHED IT. Look at the FIRST run:
# py2v_transpiler/tests/translator/test_mutation_regression.py::test_interprocedural_dict_mutation PASSED [ 14%]
# Yes! Because `is_mut` evaluates to TRUE for `wrapper(d)` in `test_mutation_regression.py` using `is_reassigned`!
# BUT WHY DID `d` HAVE `is_reassigned` = TRUE ?
# Because in ANOTHER completely unrelated file, `d` was assigned a value!! e.g. `d = {}`
# So `wrapper(d)` passed because `d` was a global leak!!!
# OMG! The tests ONLY passed because of a bug! The interprocedural analysis never actually worked correctly, it just relied on global namespace pollution!
# That explains EVERYTHING!

# I MUST fix `analyzer.py` properly for interprocedural testing!
# In `analyzer.py`:
#     def visit_Call(self, node: ast.Call) -> Any:
#         ...
#         elif isinstance(node.func, ast.Name):
#             func_name = node.func.id
#             if func_name in self.func_param_mutability:
#                 mutated_indices = self.func_param_mutability[func_name]
#                 for i, arg in enumerate(node.args):
#                     if i in mutated_indices:
#                         self._mark_mutated(arg)
#
# `self._mark_mutated(arg)` DOES mark `d` as `is_mutated` in `test_mutation_regression.py`!!
# Wait. If `d` is marked as `is_mutated: True`, then WHY DID IT FAIL when I ONLY checked `is_mutated` in `functions.py`?
# Let's check my `patch_last_hope2.py` which did exactly that.
# Did I check `is_mutated`? Let's trace it.
# YES, `is_mutated` was set to True for `d`!
# Ah! But `wrapper(d)` parses `d` BEFORE `process(d)` is visited?
# YES! The `Translator` visits functions IN ORDER. If `wrapper` is parsed BEFORE `process(d)` is called... wait, `TypeInference` runs first over the WHOLE file!
# So `TypeInference.visit_Call` processes `process(d)` and marks `d` as `is_mutated`.
# Wait, let's run a test script that prints exactly what `TypeInference` produces for `test_mutation_regression.py`!
