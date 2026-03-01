1. **Understand the Goal**: We need to extract module-level variables (assignments) and treat them correctly depending on whether they are constants (immutable) or mutable globals.
   - Immutable constants should be emitted as V `const (...)` blocks. (We could check if their names are fully uppercase as a heuristic for "constants", or if they are just not mutated). The task says: "Module-level constants like `REQUIRED = Strength(...)` and mutable globals like `planner = None` are currently incorrectly placed inside the generated `fn main()` block".
   - Mutable globals (e.g. accessed via Python `global` keyword) should be mapped to `__global` or a shared state struct in V.

2. **Analysis**:
   - In `py2v_transpiler/core/translator/__init__.py:84-112`, top-level statements that are NOT function/class/imports are executed and added to `self.main_body` via `self.emitter.add_main_statement()`.
   - V has a `__global` keyword. We can collect all variables that are declared `global` in ANY function, then treat them as mutable globals.
   - Alternatively, V allows `__global ( my_var int )`.
   - For constants, V supports `const ( MY_CONST = 1 )`.

   To properly implement this:
   a. **Pre-scan for `global` declarations**:
      We can do an AST pass before or during translation to find all `global` names. If a module-level variable is in this set, it's a mutable global. Otherwise, if it's assigned at the module level, it's a constant. (Or we can assume ALL module-level variables are `__global` if they are mutated anywhere, and `const` if they are only assigned once at the module level).
      Wait, V requires a special flag `-enable-globals` to use `__global`. The task says "mapped to `__global` or a shared state struct in V."
      Let's map them to `__global ( var_name type = ... )` if V supports it, as it's the easiest equivalent of Python's globals.
      Wait, V `__global` syntax: `__global ( planner ?Planner )`.
      Actually, let's see how V defines globals:
      ```v
      __global (
          planner ?Planner
      )
      ```
      Or a shared state struct:
      ```v
      struct GlobalState {
      mut:
          planner ?Planner
      }
      const g_state = &GlobalState{} // But V consts can't be mutable pointers without trickery, actually shared/global state is better done with __global.
      ```
      The simplest approach matching the task description: "Implement an AST pass to extract module-level assignments. Immutable constants should be emitted as V `const (...)` blocks. Mutable globals (e.g., accessed via Python `global` keyword) should be mapped to `__global` or a shared state struct in V."

   b. Let's do a pre-pass to find variables declared `global` in any function.
      `global_vars = set()`
      Iterate over AST looking for `ast.Global`.
      Any module-level assignment to a name in `global_vars` becomes a `__global`.
      Any other module-level assignment becomes a `const`.

      Wait, what if a variable is not declared `global` anywhere, but just assigned at module level and read from functions? In Python, that's allowed. In V, if it's a `const`, it can be read. If it's modified, Python requires `global`. So `global_vars` perfectly captures mutations.

3. **Detailed Steps**:
   - **Step 1**: In `TranslatorBase` or `VNodeVisitor`, add a pre-pass or scan for `global` keywords across the module.
     ```python
     self.global_vars = set()
     for node in ast.walk(ast_module):
         if isinstance(node, ast.Global):
             self.global_vars.update(node.names)
     ```
     We can do this in `visit_Module` in `py2v_transpiler/core/translator/__init__.py`.

   - **Step 2**: Track module-level assignments.
     When processing the module body, instead of just sending all assignments to `main()`, we can intercept them.
     But how does `VariablesMixin.visit_Assign` know it's at module level?
     `self.in_main` is `True` when at module level.
     If `self.in_main` is True, `visit_Assign` currently appends to `self.output`, which then gets collected in `visit_Module` and appended to `main_body`.
     Instead, we can modify `visit_Module` or `VariablesMixin` to emit `const` or `__global`.
     Wait, in `visit_Assign`, `self.output.append(f"{self._indent()}{lhs} := {rhs}")` or `mut {lhs} := ...` happens.
     If we change `visit_Assign` to check `self.in_main` AND whether it's an assignment to a module-level variable:
     If `self.in_main` and it's a variable assignment (not a destructuring, or at least a simple name):
     Is it in `self.global_vars`?
     If so, we need to declare it as `__global` and initialize it. Wait, V `__global` syntax:
     ```v
     __global (
         planner Planner
     )
     ```
     Initialization of `__global` usually happens in `main()`, or inline?
     V docs for `__global`: `__global ( my_global int = 5 )` or just `__global my_global int`.
     Constants: `const MY_CONST = 5`.
     We can collect `consts` and `globals` in `VCodeEmitter`.
