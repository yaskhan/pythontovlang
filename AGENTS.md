## Overview
This repository contains a Python-to-Vlang transpiler. The project is structured to be modular and extensible.

## Guidelines for Agents
-   **Testing**: Always add tests for new features. Use `pytest`.
-   **Types**: Ensure Python code is type-hinted. Run `mypy` to verify.
-   **Structure**: Keep the `core/` modules focused on their specific tasks. Do not mix parsing logic with generation logic.
-   **Verification**: Always verify your changes by running the transpiler on a sample file and checking the output.

## Code Style
-   Follow PEP 8.
-   Use descriptive variable names.
-   Document functions and classes.
