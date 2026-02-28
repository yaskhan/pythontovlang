1. Modify `py2v_transpiler/core/translator/classes.py`
    - Add logic in `visit_ClassDef` to check if a class inherits from `TypedDict` or `typing.TypedDict`.
    - Set `is_typed_dict = True` when found.
    - If `is_typed_dict = True`, register the struct name in `self.dataclasses` just like we do for `@dataclass`. This will allow `visit_Call` and `visit_Dict` (or assignments) to use struct initialization and field access, since `dataclasses` tells the transpiler the exact layout of the struct. We can reuse `dataclasses` dict or create a new `typed_dicts` dict.
    - Let's create `self.typed_dicts = set()` or reuse `self.dataclasses`. Reusing `self.dataclasses` is probably the easiest because `hasattr(self, 'dataclasses')` and `func_name_str in self.dataclasses` are already used to enable struct initialization.

2. Modify `py2v_transpiler/core/translator/literals.py`
    - In `visit_Dict`, if we can infer that the dict literal is being assigned to a TypedDict (via `_guess_type` of the target node, but `visit_Dict` doesn't know its target context directly).
    - Actually, `visit_AnnAssign` and `visit_Assign` are where the target type is known.
    - In `visit_AnnAssign`, if `v_type` matches a known TypedDict (i.e., it's a struct name), we could transform the dict literal into a struct initialization.
    - However, `node.value` is visited *before* we can intercept it inside `visit_AnnAssign` usually, or we can check `isinstance(node.value, ast.Dict)` and handle it specially.
    - Let's look at `visit_AnnAssign` in `variables.py`: it currently does `rhs = self.visit(node.value)` and emits `target := rhs`. If we check if `v_type` is in `self.dataclasses` (or a known TypedDict), we can format it as a struct initializer instead of a `map[string]int`.
    - Wait, `visit_Dict` translates `{"a": 1}` to `map[string]int{'a': 1}`. We can add a `target_type` parameter to `visit_Dict`? No, AST visitors generally don't take parameters.

    - Better approach: In `visit_AnnAssign` and `visit_Assign`, if RHS is `ast.Dict` and `v_type` is a TypedDict struct, we can bypass `self.visit(node.value)` and manually translate it into a struct initialization.
    - E.g. `d: MyDict = {"a": 1}` -> `d := MyDict{a: 1}`.
    - What if it's not a top-level assignment? `foo({"a": 1})` where `foo(d: MyDict)`. It's harder.
    - If mypy infers the type of the dict literal itself as `MyDict`? Yes, mypy infers it. So `self._guess_type(node)` on the `ast.Dict` node would return `MyDict`!
    - So in `visit_Dict` in `literals.py`:
      ```python
      v_type = self._guess_type(node)
      if hasattr(self, 'dataclasses') and v_type in self.dataclasses:
          # Check if it's a TypedDict (we can add a flag or just assume any known struct)
          # Struct initialization: MyDict{a: 1, b: 2}
          pairs = []
          for k, v in zip(node.keys, node.values):
              if isinstance(k, ast.Constant) and isinstance(k.value, str):
                  key_str = k.value
                  val_str = self.visit(v)
                  pairs.append(f"{key_str}: {val_str}")
          return f"{v_type}{{{', '.join(pairs)}}}"
      ```

3. Modify `py2v_transpiler/core/translator/expressions.py`
    - For `visit_Subscript` (i.e. `d["a"]`), if `value` type is a TypedDict struct (via `self._guess_type(node.value)`), then it should be transpiled to `d.a` instead of `d['a']`.
    - `visit_Subscript`:
      ```python
      val_type = self._guess_type(node.value)
      if hasattr(self, 'dataclasses') and val_type in self.dataclasses:
          if isinstance(node.slice, ast.Constant) and isinstance(node.slice.value, str):
              return f"{value}.{node.slice.value}"
      ```

4. Modify `py2v_transpiler/core/translator/variables.py`
    - For `visit_Assign` and `visit_AnnAssign`, where target is `ast.Subscript` (i.e. `d["a"] = 2`), if `d` is a TypedDict struct, it should be transpiled to `d.a = 2`.
    - `visit_Assign`:
      ```python
      elif isinstance(target, ast.Subscript):
          list_obj = self.visit(target.value)
          obj_type = self._guess_type(target.value)
          if hasattr(self, 'dataclasses') and obj_type in self.dataclasses:
              if isinstance(target.slice, ast.Constant) and isinstance(target.slice.value, str):
                  lhs = f"{list_obj}.{target.slice.value}"
                  rhs = self.visit(node.value)
                  self.output.append(f"{self._indent()}{lhs} = {rhs}")
                  return
      ```
