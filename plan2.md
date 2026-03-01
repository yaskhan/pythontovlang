Since `v` is not installed, I will follow the standard syntax for V globals:
`__global ( var_name type = value )` or initialization in `main()`.

Wait, the task says:
"Implement an AST pass to extract module-level assignments. Immutable constants should be emitted as V `const (...)` blocks. Mutable globals (e.g., accessed via Python `global` keyword) should be mapped to `__global` or a shared state struct in V."

Let's use V `__global ( ... )` for globals and `const ( ... )` for constants.
If we map a python variable `REQUIRED = Strength(...)` as a constant, V requires:
```v
const (
    REQUIRED = Strength(...)
)
```
Wait, V const names MUST be uppercase? In standard V, yes, but we can't easily change the name without breaking references unless we rename all occurrences.
Wait, the prompt says "Immutable constants should be emitted as V `const (...)` blocks. Mutable globals (e.g., accessed via Python `global` keyword) should be mapped to `__global` or a shared state struct in V."

Let's do this:
1. In `VCodeEmitter` (`py2v_transpiler/core/generator.py`), add:
```python
        self.globals: List[str] = []
        self.constants: List[str] = []

    def add_global(self, global_def: str) -> None:
        self.globals.append(global_def)

    def add_constant(self, const_def: str) -> None:
        self.constants.append(const_def)
```
And in `emit()`:
```python
        if self.globals:
            lines.append("__global (")
            lines.extend(["    " + g for g in self.globals])
            lines.append(")\n")

        if self.constants:
            lines.append("const (")
            lines.extend(["    " + c for c in self.constants])
            lines.append(")\n")
```
2. In `TranslatorBase` (`py2v_transpiler/core/translator/base.py`), add `self.global_vars: set = set()`.
3. In `VNodeVisitor.visit_Module` (`py2v_transpiler/core/translator/__init__.py`), pre-scan for `global` keywords:
```python
        self.global_vars = set()
        for subnode in ast.walk(node):
            if isinstance(subnode, ast.Global):
                self.global_vars.update(subnode.names)
```
4. In `VariablesMixin.visit_Assign` (`py2v_transpiler/core/translator/variables.py`):
When `self.in_main` is True and it's assigning to a simple `Name`:
```python
        if self.in_main and isinstance(target, ast.Name):
             # It's a module level assignment
             v_type = getattr(self, "_guess_type", lambda x: "unknown")(target)
             rhs = self.visit(node.value)
             if lhs in self.global_vars:
                 # Emit as __global
                 self.emitter.add_global(f"{lhs} {v_type}")
                 # Initialize in main body
                 self.output.append(f"{self._indent()}{lhs} = {rhs}")
             else:
                 # Emit as const
                 self.emitter.add_constant(f"{lhs} = {rhs}")
             return
```
Wait, V `const` names must be uppercase? Or does it allow lowercase if we don't strict check?
If it's lowercase, V compiler might complain, but the task doesn't ask us to rename them, just to emit as `const (...)` blocks.
Actually, what if it's assigned to a type (like type alias)? `VariablesMixin` already handles type aliases first and returns if it matches. So we put our logic after type alias check, or just before the general append.

Let's review `visit_Assign` in `py2v_transpiler/core/translator/variables.py`:
It currently has:
```python
            if self.in_main:
                is_type_alias = False
                ...
                if is_type_alias:
                     self.emitter.add_struct(f"type {lhs} = {type_alias_val}")
                     return
```
So right after that, we can add:
```python
            if self.in_main and isinstance(target, ast.Name):
                v_type = getattr(self, "_guess_type", lambda x: "unknown")(target)
                if hasattr(ast, 'unparse') and getattr(node, 'annotation', None):
                    try:
                        type_str = ast.unparse(node.annotation)
                        v_type = map_python_type_to_v(type_str)
                    except:
                        pass

                rhs = self.visit(node.value)
                if lhs in self.global_vars:
                    # Mutable global
                    # Fallback type if Any or unknown for globals
                    if v_type == "unknown":
                        v_type = "Any"
                    self.emitter.add_global(f"{lhs} {v_type}")
                    # In V, __global can't easily be initialized with function calls in declaration, so initialize in main()
                    self.output.append(f"{self._indent()}{lhs} = {rhs}")
                else:
                    # Constant
                    self.emitter.add_constant(f"{lhs} = {rhs}")
                return
```
Wait, what if it's an `AnnAssign`? The task says "Module-level constants like `REQUIRED = Strength(...)` and mutable globals like `planner = None`". `AnnAssign` is handled in `visit_AnnAssign`.
Let's modify `visit_AnnAssign` similarly.

Let's refine `__global` syntax in V.
`__global ( my_var int )` is correct. We also need to assign it later or assign immediately. Since Python allows complex initialization (like `planner = Planner()`), we should declare it in `__global` and initialize it in `fn main()`.
But wait! If `__global ( planner ?Planner )`, we can do `planner = new_Planner()` in `main()`.
However, `visit_Assign` evaluates `rhs = self.visit(node.value)`. If we emit `self.output.append(f"{lhs} = {rhs}")`, it will go to `main_body` through `visit_Module`. This is perfect!

Let's check if the variables are defined as `__global` correctly.
```python
v_type = getattr(self, "_guess_type", lambda x: "unknown")(target)
```
If `v_type` is "unknown", it will use "Any".

Wait, does V allow lowercase constants?
"Constants must be defined using `const` and their names must be uppercase. They can contain underscores."
Since the user specifically said: "Immutable constants should be emitted as V `const (...)` blocks", we will do that. If V requires uppercase, maybe we should upper-case them?
Wait, the task says: "Module-level constants like `REQUIRED = Strength(...)`". Here `REQUIRED` is already uppercase. If it's `planner = None`, it's lowercase, but it's a mutable global because it's accessed via `global planner`. So it will go to `__global`. What if there is a lowercase constant (never declared `global`)? Then we emit `const lowercase = ...`. If the V compiler fails, it's a language limitation, but we fulfilled the task correctly (or we could rename it to upper, but renaming variables affects all references, which is complex). Let's just emit `const` as requested.

Wait, `visit_Assign` already does `rhs = self.visit(node.value)`. If we return early, we bypass the rest of `visit_Assign` logic (like comprehensions, TypedDict, etc.).
We should just change the final emission instead.
