# Supported Features

This document lists all Python language features supported by the transpiler.

## Core Language Features

### Variables & Types

| Feature | Status | Notes |
|---------|--------|-------|
| Basic types (int, float, bool, str) | ✅ | Direct mapping |
| Type inference (mypy) | ✅ | Using static analysis |
| `.pyi` stub files | ✅ | Mypy plugin uses type stubs for accurate static typing |
| Lists | ✅ | `list[T]` → `[]T` |
| Dictionaries | ✅ | `dict[K, V]` → `map[K]V` |
| Tuples | ✅ | Fixed-size tuples → arrays |
| Sets | ✅ | `set[T]` → `map[T]bool` |
| Optional types | ✅ | `Optional[T]` → `?T` |
| Union types | ✅ | `X \| Y` (Python 3.10+) |
| Type aliases | ✅ | Including recursive aliases |
| TypedDict | ✅ | Both class-based and functional syntax |
| Literal types | ✅ | `Literal[1, "a"]` |
| Final variables | ✅ | `Final[T]` |
| ClassVar | ✅ | Class variables |
| Self type | ✅ | Python 3.11+, support for generic context (PEP 673 + 695) |
| Annotated types | ✅ | `Annotated[T, ...]` |
| TypeGuard | ✅ | Type narrowing |
| NoReturn | ✅ | Functions that never return |
| NewType | ✅ | Type aliases |
| ParamSpec | ✅ | Callable parameters |
| TypeVar | ✅ | Generics |
| Required/NotRequired | ✅ | TypedDict fields |
| Unpack | ✅ | TypedDict unpacking |
| TypeForm | 🧪 | PEP 747 (mapped to `Any`). See limitations below. |

### Control Flow

| Feature | Status | Notes |
|---------|--------|-------|
| if/elif/else | ✅ | Direct mapping |
| for loops | ✅ | Including else clause |
| while loops | ✅ | Including else clause |
| match/case | ✅ | Structural pattern matching |
| Guard clauses in match | ✅ | `case x if condition:` |
| OR patterns | ✅ | `case A \| B:` |
| Capture patterns | ✅ | `case Point() as p:` |
| Mapping patterns | ✅ | `{'key': value}` |
| Sequence patterns | ✅ | `[x, y, *rest]` |
| Wildcard pattern | ✅ | `case _:` |
| Class patterns | ✅ | `case Point(x=1)` |

### Functions

| Feature | Status | Notes |
|---------|--------|-------|
| Function definitions | ✅ | With type hints |
| Arguments (positional) | ✅ | |
| Keyword arguments | ✅ | |
| *args | ✅ | Variadic arguments |
| **kwargs | ✅ | Keyword variadic arguments |
| Keyword-only args | ✅ | `def f(*, arg):` |
| Positional-only args | ✅ | `def f(arg, /):` |
| Default values | ✅ | |
| Lambda expressions | ✅ | |
| Decorators | ✅ | Including with arguments |
| Async functions | ✅ | `async def` |
| Generators | ✅ | `yield` |
| Generator delegation | ✅ | `yield from` |
| Async generators | ✅ | `async for`, `async yield` |
| Bi-directional generators | ✅ | `send()`, `throw()`, `close()` |
| singledispatch | ✅ | `functools.singledispatch` |
| Overload decorator | ✅ | `@overload` |
| Type parameters (PEP 695) | ✅ | Python 3.12+ full support including ParamSpec and TypeVarTuple |

### Object-Oriented Programming

| Feature | Status | Notes |
|---------|--------|-------|
| Class definitions | ✅ | → V structs |
| Inheritance | ✅ | Via struct embedding |
| Method overriding | ✅ | |
| `__init__` method | ✅ | Constructor |
| `__new__` method | ✅ | Custom instance creation |
| Operator overloading | ✅ | `__add__`, `__sub__`, etc. |
| `__slots__` | ✅ | Memory optimization |
| Properties | ✅ | `@property`, setters |
| Class methods | ✅ | `@classmethod` |
| Static methods | ✅ | `@staticmethod` |
| Abstract methods | ✅ | Via typing |
| Metaclasses | ✅ | `class X(metaclass=M)` |
| `__init_subclass__` | ✅ | Hook for subclasses |
| Protocol (structural) | ✅ | `typing.Protocol` |
| Dataclasses | ✅ | → V structs |
| NamedTuple | ✅ | → V structs |
| Enum | ✅ | Including Flag, auto() |
| Private name mangling | ✅ | `__private` → `_Class__private` |
| Descriptors | ✅ | `__get__`, `__set__`, `__delete__` |
| `__getattr__` | ✅ | Dynamic attributes |
| `hasattr`/`getattr`/`setattr` | ✅ | |

