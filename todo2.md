# Feature Ideas for `py2v_transpiler`

Based on recent Python ecosystem developments (mypy, PyPy, Numba, NumPy, Nuitka, Codon, Cython, mypyc, Pyston, Taichi, Pyrefly, and Pyright), here are features that could be added or improved in the translator:


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

## From `ty` by Astral (Performance & Rust-based Tooling)
- [ ] **First-Class Intersection Types**
  - Expand the transpiler's type system mapping to support intersection types (e.g., `A & B`), resolving them to V interfaces that demand methods from both types.
- [ ] **Redeclarations and Partially Typed Code Support**
  - Improve the transpiler's robustness against partial typing by generating mixed static/dynamic V code (e.g., isolating fully typed regions into fast paths while allowing `Any` fallback in others) and allowing type redeclarations in consecutive scopes where standard Python permits it.
- [ ] **Fine-Grained Incremental Transpilation**
  - Shift the transpiler's architecture to support fine-grained incrementality (like `ty`'s Rust-based architecture), regenerating only specific functions or closures that have changed, rather than rewriting the entire V file on every run.

## From pytype (Lenient Type Inference & Analysis)
- [ ] **Lenient "Gradual Typing" via Pure Inference**
  - Unlike strict type checkers, add an analysis pass that infers types purely from runtime semantics without requiring type hints, allowing dynamic idioms that don't contradict existing annotations to compile gracefully to V's `Any` wrappers where strict typing fails.
- [ ] **Generating Standalone Type Stubs (`.pyi` equivalents)**
  - Implement a feature to output a standalone mapping file or pseudo-`.pyi` file during transpilation that logs the inferred V types for all unannotated Python functions, allowing users to back-port these as explicit hints into their Python source.
- [ ] **Cross-File Boundary Inference**
  - Expand the AST analyzer to intelligently parse and infer types across `import` boundaries (resolving types from other transpiled modules) before emitting V code, rather than defaulting external dependencies to `Any`.

## From py2many (Multi-Language Target & AST Rewriting)
- [ ] **Generic Intermediate Analysis Passes**
  - Structure the transpiler's core analysis into discrete, language-agnostic AST rewriting phases (e.g., "Configuration Rewriters" or "Incompatibility Handlers") before the final V emission, allowing complex Python idioms to be normalized into simpler AST structures first.
- [ ] **Enhanced Python 3 Emitting (Auto-Annotator)**
  - Similar to py2many's ability to emit enhanced Python code, add a mode to the transpiler that writes the fully type-inferred AST back out as Python code with added static type hints, serving as an auto-annotator tool prior to V translation.
