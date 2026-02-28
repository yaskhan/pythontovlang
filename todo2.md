# Feature Ideas for `py2v_transpiler`

Based on recent Python ecosystem developments (mypy, PyPy, and Numba changelogs), here are features that could be added or improved in the translator:

## From mypy Changelogs (Features & Syntax)
- [ ] **PEP 747: Annotating Type Forms (`TypeForm[T]`)**
  - Needs AST parsing support and mapping `TypeForm` to an appropriate V type or skipping it gracefully.
- [ ] **PEP 800: Disjoint Base Classes (`@disjoint_base`)**
  - Add support for detecting `@disjoint_base` decorator.
- [ ] **PEP 696: Type Variable Defaults**
  - Support new Python 3.13 syntax for generic defaults: `class Box[T = int]: ...`
- [ ] **PEP 702: `@deprecated` Decorator**
  - Transpile `warnings.deprecated` to V's `[deprecated]` attribute on functions/structs.
- [ ] **Property Setters and Getters with Different Types**
  - Ensure the translator can handle and correctly emit V code when a `@property` and its `@foo.setter` have slightly mismatched type hints (e.g., returning `int` but accepting `str | int`).
- [ ] **`__getattr__`, `__setattr__`, `__delattr__` Support**
  - While V does not support fully dynamic attributes natively, consider adding a mechanism (e.g., a fallback `map[string]Any` inside the struct) to support dynamic attribute access where needed.
- [ ] **Enum Membership Semantics (PEP 736/typing updates)**
  - Ensure transpiler correctly handles unannotated vs annotated Enum members based on new typing rules.

## From PyPy Changelogs (Optimizations & Runtime Behaviors)
- [ ] **Atomic Groups and Possessive Repeats in Regex**
  - Review if V's `regex` module supports these constructs, and if not, how `py2v_transpiler` maps Python's `re` module calls for these features.
- [ ] **`OrderedDict` Performance**
  - Check how `collections.OrderedDict` is currently mapped. Since V's standard `map` is not guaranteed to be ordered, ensure `OrderedDict` maps to an ordered data structure in V if order is relied upon.
- [ ] **String Methods on Tuples/Iterables (`str.startswith` with tuple)**
  - Python allows `s.startswith(('a', 'b'))`. Ensure the translator expands this to `s.starts_with('a') || s.starts_with('b')` in V.
- [ ] **Memoryview and Bytearray**
  - Implement translation for `memoryview()` and `bytearray()` (e.g., mapping to `[]u8` in V with appropriate mutable/immutable semantics).
- [ ] **Zlib / Encoding Optimizations**
  - Review how `zlib` and `str.encode`/`decode` are translated, ensuring they use the most efficient V standard library functions (`compress`, `encoding`).

## From Numba Changelogs (Optimizations & Advanced Types)
- [ ] **Ahead-of-Time (AOT) and Lazy Compilation Awareness**
  - Provide modes for the transpiler to generate either generic V functions that rely on V's generic instantiation (similar to Numba's lazy compilation) or explicitly instantiated monomorphic functions based on a given type signature (like Numba's `@jit(signature)`).
- [ ] **Fastmath and CPU Targeting**
  - Add transpilation pragmas/decorates (e.g. `@v_fastmath`) that map to V's compiler flags or emit specific optimized math routines (similar to Numba's `fastmath=True`).
- [ ] **Statically Typed Dictionaries and Lists**
  - Similar to Numba's `typed.Dict` and `typed.List`, ensure the transpiler heavily favors resolving Python `dict` and `list` to homogeneous V maps and arrays whenever static typing can prove it, falling back to `map[string]Any` or `[]Any` only when strictly necessary.
- [ ] **Array Expression Loop Fusion (Deforestation)**
  - Add an optimization pass in the translator to detect successive numpy-like array operations (e.g. `a * b + c`) and fuse them into a single fast loop in V, reducing intermediate array allocations.
- [ ] **`prange` (Explicit Parallel Loops)**
  - Recognize a specific construct (e.g. importing `prange` or using a specific `@parallel` decorator) and transpile it to V's concurrent/thread features, allowing parallel for-loop execution.
- [ ] **StructRef (Mutable Pass-By-Reference Structs)**
  - Ensure that Python classes (which are pass-by-reference) map appropriately to V structs passed as pointers `&T` when mutation inside functions is required, mirroring Numba's `StructRef`.
- [ ] **Dead Branch Pruning based on Semantic Constants**
  - Implement an AST rewriting pass that evaluates constant boolean expressions at transpilation time to skip generating V code for unreachable branches (e.g., `if sys.platform == 'win32':`).