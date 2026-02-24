# AGENTS.md

## Overview

This repository contains a Python-to-Vlang transpiler. The project is structured to be modular and extensible.

## Architecture

The project follows a pipeline architecture:
1.  **Parser (`core/parser.py`)**: Parses Python code into an AST using `ast`.
2.  **Analyzer (`core/analyzer.py`)**: Performs static type analysis using `mypy`.
3.  **Translator (`core/translator.py`)**: Visits the AST and translates it into Vlang constructs.
4.  **Generator (`core/generator.py`)**: Emits the final V code.

## Guidelines for Agents

-   **Testing**: Always add tests for new features. Use `pytest`.
-   **Types**: Ensure Python code is type-hinted. Run `mypy` to verify.
-   **Structure**: Keep the `core/` modules focused on their specific tasks. Do not mix parsing logic with generation logic.
-   **Verification**: Always verify your changes by running the transpiler on a sample file and checking the output.

## Code Style

-   Follow PEP 8.
-   Use descriptive variable names.
-   Document functions and classes.

## Task Completion Protocol

-   After finishing a task, update `TODO.md` by marking the corresponding checkbox as completed (change `[ ]` to `[x]`).
