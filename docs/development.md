# Development

This guide provides information for developers who want to contribute to the Python to Vlang Transpiler.

## Getting Started

### Prerequisites

- **Python 3.10+**
- **Git**
- **pytest** (for running tests)
- **mypy** (for type checking)

### Setup Development Environment

```bash
# Clone the repository
git clone https://github.com/yaskhan/pythontovlang.git
cd pythontovlang

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/macOS
# or
venv\Scripts\activate     # Windows

# Install in development mode
pip install -e ".[dev]"
```

## Project Structure

```
pythontovlang/
├── py2v_transpiler/
│   ├── __init__.py
│   ├── config.py           # Configuration classes
│   ├── main.py             # CLI entry point
│   ├── core/
│   │   ├── parser.py       # AST parsing
│   │   ├── analyzer.py     # Type inference
│   │   ├── generator.py    # Code generation
│   │   ├── dependencies.py # Import analysis
│   │   ├── decorators.py   # Decorator handling
│   │   ├── coroutines.py   # Async support
│   │   └── translator/
│   │       ├── __init__.py     # Main visitor
│   │       ├── base.py         # Base class
│   │       ├── module.py       # Module handling
│   │       ├── imports.py      # Import translation
│   │       ├── expressions.py  # Expressions
│   │       ├── literals.py     # Literals
│   │       ├── variables.py    # Variables
│   │       ├── control_flow.py # Control flow
│   │       ├── functions.py    # Functions
│   │       └── classes.py      # Classes
│   ├── stdlib_map/
│   │   ├── __init__.py
│   │   ├── mapper.py       # Stdlib mappings
│   │   └── builtins.py     # Built-in functions
│   ├── models/
│   │   ├── __init__.py
│   │   └── v_types.py      # Type mappings
│   └── tests/
│       ├── test_*.py
│       └── translator/
├── docs/                   # Documentation
├── examples/               # Example files
├── tests/                  # Integration tests
├── setup.py                # Package configuration
├── requirements.txt        # Dependencies
├── README.md               # Project overview
├── TODO.md                 # Feature checklist
└── AGENTS.md               # Development guidelines
```

## Development Workflow

### 1. Make Changes

Edit the relevant module based on the feature or bug fix:

- **New language feature**: `core/translator/`
- **New stdlib mapping**: `stdlib_map/mapper.py`
- **Type handling**: `models/v_types.py`
- **CLI changes**: `main.py`

### 2. Add Tests

Write tests for your changes:

```python
# tests/test_your_feature.py
def test_new_feature():
    python_code = """
    # Your Python code
    """
    expected_v = """
    // Expected V code
    """
    assert transpile(python_code) == expected_v
```

### 3. Run Tests

```bash
# Run all tests
python -m pytest

# Run specific test file
python -m pytest tests/test_your_feature.py

# Run with verbose output
python -m pytest -v

# Run with coverage
python -m pytest --cov=py2v_transpiler
```

### 4. Type Check

```bash
# Run mypy on the codebase
mypy py2v_transpiler/
```

### 5. Test Transpilation

```bash
# Test your changes on a sample file
py2v examples/sample.py

# Check the generated V code
cat examples/sample.v

# Try to compile with V
v run examples/sample.v
```

## Coding Standards

### Style Guide

- Follow **PEP 8** for Python code
- Use **type hints** for all functions
- Write **docstrings** for public APIs
- Keep functions **focused and small**

### Naming Conventions

```python
# Classes: PascalCase
class TypeInference:
    pass

# Functions: snake_case
def map_python_type_to_v(py_type: str) -> str:
    pass

# Constants: UPPER_CASE
MAX_RECURSION_DEPTH = 100

# Private methods: _prefix
def _internal_helper():
    pass
```

### Type Hints

Always use type hints:

```python
from typing import Optional, List, Dict, Any

def process_node(
    node: ast.AST,
    context: Optional[Dict[str, Any]] = None
) -> List[str]:
    pass
```

## Adding New Features

### 1. New Language Feature

**Step 1**: Add AST visitor method

```python
# core/translator/expressions.py
class ExpressionsMixin:
    def visit_NewFeature(self, node: ast.NewFeature) -> str:
        # Translate to V
        return f"v_code_for({self.visit(node.child)})"
```

**Step 2**: Add type handling (if needed)

```python
# models/v_types.py
def map_python_type_to_v(py_type: str) -> str:
    if py_type == "NewType":
        return "v_new_type"
```

**Step 3**: Add tests

```python
# tests/translator/test_new_feature.py
def test_new_feature_basic():
    code = """
    x = new_feature(42)
    """
    assert transpile(code) == "x := v_new_feature(42)"
```

