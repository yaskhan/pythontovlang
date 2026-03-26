## 2026-03-26 - [Optimization: Regex pre-compilation and caching]
**Learning:** Pre-compiling static regular expressions as module-level constants, moving inline imports to the top level, and implementing a simple `Dict[str, re.Pattern]` cache for dynamic patterns (like generic type placeholders) consistently yields ~50% performance gains in hot paths.
**Action:** Identify regex calls within loops or frequently called methods and apply pre-compilation or caching.
