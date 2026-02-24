# Future Plans for py2v-transpiler

## Initial Setup
- [ ] Set up project structure (src, tests)
- [ ] Configure CI/CD (GitHub Actions)
- [ ] Add basic parser setup using Python's `ast` module

## Core Features
- [ ] Implement basic transpilation for variable assignments
- [ ] Implement basic control flow (if/else, while, for loops)
- [ ] Implement function definitions and calls
- [ ] Implement basic class support (mapping to V structs)
- [ ] Implement exception handling (try/except -> or/result)
- [ ] Implement support for f-strings
- [ ] Implement type inference (using MyPy)

## Standard Library Mapping
- [ ] Map `print` -> `println`
- [ ] Map basic `math` functions
- [ ] Map basic `os` functions
- [ ] Map basic `json` functions

## Testing & Quality
- [ ] Add comprehensive unit tests for generated V code
- [ ] Add integration tests
- [ ] Add support for list comprehensions
