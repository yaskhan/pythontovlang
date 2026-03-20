# vlangtr - Python to V Self-Transpiler (Bootstrapping)

This project aims to translate the existing Python-to-Vlang transpiler into native V code. 

## Folder Structure

### `parser/`
Contains the Python source code parser. This module will handle reading Python files and converting them into an Abstract Syntax Tree (AST) that can be processed in V.

### `mypy/`
Handles information received from Mypy (type maps, signatures, etc.). This module is responsible for parsing Mypy's JSON output/metadata and providing type information to the translator.

### `translator/`
The core translation logic. It iterates through the AST and, using type information from the `mypy` module, generates equivalent V code. This is where the main "brains" of the transpiler live.

### `models/`
Defines the shared data structures used across the project, such as AST node types, type representations, and internal configuration models.

### `utils/`
Common utility functions for string manipulation, file handling, and other helper logic used by various modules.

## Getting Started

1. Ensure V is installed.
2. The initial phase involves translating core Python AST nodes to V structures.
3. Use `v.mod` to manage dependencies if needed.
