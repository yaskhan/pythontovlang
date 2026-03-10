# Installation

This guide covers the requirements and installation process for the Python to Vlang Transpiler.

## Prerequisites

- **Python 3.10+** - The transpiler requires Python 3.10 or higher for modern syntax support
- **pip** - Python package installer
- **V Compiler** (optional) - To compile the generated V code

## Installation Methods

### From PyPI (Coming Soon)

```bash
pip install py2v-transpiler
```

### From Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yaskhan/pythontovlang.git
   cd pythontovlang
   ```

2. **Install the package:**
   ```bash
   pip install .
   ```

3. **For development (includes test dependencies):**
   ```bash
   pip install -e ".[dev]"
   ```

### High-Performance Compilation (Optional)

You can compile the transpiler itself into a high-performance C-extension using `mypyc`. This significantly speeds up the transpilation process for large projects.

1. **Ensure you have a C compiler installed** (e.g., `gcc` or `clang`).
2. **Install the package with the `USE_MYPYC` environment variable:**
   ```bash
   USE_MYPYC=1 pip install .
   ```
   *Note: This will compile the core module files but will leave `main.py` as a standard Python CLI script.*

## Dependencies

The transpiler has minimal dependencies:

| Package | Version | Purpose |
|---------|---------|---------|
| `mypy` | Latest | Static type inference |
| `pytest` | Latest | Testing (dev only) |

## Verification

After installation, verify the transpiler is working:

```bash
# Check if the command is available
py2v --help

# Transpile a simple test
echo 'print("Hello, World!")' > test.py
py2v test.py
cat test.v
```

## V Compiler Setup (Optional)

To compile the generated V code:

1. **Install V:**
   ```bash
   git clone https://github.com/vlang/v.git
   cd v
   make
   ```

2. **Add V to your PATH:**
   ```bash
   # Linux/macOS
   export VROOT=/path/to/v
   export PATH=$VROOT:$PATH
   
   # Windows (PowerShell)
   $env:VROOT = "C:\path\to\v"
   $env:PATH = "$env:VROOT;$env:PATH"
   ```

3. **Compile generated code:**
   ```bash
   py2v script.py
   v run script.v
   ```

## Troubleshooting

### mypy not found
```bash
pip install mypy
```

### Syntax errors with older Python
Ensure you're using Python 3.10+. Check with:
```bash
python --version
```

### V compilation errors
The generated V code may require specific V versions. Check the V version compatibility in the project README.
