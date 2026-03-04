# Feature Ideas for `py2v_transpiler`

Based on recent Python ecosystem developments (mypy, PyPy, Numba, NumPy, Nuitka, Codon, Cython, mypyc, Pyston, Taichi, Pyrefly, and Pyright), here are features that could be added or improved in the translator:



## From mypy Changelogs (Features & Syntax)
- [ ] **PEP 747: Annotating Type Forms (`TypeForm[T]`)**
  - Needs AST parsing support and mapping `TypeForm` to an appropriate V type or skipping it gracefully.
  - Parse `TypeForm[T]` in argument and return annotations.
  - *V Translation:* Since V lacks type reification, generate overloaded functions or use `Any` with runtime checks (optionally behind an `--experimental` flag).
  - Use `--enable-incomplete-feature=TypeForm` when running mypy for validation.
- [x] **PEP 800: Disjoint Base Classes (`@disjoint_base`)**
  - Add support for detecting `@disjoint_base` decorator.
- [x] **PEP 742: TypeIs (mypy 1.10+)**
  - *Context:* Improved type guard that narrows the type in both branches of a condition.
  - Recognize functions returning `TypeIs[T]` instead of `bool`.
  - *V Translation:* Generate an `if` with an automatic type cast inside the block (using narrowing info from mypy).
  - Differentiate from `TypeGuard`: `TypeIs` narrows in the `else`-branch (to the negation). Implement handling for both branches.
- [x] **PEP 696: Type Variable Defaults**
  - Support new Python 3.13 syntax for generic defaults: `class Box[T = int]: ...`
- [x] **PEP 702: `@deprecated` Decorator**
  - Transpile `warnings.deprecated` to V's `[deprecated]` attribute on functions/structs.
- [x] **Property Setters and Getters with Different Types**
  - Ensure the translator can handle and correctly emit V code when a `@property` and its `@foo.setter` have slightly mismatched type hints (e.g., returning `int` but accepting `str | int`).
  - Implemented: Union types in setters are mapped to `Any` in V, with runtime type checks using `is` operator.
  - Added comprehensive test suite in `test_property_mismatched_types.py`.
- [x] **`__getattr__`, `__setattr__`, `__delattr__` Support**
  - While V does not support fully dynamic attributes natively, consider adding a mechanism (e.g., a fallback `map[string]Any` inside the struct) to support dynamic attribute access where needed.
- [x] **Enum Membership Semantics (PEP 736/typing updates)**
  - Ensure transpiler correctly handles unannotated vs annotated Enum members based on new typing rules.
- [x] **PEP 705: ReadOnly in TypedDict (mypy 1.12+)**
  - *Context:* Marking TypedDict fields as immutable.
  - Detect the `ReadOnly` wrapper in field annotations.
  - *V Translation:* Generate struct fields as `const` or use getter methods (since V lacks built-in read-only semantics at the field level).
  - Emit a transpiler error if mypy complains about assignment to a `ReadOnly` field.
- [x] **PEP 675: LiteralString (improved support in mypy 1.14+)**
  - *Context:* A type for strings known at compile time (injection protection).
  - Detect `LiteralString` by tracking string origin: literal, literal concatenation, f-string without variables.
  - *V Translation:* Mark as `const string` if possible for optimization and safety.
  - Warn if a `LiteralString` variable receives a value from `input()` (loss of guarantee).

## Type Narrowing Improvements (Based on mypy 1.14–1.19)
- [x] **Index Narrowing in for-loops (mypy 1.14)**
  - *Context:* Mypy now preserves the literal type of loop variables (e.g., `for key in ("name", "age"):`).
  - Retrieve the narrowed literal type of the loop variable from the mypy AST.
  - *V Translation:* Generate more precise types instead of a generic `string`/`int`.
  - Optimize collection access: if mypy guarantees the key exists, generate direct access without an `in` check.
- [x] **Narrowing in match/case with union types (mypy 1.19)**
  - *Context:* Improved type narrowing inside class patterns with a union base.
  - Synchronize with mypy CFG: use control-flow info to determine the exact type in each `case`.
  - *V Translation:* Ensure V code uses the specific struct type inside `match` branches.
  - Support capture patterns with type narrowing (e.g., `case Point(x=int() as x_val)` -> `x_val` must be `int` in V).
- [x] **Attribute and Descriptor Narrowing**
  - If mypy narrowed an object's type, narrow the attribute's type during V generation (e.g., calling a subclass method after `isinstance`).
  - Add narrowing for descriptors (`__get__`, `__set__`): if a descriptor returns a specific type, use it in V.

## From PyPy Changelogs (Optimizations & Runtime Behaviors)
- [ ] **Atomic Groups and Possessive Repeats in Regex**
  - Review if V's `regex` module supports these constructs, and if not, how `py2v_transpiler` maps Python's `re` module calls for these features.