### Expressions & Operators

| Feature | Status | Notes |
|---------|--------|-------|
| Arithmetic operators | ✅ | `+`, `-`, `*`, `/`, `//`, `%`, `**` |
| Comparison operators | ✅ | `<`, `>`, `<=`, `>=`, `==`, `!=` |
| Logical operators | ✅ | `and`, `or`, `not` |
| Bitwise operators | ✅ | `&`, `\|`, `^`, `~`, `<<`, `>>` |
| Matrix multiplication | ✅ | `@`, `@=` |
| Membership operators | ✅ | `in`, `not in` |
| Identity operators | ✅ | `is`, `is not` |
| Conditional expressions | ✅ | `x if cond else y` |
| Walrus operator | ✅ | `:=` |
| Chained comparisons | ✅ | `a < b < c` |
| Slice notation | ✅ | `list[1:3]` |
| Slice assignment | ✅ | `list[x:y] = [...]` |
| del statement | ✅ | Including slices |
| assert statement | ✅ | |
| isinstance | ✅ | Type checks |
| type() | ✅ | |

### Comprehensions

| Feature | Status | Notes |
|---------|--------|-------|
| List comprehensions | ✅ | `[x for x in y]` |
| Dict comprehensions | ✅ | `{k: v for ...}` |
| Set comprehensions | ✅ | `{x for x in y}` |
| Generator expressions | ✅ | `(x for x in y)` |
| Nested comprehensions | ✅ | |
| Async comprehensions | ✅ | `[x async for x in y]` |
| Comprehension with if | ✅ | Filtering |
| global/nonlocal in comp. | ✅ | Python 3.13+ |

### Statements & Keywords

| Feature | Status | Notes |
|---------|--------|-------|
| global | ✅ | |
| nonlocal | ✅ | (as comments in V) |
| pass | ✅ | |
| break/continue | ✅ | |
| return | ✅ | |
| raise | ✅ | Including `raise from` |
| try/except/else/finally | ✅ | Full exception handling |
| Exception groups | ✅ | `try/except*` (3.11+) |
| with statement | ✅ | Context managers |
| Multiple context managers | ✅ | `with a, b:` |
| Async with | ✅ | |
| del | ✅ | Single and multiple targets |
| import/from import | ✅ | Including relative imports |

### String Features

| Feature | Status | Notes |
|---------|--------|-------|
| f-strings | ✅ | Including debug `f"{x=}"` |
| Nested f-strings | ✅ | |
| Dynamic format specs | ✅ | `f"{x:{y}}"` |
| Raw strings | ✅ | `r"..."` |
| String concatenation | ✅ | Implicit `"a" "b"` |
| % formatting | ✅ | Legacy operator |
| .format() | ✅ | Custom `__format__` |
| bytes literals | ✅ | `b"..."` |
| bytearray | ✅ | |

### Built-in Functions

| Function | Status | V Mapping |
|----------|--------|-----------|
| `print()` | ✅ | `println()` |
| `len()` | ✅ | `.len` |
| `range()` | ✅ | `for i in 0 .. n` |
| `enumerate()` | ✅ | Helper function |
| `zip()` | ✅ | Helper function |
| `map()` | ✅ | Helper function |
| `filter()` | ✅ | Helper function |
| `any()` | ✅ | Helper function |
| `all()` | ✅ | Helper function |
| `reversed()` | ✅ | Helper function |
| `sorted()` | ✅ | Helper function |
| `input()` | ✅ | `io.read_line()` |
| `isinstance()` | ✅ | Type assertion |
| `str()` | ✅ | `.str()` |
| `int()` | ✅ | Type conversion |
| `float()` | ✅ | Type conversion |
| `bool()` | ✅ | Type conversion |
| `list()` | ✅ | Type conversion |
| `dict()` | ✅ | Type conversion |
| `set()` | ✅ | Type conversion |
| `tuple()` | ✅ | Type conversion |
| `sum()` | ✅ | Helper function |
| `min()`/`max()` | ✅ | Helper function |
| `abs()` | ✅ | `math.abs()` |
| `round()` | ✅ | `math.round()` |
| `pow()` | ✅ | `math.pow()` |
| `divmod()` | ✅ | Helper function |
| `hash()` | ✅ | Helper function |
| `id()` | ✅ | Helper function |
| `repr()` | ✅ | `.str()` |
| `ascii()` | ✅ | Helper function |
| `bin()`/`hex()`/`oct()` | ✅ | Helper function |
| `ord()`/`chr()` | ✅ | Helper function |
| `open()` | ✅ | `os.open()` with defer |

