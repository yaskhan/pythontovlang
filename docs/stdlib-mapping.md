# Standard Library Mapping

This document details how Python standard library modules are mapped to V equivalents.

## Built-in Functions

### I/O Functions

| Python | V | Notes |
|--------|-----|-------|
| `print(x)` | `println(x)` | |
| `print(a, b, sep=',')` | `println('${a},${b}')` | sep handled manually |
| `input()` | `io.read_line()` | |
| `input(prompt)` | `print(prompt); io.read_line()` | |

### Type Conversion

| Python | V | Notes |
|--------|-----|-------|
| `str(x)` | `x.str()` | Method call |
| `int(x)` | `int(x)` | |
| `float(x)` | `f64(x)` | |
| `bool(x)` | `bool(x)` | |
| `list(x)` | `[]T{x...}` | Depends on type |
| `dict(x)` | `map[K]V{}` | Depends on type |
| `set(x)` | `map[T]bool{}` | |
| `tuple(x)` | `[]T{x...}` | |

### Collection Functions

| Python | V | Notes |
|--------|-----|-------|
| `len(x)` | `x.len` | Property access |
| `range(n)` | `for i in 0 .. n` | Loop syntax |
| `range(start, stop)` | `for i in start .. stop` | |
| `range(start, stop, step)` | `for i := start; i < stop; i += step` | |
| `enumerate(iter)` | `for i, x in iter` | Native V syntax |
| `zip(a, b)` | Helper function | See helpers |
| `reversed(seq)` | Helper function | Returns reversed iterator |
| `sorted(seq)` | Helper function | Returns sorted array |

### Functional Functions

| Python | V | Notes |
|--------|-----|-------|
| `map(fn, iter)` | Helper function | Returns iterator |
| `filter(fn, iter)` | Helper function | Returns iterator |
| `any(iter)` | Helper function | Boolean result |
| `all(iter)` | Helper function | Boolean result |
| `sum(iter)` | Helper function | Numeric result |
| `min(a, b)` | `math.min(a, b)` | |
| `max(a, b)` | `math.max(a, b)` | |

### Utility Functions

| Python | V | Notes |
|--------|-----|-------|
| `isinstance(x, T)` | `x is T` | Type assertion |
| `type(x)` | `typeof(x)` | Runtime type |
| `id(x)` | `&x` | Address |
| `hash(x)` | `x.hash()` | Hash method |
| `repr(x)` | `x.str()` | String representation |
| `ascii(x)` | Helper function | ASCII-safe string |
| `bin(n)` | `n.bin()` | Binary string |
| `hex(n)` | `n.hex()` | Hex string |
| `oct(n)` | Helper function | Octal string |
| `ord(c)` | `c[0]` | Byte value |
| `chr(n)` | `string([n])` | Character |
| `abs(n)` | `math.abs(n)` | |
| `round(n)` | `math.round(n)` | |
| `pow(x, y)` | `math.pow(x, y)` | |
| `divmod(a, b)` | `[a / b, a % b]` | Tuple result |

## Math Module

| Python | V | Notes |
|--------|-----|-------|
| `math.sqrt(x)` | `math.sqrt(x)` | |
| `math.sin(x)` | `math.sin(x)` | |
| `math.cos(x)` | `math.cos(x)` | |
| `math.tan(x)` | `math.tan(x)` | |
| `math.asin(x)` | `math.asin(x)` | |
| `math.acos(x)` | `math.acos(x)` | |
| `math.atan(x)` | `math.atan(x)` | |
| `math.atan2(y, x)` | `math.atan2(y, x)` | |
| `math.sinh(x)` | `math.sinh(x)` | |
| `math.cosh(x)` | `math.cosh(x)` | |
| `math.tanh(x)` | `math.tanh(x)` | |
| `math.exp(x)` | `math.exp(x)` | |
| `math.log(x)` | `math.log(x)` | Natural log |
| `math.log10(x)` | `math.log10(x)` | |
| `math.log2(x)` | `math.log2(x)` | |
| `math.pow(x, y)` | `math.pow(x, y)` | |
| `math.ceil(x)` | `math.ceil(x)` | |
| `math.floor(x)` | `math.floor(x)` | |
| `math.fabs(x)` | `math.abs(x)` | |
| `math.trunc(x)` | `int(x)` | |
| `math.pi` | `math.pi` | Constant |
| `math.e` | `math.e` | Constant |
| `math.tau` | `math.tau` | Constant |
| `math.inf` | `math.inf` | Constant |
| `math.nan` | `math.nan` | Constant |
| `math.degrees(x)` | `math.degrees(x)` | |
| `math.radians(x)` | `math.radians(x)` | |
| `math.gcd(a, b)` | Helper function | |
| `math.lcm(a, b)` | Helper function | |
| `math.factorial(n)` | Helper function | |
| `math.isqrt(n)` | `int(math.sqrt(n))` | Integer sqrt |