- [ ] **`OrderedDict` Performance**
  - Check how `collections.OrderedDict` is currently mapped. Since V's standard `map` is not guaranteed to be ordered, ensure `OrderedDict` maps to an ordered data structure in V if order is relied upon.
- [x] **String Methods on Tuples/Iterables (`str.startswith` with tuple)**
  - Python allows `s.startswith(('a', 'b'))`. Ensure the translator expands this to `s.starts_with('a') || s.starts_with('b')` in V.
- [ ] **Memoryview and Bytearray**
  - Implement translation for `memoryview()` and `bytearray()` (e.g., mapping to `[]u8` in V with appropriate mutable/immutable semantics).
- [ ] **Zlib / Encoding Optimizations**
  - Review how `zlib` and `str.encode`/`decode` are translated, ensuring they use the most efficient V standard library functions (`compress`, `encoding`).

## From Numba Changelogs (Optimizations & Advanced Types)
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
- [ ] **`NoneType` Empty Struct Representation**
  - Optimize Python's `None` by transpiling `NoneType` to an empty struct in V, which the compiler handles efficiently with zero runtime size, rather than using a heavy boxed object or generic pointer.
- [ ] **Union Types Transpilation**
  - Map Python `Union[A, B]` types (or `A | B`) properly into V's sum types (e.g., `type MyUnion = A | B`), with corresponding `match` statements for type checking.
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

## Language Features — High Priority (new syntax Python 3.12+)
- [ ] **PEP 695: Full type parameter syntax**
  - Support syntax like `def func[T](x: T) -> T: ...`, `class Box[T]: value: T`, `type Alias[T] = list[T]`.
  - Handle new AST nodes: `TypeVar`, `ParamSpec`, `TypeVarTuple`, `type_params` list.
- [x] **PEP 696: Type parameter defaults (Python 3.13+)**
  - Support generic defaults: `def foo[T = int](x: T): ...` or `class Container[T = list[int]]: ...`.
- [ ] **PEP 750: Template string literals (`t-strings`)**
  - Support `t"Hello {name=}"`, `T"Value: {value!r}"` by mapping the returned `Template` object to a custom string builder or interpolation mechanism in V.
- [x] **PEP 758: Bracketless `except` / `except*` clauses (Python 3.14)**
  - Support multi-exception syntax without parenthesis: `except ValueError, TypeError:` and `except* OSError, IOError:`.
- [ ] **PEP 649 / PEP 749: Deferred evaluation of annotations**
  - Now default in 3.14. Correctly handle `__annotations__` as deferred objects without requiring `from __future__ import annotations`.

## Advanced Syntax & Edge Cases
- [ ] **Full generics scoping & nesting**
  - Handle type params inside nested functions/classes and their interaction with closures.
- [ ] **`ParamSpec` + `TypeVarTuple`**
  - Support `**P` and `*Ts` in the new PEP 695 syntax.
- [ ] **Generic `match` patterns with type parameters**
  - E.g., `case Box[int](value=x):`.
- [ ] **Async generators / comprehensions with type parameters**
- [ ] **`__type_params__` runtime attribute support**
  - Support this for introspection or metaclass-like features.
- [ ] **Improved error recovery & source mapping for new syntax nodes**
  - Provide better line/column tracking in the V output.
- [ ] **Support for Python 3.14+ soft keywords / future syntax changes**
- [ ] **Variance in PEP 695 syntax (mypy 1.12+)**
  - *Context:* New syntax `class C[+T]` for covariance.
  - Parse variance modifiers: detect `+T` (covariant) and `-T` (contravariant) in type parameters.
  - *V Translation:* V generics do not explicitly support variance currently—document this limitation but preserve the annotation for future-proofing.
  - Emit an error before generating V code if mypy reports a variance violation.
- [ ] **Self types with generic context (PEP 673 + PEP 695)**
  - Ensure correct resolution of `Self` inside generic classes (e.g., `Self` expands to `Builder[T]`, not `Builder[Any]`).
  - *V Translation:* Methods must return the concrete `Builder[T]`, not a generic interface.
- [ ] **Mapping patterns with `**rest` (PEP 634+)**
  - Support `**kwargs` in pattern matching (e.g., `case {"host": str() as h, **rest}:`).
  - Parse mapping patterns with unpacking.
  - *V Translation:* Generate key extraction plus a residual `map[string]Any` for `**rest`.
- [ ] **OR-patterns in nested positions**
  - Recursive processing of `|` inside patterns (e.g., `case Point(0 | 1, y):`).
  - *V Translation:* Generate nested `match` or `if x == 0 || x == 1`.
