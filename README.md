# Python to Vlang Transpiler

A robust tool to transpile Python source code into [V](https://vlang.io/) code. This project aims to bridge the gap between Python's ease of development and V's performance and safety.

## Features

This transpiler supports a wide range of Python language features and standard library modules:

### Core Language Support
-   **Variables & Types**: Type inference using `mypy` (int, float, bool, str, lists, dicts, tuples, sets).
-   **Mypy Error Tips**: Translates common mypy error codes into actionable V-specific guidance to help fix type issues for better transpilation. Supported mappings:
    - `[union-attr]`: Guidance on type checking before attribute access.
    - `[arg-type]`: Strict argument typing requirements in V.
    - `[return-value]`: Matching return values to signatures.
    - `[assignment]`: Static typing and reassignment restrictions.
    - `[index]`: Integer index and map key type requirements.
    - `[attr-defined]`: Struct field and method existence.
    - `[operator]`: Operand type compatibility.
    - `[call-arg]`: Exact parameter count matching.
    - `[name-defined]`: Variable and function declaration scope.
    - `[misc]` (for TypeForm): Experimental feature warnings.
-   **Control Flow**: `if`, `elif`, `else`, `for`, `while`, `match`/`case` pattern matching.
-   **Generics (PEP 695/696)**: Support for PEP 695 syntax (e.g. `def foo[T](x: T): ...`), including support for `ParamSpec` (`**P`) and `TypeVarTuple` (`*Ts`) in classes and functions.
    - *Note on Limitations*: Due to V's current lack of native variadic generics and parameter specification variables, `ParamSpec` and `TypeVarTuple` are often erased to `Any` or simplified generic parameters in the generated V code.
-   **Functions**: Function definitions, arguments, return values, lambdas, and decorators.
-   **Object-Oriented Programming**: Classes, inheritance (via struct embedding), method overriding, `__init__`, and operator overloading (`__add__`, etc.).
-   **Syntactic Sugar**: List comprehensions, f-strings, walrus operator (`:=`), slice notation (`list[1:3]`).
-   **Keywords**: `global`, `nonlocal` (as comments), `assert`, `del` (partially mapped).

### Standard Library Mapping
-   **Built-ins**: `print`, `len`, `range`, `enumerate`, `zip`, `map`, `filter`, `any`, `all`, `reversed`, `sorted`, `input`, `isinstance`.
-   **Math**: Mappings for `math` module functions (`sqrt`, `sin`, `pi`, etc.).
-   **File I/O**: `open()` context managers (`with open(...)`) mapped to `os.open` with `defer { close() }`.
-   **Modules**: Support for `random`, `json`, `time`, `datetime`, `os`, `sys`, and basic regex (`re`).
-   **Pydantic**: Full support for `BaseModel`, `Field` validation, `ConfigDict`, validators (`@field_validator`, `@model_validator`), and automatic `.validate() !` method generation. See [Pydantic Support](docs/pydantic.md).

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
