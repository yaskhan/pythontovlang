Let's find the exact place to modify `visit_Assign`.

```python
            # ... Inside visit_Assign
            if is_simple_list and v_type.startswith("[]") and cap > 0:
                self.output.append(f"{self._indent()}mut {lhs} := {v_type}{{cap: {cap}}}")
                # ...
            elif hasattr(self, 'dataclasses') and v_type in self.dataclasses and isinstance(node.value, ast.Dict):
                # ...
                self.output.append(f"{self._indent()}{lhs} := {rhs}")
            else:
                rhs = self.visit(node.value)

                # OUR NEW LOGIC HERE:
                if self.in_main and isinstance(target, ast.Name):
                    if lhs in getattr(self, "global_vars", set()):
                        # Mutable global
                        if v_type == "unknown":
                            v_type = "Any"
                        self.emitter.add_global(f"{lhs} {v_type}")
                        self.output.append(f"{self._indent()}{lhs} = {rhs}")
                    else:
                        # Immutable constant
                        self.emitter.add_constant(f"{lhs} = {rhs}")
                else:
                    self.output.append(f"{self._indent()}{lhs} := {rhs}")
```

Wait! What if `self.in_main` is True, and it goes into `is_simple_list` branch? Then it does `mut {lhs} := ...` inside `main()`. It won't be accessible globally.
So we must intercept it BEFORE those checks, or do the checks and then emit to global/const!

If we intercept it BEFORE those checks:
```python
        if self.in_main and isinstance(target, ast.Name):
            v_type = getattr(self, "_guess_type", lambda x: "unknown")(target)
            if v_type == "unknown":
                v_type = "Any"
            rhs = self.visit(node.value)

            if lhs in getattr(self, "global_vars", set()):
                # Mutable global
                self.emitter.add_global(f"{lhs} {v_type}")
                self.output.append(f"{self._indent()}{lhs} = {rhs}")
            else:
                # Immutable constant
                self.emitter.add_constant(f"{lhs} = {rhs}")
            return
```
This is safe because top-level code usually doesn't need pre-allocated lists or TypedDict definitions initialized piecemeal. If it does, `rhs = self.visit(node.value)` handles it normally without pre-allocation, which is fine for globals.

What about `visit_AnnAssign`?
```python
        if self.in_main and isinstance(node.target, ast.Name):
            target_name = target
            if not v_type or v_type == "unknown":
                v_type = "Any"

            if node.value:
                rhs = self.visit(node.value)
                if target_name in getattr(self, "global_vars", set()):
                    self.emitter.add_global(f"{target_name} {v_type}")
                    self.output.append(f"{self._indent()}{target_name} = {rhs}")
                else:
                    self.emitter.add_constant(f"{target_name} = {rhs}")
            else:
                if target_name in getattr(self, "global_vars", set()):
                    self.emitter.add_global(f"{target_name} {v_type}")
                    # we don't need to append anything for initialization since it's just a declaration
                else:
                    self.emitter.add_constant(f"{target_name} = /* uninitialized constant */ 0")
            return
```

We must also add `self.global_vars = set()` to `__init__.py`'s `visit_Module`:
```python
    def visit_Module(self, node: ast.Module) -> str:
        self.global_vars = set()
        for subnode in ast.walk(node):
            if isinstance(subnode, ast.Global):
                self.global_vars.update(subnode.names)

        # ... rest of visit_Module ...
```

And update `py2v_transpiler/core/generator.py`:
```python
    def __init__(self):
        self.imports: List[str] = []
        self.structs: List[str] = []
        self.functions: List[str] = []
        self.main_body: List[str] = []

        self.globals: List[str] = []
        self.constants: List[str] = []
        ...

    def add_global(self, global_def: str) -> None:
        """Adds a __global definition."""
        self.globals.append(global_def)

    def add_constant(self, const_def: str) -> None:
        """Adds a const definition."""
        self.constants.append(const_def)

    def emit(self) -> str:
        lines = ["module main\n"]
        ...
        if self.structs:
            lines.extend(self.structs)
            lines.append("")

        if self.globals:
            lines.append("__global (")
            lines.extend(["    " + g for g in self.globals])
            lines.append(")\n")

        if self.constants:
            lines.append("const (")
            lines.extend(["    " + c for c in self.constants])
            lines.append(")\n")

        if self.functions: ...
```

Wait, `VCodeEmitter.emit_global_helpers` doesn't need globals/constants since they belong to the specific parsed file (`main.py` parses file by file, each gets its own `emit()`).
