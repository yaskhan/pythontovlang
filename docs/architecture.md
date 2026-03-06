# Architecture

This document describes the internal architecture of the Python to Vlang Transpiler.

## Overview

The transpiler follows a **pipeline architecture** with distinct phases:

```
Python Source → Parser → AST → Analyzer → Typed AST → Translator → V AST → Generator → V Source
```

## Components

### 1. Parser (`core/parser.py`)

**Purpose**: Parses Python source code into an Abstract Syntax Tree (AST).

**Implementation**:
- Wraps Python's built-in `ast` module
- Handles file I/O and encoding
- Provides error reporting for syntax errors

**Key Classes**:
```python
class PyASTParser:
    def parse(self, source: str) -> ast.AST
    def parse_file(self, file_path: str) -> ast.AST
    def dump_tree(self, tree: ast.AST) -> str  # Debug output
```

**Example**:
```python
from py2v_transpiler.core.parser import PyASTParser

parser = PyASTParser()
tree = parser.parse("def foo(): pass")
print(parser.dump_tree(tree))
```

### 2. Analyzer (`core/analyzer.py`)

**Purpose**: Performs static type inference using mypy.

**Implementation**:
- Integrates with mypy's API
- Annotates AST nodes with type information
- Handles type aliases and complex types

**Key Classes**:
```python
class TypeInference:
    def analyze(self, tree: ast.AST) -> None
    def get_type(self, node: ast.AST) -> Optional[str]
    def infer_alias_types(self, tree: ast.AST) -> Dict[str, str]
```

**Type Inference Process**:
1. Run mypy on source code (automatically resolving and extracting types from available `.pyi` stub files)
2. Parse mypy output
3. Annotate AST nodes with types
4. Handle special cases (aliases, generics)

### 3. Translator (`core/translator/`)

**Purpose**: Visits AST nodes and translates them to V constructs.

**Implementation**:
- Uses the Visitor pattern
- Modular design with mixins for different node types
- Handles stdlib mapping

**Module Structure**:
```
core/translator/
├── __init__.py      # VNodeVisitor main class
├── base.py          # TranslatorBase with shared state
├── module.py        # Module-level handling
├── imports.py       # Import statements
├── expressions.py   # Expressions and operators
├── literals.py      # Literals (strings, numbers)
├── variables.py     # Variable assignments
├── control_flow.py  # if, for, while, match
├── functions.py     # Function definitions
└── classes.py       # Class definitions
```

**Key Classes**:
```python
class VNodeVisitor(
    ModuleMixin,
    ImportsMixin,
    ExpressionsMixin,
    ClassesMixin,
    FunctionsMixin,
    ControlFlowMixin,
    VariablesMixin,
    LiteralsMixin,
    TranslatorBase
):
    # Visits AST nodes and emits V code
```

**Translation Process**:
1. Visit module node
2. Process imports
3. Translate classes and functions
4. Handle expressions and statements
5. Apply stdlib mappings

### 4. Standard Library Mapper (`stdlib_map/mapper.py`)

**Purpose**: Maps Python stdlib calls to V equivalents.

**Implementation**:
- Dictionary-based mappings
- Custom transformation functions for complex cases

**Key Classes**:
```python
class StdLibMapper:
    def __init__(self):
        self.mappings: Dict[str, Dict[str, Union[str, Callable]]]
    
    def map(self, module: str, function: str, args: List[str]) -> str
```

**Mapping Types**:
- **Direct**: `math.sqrt` → `math.sqrt`
- **Transform**: `random.randint(a, b)` → `rand.int(a..b)`
- **Custom**: Complex transformations via callable

### 5. Generator (`core/generator.py`)

**Purpose**: Emits final V source code with proper formatting.

**Implementation**:
- Collects imports, structs, functions
- Manages code structure
- Generates helper functions

**Key Classes**:
```python
class VCodeEmitter:
    def __init__(self):
        self.imports: List[str]
        self.structs: List[str]
        self.functions: List[str]
        self.main_body: List[str]
    
    def emit_global_helpers(...) -> str
```

**Output Structure**:
```v
// Imports
import os
import math

// Structs (from classes)
struct Point {
    x int
    y int
}

// Functions
fn foo() int {
    return 42
}

// Main
fn main() {
    // Program entry point
}
```

## Data Flow

### 1. Input Phase
```
┌─────────────┐
│ Python File │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Parser    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Raw AST    │
└──────┬──────┘
```