- [ ] **Guard expressions with type narrowing**
  - Link guard conditions with narrowing (e.g., `case User(name=n) if len(n) > 5:`).
  - Use mypy to verify the guard doesn't contradict the type.
  - *V Translation:* Generate an `if` inside the `match` branch while preserving the narrowed type.
- [ ] **Type-directed code generation**
  - Use inferred mypy types to optimize V code.
  - If mypy infers `Literal[1, 2, 3]`, generate an `enum` in V instead of a generic `int`.
  - If the type is `tuple[int, str]`, generate a `struct { int, string }` with named fields (if a NamedTuple annotation exists).
- [ ] **"Strict syntax mode" for translation**
  - A mode requiring Python 3.12+ syntax.
  - Refuse to transpile old `Generic[T]` syntax, requiring the new `[T]` syntax (PEP 695).
  - Require explicit annotations wherever mypy in strict mode infers `Any`.
- [ ] **Better error mapping: mypy error codes → V tips**
  - Translate mypy error codes into understandable messages.
  - E.g., `[union-attr]` -> "In V, you must explicitly check the type before accessing a union attribute."
  - E.g., `[misc]` for `TypeForm` -> "Experimental feature, use --experimental."
- [ ] **F-string: New Python 3.12+ features**
  - Parse complex format-specs (e.g., `=` inside format spec, not just debug `x=`).
  - *V Translation:* V's `fmt` uses different specifiers—add a mapping table.
- [ ] **Type narrowing through attribute assignment**
  - Track mutations of narrowed variables.
  - If a variable can be changed after narrowing, drop the narrowed type.
  - *V Translation:* Generate a repeated check if V doesn't guarantee immutability.

## Infrastructure & Tooling
- [ ] **Documentation and Usage Examples**
  - Include examples for the new syntax and a Vlang interop guide.
- [ ] **Comprehensive test suite coverage for all new PEP syntax**
  - e.g., add a `tests/syntax_3_12_3_14/` suite.
- [ ] **CI matrix with Python 3.12–3.14**
  - Ensure AST compatibility across modern Python versions.
- [ ] **CLI flags for targets**
  - E.g., `--target-python=3.14` or `--strict-generics`.

## Nice-to-have (syntax only)
- [ ] **Support for future Python 3.15+ syntax**
  - Monitor the PEP queue for upcoming changes.
- [ ] **Better V-specific optimizations for generics**
  - E.g., monomorphization hints or inlining where possible.
- [ ] **Source-to-source fidelity mode**
  - Preserve original comments and formatting as much as possible.

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
- [x] **Type-Directed Operator Overloading**
  - *Context:* The transpiler currently supports operator overloading (`__add__`, etc.) dynamically via `Any`.
  - *V Translation:* Use the inferred mypy static types to generate direct, statically typed V operator calls (`+`, `-`, `*`) between primitive numeric types (e.g., `f64 * f64`) rather than boxing them into the `Any` sum type.
- [x] **Static Subscript & Slicing Fast Paths**
  - *Context:* List/Tuple access and slicing currently map generically.
  - *V Translation:* If the mypy plugin definitively infers a variable as `list[int]`, generate native V array index access (`arr[i]`) and statically bound V slicing (`arr[start..end]`), bypassing dynamic runtime boundary checks on `Any` wrappers.
- [x] **Strict Cast Elimination (`isinstance` / `typing.cast`)**
  - *Context:* Mypy provides exact narrowed type metadata.
  - *V Translation:* When a variable passes an `isinstance` check, or is wrapped in a `typing.cast`, use the mypy plugin data to emit direct V type casts (`x as int` or `x as string`) for the duration of that scope, eliminating redundant `match` or `.try_int()` calls on the custom `Any` type.
- [x] **Pre-allocated Capacity for Typed Collections**
  - *Context:* If a collection's type is strictly known and populated with a set length.
  - *V Translation:* Utilize mypy's type inference on literals/tuples to initialize V arrays with exact capacities (`[]int{cap: N}`) during assignments like `arr = [x, y, z]`.
- [ ] **Monomorphization of Generic Classes (Mypy Driven)**
  - *Context:* Python doesn't inherently instantiate generic classes differently, but V requires it (e.g., `Box[int]`).
  - *V Translation:* When the mypy plugin records instantiation metadata for generic user classes (e.g., `Box(1)`), use that data to correctly map and emit the explicit V generic instantiation type `Box[int]`.
- [x] **Static Duck Typing Mapping to V Interfaces**
  - *Context:* Python duck typing via `typing.Protocol` is inherently dynamic, but mypy proves its safety statically.
  - *V Translation:* When mypy confirms a function argument structurally matches a `Protocol`, generate V code that uses explicit, lightweight V `interface` casting instead of boxing everything into an `Any` wrapper with runtime method checks.
