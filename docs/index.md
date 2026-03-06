# Python to Vlang Transpiler

**A robust tool to transpile Python source code into V code.**

This project bridges the gap between Python's ease of development and V's performance and safety.

## Quick Start

```bash
# Installation
pip install .

# Transpile a file
py2v script.py

# Transpile a project recursively
py2v my_project/ --recursive
```

## Key Features

- **Type Inference**: Static typing via `mypy` (int, float, bool, str, lists, dicts, tuples, sets)
- **Control Flow**: `if`, `for`, `while`, `match`/`case`
- **Functions**: Definitions, arguments, return values, lambdas, decorators
- **OOP**: Classes, inheritance, operator overloading, `__init__`
- **Syntactic Sugar**: List comprehensions, f-strings, walrus operator (`:=`), slice notation
- **Standard Library**: `math`, `json`, `random`, `os`, `sys`, `datetime`, `re` and more

## Documentation Navigation

| Section | Description |
|---------|-------------|
| [Installation](installation.md) | Requirements and installation from source |
| [Usage](usage.md) | CLI options and usage examples |
| [Supported Features](supported-features.md) | Complete list of supported Python features |
| [Standard Library Mapping](stdlib-mapping.md) | Python to V standard library correspondence |
| [Architecture](architecture.md) | Internal structure of the transpiler |
| [Development](development.md) | Developer guidelines |

## Example

**Python (input.py):**
```python
from math import sqrt

def fibonacci(n: int) -> list[int]:
    """Generate Fibonacci sequence."""
    if n <= 0:
        return []
    elif n == 1:
        return [0]
    
    seq = [0, 1]
    for i in range(2, n):
        seq.append(seq[-1] + seq[-2])
    return seq

if __name__ == "__main__":
    print(fibonacci(10))
```

**V (output.v):**
```v
import math

fn fibonacci(n int) []int {
    // Generate Fibonacci sequence
    if n <= 0 {
        return []
    } else if n == 1 {
        return [0]
    }

    mut seq := []int{len: 2, init: [0, 1]}
    for i in 2 .. n {
        seq << seq[seq.len - 1] + seq[seq.len - 2]
    }
    return seq
}

fn main() {
    println(fibonacci(10))
}
```

## License

[MIT License](../LICENSE)

## Links

- [GitHub Repository](https://github.com/yaskhan/pythontovlang)
- [V Language](https://vlang.io)
- [V Documentation](https://modules.vlang.io)
