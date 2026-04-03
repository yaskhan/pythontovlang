## 2026-03-26 - [Optimization: Regex pre-compilation and caching]
**Learning:** Pre-compiling static regular expressions as module-level constants, moving inline imports to the top level, and implementing a simple `Dict[str, re.Pattern]` cache for dynamic patterns (like generic type placeholders) consistently yields ~50% performance gains in hot paths.
**Action:** Identify regex calls within loops or frequently called methods and apply pre-compilation or caching.

## 2026-03-27 - [Optimization: Constant lifting for static mappings]
**Learning:** Redefining static mapping dictionaries (e.g., operator maps, type maps) inside frequently called visitor methods or utility functions adds significant overhead. Lifting these to module-level constants yields up to ~55% performance gains in hot paths like `map_python_type_to_v`.
**Action:** Identify static dictionaries in hot paths and move them to the module level as constants.

## 2026-03-28 - [Optimization: Lifting static structures and helpers]
**Learning:** Lifting local static sets/dictionaries (e.g., `_MUTATING_METHODS` in `visitor.py`/`inferers.py`, `_OP_MAP` in `calls_overloads.py`) and local helper functions (e.g., `_to_standard_str` in `literals.py`) to the module level in hot AST traversal paths yields significant performance improvements (4.5x - 10x speedup for lookups) by avoiding redundant object creation.
**Action:** Scan visitor methods for local constant collections or helper functions and lift them to module scope.

## 2026-03-29 - [Optimization: Fast-path for common lookups]
**Learning:** Implementing a "fast-path" for the most common input cases (e.g., common types like `int`, `str`, `Any`) at the start of expensive resolution functions (like `map_python_type_to_v`) avoids regex and string parsing overhead for the majority of calls, yielding 1.3x-2.5x speedups in those hot paths.
**Action:** Identify the most frequent inputs to hot functions and add a direct lookup or fast-path guard.

## 2026-03-30 - [Optimization: Memoization for repetitive transformations]
**Learning:** Repetitive string transformations (like CamelCase to snake_case) and name sanitization are major bottlenecks in transpilers. Applying `@functools.lru_cache` to core naming functions and replacing manual character loops with optimized C-backed string methods (like `lstrip`) yields dramatic performance gains (up to 21x for memoized regex and 5x for optimized string stripping).
**Action:** Identify frequent transformations or lookups and apply memoization or more efficient built-in string methods.

## 2026-03-31 - [Optimization: AST Caching for Type Parsing]
**Learning:** `ast.parse` is an expensive operation that becomes a bottleneck when resolving hundreds of type annotations. Caching the parsed AST nodes in a module-level dictionary (`_TYPE_AST_CACHE`) and using a regex fast-path (`_IDENTIFIER_RE`) for simple types yields dramatic speedups (~6.4x) in core type resolution paths.
**Action:** Use a combination of regex fast-paths for simple strings and dictionary-based AST caches for complex expressions that require parsing.

## 2026-04-01 - [Optimization: Context-independent memoization]
**Learning:** When memoizing recursive functions like `get_depth` in a hierarchy, avoid using accumulating parameters (e.g., `current_depth`) as part of the result if it's not part of the cache key. An optimization that incorrectly caches a context-dependent result will lead to logical regressions.
**Action:** Refactor recursive functions to return absolute values (e.g., height from root) that are independent of the call stack before applying memoization.

## 2026-04-02 - [Optimization: Lifting local imports and static structures in hot paths]
**Learning:** Lifting local imports (e.g., `map_python_type_to_v`) and converting static tuples used for membership checks into module-level sets yields significant gains in core type resolution paths. Benchmarks showed up to 48% speedup for simple checks (`_is_numeric_type`) and ~6% for complex ones (`_map_type`) by eliminating redundant object creation and `sys.modules` lookups.
**Action:** Identify frequently called helper methods with internal static collections or local imports and lift them to module scope as constants or sets.