- [ ] **Loop Unrolling for Static `tuple` Lengths**
  - *Context:* Mypy can infer exact lengths and types of tuples (e.g., `tuple[int, str, float]`).
  - *V Translation:* When a `for` loop iterates over such a definitively typed static tuple, use the mypy data to unroll the loop during V transpilation, emitting sequential statically typed assignments rather than a dynamic V `for` loop over an `[]Any` array.
- [x] **Compile-Time Evaluation of `typing.assert_type`**
  - *Context:* Python developers use `assert_type()` to verify mypy's understanding.
  - *V Translation:* Provide a dedicated AST node handler for `assert_type`. Verify that the transpiler's internal type mapping agrees with the mypy plugin's provided type; if it matches, strip the assertion entirely from the V code (zero runtime overhead).
- [x] **Exhaustiveness Checking (`typing.assert_never`)**
  - *Context:* Used to ensure all branches of an `Enum` or `Union` are handled.
  - *V Translation:* When the AST contains `assert_never()`, use mypy's control-flow reachability data to verify dead code. Emit a compile-time V error (`$compile_error()`) or `panic()` if the transpiler logic detects the code could be reachable despite mypy's assumptions.
- [x] **Type-Aware List Comprehension Pre-allocation**
  - *Context:* List comprehensions currently map to dynamic V arrays built via `<<`.
  - *V Translation:* If mypy can infer the exact length of the iterator (e.g., iterating over a static tuple or bounded range), generate an initially empty V array with the `cap:` set to the inferred length to avoid reallocation during the comprehension loop.
- [x] **Strict Structural `TypedDict` Mapping**
  - *Context:* Python dictionaries can be highly dynamic, often falling back to `map[string]Any`.
  - *V Translation:* If mypy explicitly types a dictionary assignment/usage as a specific `TypedDict`, bypass the `map` entirely and emit it as an exact, unboxed V `struct` to ensure zero-overhead field access.
- [x] **Generic Type Aliases Mapping (PEP 695)**
  - *Context:* Python 3.12+ introduced `type Alias[T] = dict[str, T]`.
  - *V Translation:* Leverage the mypy plugin to resolve these aliases statically and map them directly to V's generic type definitions (e.g., `type Alias[T] = map[string]T`), allowing subsequent variables to be defined natively.
- [x] **`Any` Fallback Profiler / Strict Typing Mode**
  - *Context:* It's difficult for a user to know when their Python code failed to transpile into efficient V code due to missing type hints.
  - *V Translation:* Add a CLI flag (e.g., `--warn-dynamic`) that utilizes the mypy plugin's data to emit warnings indicating exactly which lines/variables fell back to the `Any` sum type, encouraging users to improve their Python type annotations for better V code emission.
- [x] **Static Function Overload Resolution (`typing.overload`)**
  - *Context:* V does not support function overloading, making Python's `@overload` tricky to map directly.
  - *V Translation:* Use the mypy plugin to determine the exact matched overload signature at every *call site*. Generate uniquely named V functions for each signature (e.g., `func_int_int`, `func_str_str`) and emit direct calls to them, bypassing dynamic type introspection entirely.
- [ ] **Exact Mutability Mapping (`Final` / reassignments)**
  - *Context:* V variables default to immutable. Currently, the transpiler might over-use `mut` to be safe.
  - *V Translation:* Utilize mypy's reassignment tracking and `typing.Final` annotations. If mypy proves a variable is never reassigned after initialization, emit it without the `mut` keyword in V, relying on V's strict compiler to ensure immutability.
- [x] **Config-Aware Nullability (`strict_optional`)**
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
- [x] **Statically Typed `*args` and `**kwargs`**
  - *Context:* Variadic arguments default to highly dynamic processing.
  - *V Translation:* If mypy infers that variadic arguments are homogeneous (e.g., `*args: int`), emit them directly as explicit V arrays (`[]int`) or maps (`map[string]int`) rather than generic `[]Any` arrays, stripping out variadic wrapper overhead.
- [x] **Exception Block Type Narrowing**
  - *Context:* Mypy knows the exact type(s) of an exception bound in `except Exception as e:`.
  - *V Translation:* Use the mypy data to strongly type the `e` variable in V's exception handling blocks, allowing direct access to the exception struct's fields without `Any` downcasting.

**Priority for Upcoming Releases:**
1. PEP 695 + 696 (Most requested feature for 2024-2025)
2. PEP 750 t-strings
3. PEP 758 bracketless except
4. Complete `try/except*` (Exception groups) emission
5. Docs + Tests
## Analysis of `bm_deltablue.py` Transpilation Issues
Based on the transpilation of the `bm_deltablue.py` benchmark, several critical areas for improvement have been identified:

