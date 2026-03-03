# Usage

This guide covers the command-line interface and usage patterns for the Python to Vlang Transpiler.

## Command-Line Interface

### Basic Usage

Transpile a single Python file:

```bash
py2v path/to/script.py
```

This generates `script.v` next to the source file.

### Recursive Directory Processing

Transpile all Python files in a directory recursively:

```bash
py2v path/to/project/ --recursive
```

### Dependency Analysis

Analyze imports and dependencies in a project:

```bash
py2v --analyze-deps path/to/project/
```

## CLI Options

| Option | Short | Description |
|--------|-------|-------------|
| `--recursive` | `-r` | Process directories recursively |
| `--analyze-deps` | | Analyze import dependencies instead of transpiling |
| `--no-mypy` | | Disable mypy type inference (faster, less accurate) |
| `--warn-dynamic` | | Emit warnings for variables that fell back to `Any` type |
| `--no-helpers` | | Don't generate helper functions file |
| `--helpers-only` | | Only generate helpers file, skip transpiled sources |
| `--help` | `-h` | Show help message |

## Usage Examples

### Simple Script

```bash
# Transpile a single file
py2v hello.py

# Output: hello.v is created in the same directory
```

### Project with Multiple Files

```bash
# Transpile entire project
py2v src/ --recursive

# Generate only helpers (useful for large projects)
py2v src/ --recursive --helpers-only
```

### Type Analysis

```bash
# Enable dynamic type warnings
py2v script.py --warn-dynamic

# Output includes warnings like:
# WARNING: Variable 'x' at line 10 fell back to Any type
```

### Dependency Analysis

```bash
# Analyze project dependencies
py2v --analyze-deps myproject/

# Output shows import graph and identifies unsupported modules
```

## Programmatic Usage

You can also use the transpiler as a Python library:

```python
from py2v_transpiler.main import Transpiler

# Create transpiler instance
transpiler = Transpiler()

# Transpile source code
python_code = '''
def greet(name: str) -> str:
    return f"Hello, {name}!"
'''

v_code = transpiler.transpile(python_code)
print(v_code)
```

## Configuration

### TranspilerConfig

For advanced usage, configure the transpiler:

```python
from py2v_transpiler.config import TranspilerConfig

config = TranspilerConfig(
    strict_types=True,      # Enable strict type checking
    output_dir="output",    # Output directory
    mypy_enabled=True,      # Enable mypy type inference
    warn_dynamic=True,      # Warn about dynamic types
    no_helpers=False,       # Generate helpers
    helpers_only=False      # Generate only helpers
)
```

## Output Structure

By default, the transpiler generates:

1. **`<script>.v`** - The transpiled V source code
2. **`py2v_helpers.v`** (optional) - Common helper functions and types

### Example Output

```
my_project/
├── src/
│   ├── main.py      →  main.v
│   └── utils.py     →  utils.v
└── py2v_helpers.v   (common helpers)
```

## Best Practices

1. **Type Hints**: Add type hints to your Python code for better V output
2. **Test Incrementally**: Transpile and test small modules first
3. **Check Warnings**: Use `--warn-dynamic` to identify type issues
4. **Review Generated Code**: Always review the generated V code before compilation

## Limitations

- Some Python dynamic features may not translate perfectly
- Complex metaprogramming may require manual adjustment
- Some standard library modules have partial or approximate mappings

See [Supported Features](supported-features.md) for detailed compatibility information.
