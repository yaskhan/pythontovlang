# Python to Vlang Transpiler

A robust tool to transpile Python source code into [V](https://vlang.io/) code. This project aims to bridge the gap between Python's ease of development and V's performance and safety.

## Current Limitations

The transpiler is under active development. Below are some of the current limitations and known issues when transpiling Python to V:

### Type System & Inference
- **SumType Narrowing**: V requires explicit type narrowing (flow-sensitive typing) for SumTypes (unions) before accessing type-specific methods or operators.
- **Generic Field Hardcoding**: In some cases, generic class fields may have hardcoded types instead of the generic parameter.
- **NoneType Handling**: Direct assignment of `None` to typed variables or explicit `NoneType` checks may produce invalid V syntax like `Any(NoneType{})`.

### Functions & Closures
- **Default Parameters**: Python's default parameter values are not always correctly mapped to V's optional arguments.
- **Variadic Arguments**: Support for `*args` and `**kwargs` is limited; `*args` are often converted to slices which must be the last parameter in V.
- **Lambdas**: Default values in lambdas may be lost, and late binding in list comprehensions is not currently preserved.
- **Decorators**: Custom decorators may generate warnings and produce code that requires manual adjustment.

### Control Flow & Data Structures
- **For/Else**: The `else` clause in a `for` loop always executes, regardless of whether a `break` was encountered.
- **Tuple Destructuring**: Index-based destructuring of heterogeneous tuples (TupleStructs) sometimes uses invalid `[]` syntax instead of `.it_n`.
- **List Operations**: `list.extend()` may incorrectly add a list as a single element (`<<`) rather than extending it.
- **Set/Dict Comprehensions**: Some advanced comprehension semantics are still being refined.

### Standard Library & Built-ins
- **String Formatting**: `str.format()` and `str.format_map()` are not supported. Use V's native string interpolation (`'${var}'`).
- **Async/Await**: Asynchronous programming features are not currently supported.
- **Exception Handling**: `try/except` blocks may require external libraries (like `div72.vexc`) and are not fully idiomatic.

## Installation

### Prerequisites
-   Python 3.10+
-   `mypy` (for type inference)

### From Source

1.  Clone the repository:
    ```bash
    git clone https://github.com/yaskhan/pythontovlang.git
    cd pythontovlang
    ```

2.  Install the package:
    ```bash
    pip install .
    ```

    For development (includes test dependencies):
    ```bash
    pip install -e .[dev]
    ```

## Usage

You can use the transpiler via the installed command `py2v` or directly via python module.

### Basic Usage

Transpile a single file:
```bash
py2v path/to/script.py
```
This generates `path/to/script.v` next to the source file.

### Recursive Directory Processing

Transpile all Python files in a directory recursively:
```bash
py2v path/to/project/ --recursive
```

### Dependency Analysis

Analyze imports in a project to check topology:
```bash
py2v --analyze-deps path/to/project/
```

### CLI Options

-   `-r`, `--recursive`: Process directories recursively.
-   `--analyze-deps`: Analyze import dependencies for a directory instead of transpiling.
-   `--warn-dynamic`: Enables the strict typing profiler. It emits warnings indicating exactly which lines/variables fell back to the `Any` dynamic sum type during transpilation.
-   `--no-helpers`: Do not generate files containing helper functions and types. Only emits the transpiled V code for the source scripts.
-   `--helpers-only`: Only generate the helper file (e.g. `py2v_helpers.v`) by accumulating required helper functions across the processed files. Does not emit the actual transpiled `.v` script files. Useful for large projects to generate a single common helper library.

## Architecture

The project follows a pipeline architecture:

1.  **Parser (`core/parser.py`)**: Wraps Python's `ast` module to generate an Abstract Syntax Tree.
2.  **Analyzer (`core/analyzer.py`)**: Uses `mypy` to perform static type analysis and annotate the AST with type information.
3.  **Translator (`core/translator.py`)**: Traverses the AST (Visitor pattern) and translates Python nodes to V code strings. It uses `StdLibMapper` to resolve library calls.
4.  **Mapper (`stdlib_map/mapper.py`)**: Handles mapping of Python standard library modules/functions to their V equivalents.
5.  **Generator (`core/generator.py`)**: Emits the final V source code, managing imports and structure.

See [AGENTS.md](AGENTS.md) for development guidelines.

## Testing

Run the comprehensive test suite using `pytest`:

```bash
python -m pytest
```