- [x] **Polymorphism and Interfaces (`@abstractmethod` and Inheritance)**
  - *Context:* Python abstract base classes (e.g., `Constraint`) and their concrete implementations (`UrnaryConstraint`, `BinaryConstraint`) are currently transpiled using V struct embedding. However, V struct embedding does not support dynamic virtual method dispatch.
  - *Task:* Detect polymorphic base classes (especially those with `@abstractmethod`) and transpile them to V `interface`s, ensuring that method calls on base types dynamically dispatch to the concrete structs.

- [x] **Constructors and `super().__init__` Handling**
  - *Context:* `super(StayConstraint, self).__init__(v, string)` is incorrectly emitted as `self.UrnaryConstraint.__init__(v, string)` inside a factory function where `self` is not even defined or allocated.
  - *Task:* Refactor constructor generation so that derived classes properly instantiate and return their base/embedded structs (e.g., `return StayConstraint{ UrnaryConstraint: new_UrnaryConstraint(...) }`), rather than relying on non-existent `__init__` methods.

- [x] **Global Variables and Module-Level Constants**
  - *Context:* Module-level constants like `REQUIRED = Strength(...)` and mutable globals like `planner = None` are currently incorrectly placed inside the generated `fn main()` block, making them inaccessible to the methods that reference them.
  - *Task:* Implement an AST pass to extract module-level assignments. Immutable constants should be emitted as V `const (...)` blocks. Mutable globals (e.g., accessed via Python `global` keyword) should be mapped to `__global` or a shared state struct in V.

- [x] **Type Aliasing without Generics (`OrderedCollection = list`)**
  - *Context:* `OrderedCollection = list` defaults to `type OrderedCollection = []int`, which fails when the list is meant to hold objects like `Constraint` or `Variable`.
  - *Task:* Improve type inference for type aliases of collections by analyzing append/usage sites, or fallback to `[]Any` (or the sum type) when the inner type cannot be statically resolved.

- [x] **Base `object` Class Cleanup**
  - *Context:* `class Strength(object):` results in `struct Strength { object }`, but `object` is not a standard type in V.
  - *Task:* Automatically strip `object` from the base class list during struct generation.

- [x] **Class Instantiation Fallbacks**
  - *Context:* While factory functions like `new_Strength` are generated, some instantiations are emitted as `Strength(0, 'required')` which fails to compile in V.
  - *Task:* Ensure that all class instantiation AST nodes consistently map to either `new_ClassName(...)` or `ClassName{...}`.

- [x] **Type Casts to `float`**
  - *Context:* Python's `float(j)` is emitted directly as `float(j)`.
  - *Task:* Map the Python `float` builtin explicitly to V's `f64` (i.e., `f64(j)`).

- [x] **Magic Methods Mapping (`__len__`, `__getitem__`)**
  - *Context:* Magic methods are emitted with their literal names (e.g., `fn (self Plan) __len__() int`).
  - *Task:* Transpile `__len__` to V's idiomatic `.len()` methods (or expose as a length property) and `__getitem__` to V's index operator overloading (e.g., `fn (self Plan) idx(index int) Constraint`).

- [x] **`None` Initialization**
  - *Context:* `planner = None` emits `planner := none`, which is invalid in V without an explicit Option type (`?Type`).
  - *Task:* Enforce that variables initialized to `None` are explicitly typed as V Optionals (e.g., `mut planner := ?Planner(none)` or fallback to `?Any(none)`).

## Analysis of `bm_hexiom.py` Transpilation Issues
Based on the transpilation of the `bm_hexiom.py` benchmark, several critical areas for improvement have been identified:

- [x] **Inline List and Generator Comprehensions**
  - *Context:* Comprehensions such as `[self.cells[i][:] for i in range(self.count)]` and generator expressions inside functions like `max(...)` or `sum(...)` emit `/* unknown */` or `// List comprehension expression not supported inline yet`.
  - *Task:* Implement full support for inline list comprehensions and generator expressions, mapping them to V's `map`/`filter` array methods, or extracting them into inline loops or closure helpers.

- [x] **`six` Module and Legacy Compatibility Helpers**
  - *Context:* Functions from `six` (`u as u_lit`, `text_type`) are emitted directly, resulting in undefined V functions.
  - *Task:* Add AST node interception or standard library mapping for common `six` module utilities, translating `text_type(x)` to `x.str()` and bypassing `u_lit` wrappers for string literals.

- [x] **Type Inference for Module-Level Dictionaries and Tuple Values**
  - *Context:* The `LEVELS` global dictionary is inferred as `map[string]int{}`, but is populated with integer keys and string-tuple values (e.g., `LEVELS[2] = ("...", "...")`).
  - *Task:* Improve type inference for dictionaries populated by subsequent index assignments (`dict[key] = value`). Correctly map Python tuples to V structs, arrays, or multiple return values when used as dictionary values.

