# Python to Vlang Transpiler

A transpiler to convert Python code to [V](https://vlang.io/) language.

## Features

- Converts Python AST to V AST.
- Uses `mypy` for type inference.
- Generates readable V code.
- Basic support for variable assignments and function definitions.

## Installation

### From Source

```bash
git clone https://github.com/your-repo/py2v-transpiler.git
cd py2v-transpiler
pip install .
```

For development:

```bash
pip install -e .[dev]
```

## Usage

```bash
py2v <path/to/script.py>
```

This will generate `path/to/script.v`.

## Architecture

See [AGENTS.md](AGENTS.md) for details on the architecture and development guidelines.

## Requirements

- Python 3.8+
- mypy
