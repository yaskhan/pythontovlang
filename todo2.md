# Feature Ideas for `py2v_transpiler`

Based on recent Python ecosystem developments (mypy, PyPy, Numba, NumPy, Nuitka, and Codon changelogs), here are features that could be added or improved in the translator:

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

## From NumPy Changelogs (Array Semantics & APIs)
- [ ] **Transpile-time Deprecation Warnings**
  - Have the transpiler detect usages of recently deprecated NumPy APIs (e.g. `np.trapz`, `np.in1d`, positional `out` arguments) and emit compiler warnings encouraging the user to upgrade to their modern equivalents (e.g. `np.trapezoid`, `np.isin`, keyword `out=`).
- [ ] **Hash-based `np.unique` Optimization**
  - NumPy recently optimized `np.unique` for strings and complex numbers using a hash table instead of sorting. When transpiling `np.unique(..., return_index=False, return_inverse=False, return_counts=False)`, evaluate using V's maps/sets for O(N) deduplication rather than sorting, if the output order isn't required by the specific context.
- [ ] **Support `ndmax` in Array Creation**
  - Ensure any transpilation of `np.array(..., ndmax=N)` correctly bounds the recursion depth of nested lists/arrays to match the new NumPy 2.4 behavior.
- [ ] **`__numpy_dtype__` Protocol Handling**
  - Add logic in the type mapping layer to prefer `__numpy_dtype__` over `.dtype` when determining the static type of user-defined array-like classes.
- [ ] **Iterator `ndindex` Optimizations**
  - Transpile `np.ndindex` iteration into flat, product-based nested loops internally, rather than creating Python-style iterator objects, mirroring NumPy's recent internal refactor using `itertools.product`.

## From Nuitka Changelogs (Compilation & Static Optimizations)
- [ ] **Loop Type Shape Analysis**
  - Track the type stability of loop variables. If an integer is known to stay within bounds or remain an integer, avoid generating dynamic type checks (like `isinstance` or dynamic `Any` wrapper unwrapping) inside the loop body.
- [ ] **Fast Pathing for Sequence Sizes**
  - When the size of a tuple, list, or dict is known ahead of time at transpile time, pre-allocate the exact capacity in V (e.g., `[]int{cap: N}`) instead of relying on dynamic resizing.
- [ ] **Static Optimization of `sys.exit` and Exceptions**
  - Statically optimize `sys.exit()` calls into direct exceptions or process termination in V, allowing the transpiler to recognize dead code paths following the exit.
  - Optimize exception instantiation so that known exception raises bypass generic exception factory methods.
- [ ] **Avoid Object Allocation overhead in `list.remove` and `list.extend`**
  - Implement dedicated low-level slice and memory moving functions in V for Python's `list.remove` and `list.extend` to avoid mapping them to slower generic iterators where possible.
- [ ] **Variable-Length Integer Encoding (Compact `int`)**
  - Investigate compact representation for Python's arbitrary-precision integers. For small values, use V's native primitives (`int`, `i64`), and only box large integers dynamically to reduce memory footprint.
- [ ] **Constant Subscript Optimization**
  - Statically evaluate subscripts (e.g., `x[1]`) when both `x` and the index are known immutable constants at compile time, emitting just the resulting constant in V.

## From Codon (High-Performance Compilation & Types)
- [ ] **Targeting Extension Modules (`pyext`)**
  - Add a compilation mode (`--pyext` equivalent) that wraps the generated V code in Python C-API bindings (using V's C interoperability), allowing transpiled code to be imported seamlessly back into standard CPython.
- [ ] **Explicit Sized Integer/Float Types**
  - Support syntax for explicitly sized numbers (like `Int[N]`, `UInt[N]`, `float16`, `float32`) to map directly to V's precise types (`i8`, `u16`, `f32`, etc.) without relying on inference.
- [ ] **`NoneType` Empty Struct Representation**
  - Optimize Python's `None` by transpiling `NoneType` to an empty struct in V, which the compiler handles efficiently with zero runtime size, rather than using a heavy boxed object or generic pointer.
- [ ] **Union Types Transpilation**
  - Map Python `Union[A, B]` types (or `A | B`) properly into V's sum types (e.g., `type MyUnion = A | B`), with corresponding `match` statements for type checking.
- [ ] **Demoting Heap Allocations to Stack (`alloca`)**
  - Implement an analysis pass that detects small, locally scoped objects/classes that do not escape the function, and emit V code that allocates them as value types on the stack rather than reference types on the heap.
- [ ] **Static Expressions**
  - Add support for compile-time execution of certain Python constructs (e.g., a `staticenumerate` equivalent or constant folding) that emits only the resulting static V code.