- [x] **Module-Level Dictionary Initialization Scope**
  - *Context:* `LEVELS[2] = ...` assignments are placed inside the generated `fn main()`, trapping the global state in a local scope.
  - *Task:* Ensure that module-level collection mutations (like dict assignments) are placed in a V `fn init()` block or a `__global` initialization routine so that global constants are properly populated and accessible to other functions.

- [x] **`StringIO` and `IO` Type Mappings**
  - *Context:* `bm_hexiom.py` uses `StringIO` for stream output, which maps directly to undefined `StringIO` and `IO[string]` types in V.
  - *Task:* Map `io.StringIO` (and `six.moves.StringIO`) to V's `strings.Builder`. Map `IO[str]` to `&strings.Builder` or an appropriate stream interface in V.

- [x] **Modulo `%` String Formatting**
  - *Context:* Python's string formatting `"%s " % c` is emitted directly as `'%s ' % c`, which is invalid syntax in V.
  - *Task:* Intercept the `%` binary operator when the left operand is a string, and transpile it to V's string interpolation (e.g., `'$c '`) or generate calls using V's `fmt` module.

## Analysis of `bm_raytrace.py` Transpilation Issues
Based on the transpilation of the `bm_raytrace.py` benchmark, several critical areas for improvement have been identified:

- [x] **Magic Methods with Overloads (`__add__`, `__sub__`, etc.)**
  - *Context:* Python's magic methods like `__add__` with `@overload` are currently emitted as uniquely named functions (e.g., `__add___Vector` or `__add___Point`) instead of V's overloaded operators (`+`). Normal magic methods like `__sub__` correctly map to V's `-` operator, but overloaded ones do not fallback or combine into operator overloads properly.
  - *Task:* Ensure that when overloaded magic methods are encountered, they map correctly to V's operator overloading syntax (e.g. `fn (a Vector) + (b Vector) Vector`), generating multiple overloaded operators if V supports them, or handling type disjunctions cleanly.

- [x] **Duplicate Global Variable Emission (`Final`)**
  - *Context:* Module-level variables defined as `Final` and instantiated (e.g., `Vector_ZERO: Final = Vector(0, 0, 0)`) are emitted multiple times inside `fn main()` in the transpiled output.
  - *Task:* Fix the bug in the module/variable visitation logic to prevent duplicate generation of `Final` or uppercase module-level constants.

- [x] **Global Constants Placement (`const`)**
  - *Context:* Constants like `DEFAULT_WIDTH := 100` and `Vector_ZERO := new_Vector(0, 0, 0)` are placed inside the generated `fn main()` block rather than an appropriate V `const ( ... )` block or global state.
  - *Task:* Refactor module-level assignment handling so that constants (e.g., `Final` or uppercase variables) are correctly emitted in a V `const` block (if compile-time evaluable) or an `init` block/global struct (if they require runtime instantiation like `new_Vector`).

- [x] **Duplicate Method Generation (`__str__` and `__repr__`)**
  - *Context:* Both `__str__` and `__repr__` methods on a Python class map to V's `.str() string` method, leading to compilation errors due to duplicate method declarations (e.g., `fn (self Vector) str() string { ... }` defined twice).
  - *Task:* Handle duplicate V method mapping by either combining `__str__` and `__repr__`, taking precedence of `__str__` over `__repr__`, or renaming `__repr__` to `repr()` instead of mapping both to `.str()`.

- [x] **Class Instantiation Fallbacks in Method Returns**
  - *Context:* Inside methods like `__add__` and `__sub__`, the transpiled code emits returns like `return Point(...)` instead of `return new_Point(...)` or `return Point{...}`, which fails to compile in V because `Point(...)` is invalid syntax for struct initialization or function calls unless it's a cast.
  - *Task:* Ensure that instantiation of objects within internal methods correctly tracks class names and forces `new_ClassName(...)` or `ClassName{...}` syntax as it does in standard assignments.

## Analysis of `primes.py` Transpilation Issues
Based on the transpilation of the `primes.py` benchmark, several critical areas for improvement have been identified:

- [ ] **Array Multiplication for Initialization (`[False] * (limit + 1)`)**
  - *Context:* Python's `[False] * (limit + 1)` is currently transpiled as `[false] * limit + 1`. This is invalid V syntax for array initialization and loses the parentheses.
  - *Task:* Map Python array multiplication (when the left operand is a single-element list) to V's array initialization syntax: `[]bool{len: limit + 1, init: false}`. Ensure parentheses around binary operations are correctly preserved during unparsing.

