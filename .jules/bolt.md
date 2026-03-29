## 2026-03-26 - [Optimization: Regex pre-compilation and caching]
**Learning:** Pre-compiling static regular expressions as module-level constants, moving inline imports to the top level, and implementing a simple `Dict[str, re.Pattern]` cache for dynamic patterns (like generic type placeholders) consistently yields ~50% performance gains in hot paths.
**Action:** Identify regex calls within loops or frequently called methods and apply pre-compilation or caching.

## 2026-03-27 - [Optimization: Constant lifting for static mappings]
**Learning:** Redefining static mapping dictionaries (e.g., operator maps, type maps) inside frequently called visitor methods or utility functions adds significant overhead. Lifting these to module-level constants yields up to ~55% performance gains in hot paths like `map_python_type_to_v`.
**Action:** Identify static dictionaries in hot paths and move them to the module level as constants.

## 2026-03-28 - [Optimization: Lifting static structures and helpers]
**Learning:** Lifting local static sets/dictionaries (e.g., `_MUTATING_METHODS` in `visitor.py`/`inferers.py`, `_OP_MAP` in `calls_overloads.py`) and local helper functions (e.g., `_to_standard_str` in `literals.py`) to the module level in hot AST traversal paths yields significant performance improvements (4.5x - 10x speedup for lookups) by avoiding redundant object creation.
**Action:** Scan visitor methods for local constant collections or helper functions and lift them to module scope.
