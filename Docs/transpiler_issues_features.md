# Py2V Transpiler Features Issues

The following issues were identified while transpiling Python code containing specific core language features such as lambdas, generators, and multiple inheritance.

### 1. Missing Standard Type Definitions for Generators (`PyGeneratorInput` and `PyGenerator`)
**Description:**
When translating Python generators (`yield` statements), the transpiler implements this via V channels (using `spawn` and `chan`). However, it relies on generated runtime helper types like `PyGeneratorInput` and `PyGenerator[T]`, which are entirely missing from the resulting `test_features.v` module context. These helper types are expected to be available, but since they are missing, the V compiler throws unknown type and struct errors.

**Expected Behavior:**
The transpiler should properly emit the definitions for `PyGeneratorInput` and `PyGenerator[T]` within the generated file or as an automatically included/imported helper module that compiles alongside the main file.

**Output from V compiler:**
```
test_features.v:12:47: error: unknown type `PyGeneratorInput`.
   10 |     return fn (x int) int { return x * -1 }
   11 | }
   12 | pub fn my_counter(ch_out chan int, ch_in chan PyGeneratorInput, n int) {
      |                                               ~~~~~~~~~~~~~~~~~~~~~

test_features.v:35:14: error: unknown struct: PyGenerator[int]
   33 |     ch_1 := chan int{cap: 0}
   34 |     ch_in_1 := chan PyGeneratorInput{cap: 0}
   35 |     gen_1 := PyGenerator[int]{out: ch_1, in_: ch_in_1}
      |              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

### 2. Invalid Optional Channel Syntax (`chan ?int`)
**Description:**
When translating a generator that yields integers, the transpiler creates the output channel with the signature `chan ?int` (an optional integer channel). In modern V, you cannot specify a channel of an optional type directly in this way without a type alias or explicitly boxing it, resulting in the compiler error ``chan` has no type specified. Use `chan Type` instead of `chan``.

**Expected Behavior:**
The transpiler should omit the optional `?` when defining the channel for the generator if it isn't strictly necessary, or it should use a named sum type / struct to box the optional yield value.

**Output from V compiler:**
```
test_features.v:12:26: error: `chan` has no type specified. Use `chan Type` instead of `chan`
   10 |     return fn (x int) int { return x * -1 }
   11 | }
   12 | pub fn my_counter(ch_out chan ?int, ch_in chan PyGeneratorInput, n int) {
      |                          ~~~~
```

### 3. Multiple Inheritance Missing Methods
**Description:**
Python multiple inheritance (e.g., `class ApplicationService(LoggerMixin, DatabaseHandler)`) transpiles down to V by using struct embedding. However, the first base class (`LoggerMixin`) is completely missing from the generated `ApplicationService` struct embedding, while the second one (`DatabaseHandler`) is included.

**Generated output for structs:**
```v
pub struct DatabaseHandler {
}
pub struct ApplicationService {
    DatabaseHandler
}
// LoggerMixin is missing entirely!
```

This indicates the transpiler struggles with properly mapping multiple parent classes via struct embedding, silently dropping parts of the inheritance tree, which will cause method resolution failures at runtime when the embedded method isn't copied over.