- [x] **Parentheses Preservation in Boolean Expressions**
  - *Context:* Python's `n <= self.limit and (n % 12 == 1 or n % 12 == 5)` drops the parentheses around the `or` clause in V: `n <= self.limit && n % 12 == 1 || n % 12 == 5`. This changes operator precedence.
  - *Task:* Ensure the AST transpilation correctly preserves grouping parentheses for binary and boolean operations.

- [x] **Dictionary Type Inference (`self.children = {}`)**
  - *Context:* In `Node.__init__`, `self.children = {}` causes `self.children` to be inferred as `map[string]int{}`, which is incorrect since it stores `Node` instances later.
  - *Task:* Improve type inference for empty dictionaries by analyzing subsequent dictionary assignments (like `head.children[ch] = Node()`) to infer the correct value type (`map[string]Node`).

- [x] **String Iteration (`for ch in str(el):`)**
  - *Context:* Iterating over a string in V yields bytes (`u8`), but the Python code expects string characters to be used as map keys (`head.children[ch]`).
  - *Task:* Handle string iteration correctly by mapping the iterated byte to a string (e.g., using a custom iterator or `.ascii_str()`) when the string semantics are required.

- [x] **Truth Value Testing for Arrays/Queues (`while queue:`)**
  - *Context:* `while queue:` is transpiled directly to `for queue {`, which is invalid in V.
  - *Task:* Map truth value testing of collections (lists, dicts, etc.) to explicit `.len > 0` checks in V (e.g., `for queue.len > 0 {`).

- [x] **Iterating over Dictionary Items (`for ch, v in top.children.items():`)**
  - *Context:* Emits `for [ch, v] in top.children.items() {` which is not idiomatic V.
  - *Task:* Map `.items()` iteration on maps directly to V's native map iteration syntax: `for ch, v in top.children {`.

- [x] **String to Integer Conversion (`int(prefix)`)**
  - *Context:* `int(prefix)` where `prefix` is a string is emitted literally, but V requires `prefix.int()`.
  - *Task:* Map `int()` casts on string variables to the `.int()` method in V.

- [x] **String `bytes()` Encoding**
  - *Context:* `bytes(msg, "utf8")` is emitted as `bytes(msg, 'utf8')`.
  - *Task:* Map `bytes(string, encoding)` to V's native `string.bytes()` method.

- [x] **`sys.stderr` Redirection (`print(..., file=sys.stderr)`)**
  - *Context:* `print` statements with `file=sys.stderr` are transpiled to standard `println`.
  - *Task:* Recognize `file=sys.stderr` in `print` calls and map them to V's `eprintln`.

- [x] **Missing Modules (`platform`)**
  - *Context:* `platform.python_implementation()` is emitted directly but `platform` doesn't exist in V.
  - *Task:* Provide an AST mapping or standard library mock for `platform.python_implementation()` returning `'V'` or similar.
## Analysis of `bm_spectral_norm.py` Transpilation Issues
Based on the transpilation of the `bm_spectral_norm.py` benchmark, several critical areas for improvement have been identified:

- [x] **Parentheses Dropped in Binary Operations**
  - *Context:* The Python expression `(i + j) * (i + j + 1) // 2` is transpiled to `int(math.floor(f64(i + j * i + j + 1) / f64(2)))`, completely dropping the required parentheses and changing the mathematical logic.
  - *Task:* Ensure that AST grouping parentheses are preserved or reconstructed during binary operation transpilation.

- [x] **Inline List Comprehensions**
  - *Context:* `[func((i, u)) for i in xrange(len(list(u)))]` emits `// List comprehension expression not supported inline yet` and returns `None` (which is invalid in V).
  - *Task:* Implement full support for inline list comprehensions, either mapping them to V's array methods (`.map()`, `.filter()`) or extracting them into inline closures or helper variables.

- [x] **List Replication (`[x] * N`)**
  - *Context:* `[1] * DEFAULT_N` is emitted directly as `[1] * DEFAULT_N`, which is not valid V array repetition syntax.
  - *Task:* Transpile Python list repetition into V's array initialization syntax with `len` and `init` (e.g., `[]int{len: DEFAULT_N, init: 1}`).

- [x] **`six.moves` and `itertools` Compatibility**
  - *Context:* Functions `xrange` and `izip` from `six.moves` are emitted directly without mapping, causing undefined function errors in V.
  - *Task:* Map `xrange` to V ranges (e.g., `0 .. loops`) or a range generator. Map `izip` (and `zip`) to V's `arrays.zip()` or handle simultaneous iteration natively.

- [x] **Destructuring in `for` loops**
  - *Context:* `for ue, ve in izip(u, v):` emits `for [ue, ve] in izip(u, v) {`, which is invalid V syntax.
  - *Task:* Fix tuple unpacking syntax inside V `for` loop assignments, likely requiring translation to indexed loops or `arrays.zip()`.

