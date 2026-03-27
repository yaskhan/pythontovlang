# Tests `vlangtr`

This folder contains the main tests for the V-part of the transpiler.

## What's here

- `transpiler_test.v` - main harness for comparing Python input and V output.
- `remaining_expr_tests_test.v` - targeted tests for individual expressions and operators.
- `cases/` - a collection of input `.py` files and expected `.expected.v` files.

## How `transpiler_test.v` works

The main test iterates through all `.py` files inside `cases/` recursively:

1. finds a Python file;
2. looks for a file with the same name and `.expected.v` extension nearby;
3. runs the source through `translator.new_translator()`;
4. compares the result with expected.

If `.expected.v` is missing, the case is skipped.

### Statistics

At the end of the run, a summary is printed:

- `total` - how many `.py` files were found;
- `checked` - how many cases were actually compared;
- `passed` - how many matched;
- `failed` - how many failed;
- `skipped` - how many were skipped;
- `success_rate` - percentage of successful checks.

If there are errors, the harness doesn't stop at the first one, but collects all problematic cases and lists them.

## Directives in `.expected.v`

A regular expected-file is compared as a whole.

If the file contains directives, it's checked as a set of substring rules:

- `@@in# "snippet"` - the fragment must be present;
- `@@notin# "snippet"` - the fragment must not be present;
- `@@or# "snippet"` - an alternative fragment for the previous `@@in#`.

Examples:

```v
@@in# "b := py_any(a)"
@@notin# "b := py_any(a)"
@@in# "assert False" @@or# "assert false"
```

If the directive syntax is broken, the expected-file is considered invalid and the test fails with the file name and line number.

## `cases/`

The structure of `cases/` mirrors the tree of source Python cases.

For each case, there are usually:

- `something.py` - input;
- `something.expected.v` - expected V result;
- sometimes nested subfolders for grouping by subsystem.

The `cases/generated/` folder contains auto-generated case pairs from the old `py2v_transpiler/tests/translator`.

## `remaining_expr_tests_test.v`

This file doesn't use `cases/`.

It checks individual expressions directly through `translator.expressions.ExprGen`:

- `assert`
- `//`
- `**`
- `round`
- `isinstance`
- `issubclass`
- `%`-string formatting

This format is convenient for local checking of a single operator when a full transpiler pipeline is not needed.

## How to run

Run all V-tests:

```bash
v -enable-globals test vlangtr/tests
```

Run only the main harness:

```bash
v -enable-globals test vlangtr/tests/transpiler_test.v
```

Run only expression tests:

```bash
v -enable-globals test vlangtr/tests/remaining_expr_tests_test.v
```

## Practice

- For new transpilation cases, add a pair `*.py` + `*.expected.v` to `cases/`.
- For small expression regressions, it's better to add a test to `remaining_expr_tests_test.v`.
- Temporary debug files are better kept in `debug/` rather than `tests/`.