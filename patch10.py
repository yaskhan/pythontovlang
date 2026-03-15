with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# Mypy correctly tracks `is_mutated` in interprocedural calls because `mutating_methods` checks `data['key'] = ...` but wait, `data['key'] = ...` is an Assignment!
# In `mypy_plugin.py`, `visit_assignment_stmt` marks the target as `is_mutated: True`!
# So for `data['key'] = 'value'`, `data` gets `is_mutated: True`!
# Then in `wrapper(d)`, `process(d)` is a call. In mypy_plugin.py, it doesn't trace interprocedurally to update `d`!
# WAIT! Mypy plugin DOES NOT do interprocedural analysis in `mutability_map` for `d`!
# The ONLY reason `wrapper(mut d)` was working before is because `FunctionMutabilityScanner` (in analyzer.py) was leaking the global mutability!
# Ah! `FunctionMutabilityScanner` was tracking `is_reassigned` globally?!
# NO! `TypeInference.visit_Call` propagates mutability to callers!
# Let's check `analyzer.py` `visit_Call`.
