# Python to Vlang Transpiler

A robust tool to transpile Python source code into [V](https://vlang.io/) code. This project aims to bridge the gap between Python's ease of development and V's performance and safety.

## Features

This transpiler supports a wide range of Python language features and standard library modules:

### Core Language Support
-   **Variables & Types**: Type inference using `mypy` (int, float, bool, str, lists, dicts, tuples, sets).
-   **Control Flow**: `if`, `elif`, `else`, `for`, `while`, `match`/`case` pattern matching.
-   **Functions**: Function definitions, arguments, return values, lambdas, and decorators.
-   **Object-Oriented Programming**: Classes, inheritance (via struct embedding), method overriding, `__init__`, and operator overloading (`__add__`, etc.).
-   **Syntactic Sugar**: List comprehensions, f-strings, walrus operator (`:=`), slice notation (`list[1:3]`).
-   **Keywords**: `global`, `nonlocal` (as comments), `assert`, `del` (partially mapped).

### Standard Library Mapping
-   **Built-ins**: `print`, `len`, `range`, `enumerate`, `zip`, `map`, `filter`, `any`, `all`, `reversed`, `sorted`, `input`, `isinstance`.
-   **Math**: Mappings for `math` module functions (`sqrt`, `sin`, `pi`, etc.).
-   **File I/O**: `open()` context managers (`with open(...)`) mapped to `os.open` with `defer { close() }`.
-   **Modules**: Support for `random`, `json`, `time`, `datetime`, `os`, `sys`, and basic regex (`re`).

## Installation

### Prerequisites
-   Python 3.10+ (if using Python 3.10, `tomli` is recommended for parsing `pyproject.toml`)
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
-   `--no-mypy`: Disable strict type inference via `mypy` (faster but less accurate types).

### Configuration Options
The transpiler respects `mypy` configuration files (`mypy.ini`, `setup.cfg`, `pyproject.toml`).
-   **Config-Aware Nullability (`strict_optional`)**: If `strict_optional = False` is set in your `mypy` config, the transpiler will map union types like `int | None` and `Optional[int]` to Vlang's `Any` type to match legacy Python semantics. By default (`strict_optional = True`), they map strictly to V optionals (`?int`).
  - *Note:* Parsing `pyproject.toml` requires Python 3.11+ (which includes `tomllib` natively) or the `tomli` package on older Python versions.

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
