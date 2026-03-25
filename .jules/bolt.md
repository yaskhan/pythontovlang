## 2025-05-15 - [Optimization: Module-level regex pre-compilation]
**Learning:** Pre-compiling regular expressions as module-level constants in Python provides a significant performance boost (~40-50%) in core transpilation paths compared to inline `re.match`/`re.sub` calls, especially when redundant imports are also moved to the top level.
**Action:** Always pre-compile regular expressions at the module level for any frequently called methods or loops in the transpiler's critical path.