- [ ] **Standard Library Interoperability Maps**
  - Build a declarative mapping or rule-based configuration system (like py2many's framework) to automatically translate complex Python standard library calls into their exact V standard library equivalents or injected polyfills, handling the impedance mismatch systemically rather than ad-hoc.
- [ ] **LLM-Assisted Translation Mode**
  - Provide an optional integration hook where the transpiler can query an LLM (like py2many's LLM-assisted mode) to resolve highly dynamic or complex Python logic that strictly defies static compilation into V.

## Niche Syntax & Semantic Edge Cases (New Additions)
- [ ] **Python 3.13 `global` and `nonlocal` in Comprehensions**
  - *Context:* Python 3.13 allows `global` and `nonlocal` bindings inside list/dict/set comprehensions and generator expressions, removing the implicit function scope restrictions of older versions.
  - *V Translation:* Map these variables directly to the outer V scope, ensuring the V compiler tracks mutations correctly without creating intermediate closures.
- [ ] **PEP 688: Buffer Protocol Type Annotations (`collections.abc.Buffer`)**
  - *Context:* Python 3.12+ formalizes the `Buffer` type for objects exposing the C-level buffer protocol.
  - *V Translation:* Map `collections.abc.Buffer` to V's `[]u8` or a custom `unsafe { &u8 }` wrapper struct when transpiling systems-level Python code.
- [ ] **Asynchronous generator `athrow()` and `aclose()` (PEP 525 specifics)**
  - *Context:* While `async generators` are supported, the specific asynchronous injection methods `athrow` and `aclose` require careful handling in the generated V state machine.
  - *V Translation:* Implement an extended `AsyncPyGenerator[T]` struct in V with `throw()` and `close()` channels/methods that mirror the asynchronous teardown logic.
- [ ] **`sys.monitoring` API (PEP 669) Code Gen Markers**
  - *Context:* Python 3.12 introduced a low-impact monitoring API. While it is heavily CPython specific, the transpiler could use it conceptually.
  - *V Translation:* Provide a transpiler flag `--emit-tracing` that injects Vlang profiling/tracing hooks (like `println` or V's built-in `benchmark` tools) at the exact AST nodes corresponding to Python's `CALL`, `RETURN`, and `EXCEPTION` events.

## Mypy Plugin Integration & Type-Driven Optimizations
*(Leveraging the newly integrated `py2v_transpiler.core.mypy_plugin.VlangPlugin` and `types_for_vlang.json`)*
- [ ] **Type-Directed Operator Overloading**
  - *Context:* The transpiler currently supports operator overloading (`__add__`, etc.) dynamically via `Any`.
  - *V Translation:* Use the inferred mypy static types to generate direct, statically typed V operator calls (`+`, `-`, `*`) between primitive numeric types (e.g., `f64 * f64`) rather than boxing them into the `Any` sum type.
- [ ] **Static Subscript & Slicing Fast Paths**
  - *Context:* List/Tuple access and slicing currently map generically.
  - *V Translation:* If the mypy plugin definitively infers a variable as `list[int]`, generate native V array index access (`arr[i]`) and statically bound V slicing (`arr[start..end]`), bypassing dynamic runtime boundary checks on `Any` wrappers.
- [ ] **Strict Cast Elimination (`isinstance` / `typing.cast`)**
  - *Context:* Mypy provides exact narrowed type metadata.
  - *V Translation:* When a variable passes an `isinstance` check, or is wrapped in a `typing.cast`, use the mypy plugin data to emit direct V type casts (`x as int` or `x as string`) for the duration of that scope, eliminating redundant `match` or `.try_int()` calls on the custom `Any` type.
- [ ] **Pre-allocated Capacity for Typed Collections**
  - *Context:* If a collection's type is strictly known and populated with a set length.
  - *V Translation:* Utilize mypy's type inference on literals/tuples to initialize V arrays with exact capacities (`[]int{cap: N}`) during assignments like `arr = [x, y, z]`.
- [ ] **Monomorphization of Generic Classes (Mypy Driven)**
  - *Context:* Python doesn't inherently instantiate generic classes differently, but V requires it (e.g., `Box[int]`).
  - *V Translation:* When the mypy plugin records instantiation metadata for generic user classes (e.g., `Box(1)`), use that data to correctly map and emit the explicit V generic instantiation type `Box[int]`.
- [ ] **Static Duck Typing Mapping to V Interfaces**
  - *Context:* Python duck typing via `typing.Protocol` is inherently dynamic, but mypy proves its safety statically.
  - *V Translation:* When mypy confirms a function argument structurally matches a `Protocol`, generate V code that uses explicit, lightweight V `interface` casting instead of boxing everything into an `Any` wrapper with runtime method checks.
- [ ] **Loop Unrolling for Static `tuple` Lengths**
  - *Context:* Mypy can infer exact lengths and types of tuples (e.g., `tuple[int, str, float]`).
  - *V Translation:* When a `for` loop iterates over such a definitively typed static tuple, use the mypy data to unroll the loop during V transpilation, emitting sequential statically typed assignments rather than a dynamic V `for` loop over an `[]Any` array.
- [ ] **Compile-Time Evaluation of `typing.assert_type`**
  - *Context:* Python developers use `assert_type()` to verify mypy's understanding.
  - *V Translation:* Provide a dedicated AST node handler for `assert_type`. Verify that the transpiler's internal type mapping agrees with the mypy plugin's provided type; if it matches, strip the assertion entirely from the V code (zero runtime overhead).
- [ ] **Exhaustiveness Checking (`typing.assert_never`)**
  - *Context:* Used to ensure all branches of an `Enum` or `Union` are handled.
  - *V Translation:* When the AST contains `assert_never()`, use mypy's control-flow reachability data to verify dead code. Emit a compile-time V error (`$compile_error()`) or `panic()` if the transpiler logic detects the code could be reachable despite mypy's assumptions.
- [ ] **Type-Aware List Comprehension Pre-allocation**
  - *Context:* List comprehensions currently map to dynamic V arrays built via `<<`.
  - *V Translation:* If mypy can infer the exact length of the iterator (e.g., iterating over a static tuple or bounded range), generate an initially empty V array with the `cap:` set to the inferred length to avoid reallocation during the comprehension loop.
- [ ] **Strict Structural `TypedDict` Mapping**
  - *Context:* Python dictionaries can be highly dynamic, often falling back to `map[string]Any`.
  - *V Translation:* If mypy explicitly types a dictionary assignment/usage as a specific `TypedDict`, bypass the `map` entirely and emit it as an exact, unboxed V `struct` to ensure zero-overhead field access.
- [ ] **Generic Type Aliases Mapping (PEP 695)**
  - *Context:* Python 3.12+ introduced `type Alias[T] = dict[str, T]`.
  - *V Translation:* Leverage the mypy plugin to resolve these aliases statically and map them directly to V's generic type definitions (e.g., `type Alias[T] = map[string]T`), allowing subsequent variables to be defined natively.
- [ ] **`Any` Fallback Profiler / Strict Typing Mode**
  - *Context:* It's difficult for a user to know when their Python code failed to transpile into efficient V code due to missing type hints.
  - *V Translation:* Add a CLI flag (e.g., `--warn-dynamic`) that utilizes the mypy plugin's data to emit warnings indicating exactly which lines/variables fell back to the `Any` sum type, encouraging users to improve their Python type annotations for better V code emission.
- [ ] **Static Function Overload Resolution (`typing.overload`)**
  - *Context:* V does not support function overloading, making Python's `@overload` tricky to map directly.
  - *V Translation:* Use the mypy plugin to determine the exact matched overload signature at every *call site*. Generate uniquely named V functions for each signature (e.g., `func_int_int`, `func_str_str`) and emit direct calls to them, bypassing dynamic type introspection entirely.
- [ ] **Exact Mutability Mapping (`Final` / reassignments)**
  - *Context:* V variables default to immutable. Currently, the transpiler might over-use `mut` to be safe.
  - *V Translation:* Utilize mypy's reassignment tracking and `typing.Final` annotations. If mypy proves a variable is never reassigned after initialization, emit it without the `mut` keyword in V, relying on V's strict compiler to ensure immutability.
- [ ] **Config-Aware Nullability (`strict_optional`)**
  - *Context:* Mypy's `strict_optional` setting dictates whether `None` is a valid value for unannotated types.
  - *V Translation:* Hook into the user's `mypy.ini` or `pyproject.toml`. If `strict_optional = True`, map union types like `int | None` strictly to V optionals (`?int`). If `False`, rely on the `Any` wrapper with `none` tracking to match legacy Python semantics.
- [ ] **`typing.Literal` Mapping to V Enums / Constants**
  - *Context:* Python literals limit variables to specific values (e.g., `Literal["read", "write"]`).
  - *V Translation:* When mypy strictly enforces a `Literal` type over a specific set of strings or integers, automatically generate an internal V `enum` or emit compile-time V `const` bound checks, rather than passing arbitrary dynamic strings around.
- [ ] **`@dataclass` Perfect Field Inference**
  - *Context:* Mypy evaluates `dataclasses` perfectly, including default factories and `InitVar`.
  - *V Translation:* Use the mypy plugin data for `@dataclass` classes to entirely bypass Python-style `__init__` generation and `Any` field guessing, instead emitting exact V struct layouts and native V initialization blocks.
- [ ] **Dead Code Elimination via Reachability Analysis**
  - *Context:* Mypy tracks code reachability (e.g., after `assert False` or an impossible `if` condition).
  - *V Translation:* When mypy flags an AST node or block as unreachable, completely omit that block from the V output, preventing compilation of impossible branches.
- [ ] **Statically Typed `*args` and `**kwargs`**
  - *Context:* Variadic arguments default to highly dynamic processing.
  - *V Translation:* If mypy infers that variadic arguments are homogeneous (e.g., `*args: int`), emit them directly as explicit V arrays (`[]int`) or maps (`map[string]int`) rather than generic `[]Any` arrays, stripping out variadic wrapper overhead.
- [ ] **Exception Block Type Narrowing**
  - *Context:* Mypy knows the exact type(s) of an exception bound in `except Exception as e:`.
  - *V Translation:* Use the mypy data to strongly type the `e` variable in V's exception handling blocks, allowing direct access to the exception struct's fields without `Any` downcasting.

**Priority for Upcoming Releases:**
1. PEP 695 + 696 (Most requested feature for 2024-2025)
2. PEP 750 t-strings
3. PEP 758 bracketless except
4. Complete `try/except*` (Exception groups) emission
5. Docs + Tests