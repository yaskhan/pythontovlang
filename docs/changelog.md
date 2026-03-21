# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased] — HEAD

Latest commits not yet grouped into a release tag. See [commits on GitHub](https://github.com/yaskhan/pythontovlang/commits/main) for the full history.

---

## [0.10.0] — 2026-03-19 to 2026-03-22

> ~30 commits · PRs #464–#498

### Added
- **Mypy Bootstrapping Prep**: Optimizations for large project transpilation and initial Mypy self-transpiler support.
- **LLM Code Hints**: Support for `_pending_llm_call_comments` in `VNodeVisitor` to inject AI-generated refactoring hints directly into generated V code.
- **Top-level Splitting**: Automated splitting of module top-level code between `init()` and `main()` to resolve `duplicate fn main()` errors in V.
- **Unit Testing Framework**: Added comprehensive unit tests for the AST module and core transpiler components.

### Fixed
- **Base Class Detection**: Fixed `_Impl` struct and interface generation for `Node`, `SymbolNode`, and other base classes by using global class hierarchy instead of local type inference maps.
- **Lambda Capture-by-Value**: Fixed `i=i` default argument pattern in lambdas (Issue #35).
- **Lambda Default Arguments**: Fixed missing default argument injection in generated lambda calls (Issue #32).
- **For/Else Semantics**: Properly mapped Python's `for/else` blocks to V using state flags (Issue #29).
- **Emitter Shadowing**: Resolved critical bug where `VNodeVisitor` property for `emitter` shadowed derived class attributes.
- **Vlang Naming Conventions**: Enforced strict V naming rules (snake_case for variables, PascalCase for types) through the generator.
- **Property Setters**: Corrected return types for `@property.setter` methods to match V requirements.
- **Core Stability**: Resolved all 811 tests in the transpiler test suite.

### Refactored
- **AST Module**: Renamed `vlangtr/parser` to `vlangtr/ast` for better alignment with project goals.

---

## [0.9.0] — 2026-03-17 to 2026-03-18

> ~50 commits · PRs #450–#463

### Added
- **PEP 742** `TypeIs` support for improved type narrowing
- **PEP 750** Template string literals (`t"..."`)
- **PEP 705** `ReadOnly` fields in `TypedDict`
- **PEP 649/749** Deferred evaluation of annotations
- **PEP 695** Full type parameter syntax (`type Alias[T] = ...`), variance support with scoped metadata
- **PEP 696** Type variable defaults
- `TYPE_CHECKING` constant support
- `issubclass()` correct compilation in V
- `AnnAssign` class variable support (`x: int = 0` at class body level)
- Unit tests for class variables, inheritance, and reversal slicing

### Fixed
- Python string/list reversal slicing (`s[::-1]`) now correctly transpiles to V idiom
- Variable capture in nested lambdas
- Map Python string methods to V equivalents (`startswith`, `endswith`, `center`, etc.)
- `mypy` `col_offset` attribute check in type-guessing
- `**kwargs` handling and signature leakage in nested functions
- `list.pop(index)`, `list.remove(value)`, `list.count(value)` transpilation
- Missing `delete_many` / `insert_many` helpers for slice assignments
- `.clear()` for lists now emits `[]` instead of `{}`
- Fix comprehension typing in nested comprehensions

### Performance
- Optimize module usage checks
- Optimize character membership checks in `py_format` helper

---

## [0.8.0] — 2026-03-12 to 2026-03-16

> ~100 commits · PRs #406–#449

### Added
- Major core refactor: `analyzer.py`, `functions.py`, `base.py`, `classes.py`, `calls.py`
- Optional `mypyc` compilation support via `setup.py`
- `NoneType` struct to correctly represent `None` as a V type
- Documentation for `Any`, `NoneType`, and boolean operations ([Dynamic Types & None](typing_and_none.md))

### Fixed
- Optional checking precedence: wrap left operands in parens for `is NoneType` checks
- Void assignment mismatch: assign `Any(NoneType{})` instead of empty call result
- `dict.get()` `or`-block type mismatch in generated V
- Inject default arguments at call sites for missing parameters
- `Any()` initialization instead of `(expr as Any)` for Any sum type
- V optional type initialization syntax (`?Type(none)`)
- Extra `none` argument added to function calls with default arguments
- `Protocol[T]` incorrectly embedded as struct field — now generates interface
- Empty enum transpilation preventing V compilation errors
- Implicit generics extraction for functions without PEP 695 type params
- `None` in lists, `.count(None)`, and `None in list` translation
- List literal syntax: square brackets `[]` instead of curly braces
- Public constants: place in `pub const ()` block
- Uninitialized function-pointer struct fields
- `type` / `builtins.type` hints now map to V `Any`
- V attribute syntax updated from `[attr]` to `@[attr]`
- Multi-parameter generic embedding syntax errors
- `dict.get()` and `os.environ.get()` visibility
- Variable redefinition errors in generated V code
- Mutable parameter type errors
- Fix CI: deprecated Node.js actions, V action tarball 401 error
- Security: fix insecure `PYTHONPATH` modification
- Detect mutations in subscript assignments

### Performance
- Optimize `mypy` plugin by caching AST nodes and hoisting imports
- Optimize type string conversions in `py_string_format`
- Optimize module symbol scanning loops
- Optimize `join()` using generator expressions

---

## [0.7.0] — 2026-03-06 to 2026-03-11

> ~150 commits · PRs #334–#405

### Added
- Flow-sensitive type narrowing for conditionals and exception blocks
- Pydantic v2 support: `BaseModel` → V struct, `Field` constraints, `Config` class, `@field_validator` / `@model_validator`
- V constructors with validation for Pydantic models
- `//##LLM@@` markers for post-transpilation AI refactoring hints
- `typing.Literal` mapping to V enums
- `__type_params__` runtime attribute support
- Monomorphization of generic classes via mypy plugin metadata
- ABC support and instantiation validation
- `typing.Callable` proper V function type syntax
- `list.extend()` → V `<< ...` spread operator
- Loop index type narrowing for TypedDicts (mypy 1.14)
- `@classmethod` transpilation for generic classes and interfaces
- Error recovery and source mapping
- `list.append()` → V push operator `<<`
- `len()` built-in → `.len` property
- `.clone()` on mutable collection assignments
- `@staticmethod` and `@classmethod` → prefixed global functions
- Multiple inheritance / mixin support
- Closures and nested functions support
- Named sum types for unions (deprecate inline sum types)
- Type narrowing in `match/case` patterns
- Mypy error code → V tips mapping
- `__all__` module exports support
- Automated V compilation check in CI
- GitHub Pages docs site (Jekyll config)
- `Add docs about LLM comments` documentation

### Fixed
- I/O error handling for `os` module operations (Result/Error)
- `math.log()` argument mismatch and f64 casting
- `datetime` module resolution and mapping
- Set operations helper functions
- Mixed-type dictionary mapping and `json.loads` translation
- `@overload` function generation for `__init__` methods
- Generic struct definitions and multi-parameter generic inheritance
- `os.path` check functions now infer `bool` return type
- Variable redefinition during type narrowing in loops
- `mut` arguments on primitive types
- Fix CI mypy stubs V compilation errors
- Map `Any` map keys to `map[string]` to satisfy V requirements
- `fix: map Python string methods splitlines and join to V equivalents`
- Resolve V syntax error on multi-parameter generic embedding
- Undefined `narrowed_x` identifiers

---

## [0.6.0] — 2026-03-03 to 2026-03-05

> ~180 commits · PRs #252–#333

### Added
- PEP 695 Full type parameter syntax (initial implementation)
- PEP 675 `LiteralString` support
- PEP 747 `TypeForm[T]` support
- PEP 800 `disjoint_base` decorator support
- PEP 758 bracketless `except` and `except*` clauses
- Match/case type narrowing with union types
- Guard expressions with type narrowing in `match/case`
- Statically typed collections (typed dicts and lists)
- `memoryview` and `bytearray` translation
- Buffer protocol translation
- `@dataclass` perfect field inference using mypy plugin data
- `ParamSpec` and `TypeVarTuple` support (PEP 695)
- Self types with generic context (PEP 673 + PEP 695)
- Exact Mutability Mapping using mypy reassignment tracking
- `typing.assert_never` → V `panic`
- PEP 702 `@deprecated` decorator
- Cyclic import resolution via automatic module flattening
- For-loop tuple destructuring
- `six.moves` and `itertools` compatibility
- `typing.assert_type` compile-time evaluation
- Strict cast elimination for `typing.cast`
- Type-directed operator overloading
- Pre-allocated typed collections and list comprehensions
- Config-aware nullability (`strict_optional` via TOML config)
- Exception block type narrowing
- Statically typed `*args` and `**kwargs`
- Strict structural `TypedDict` mapping to V structs
- Static duck typing: explicit interface cast for arguments
- Generic match patterns
- `__all__` exports and `import *` handling
- `.pyi` stub files support
- `NoReturn` and `typing.Any` in stub function parameters
- Enum Membership Semantics (PEP 736/typing updates)
- Mypy plugin for mutability analysis

### Fixed
- `super()` constructor calls and `__init__` generation
- `object` base class auto-stripped from struct generation
- `isinstance` tuple checks
- `StringIO` / `IO[str]` → `strings.Builder`
- Duplicate `__str__`/`__repr__` V method mapping
- Class instantiation fallbacks in method returns
- Type casts to `float`
- Overloading for magic methods (`__len__`, `__getitem__`, etc.)
- Inline comprehensions (list/dict/set/generator)
- String modulo (`%`) formatting
- Module-level dict init scope
- Dictionary type inference for attributes
- String iteration in `for` loops (bytes → characters)
- Truth value testing for collections (`while x:`)
- `dict.items()` iteration transpile
- `int()` cast on strings → V `.int()` method
- Parentheses dropped in binary operations

---

## [0.5.0] — 2026-03-01 to 2026-03-02

> ~100 commits · PRs #55–#250

### Added
- `--warn-dynamic` CLI flag for profiler Any fallbacks
- `--no-helpers` and `--helpers-only` CLI flags
- Helper code generation into a separate `.v` file per directory
- Static function overload resolution (`typing.overload`)
- PEP 695 generic type aliases for dict literal initialization
- `repr` refactor: translated `translator.py` into a package with mixins
- `sys.stderr` redirection for `print()` calls
- `platform.python_implementation()` → `'V'`
- `bytes(string, encoding)` support
- List replication `[x] * N` → V array init
- Inline list/dict/set/generator comprehensions
- Six module string helpers
- Globals and constants extracted from `main()`
- GH Pages documentation site scaffold

### Fixed
- Global constants placement for V code generation
- Duplicate global/constant emission for `Final` variables
- `time.time()` mapping precision to `f64`
- Forward references in Python type hints
- V keyword collisions via AST sanitization
- Variable scoping issues inside `if`/`else` blocks
- Array initialization (`[None] * N`) with proper type inference
- Explicit `BaseClass.__init__()` → struct embedding initialization
- `sys.stderr` handling
- Array init syntax

---

## [0.4.0] — 2026-02-27 to 2026-02-28

> ~100 commits · PRs #30–#54

### Added
- Mypy plugin integration for type extraction into the transpiler
- `Any` sum type with `NoneType` as a member
- `vexc` exception runtime for `try/except` and `raise` blocks
- Bi-directional generator methods (`send`, `throw`, `close`)
- Async/await, `yield from`, union types support
- Structural pattern matching (`match/case`) with class patterns and OR-patterns
- `contextlib` and `typing` module support
- `hasattr` translation using static type information
- Mypy in-memory data transfer optimization
- `@deprecated` decorator support (PEP 702)

### Fixed
- `isinstance` with tuple of types
- `floor division`, `%` format, `pow`, `sort`, `round`, string predicates
- Double evaluation in augmented assignments (`**=`, `//=`)
- Python power operator (`**`) transpilation
- CI mypy strict typing errors across modules
- Python 3.10 `ast.TypeVar`/`ast.TypeAlias` compatibility
- Relative imports, docstrings, multiple exceptions in `except`
- Decorators with arguments
- Async comprehensions
- `del` statement and `.clear()` for lists and dicts

---

## [0.3.0] — 2026-02-25 to 2026-02-26

> ~200 commits · PRs #6–#29

### Added
- Standard library mappings: `hashlib`, `platform`, `subprocess`, `sqlite3`, `csv`, `urllib`, `http.client`, `socket`, `threading`, `functools`, `operator`, `itertools`, `collections`, `uuid`, `argparse`, `logging`, `shutil`, `tempfile`, `unittest`, `base64`, `zlib`, `gzip`, `pickle`, `statistics`, `fractions`, `array`, `struct`, `copy`
- `**kwargs` in function definitions
- `*args` in function calls
- Generator expressions
- `bytes` literals
- Set and dictionary comprehensions
- Chained comparisons
- Destructuring assignment
- Decorators (mapped to comments initially)
- Class inheritance
- Structural pattern matching (`match/case`) initial support
- `walrus operator` (`:=`)
- `isinstance` checks
- Type aliases
- `IntEnum` translation
- Coroutines / generators via V channels and `spawn`
- Operator overloading
- `__main__` block unwrapping
- `zip()`, `enumerate()`, `map()`, `filter()`, `any()`, `all()`, `reversed()`, `sorted()` built-ins
- `range()` with step argument
- `print()` `end=` and `sep=` arguments
- `input()` function
- `del` statement

### Fixed
- mypy errors across `literals.py`, `expressions.py`, `control_flow.py`
- Compatibility with Python 3.10 (`ast.Index` deprecation)
- CI: missing `__init__.py` files, import corrections
- `.real` / `.imag` renaming in complex number support
- Comprehension assignment type errors

---

## [0.2.0] — 2026-02-24 (day 1, afternoon)

> ~30 commits · PRs #3–#5

### Added
- AST Parser with file reading and error handling
- Dependency graph analyzer
- Type analyzer (`mypy`-based inference)
- Translator for: control flow (`if`, `for`, `while`), classes, code generator
- List comprehensions
- F-strings
- Module imports
- Tuples, enhanced dicts
- Exception handling and context managers
- Lambda and async/await (initial)
- Generators and slice notation
- Sets, `assert`, `global`/`nonlocal`
- TODO.md roadmap tracking

---

## [0.1.0] — 2026-02-24 (initial commits)

> First 3 commits

### Added
- Initial project scaffold (`py2v_transpiler/` package, `setup.py`, `pytest.ini`, `mypy.ini`)
- GitHub Actions CI pipeline
- `AGENTS.md` guidelines for AI contributors
- MIT License
- Initial `README.md`
