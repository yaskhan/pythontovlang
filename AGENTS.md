## Important: Test Files Location
**All test files for verification and debugging should be created in the `debug/` folder.** This folder is gitignored and serves as a scratch space for testing transpiler output.

## Overview
This repository contains a Python-to-Vlang transpiler. The project is structured to be modular and extensible.

## Guidelines for Agents
-   **Testing**: Always add tests for new features. Use `pytest`.
-   **Types**: Ensure Python code is type-hinted. Run `mypy` to verify.
-   **Structure**: Keep the `core/` modules focused on their specific tasks. Do not mix parsing logic with generation logic.
-   **Verification**: Always verify your changes by running the transpiler on a sample file and checking the output. Use the `debug/` folder for temporary test files.

## Code Style
-   Follow PEP 8.
-   Use descriptive variable names.
-   Document functions and classes.