### 2. New Standard Library Mapping

**Step 1**: Add to mapper

```python
# stdlib_map/mapper.py
class StdLibMapper:
    def __init__(self):
        self.mappings["new_module"] = {
            "function": self._new_module_function,
        }
    
    def _new_module_function(self, args: List[str]) -> str:
        return f"v_function({', '.join(args)})"
```

**Step 2**: Add tests

```python
# tests/test_stdlib.py
def test_new_module_mapping():
    code = """
    from new_module import function
    result = function(1, 2)
    """
    assert "v_function(1, 2)" in transpile(code)
```

### 3. New Type Support

**Step 1**: Update type mapper

```python
# models/v_types.py
def _map_ast_type(node: ast.AST, ...) -> str:
    if isinstance(node, ast.NewTypeNode):
        # Handle new type
        return "v_type"
```

**Step 2**: Add tests

```python
# tests/test_types.py
def test_new_type_mapping():
    assert map_python_type_to_v("NewType[int]") == "v_type[int]"
```

## Debugging

### Enable Debug Output

```python
from py2v_transpiler.core.parser import PyASTParser

parser = PyASTParser()
tree = parser.parse(source_code)
print(parser.dump_tree(tree))  # Debug AST
```

### Type Inference Debug

```python
from py2v_transpiler.core.analyzer import TypeInference

analyzer = TypeInference()
analyzer.analyze(tree)
print(analyzer.get_type(some_node))
```

### Verbose Transpilation

```bash
# Enable warnings for dynamic types
py2v script.py --warn-dynamic
```

## Common Issues

### Issue: Type Inference Fails

**Solution**: Ensure code has type hints or add fallback handling:

```python
def visit_Assign(self, node: ast.Assign) -> str:
    inferred_type = self.type_inference.get_type(node.targets[0])
    if inferred_type is None:
        inferred_type = "Any"  # Fallback
```

### Issue: V Compilation Error

**Solution**: Check the generated V code for syntax errors:

```bash
# View generated code
cat script.v

# Try to compile
v build script.v
```

### Issue: Import Not Found

**Solution**: Add the mapping to stdlib_map/mapper.py or mark as unsupported.

## Testing Guidelines

### Test Categories

1. **Unit Tests**: Test individual components
2. **Integration Tests**: Test full transpilation
3. **Regression Tests**: Test bug fixes

### Test Structure

```python
import pytest
from py2v_transpiler.main import Transpiler

class TestFeature:
    def test_basic_case(self):
        """Test the basic functionality."""
        code = "..."
        expected = "..."
        assert Transpiler().transpile(code) == expected
    
    def test_edge_case(self):
        """Test edge cases."""
        pass
    
    def test_error_case(self):
        """Test error handling."""
        with pytest.raises(ExpectedError):
            Transpiler().transpile(invalid_code)
```

## Documentation

### Update Documentation

When adding features, update:

1. **README.md**: Overview and quick start
2. **docs/supported-features.md**: Feature list
3. **docs/stdlib-mapping.md**: Library mappings
4. **TODO.md**: Mark completed features

### Documentation Style

- Use clear, concise language
- Include code examples
- Note any limitations
- Link to related sections

## Performance Tips

### Optimize AST Traversal

```python
# Good: Single pass
def visit_Module(self, node: ast.Module) -> str:
    for stmt in node.body:
        self.visit(stmt)

# Bad: Multiple walks
for stmt in node.body:
    ast.walk(node)  # Don't do this
```

### String Building

```python
# Good: List accumulation
output = []
for item in items:
    output.append(self.visit(item))
return "\n".join(output)

# Bad: String concatenation
output = ""
for item in items:
    output += self.visit(item)  # Don't do this
```

## Release Process

### Before Release

1. Update version in `setup.py`
2. Update `CHANGELOG.md` (if exists)
3. Mark completed features in `TODO.md`
4. Run all tests
5. Run mypy type checking

### Create Release

```bash
# Tag the release
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0

# Build package
python setup.py sdist bdist_wheel

# Upload to PyPI (when ready)
twine upload dist/*
```

## Contributing

### Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run tests and type checking
6. Submit PR

### Commit Messages

Follow conventional commits:

```
feat: Add support for new Python feature
fix: Fix type inference for generics
docs: Update installation instructions
test: Add tests for stdlib mapping
refactor: Improve translator structure
```

## Getting Help

- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions for questions
- **Code Review**: Request review from maintainers

## Future Directions

See [TODO.md](../TODO.md) and [todo2.md](../todo2.md) for:

- Python 3.12+ syntax support
- Performance optimizations
- Better error messages
- More stdlib mappings
- Enhanced type inference