## Random Module

| Python | V | Notes |
|--------|-----|-------|
| `random.randint(a, b)` | `rand.int(a..b)` | Inclusive |
| `random.random()` | `rand.f64()` | 0.0 to 1.0 |
| `random.uniform(a, b)` | `rand.f64() * (b - a) + a` | |
| `random.choice(seq)` | Helper function | Random element |
| `random.choices(seq, k=n)` | Helper function | n elements |
| `random.shuffle(seq)` | Helper function | In-place |
| `random.sample(seq, k)` | Helper function | Unique elements |
| `random.seed(n)` | `rand.seed(n)` | |
| `random.randrange(start, stop)` | `rand.int(start..stop-1)` | |

## JSON Module

| Python | V | Notes |
|--------|-----|-------|
| `json.loads(s)` | `json.decode(s)` | Parse JSON |
| `json.dumps(obj)` | `json.encode(obj)` | Serialize |
| `json.load(f)` | `json.decode(f.read())` | From file |
| `json.dump(obj, f)` | `f.write(json.encode(obj))` | To file |

## Time Module

| Python | V | Notes |
|--------|-----|-------|
| `time.time()` | `time.now().unix()` | Unix timestamp |
| `time.sleep(s)` | `time.sleep(s * time.second)` | |
| `time.localtime()` | `time.now()` | Local time |
| `time.gmtime()` | `time.now().utc()` | UTC time |
| `time.strftime(fmt, t)` | `t.format(fmt)` | Format |
| `time.strptime(s, fmt)` | `time.parse(s, fmt)` | Parse |
| `time.monotonic()` | `time.monotonic()` | Monotonic clock |

## Datetime Module

| Python | V | Notes |
|--------|-----|-------|
| `datetime.now()` | `time.now()` | |
| `datetime.today()` | `time.now()` | |
| `datetime.utcnow()` | `time.now().utc()` | |
| `date.today()` | `time.now()` | |
| `datetime.year` | `.year` | |
| `datetime.month` | `.month` | |
| `datetime.day` | `.day` | |
| `datetime.hour` | `.hour` | |
| `datetime.minute` | `.minute` | |
| `datetime.second` | `.second` | |
| `datetime.timestamp()` | `.unix()` | |

## OS Module

| Python | V | Notes |
|--------|-----|-------|
| `os.environ` | `os.environ` | Environment |
| `os.getenv(key)` | `os.getenv(key)` | |
| `os.getenv(key, default)` | `os.getenv(key) or default` | |
| `os.getcwd()` | `os.getwd()` | Current directory |
| `os.chdir(path)` | `os.cd(path)` | Change directory |
| `os.listdir(path)` | `os.ls(path)` | List files |
| `os.mkdir(path)` | `os.mkdir(path)` | |
| `os.makedirs(path)` | `os.mkdir_all(path)` | Recursive |
| `os.remove(path)` | `os.rm(path)` | |
| `os.rmdir(path)` | `os.rmdir(path)` | |
| `os.path.join(a, b)` | `os.join_path(a, b)` | |
| `os.path.exists(path)` | `os.exists(path)` | |
| `os.path.isfile(path)` | `os.is_file(path)` | |
| `os.path.isdir(path)` | `os.is_dir(path)` | |
| `os.path.abspath(path)` | `os.abs_path(path)` | |
| `os.path.basename(path)` | `os.base(path)` | |
| `os.path.dirname(path)` | `os.dir(path)` | |
| `os.system(cmd)` | `os.system(cmd)` | |
| `os.popen(cmd)` | `os.exec(cmd)` | |
| `os.name` | `os.user_os()` | Platform |

## Sys Module

| Python | V | Notes |
|--------|-----|-------|
| `sys.exit(code)` | `exit(code)` | |
| `sys.argv` | `os.args` | Command line args |
| `sys.platform` | `os.user_os()` | Platform string |
| `sys.version` | Helper string | Version info |
| `sys.path` | Helper list | Import paths |
| `sys.stdin` | `io.stdin` | |
| `sys.stdout` | `io.stdout` | |
| `sys.stderr` | `io.stderr` | |

## Re Module (Regex)

| Python | V | Notes |
|--------|-----|-------|
| `re.match(pattern, s)` | `regex.match(pattern, s)` | |
| `re.search(pattern, s)` | `regex.find(pattern, s)` | |
| `re.findall(pattern, s)` | `regex.find_all(pattern, s)` | |
| `re.sub(pattern, repl, s)` | `regex.replace(pattern, s, repl)` | |
| `re.split(pattern, s)` | `regex.split(pattern, s)` | |
| `re.compile(pattern)` | `regex.compile(pattern)` | |

## Collections Module

