Ah, looking at the test failure:
```python
    x = 42
    s = f"Val: {x:05}"
```
This is a module-level assignment!
Because of my changes, these get extracted as constants in V:
```v
const (
    x = 42
    s = 'Val: ${x:05}'
)
```
But the test expected `s := 'Val: ${x:05}'`.

Wait, the same thing is happening for all other failing tests! They are testing small snippets of Python code by just providing module-level statements and expecting them to be emitted as variables in the module (which were previously dumped into `main()`).
For example:
`x = 1` -> previously emitted `x := 1` inside `main()`. Now emitted as `const ( x = 1 )`.

The tests explicitly check `assert "x := 1" in v_code` or similar.
Because we changed module-level assignment logic to use `const` or `__global`, these tests fail.

How to fix this?
A. We can update the tests to look for `const (\n    x = 1\n)` or similar.
B. If the user expects standard assignments to go to `main()` UNLESS it's a known constant?
The task description says: "Module-level constants like `REQUIRED = Strength(...)` and mutable globals like `planner = None` are currently incorrectly placed inside the generated `fn main()` block, making them inaccessible to the methods that reference them."

Wait, how do we distinguish a "constant" from just a module-level variable that's not modified? Python doesn't have a `const` keyword.
A common heuristic is that CONSTANTS are UPPERCASE.
Does the task hint at this? "Module-level constants like `REQUIRED = ...`".
If we only extract uppercase variables as `const`, then `x = 42` will remain in `main()`. This would fix almost all the test breakages, which use lowercase variables for general test snippets.
Another alternative is to extract *all* module-level assignments as `const` except globals, but then we have to rewrite 103 failing tests to expect `const ( x = 42 )` instead of `x := 42`.
Let's see if upper-casing is the right heuristic.
"Immutable constants should be emitted as V `const (...)` blocks."
If we look at `VariablesMixin.visit_Assign`, we already have a heuristic for TypeAliases: `if lhs[0].isupper():`

If we use `if lhs.isupper():` as a heuristic for constants:
```python
                    if lhs in getattr(self, "global_vars", set()):
                        # ... __global
                    elif lhs.isupper():
                        # ... const
                    else:
                        self.output.append(f"{self._indent()}{lhs} := {rhs}")
```

Let's test this heuristic. If `x = 42` is not uppercase, it goes to `main()`. If `REQUIRED = ...`, it goes to `const`.
Wait! What if they are assigned as `GLOBAL_VAR1: int = 1`? `GLOBAL_VAR1` is uppercase, so it will be a constant. But wait, in the test earlier `GLOBAL_VAR1` was also declared as `global GLOBAL_VAR1`, so it went to `__global`, which is correct.
What if `Global_Var2 = 2`? `Global_Var2` is not fully uppercase, so it would go to `main()`. Is that desired? The user only asked for "Module-level constants like `REQUIRED = Strength(...)`". It strongly implies uppercase.

Let's change the heuristic to `lhs.isupper()` for constants.
Wait, what if `lhs` is not just a string, but what if it's `__version__`? `__version__.isupper()` is False because of lowercase letters. But `__VERSION__` is True.
What if `lhs` is a type alias `OrderedCollection = list`? We already handle TypeAliases separately.
Let's modify `VariablesMixin` in `py2v_transpiler/core/translator/variables.py` to only emit `const` if `lhs.isupper()`.
