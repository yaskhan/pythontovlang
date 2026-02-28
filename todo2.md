# Feature Ideas for `py2v_transpiler`

Based on recent Python ecosystem developments (mypy, PyPy, Numba, NumPy, Nuitka, Codon, Cython, mypyc, Pyston, Taichi, Pyrefly, and Pyright), here are features that could be added or improved in the translator:

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

## From Cython Changelogs (Typing & C-Level Optimizations)
- [ ] **C-Array Substitution for Literal Loops**
  - Transpile loops over literal sequences or strings directly into fast, static V arrays (e.g., `for x in [1, 2, 3]:` becomes `for x in [1, 2, 3]! { ... }`), bypassing dynamic list overhead.
- [ ] **Memoryview Slicing Optimizations**
  - If array/memoryview slicing occurs repeatedly inside a loop and doesn't escape, optimize away the slice object creation and bounds checking entirely (or map to fast pointer arithmetic/V array slices without allocating new views).
- [ ] **Compile-Time Method Evaluation**
  - Evaluate method calls on builtin literal values at compile time (e.g., `"a b c".split()` -> `["a", "b", "c"]`) when applicable, emitting only the static result.
- [ ] **Fast Paths for Builtins (`int`, `float`, `str`)**
  - Special case operations on common builtin types (`int`, `float`, `str`, `bytes`) by bypassing generic dynamic dispatch and mapping them directly to V's native type operators.
- [ ] **Optimized Unpacking of Integers/Variables**
  - Ensure that unpacking (e.g., `a, b = c, d`) avoids creating intermediate tuple objects on the heap, instead using temporary stack variables, especially in conditional assignments and comprehensions.
- [ ] **C++ Exception Handlers mapping**
  - Improve the transpilation of Python exception handling (`try`/`except`) to natively map to V's `Result` types (`!`) or `?` syntax wherever possible, avoiding the overhead of heavy exception state objects.

## From mypyc (Static Typing to C Extensions)
- [ ] **Early Binding based on Final and Static Types**
  - Implement "early binding" optimization where methods or variables declared as `Final` or with strict static types bypass dynamic namespace or dictionary lookups entirely, emitting direct V struct field access or V method calls.
- [ ] **Native Extension Classes (V Structs)**
  - Map Python classes with full static typing directly to V structs with fixed memory layouts (avoiding dynamic `__dict__` overhead), mirroring mypyc's Native Classes concept.
- [ ] **Unboxed Primitive Types**
  - Use raw, unboxed V primitives (e.g., `int`, `f64`, `bool`) for local variables and function arguments wherever static type hints are strictly defined, bypassing the `Any` wrapper sum-type to reduce heap allocation and GC pressure.
- [ ] **Strict Runtime Type Checking**
  - Emit V code that automatically performs `isinstance` or dynamic cast checks at the boundaries of transpiled functions for any arguments passed as `Any` that are assigned to statically typed parameters, ensuring runtime safety.
- [ ] **Final Values Constant Folding**
  - Automatically evaluate and inline module-level constants decorated with `typing.Final` directly into the generated V code during transpilation, avoiding runtime lookups.

## From Pyston (JIT & Runtime Optimizations)
- [ ] **Aggressive Attribute Caching**
  - Instead of relying on full dynamic lookups (`getattr` / `getattr_str`) every time, implement an inline cache mechanism in V (where appropriate) for frequently accessed attributes on dynamic Python-like objects.
- [ ] **Dynamic Specialization (Quickening)**
  - Implement a mechanism where generically-typed variables (`Any`) in hot loops are specialized (or "quickened") to their underlying concrete V types (`int`, `f64`) if the type is observed to be stable, bypassing the `Any` wrapper sum-type overhead.
- [ ] **Reduced Reference Count Operations**
  - When mapping Python to V, rely on V's value semantics and ownership models (like borrowing `&T`) to avoid generating redundant reference counting logic when passing objects between functions, mimicking Pyston's reduction of GC overhead.
- [ ] **Faster C/Foreign Function Calls**
  - Optimize the bridge between the transpiled V code and external C functions (e.g., standard library) to avoid constructing full Python-like argument tuples, passing native V types directly when the signature is known.

## From Taichi (Parallel GPU/CPU Computation)
- [ ] **`@ti.kernel` GPU/CPU Offloading**
  - Add support for a decorator (like `@v_kernel`) that indicates a function should be compiled directly to compute shaders (e.g., via V's `sokol` or `gggg` bindings) for massive parallelization on the GPU or optimized CPU vectorization.
- [ ] **Data Structure Access Lowering**
  - Implement intermediate representations in the transpiler that explicitly track data structure access index bounds and types to apply automatic access optimization passes (hoisting, bounds check elimination) before V emission.
- [ ] **Spatially Sparse Data Structures (SNode)**
  - Allow transpiling advanced sparse hierarchical Python arrays/fields to V's efficient sparse map representations or explicit multi-layered structs for memory efficiency in numerical simulations.
- [ ] **Specialized Loop Vectorizers**
  - Beyond `prange`, detect data-parallel independent inner loops during the AST analysis phase and apply compiler directives or SIMD-intrinsics when mapping to V to guarantee vectorization.

## From Pyrefly (Fast Type Checking & Language Server)
- [ ] **Flow-Sensitive Type Narrowing**
  - Enhance the internal type inference engine (`TypeInference`) to refine types based on control flow (e.g., if a union type passes an `isinstance` check or an `is not None` check, narrow the static type for the remainder of the block).
- [ ] **Single & Multi-Assignment Type Inference**
  - Improve variable type inference to intelligently construct `Union` types when a single variable is assigned differing types across multiple code paths, rather than falling back immediately to `Any`.
- [ ] **Strict "Unknown" vs "Any" Tracking**
  - Introduce an `Unknown` internal type distinct from `Any` to explicitly track cases where type inference failed vs where the user explicitly requested dynamic typing, allowing the transpiler to emit targeted warnings for "blind spots".
- [ ] **Module-Level Incremental Checking**
  - Design the transpiler's analysis and emission phases to be incremental and highly parallelizable at the module level, mimicking Pyrefly's speed when analyzing large codebases.

## From Pyright (Advanced Type Inference & Checking)
- [ ] **Advanced Type Guards (Type Narrowing)**
  - Expand type inference to understand custom `TypeGuard` functions and Python's `assert` statements, using them to eliminate branch paths or cast variables safely before V code generation.
- [ ] **Reachability Analysis**
  - Implement thorough unreachable code detection (e.g., after `typing.NoReturn` function calls or impossible `match`/`if` branches based on type constraints) to omit dead V code completely.
- [ ] **TypedDict Structural Inference**
  - Recognize duck-typed dictionary literal assignments that structurally match a `TypedDict` and automatically cast them to the corresponding V `struct` without requiring explicit constructor calls.
- [ ] **Overload Resolution Strictness**
  - When encountering overloaded functions, perform strict static resolution at transpilation time to emit a direct call to the exact V function variant, eliminating runtime type introspection.