| Python | V | Notes |
|--------|-----|-------|
| `defaultdict(fn)` | `map[K]V{}` + helper | Default factory |
| `Counter(iter)` | `map[T]int` | Count elements |
| `OrderedDict()` | `map[K]V` (ordered) | V maps are ordered |
| `deque()` | `[]T` | Use array |
| `namedtuple()` | `struct {}` | Define struct |

## Functools Module

| Python | V | Notes |
|--------|-----|-------|
| `partial(fn, *args)` | Closure | Partial application |
| `singledispatch(fn)` | Helper decorator | Function overloading |
| `lru_cache(fn)` | Helper decorator | Memoization |
| `reduce(fn, iter)` | Helper function | Fold operation |
| `wraps(fn)` | Comment | Decorator helper |

## Itertools Module

| Python | V | Notes |
|--------|-----|-------|
| `count(start, step)` | Generator function | Infinite counter |
| `cycle(iter)` | Generator function | Infinite cycle |
| `repeat(obj, n)` | Generator function | Repeat n times |
| `chain(a, b)` | `[...a, ...b]` | Concatenate |
| `islice(iter, n)` | `iter[0:n]` | Slice |
| `combinations(iter, r)` | Helper function | |
| `permutations(iter, r)` | Helper function | |
| `product(*iters)` | Helper function | Cartesian product |
| `groupby(iter, key)` | Helper function | Group by key |

## Typing Module

| Python | V | Notes |
|--------|-----|-------|
| `List[T]` | `[]T` | |
| `Dict[K, V]` | `map[K]V` | |
| `Tuple[A, B]` | `[]A` or struct | |
| `Set[T]` | `map[T]bool` | |
| `Optional[T]` | `?T` | |
| `Union[A, B]` | `A \| B` or `Any` | |
| `Callable[[A], B]` | `fn (A) B` | |
| `Any` | `Any` | Dynamic type |
| `Final[T]` | `const` | Immutable |
| `ClassVar[T]` | Class field | |
| `Literal[...]` | Specific type | |
| `Type[T]` | `T` | Type object |
| `Self` | `Self` | Current type |
| `NoReturn` | `void` | Never returns |
| `TypeGuard[T]` | `bool` | Type narrowing |
| `Annotated[T, ...]` | `T` | Metadata stripped |
| `NewType(name, T)` | `type name = T` | Type alias |
| `TypeVar('T')` | Generic parameter | |
| `ParamSpec('P')` | Generic params | |
| `Protocol` | Interface | Structural subtyping |
| `TypedDict` | `struct {}` | |
| `NamedTuple` | `struct {}` | |
| `dataclass` | `struct {}` | |
| `Generic[T]` | `[T]` | Type parameter |

## IO Module

| Python | V | Notes |
|--------|-----|-------|
| `open(path, 'r')` | `os.open(path)` or `os.read_file(path)` | |
| `open(path, 'w')` | `os.write_file(path, data)` | |
| `with open(...) as f` | `defer { f.close() }` | Context manager |
| `f.read()` | `f.read_string()` | |
| `f.write(s)` | `f.write_string(s)` | |
| `f.readline()` | `f.read_line()` | |
| `f.readlines()` | `f.read_lines()` | |
| `f.close()` | `f.close()` | |
| `StringIO()` | `strings.Builder` | |

## Pathlib Module

| Python | V | Notes |
|--------|-----|-------|
| `Path(p)` | `os.join_path(p)` | |
| `Path.cwd()` | `os.getwd()` | |
| `p.exists()` | `os.exists(p)` | |
| `p.is_file()` | `os.is_file(p)` | |
| `p.is_dir()` | `os.is_dir(p)` | |
| `p.read_text()` | `os.read_file(p)` | |
| `p.write_text(s)` | `os.write_file(p, s)` | |
| `p.parent` | `os.dir(p)` | |
| `p.name` | `os.base(p)` | |
| `p.suffix` | Helper function | File extension |
| `p.stem` | Helper function | Name without suffix |

## Helper Functions

The transpiler generates a `py2v_helpers.v` file with common helper functions:

```v
// enumerate helper
fn enumerate<T>(arr []T) []struct { idx int, value T } {
    // ...
}

// zip helper
fn zip<A, B>(a []A, b []B) []struct { first A, second B } {
    // ...
}

// sorted helper
fn sorted<T>(arr []T) []T {
    // ...
}

// reversed helper
fn reversed<T>(arr []T) []T {
    // ...
}

// any helper
fn any<T>(arr []T, fn fn (T) bool) bool {
    // ...
}

// all helper
fn all<T>(arr []T, fn fn (T) bool) bool {
    // ...
}
```

## Notes

1. **Type Safety**: V is more strict than Python. Some mappings may require explicit type conversions.

2. **Error Handling**: Python exceptions are mapped to V's error handling (`!` and `?`).

3. **Memory Management**: Python's garbage collection is replaced by V's ownership model.

4. **Concurrency**: Python's `threading` maps to V's `spawn` and channels.

5. **Async**: Python's `asyncio` maps to V's async/await model.