### 2. Analysis Phase
```
       │
       ▼
┌─────────────┐
│  Analyzer   │
│   (mypy)    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Typed AST   │
└──────┬──────┘
```

### 3. Translation Phase
```
       │
       ▼
┌─────────────┐
│ Translator  │
│  (Visitor)  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  V Code     │
│  (buffer)   │
└──────┬──────┘
```

### 4. Output Phase
```
       │
       ▼
┌─────────────┐
│  Generator  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   V File    │
└─────────────┘
```

## Type System Mapping

### Basic Types

| Python | V |
|--------|-----|
| `int` | `int` |
| `float` | `f64` |
| `bool` | `bool` |
| `str` | `string` |
| `None` | `none` |
| `Any` | `Any` |

### Generic Types

| Python | V |
|--------|-----|
| `list[T]` | `[]T` |
| `dict[K, V]` | `map[K]V` |
| `set[T]` | `map[T]bool` |
| `tuple[A, B]` | `[]A` (homogeneous) |
| `Optional[T]` | `?T` |
| `Union[A, B]` | `A \| B` or `Any` |

### Callable Types

| Python | V |
|--------|-----|
| `Callable[[int], str]` | `fn (int) string` |
| `Callable[..., Any]` | `fn` |

## Error Handling

### Python Exceptions → V Errors

Python's exception handling is mapped to V's error handling:

```python
# Python
try:
    risky_operation()
except ValueError as e:
    print(f"Error: {e}")
```

```v
// V
result := risky_operation() or {
    println('Error: ${err}')
    return
}
```

### Exception Types

| Python | V |
|--------|-----|
| `ValueError` | Custom error |
| `TypeError` | Type mismatch |
| `KeyError` | Map access error |
| `IndexError` | Array bounds check |
| `RuntimeError` | Generic error |

## Helper Functions

The transpiler generates helper functions for Python features without direct V equivalents:

### Location: `py2v_helpers.v`

**Generated Helpers**:
- `enumerate()` - Index iteration
- `zip()` - Parallel iteration
- `sorted()` - Sorting
- `reversed()` - Reverse iteration
- `any()` / `all()` - Boolean aggregation
- `map()` / `filter()` - Functional operations

**Conditional Generation**:
- Only used helpers are included
- Tracked via `used_builtins` set in translator

## Configuration

### TranspilerConfig

```python
class TranspilerConfig:
    strict_types: bool      # Enable strict type checking
    output_dir: str         # Output directory
    mypy_enabled: bool      # Enable mypy inference
    warn_dynamic: bool      # Warn about Any types
    no_helpers: bool        # Skip helper generation
    helpers_only: bool      # Generate only helpers
```

## Extension Points

### Adding New Mappings

1. **Stdlib Mapping**: Add to `stdlib_map/mapper.py`
```python
self.mappings["new_module"] = {
    "function": "v_function"
}
```

2. **Type Mapping**: Add to `models/v_types.py`
```python
def map_python_type_to_v(py_type: str) -> str:
    if py_type == "NewType":
        return "v_type"
```

3. **AST Node**: Add visitor method to translator
```python
def visit_NewNode(self, node: ast.AST) -> str:
    # Translation logic
```

## Performance Considerations

1. **Type Inference**: mypy analysis is cached when possible
2. **AST Traversal**: Single-pass translation where feasible
3. **String Building**: Uses list accumulation + join for efficiency
4. **Import Deduplication**: Tracks imported modules to avoid duplicates

## Testing Architecture

```
tests/
├── test_parser.py       # Parser tests
├── test_analyzer.py     # Type inference tests
├── test_generator.py    # Code generation tests
├── test_dependencies.py # Dependency analysis tests
├── test_v2_features.py  # New feature tests
└── translator/          # Translation tests
    ├── test_classes.py
    ├── test_functions.py
    ├── test_control_flow.py
    └── ...
```

**Test Pattern**:
```python
def test_feature():
    python_code = """
    def foo() -> int:
        return 42
    """
    expected_v = """
    fn foo() int {
        return 42
    }
    """
    assert transpile(python_code) == expected_v
```

## Future Architecture Improvements

See [TODO.md](../TODO.md) and [todo2.md](../todo2.md) for planned enhancements:

- Incremental transpilation
- Better error messages with source mapping
- Optimization passes (loop fusion, constant folding)
- Multi-language target support
- Enhanced type narrowing
