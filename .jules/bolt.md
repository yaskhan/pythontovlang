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

## 2026-04-03 - [Optimization: Dictionary lookups for hot branching logic]
**Learning:** Replacing long sequential `if/elif` string comparisons with module-level dictionary lookups in hot paths (like `_guess_type_call`) yields measurable speedups (~24%) by moving from $O(n)$ to $O(1)$ lookup time. Additionally, lifting local dictionary creation out of visitor methods (e.g., `visit_BoolOp`) avoids redundant allocations.
**Action:** Identify long identifier-based `if/elif` chains or local dictionaries in hot AST traversal methods and refactor them into module-level constant lookups.

## 2026-04-04 - [Optimization: Composite Tuple Keys for Location-based Lookups]
**Learning:** Using composite tuples `(identifier, (line, col))` as dictionary keys is significantly more efficient than formatted strings `f"{identifier}@{line}:{col}"` in hot AST traversal paths. Tuples avoid repeated string formatting overhead and offer faster hashing and comparison than string representations of complex data.
**Action:** Replace string-based location keys and combined identifier@location strings with tuples or nested tuples to minimize overhead in hot resolution paths.

## 2026-04-05 - [Optimization: O(1) dispatch for AST node operations]
**Learning:** Sequential `if/elif` chains using `isinstance()` are a common bottleneck in AST visitors. Replacing these with a module-level dispatch dictionary mapping `type(node)` to handler functions/lambdas, combined with lifting static constants, yields dramatic speedups (~18x) by moving from (n)$ type checking to (1)$ lookup and avoiding redundant object allocations.
**Action:** Identify `if/elif` chains performing type-based dispatch in hot AST traversal paths and refactor them into module-level dispatch dictionaries.

## 2026-04-06 - [Optimization: O(1) dispatch for built-in call resolution]
**Learning:** Replacing a long sequential `if/elif` chain (approx. 30 cases) with a module-level dispatch dictionary in the hot built-in call resolution path (`_handle_builtin_type_cast`) yields a ~1.5x speedup for the lookup logic. This reduces the per-call overhead for both built-in and non-built-in calls during AST traversal.
**Action:** Use dispatch dictionaries for large conditional blocks that map identifiers to specialized handling logic in hot visitor paths.

## 2026-04-07 - [Optimization: O(1) dispatch and result caching for operator translation]
**Learning:** Sequential `isinstance` checks and redundant recursive `_guess_type` calls in hot AST traversal paths (like operator visitors) are major bottlenecks. Replacing them with `type()` based dispatch and pre-calculating results in complex chains (like chained comparisons) yields 26-37% speedups.
**Action:** Use `type(node.op)` for O(1) dispatch and cache `None`-checks and type guesses within visitor loops to avoid redundant AST traversal.