## Standard Library Support

### Fully Supported

| Module | Status | Notes |
|--------|--------|-------|
| `math` | ✅ | All common functions |
| `random` | ✅ | `randint`, `choice`, `random`, `seed` |
| `json` | ✅ | `loads`, `dumps` |
| `time` | ✅ | `time`, `sleep` |
| `datetime` | ✅ | `datetime.now`, `date.today` |
| `os` | ✅ | Path operations, environment |
| `sys` | ✅ | `exit`, `argv`, `platform` |
| `re` | ✅ | Basic regex operations |

### Partially Supported

| Module | Status | Notes |
|--------|--------|-------|
| `collections` | ⚠️ | `defaultdict`, `Counter`, `OrderedDict` |
| `itertools` | ⚠️ | Common functions |
| `functools` | ⚠️ | `partial`, `singledispatch`, `lru_cache` |
| `typing` | ✅ | Most typing constructs |
| `dataclasses` | ✅ | Field definitions |
| `enum` | ✅ | Enum, Flag, auto() |
| `pydantic` | ✅ | `BaseModel`, `Field` validation and alias support |
| `pathlib` | ⚠️ | Basic Path operations |
| `io` | ⚠️ | `StringIO`, basic I/O |
| `logging` | ⚠️ | Basic logging |
| `argparse` | ⚠️ | Basic argument parsing |
| `unittest` | ⚠️ | Test structure |
| `subprocess` | ⚠️ | Basic process execution |
| `socket` | ⚠️ | Basic socket operations |
| `http.client` | ⚠️ | HTTP requests |
| `urllib` | ⚠️ | URL parsing |
| `csv` | ⚠️ | CSV reading/writing |
| `sqlite3` | ⚠️ | Database operations |
| `threading` | ⚠️ | Basic threading |
| `multiprocessing` | ⚠️ | Process spawning |
| `hashlib` | ⚠️ | Hash functions |
| `uuid` | ⚠️ | UUID generation |
| `base64` | ⚠️ | Encoding/decoding |
| `struct` | ⚠️ | Binary packing |
| `array` | ⚠️ | Typed arrays |
| `copy` | ⚠️ | `copy`, `deepcopy` |
| `pickle` | ⚠️ | Serialization |
| `zlib`/`gzip` | ⚠️ | Compression |
| `decimal` | ⚠️ | Decimal arithmetic |
| `fractions` | ⚠️ | Fraction operations |
| `statistics` | ⚠️ | Statistical functions |
| `contextlib` | ⚠️ | Context managers |
| `shutil` | ⚠️ | File operations |
| `tempfile` | ⚠️ | Temporary files |
| `platform` | ⚠️ | Platform info |

## Python Version Support

| Python Version | Status | Notes |
|----------------|--------|-------|
| 3.10 | ✅ | Minimum supported version |
| 3.11 | ✅ | Full support |
| 3.12 | ✅ | PEP 695 type parameters |
| 3.13 | ✅ | Latest features |
| 3.14+ | ⚠️ | Experimental (future syntax) |

## Legend

- ✅ = Fully supported
- 🧪 = Experimental (requires `--experimental` flag)
- ⚠️ = Partially supported (some features may not work)
- ❌ = Not supported

## Type Reification Limitations (PEP 747)

Python's PEP 747 introduces `TypeForm[T]` to annotate values that represent a type itself. In V, there is no direct equivalent for runtime type reification that matches Python's dynamic nature.

Currently, the transpiler maps `TypeForm[T]` to the V `Any` sum type. This allows the code to compile and run, but loses the static type-checking guarantees that Python's type checkers (like mypy) provide for `TypeForm`. Use this feature with caution and ensure that runtime type checks are performed if necessary.