- [x] **`time.time()` Precision Mapping**
  - *Context:* `time.time()` maps to `time.now().unix()`, returning an integer (seconds), losing the fractional millisecond precision expected in Python benchmarking.
  - *Task:* Map `time.time()` to a V equivalent that returns an `f64` timestamp, such as `f64(time.now().unix_time_milli()) / 1000.0`.

## Analysis of `bm_richards.py` Transpilation Issues
Based on the transpilation of the `bm_richards.py` benchmark, several critical areas for improvement have been identified:

- [x] **V Keyword Collision (`fn`)**
  - *Context:* Python method named `fn` (e.g., `def fn(self, pkt, r):`) is transpiled directly as `fn (self Task) fn(...)`, which causes a syntax error in V because `fn` is a reserved keyword.
  - *Task:* Implement an AST sanitization pass to rename or prefix Python identifiers that conflict with Vlang reserved keywords (e.g., mapping `fn` to `fn_` or `py_fn`).

- [x] **Array Initialization with `[None] * N`**
  - *Context:* Python's `[None] * TASKTABSIZE` is emitted directly as `[none] * TASKTABSIZE`, which is invalid V syntax for initializing arrays.
  - *Task:* Transpile list repetitions containing `None` into proper V array initialization (e.g., `[]?Task{len: TASKTABSIZE, init: none}`).

- [x] **Scoping Issues with `if/else` Variable Assignments**
  - *Context:* In `Task.runTask()`, a variable `msg` is initialized conditionally in `if/else` blocks (e.g., `msg := self.input` in `if`, `mut msg := ?int(none)` in `else`), making it inaccessible outside the blocks when passed to `return self.fn(msg, self.handle)`.
  - *Task:* Improve variable scoping generation. If a variable is conditionally declared and used outside the condition, pre-declare it as `mut` before the `if/else` block (e.g., `mut msg := ?Packet(none)`).

- [x] **`Optional` Type Inference with Forward References (`'Packet'`)**
  - *Context:* Mypy forward references like `Optional['Packet']` (or `Optional['Task']`) are failing to map accurately in the `else` block fallback type generation, falling back to `?int(none)` instead of `?Packet(none)`.
  - *Task:* Update type mapping to correctly resolve and strip string quotes from forward reference annotations like `'Packet'` so they properly map to their concrete V types.

- [x] **Explicit Base Class Constructor Calls (`Base.__init__`)**
  - *Context:* Calls like `Task.__init__(self, i, p, w, s, r)` are emitted directly, which doesn't correctly update the embedded V struct unless the explicit embedded struct is initialized or fields are copied.
  - *Task:* Refactor explicit `BaseClass.__init__(self, ...)` calls to properly initialize the embedded struct fields inside the derived V struct.

## Analysis of `pi_test.py` Transpilation Issues
Based on the transpilation of the `pi_test.py` script, the following area for improvement has been identified:

- [x] **`decimal` module support**
  - *Context:* Python's `decimal` module is used for arbitrary-precision decimal arithmetic. The transpiler currently translates `decimal.localcontext()` directly and `decimal.Decimal` as `py_decimal`, but there's no native equivalent or mapping for arbitrary precision decimals in V standard library out of the box used here correctly.
  - *Task:* Implement mapping for Python's `decimal` module, potentially utilizing a V library for arbitrary precision arithmetic or BigInts, and correctly mapping context managers like `localcontext`.

## Analysis of `mypy_stubs` Transpilation Issues
Based on the transpilation of the `mypy_stubs` tests, the following critical area for improvement has been identified:

- [ ] **`Protocol[T]` and Generic Subscript Base Class Handling**
  - *Context:* When a class inherits from a parameterized protocol like `class Iterable(Protocol[T_co]):`, the transpiler fails to recognize `Protocol[T_co]` as a protocol because it checks for `ast.Name` (`Protocol`) but not `ast.Subscript`. Consequently, it treats it as a regular generic base, fails to set `is_protocol = True`, and generates a standard V `struct` instead of an `interface`. Furthermore, generic type parameters are only extracted when the base name is exactly `"Generic"`, so classes inheriting from `Protocol[T]` lose their generic parameters, leading to V compiler errors like `generic error: struct 'main.Awaitable' is not a generic struct`.
  - *Task:* Update `ClassesMixin.visit_ClassDef` to check for `"Protocol"` and `"typing.Protocol"` in `ast.Subscript` bases, properly setting `is_protocol = True` and extracting generic type parameters (similar to how `"Generic"` is currently handled). Ensure that these parameterized protocol bases are omitted from the generated struct/interface fields.
