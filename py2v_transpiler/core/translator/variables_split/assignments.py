import ast
from typing import Any, List, Optional, Dict, Set, Union, TYPE_CHECKING, Tuple
from ..base import TranslatorBase
from py2v_transpiler.models.v_types import map_python_type_to_v

if TYPE_CHECKING:
    pass

class AssignmentsMixin(TranslatorBase):
    if TYPE_CHECKING:
        defined_top_level_symbols: Set[str]
        output: List[str]
        in_main: bool
        _local_vars_in_scope: Set[str]
        name_remap: Dict[str, str]
        unique_id_counter: int
        _zip_counter: int
        known_interfaces: Set[str]
        dataclasses: Dict[str, List[str]]
        type_inference: Any
        current_assignment_type: Optional[str]
        def _indent(self) -> str: ...
        def _sanitize_name(self, name: str, is_type: bool = False) -> str: ...
        def _guess_type(self, node: ast.AST, use_location: bool = True) -> str: ...
        def _map_type(self, type_str: str, struct_name: Optional[str] = None, allow_union: bool = True, register_sum_types: bool = True, is_return: bool = False) -> str: ...
        def _is_tuple_struct(self, v_type: str) -> bool: ...
        def _is_clonable_collection(self, v_type: str) -> bool: ...
        def _is_literal_string_expr(self, node: ast.AST) -> bool: ...
        def visit_ListComp(self, node: Union[ast.ListComp, ast.GeneratorExp], target_var: Optional[str] = None) -> Optional[str]: ...
        def visit_SetComp(self, node: ast.SetComp, target_var: Optional[str] = None) -> Optional[str]: ...
        def visit_DictComp(self, node: ast.DictComp, target_var: Optional[str] = None) -> Optional[str]: ...

    """Assignment handling: visit_Assign and helper methods"""

    def _is_compile_time_evaluable(self, node: ast.AST) -> bool:
        if isinstance(node, ast.Constant): return True
        if isinstance(node, ast.Name): return node.id.isupper()
        if isinstance(node, ast.UnaryOp): return self._is_compile_time_evaluable(node.operand)
        if isinstance(node, ast.BinOp): return self._is_compile_time_evaluable(node.left) and self._is_compile_time_evaluable(node.right)
        if isinstance(node, (ast.List, ast.Tuple, ast.Set)): return all(self._is_compile_time_evaluable(elt) for elt in node.elts)
        if isinstance(node, ast.Dict): return all(self._is_compile_time_evaluable(k) for k in node.keys if k) and all(self._is_compile_time_evaluable(v) for v in node.values)
        return False

    def visit_Assign(self, node: ast.Assign) -> None:
        target = node.targets[0]
        lhs = ""
        if isinstance(target, ast.Name):
            # Check if it COULD be a type alias (starts with capital)
            maybe_type = target.id[0].isupper() or (target.id.startswith('_') and len(target.id) > 1 and any(c.isupper() for c in target.id))
            lhs = self._sanitize_name(target.id) if not maybe_type else self._sanitize_name(target.id, is_type=True)

            if target.id in self.name_remap: del self.name_remap[target.id]
            if self.in_main: self.defined_top_level_symbols.add(target.id)
            if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "NewType":
                if len(node.value.args) == 2:
                    try:
                        base_str = ast.unparse(node.value.args[1])
                        mapped_base = map_python_type_to_v(base_str, allow_union=True, self_name=self._get_full_self_type())
                        pub = "pub " if self._is_exported(target.id) else ""
                        self.emitter.add_struct(f"{pub}type {lhs} = {mapped_base}")
                        return
                    except: pass
            if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id in ("TypeVar", "ParamSpec", "TypeVarTuple"):
                self.type_vars.add(target.id)
                is_constrained, constraints = False, []
                if node.value.func.id == "TypeVar":
                    for arg in node.value.args[1:]:
                        is_constrained = True
                        if isinstance(arg, ast.Name): constraints.append(map_python_type_to_v(arg.id, self_name=self._get_full_self_type()))
                        elif isinstance(arg, ast.Constant) and isinstance(arg.value, str): constraints.append(map_python_type_to_v(arg.value, self_name=self._get_full_self_type()))
                for kw in node.value.keywords:
                    if kw.arg == "bound":
                        is_constrained = True
                        try:
                            bound_str = ast.unparse(kw.value)
                            mapped = map_python_type_to_v(bound_str, self_name=self._get_full_self_type())
                            if "|" in mapped: constraints.extend([s.strip() for s in mapped.split("|")])
                            else: constraints.append(mapped)
                        except: pass
                    elif kw.arg == "default":
                        try:
                            v_default = self._map_type(ast.unparse(kw.value))
                            self.generic_defaults[target.id] = v_default
                        except: pass
                if is_constrained: self.constrained_typevars.add(target.id)
                if constraints:
                    sanitized_lhs = lhs.lstrip('_')
                    final_type = " | ".join(constraints)
                    pub = "pub " if self._is_exported(target.id) else ""
                    self.emitter.add_struct(f"{pub}type {sanitized_lhs} = {final_type}")
                return
            if self.in_main:
                is_type_alias, type_alias_val = False, ""
                # Use the original target.id to check for uppercase
                if target.id[0].isupper() or (target.id.startswith('_') and len(target.id) > 1 and any(c.isupper() for c in target.id)):
                     if hasattr(self, 'type_inference') and target.id in self.type_inference.type_map and isinstance(node.value, ast.Name):
                          is_type_alias, type_alias_val = True, self.type_inference.type_map[target.id]
                     else:
                          try:
                               rhs_source = ast.unparse(node.value)
                               mapped = self._map_type(rhs_source, allow_union=True, register_sum_types=False)
                               if mapped != "void" and mapped != rhs_source: is_type_alias, type_alias_val = True, mapped
                               elif mapped == "int" and rhs_source == "int": is_type_alias, type_alias_val = True, "int"
                               elif mapped == "f64" and rhs_source == "float": is_type_alias, type_alias_val = True, "f64"
                               elif mapped == "string" and rhs_source == "str": is_type_alias, type_alias_val = True, "string"
                               elif mapped == "bool" and rhs_source == "bool": is_type_alias, type_alias_val = True, "bool"
                               elif isinstance(node.value, ast.Name) and node.value.id[0].isupper(): is_type_alias, type_alias_val = True, node.value.id
                          except: pass
                if is_type_alias:
                     pub = "pub " if self._is_exported(target.id) else ""
                     found_vars = []
                     for tv in self.type_vars:
                         if f"{tv}" in type_alias_val:
                             v_gen = self._get_generic_map([tv]).get(tv, "T")
                             if v_gen not in found_vars: found_vars.append(v_gen)
                     gen_str = f"[{', '.join(found_vars)}]" if found_vars else ""
                     if found_vars:
                         for tv in sorted(list(self.type_vars), key=len, reverse=True):
                              v_gen = self._get_generic_map([tv]).get(tv, "T")
                              type_alias_val = type_alias_val.replace(tv, v_gen)
                     self.emitter.add_struct(f"{pub}type {lhs}{gen_str} = {type_alias_val}")
                     return
                
                # If it's NOT a type alias but started with a capital letter,
                # we should re-sanitize it as a regular variable (snake_case).
                # V requires snake_case for constants too.
                if maybe_type:
                    lhs = self._sanitize_name(target.id)
                elif isinstance(target, ast.Name) and target.id.isupper():
                    lhs = self._sanitize_name(target.id)

        elif isinstance(target, ast.Attribute):
            lhs = self.visit(target)
            if "_meta." not in lhs:
                 obj_type = self._guess_type(target.value)
                 if hasattr(self, "readonly_fields") and obj_type in self.readonly_fields:
                     field_name = self._sanitize_name(target.attr)
                     if field_name in self.readonly_fields[obj_type]:
                         self.output.append(f"{self._indent()}$compile_error(\"Cannot assign to ReadOnly TypedDict field '{field_name}'\")")
                         return
                 if (obj_type, target.attr) in self.property_setters:
                     obj_expr = self.visit(target.value)
                     rhs_expr = self.visit(node.value)
                     self.output.append(f"{self._indent()}{obj_expr}.set_{target.attr}({rhs_expr})")
                     return
        elif isinstance(target, ast.Subscript):
            obj_type = getattr(self, "_guess_type", lambda x: "unknown")(target.value)
            if hasattr(self, 'dataclasses') and obj_type in self.dataclasses:
                list_obj = self.visit(target.value)
                if isinstance(target.slice, ast.Constant) and isinstance(target.slice.value, str):
                    field_name = self._sanitize_name(target.slice.value)
                    if hasattr(self, 'readonly_fields') and obj_type in self.readonly_fields:
                        if field_name in self.readonly_fields[obj_type]:
                            self.output.append(f"{self._indent()}$compile_error(\"Cannot assign to ReadOnly TypedDict field '{field_name}'\")")
                            return
                    lhs = f"{list_obj}.{field_name}"
                    rhs = self.visit(node.value)
                    self.output.append(f"{self._indent()}{lhs} = {rhs}")
                    return
            if isinstance(target.slice, ast.Slice):
                list_obj = self.visit(target.value)
                lower = self.visit(target.slice.lower) if target.slice.lower else "0"
                upper = self.visit(target.slice.upper) if target.slice.upper else f"{list_obj}.len"
                rhs = self.visit(node.value)
                step_node = target.slice.step
                step_val = None
                if step_node is not None:
                    if isinstance(step_node, ast.Constant) and isinstance(step_node.value, int):
                        step_val = step_node.value
                    elif (isinstance(step_node, ast.UnaryOp) and isinstance(step_node.op, ast.USub)
                          and isinstance(step_node.operand, ast.Constant)
                          and isinstance(step_node.operand.value, int)):
                        step_val = -step_node.operand.value
                if step_val is not None and step_val >= 2:
                    uid = self.unique_id_counter
                    self.unique_id_counter += 1
                    rhs_tmp = f"py_step_rhs_{uid}"
                    i_tmp = f"py_step_i_{uid}"
                    idx_tmp = f"py_step_idx_{uid}"
                    ind = self._indent()
                    ind1 = ind + "\t"
                    self.output.append(f"{ind}{rhs_tmp} := {rhs}")
                    self.output.append(f"{ind}mut {i_tmp} := 0")
                    self.output.append(f"{ind}for {idx_tmp} := {lower}; {idx_tmp} < {upper}; {idx_tmp} += {step_val} {{")
                    self.output.append(f"{ind1}if {i_tmp} >= {rhs_tmp}.len {{ break }}")
                    self.output.append(f"{ind1}{list_obj}[{idx_tmp}] = {rhs_tmp}[{i_tmp}]")
                    self.output.append(f"{ind1}{i_tmp}++")
                    self.output.append(f"{ind}}}")
                elif step_val is not None and step_val < 0:
                    self.output.append(f"{self._indent()}//##LLM@@ Negative step slice assignment not supported; manual loop required")
                    self.used_delete_many, self.used_insert_many = True, True
                    self.output.append(f"{self._indent()}{list_obj}.delete_many({lower}, ({upper}) - ({lower}))")
                    self.output.append(f"{self._indent()}{list_obj}.insert_many({lower}, {rhs})")
                elif step_node is not None and not isinstance(step_node, ast.Constant):
                    self.output.append(f"{self._indent()}//##LLM@@ Non-constant step slice assignment not supported; manual loop required")
                    self.used_delete_many, self.used_insert_many = True, True
                    self.output.append(f"{self._indent()}{list_obj}.delete_many({lower}, ({upper}) - ({lower}))")
                    self.output.append(f"{self._indent()}{list_obj}.insert_many({lower}, {rhs})")
                else:
                    self.used_delete_many, self.used_insert_many = True, True
                    self.output.append(f"{self._indent()}{list_obj}.delete_many({lower}, ({upper}) - ({lower}))")
                    self.output.append(f"{self._indent()}{list_obj}.insert_many({lower}, {rhs})")
                return
            lhs = self.visit(target)
        elif isinstance(target, (ast.Tuple, ast.List)):
             rhs = self.visit(node.value)
             if self.in_main:
                  def track_targets(t):
                       if isinstance(t, (ast.Tuple, ast.List)):
                            for elt in t.elts: track_targets(elt)
                       elif isinstance(t, ast.Starred): track_targets(t.value)
                       elif isinstance(t, ast.Name): self.defined_top_level_symbols.add(t.id)
                  track_targets(target)
             if not any(isinstance(elt, (ast.Tuple, ast.List, ast.Starred)) for elt in target.elts) and isinstance(node.value, (ast.Tuple, ast.List)) and len(node.value.elts) == len(target.elts):
                  lhs_parts = [self.visit(t) for t in target.elts]
                  rhs_parts = [self.visit(v) for v in node.value.elts]
                  self.output.append(f"{self._indent()}{', '.join(lhs_parts)} := {', '.join(rhs_parts)}")
                  return
             rhs_type = self._guess_type(node.value)
             self._visit_destructuring(target, rhs, rhs_type)
             return

        if len(node.targets) > 1:
            rhs = self.visit(node.value)
            rhs_type = self._guess_type(node.value)
            tmp = f"py_assign_tmp_{self.unique_id_counter}"
            self.unique_id_counter += 1
            self.output.append(f"{self._indent()}{tmp} := {rhs}")
            for t in node.targets: self._visit_destructuring(t, tmp, rhs_type)
            return

        if not lhs: return

        # Register lambda call signature so the call-site default injection works.
        # Must happen before visit_Lambda so defaults are available when power(5) is translated.
        if (isinstance(node.value, ast.Lambda)
                and len(node.targets) == 1
                and isinstance(node.targets[0], ast.Name)):
            self._register_lambda_signature(node.targets[0].id, node.value)

        if isinstance(node.value, ast.ListComp):
            if hasattr(self, 'visit_ListComp'): self.visit_ListComp(node.value, target_var=lhs)
            else: self.output.append(f"{self._indent()}//##LLM@@ List comprehension support is missing")
        elif isinstance(node.value, ast.SetComp):
            if hasattr(self, 'visit_SetComp'): self.visit_SetComp(node.value, target_var=lhs)
            else: self.output.append(f"{self._indent()}//##LLM@@ Set comprehension support is missing")
        elif isinstance(node.value, ast.DictComp):
            if hasattr(self, 'visit_DictComp'): self.visit_DictComp(node.value, target_var=lhs)
            else: self.output.append(f"{self._indent()}//##LLM@@ Dict comprehension support is missing")
        elif isinstance(node.value, ast.GeneratorExp):
            if hasattr(self, 'visit_ListComp'): self.visit_ListComp(node.value, target_var=lhs)
            else: self.output.append(f"{self._indent()}//##LLM@@ Generator expression support is missing")
        else:
            is_simple_list, cap = False, 0
            if isinstance(node.value, (ast.List, ast.Tuple)):
                if not any(isinstance(elt, ast.Starred) for elt in node.value.elts):
                    is_simple_list, cap = True, len(node.value.elts)
            v_type = getattr(self, "_guess_type", lambda x: "unknown")(target)
            if isinstance(target, ast.Name) and hasattr(self, 'type_inference'):
                loc_key_lhs = f"{target.id}@{node.lineno}:{node.col_offset}"
                mypy_raw_type = self.type_inference.raw_type_map.get(loc_key_lhs) or self.type_inference.raw_type_map.get(target.id)
                if mypy_raw_type:
                    mapped_v_type = self._map_type(mypy_raw_type, register_sum_types=True)
                    if mapped_v_type and (mapped_v_type.startswith("LiteralEnum_") or mapped_v_type.startswith("TupleStruct_")): v_type = mapped_v_type
            if isinstance(target, ast.Name):
                assigned_type = getattr(self, "_guess_type", lambda x: "unknown")(node.value)
                if assigned_type != "unknown" and assigned_type != "int":
                    if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'type_map'):
                        if target.id not in self.type_inference.type_map: self.type_inference.type_map[target.id] = assigned_type
            is_literal_string = v_type == "LiteralString"
            if is_literal_string and not self._is_literal_string_expr(node.value):
                self.output.append(f"{self._indent()}//##LLM@@ LiteralString variable '{lhs}' receives non-literal value")
            is_implicit_literal = False
            if self._is_literal_string_expr(node.value):
                 is_implicit_literal = True
                 if v_type == "unknown":
                     v_type = "string"
                     if isinstance(target, ast.Name) and hasattr(self, 'type_inference') and hasattr(self.type_inference, 'type_map'):
                         if target.id not in self.type_inference.type_map: self.type_inference.type_map[target.id] = "string"
            is_mut = False
            if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                mut_info = self.type_inference.mutability_map.get(f"{lhs}@{node.lineno}:{node.col_offset}") or self.type_inference.mutability_map.get(lhs)
                if mut_info: is_mut = (mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)) and not mut_info.get("is_final", False)
            is_interface_array, base_v_type = False, ""
            if v_type.startswith("[]"): base_v_type = v_type[2:]
            elif v_type.startswith("?[]"): base_v_type = v_type[3:]
            if base_v_type and base_v_type in self.known_interfaces: is_interface_array = True
            if is_interface_array and isinstance(node.value, (ast.List, ast.Tuple)) and node.value.elts:
                v_lhs = lhs
                if not self.in_main and v_lhs in self._local_vars_in_scope: self.output.append(f"{self._indent()}{v_lhs} = {v_type}{{}}")
                else:
                    self.output.append(f"{self._indent()}mut {v_lhs} := {v_type}{{}}")
                    if not self.in_main: self._local_vars_in_scope.add(v_lhs)
                if isinstance(node.value, (ast.List, ast.Tuple)):
                    for elt in node.value.elts: 
                        self.output.append(f"{self._indent()}{v_lhs} << {self.visit(elt)}")
                return
            if is_simple_list and v_type.startswith("[]") and cap > 0 and is_mut:
                v_lhs = lhs
                if not self.in_main and v_lhs in self._local_vars_in_scope: self.output.append(f"{self._indent()}{v_lhs} = {v_type}{{cap: {cap}}}")
                else:
                    self.output.append(f"{self._indent()}mut {v_lhs} := {v_type}{{cap: {cap}}}")
                    if not self.in_main: self._local_vars_in_scope.add(v_lhs)
                if isinstance(node.value, (ast.List, ast.Tuple)):
                    for elt in node.value.elts: 
                        self.output.append(f"{self._indent()}{v_lhs} << {self.visit(elt)}")
                return
            elif hasattr(self, 'dataclasses') and v_type in self.dataclasses and isinstance(node.value, ast.Dict):
                pairs = [f"{self._sanitize_name(k.value)}: {self.visit(v)}" for k, v in zip(node.value.keys, node.value.values) if isinstance(k, ast.Constant) and isinstance(k.value, str)]
                rhs, v_lhs = f"{v_type}{{{', '.join(pairs)}}}", lhs
                if not self.in_main and v_lhs in self._local_vars_in_scope: self.output.append(f"{self._indent()}{v_lhs} = {rhs}")
                else:
                    self.output.append(f"{self._indent()}{v_lhs} := {rhs}")
                    if not self.in_main: self._local_vars_in_scope.add(v_lhs)
                return
            else:
                is_void_call = False
                if isinstance(node.value, ast.Call):
                    if self._map_type(self._guess_type(node.value), is_return=True) == "void": is_void_call = True
                if isinstance(node.value, ast.Dict) and not node.value.keys and v_type.startswith("map["): rhs = f"{v_type}{{}}"
                elif is_void_call:
                    prev_type = self.current_assignment_type
                    self.current_assignment_type = v_type
                    call_expr = self.visit(node.value)
                    self.current_assignment_type = prev_type
                    self.output.append(f"{self._indent()}{call_expr}")
                    local_v_type = getattr(self, "_guess_type", lambda x: "unknown")(target)
                    if local_v_type == "Any" or (local_v_type.startswith("map[") and local_v_type.endswith("]Any")) or local_v_type == "unknown": rhs = "Any(NoneType{})"
                    else:
                        if not local_v_type.startswith("?"): local_v_type = f"?{local_v_type}"
                        rhs = f"(none as {local_v_type})"
                else:
                    prev_type = getattr(self, "current_assignment_type", None)
                    self.current_assignment_type = v_type
                    rhs = self.visit(node.value)
                    if v_type.startswith("LiteralEnum_"):
                        clean_val = "".join(c for c in rhs if c.isalnum() or c == "_").lower()
                        if not clean_val: clean_val = "empty"
                        if clean_val[0].isdigit(): clean_val = "v" + clean_val
                        rhs = f".{clean_val}"
                    self.current_assignment_type = prev_type
                assigned_value_type = getattr(self, "_guess_type", lambda x: "unknown")(node.value)
                if (assigned_value_type == "void" or assigned_value_type == "none" or assigned_value_type == "None") and isinstance(node.value, ast.Call):
                    self.output.append(f"{self._indent()}{rhs}")
                    target_type = getattr(self, "_guess_type", lambda x: "unknown")(target)
                    if getattr(self, "current_assignment_type", None) == "Any" or target_type == "Any" or target_type == "unknown": rhs, v_type = "Any(NoneType{})", "Any"
                    else: rhs = "none"
                emit_fn = self.output.append
                if self.in_main:
                    base_lhs = lhs.split('.')[0].split('[')[0]
                    # Check original ID for uppercase detection
                    orig_is_upper = isinstance(target, ast.Name) and target.id.isupper()
                    if base_lhs in getattr(self, "global_vars", set()):
                        emit_fn = lambda stmt: self.emitter.add_init_statement(stmt.strip())
                        if isinstance(target, ast.Name):
                            if v_type == "unknown": v_type = "Any"
                            self.emitter.add_global(f"{lhs} {v_type}")
                    elif orig_is_upper:
                        emit_fn = lambda stmt: self.emitter.add_init_statement(stmt.strip())
                        if isinstance(target, ast.Name):
                            v_lhs = self._to_snake_case(lhs)
                            if self._is_compile_time_evaluable(node.value):
                                pub = "pub " if self._is_exported(target.id) else ""
                                self.emitter.add_constant(f"pub {v_lhs} = {rhs}" if pub else f"{v_lhs} = {rhs}")
                                return
                            else:
                                if v_type == "unknown" or v_type == "int": v_type = "Any"
                                self.emitter.add_global(f"{v_lhs} {v_type}")
                if self.in_main and isinstance(target, ast.Name) and (lhs in getattr(self, "global_vars", set()) or target.id.isupper() or is_implicit_literal or is_literal_string):
                    v_lhs = lhs
                    if (is_implicit_literal or is_literal_string) and self._is_compile_time_evaluable(node.value) and not target.id.isupper():
                        pub = "pub " if self._is_exported(target.id) else ""
                        self.emitter.add_constant(f"pub {v_lhs} = {rhs}" if pub else f"{v_lhs} = {rhs}")
                        return
                    if (is_implicit_literal or is_literal_string) and not self._is_compile_time_evaluable(node.value) and not target.id.isupper():
                        if lhs not in getattr(self, "global_vars", set()): self.emitter.add_global(f"{v_lhs} string")
                        self.emitter.add_init_statement(f"{v_lhs} = {rhs}")
                        return
                    if not (target.id.isupper() and self._is_compile_time_evaluable(node.value)): emit_fn(f"{self._indent()}{v_lhs} = {rhs}")
                elif rhs == "none":
                    local_v_type, v_lhs = getattr(self, "_guess_type", lambda x: "unknown")(target), lhs
                    if isinstance(target, (ast.Attribute, ast.Subscript)) or (not self.in_main and v_lhs in self._local_vars_in_scope):
                        if local_v_type == "Any" or (local_v_type.startswith("map[") and local_v_type.endswith("]Any")): emit_fn(f"{self._indent()}{v_lhs} = Any(NoneType{{}})")
                        else: emit_fn(f"{self._indent()}{v_lhs} = none")
                    else:
                        if local_v_type and local_v_type != "unknown":
                            if local_v_type == "Any" or (local_v_type.startswith("map[") and local_v_type.endswith("]Any")): emit_fn(f"{self._indent()}mut {v_lhs} := Any(NoneType{{}})")
                            else:
                                if not local_v_type.startswith("?"): local_v_type = f"?{local_v_type}"
                                emit_fn(f"{self._indent()}mut {v_lhs} := {local_v_type}(none)")
                        else: emit_fn(f"{self._indent()}mut {v_lhs} := Any(NoneType{{}})")
                        if not self.in_main: self._local_vars_in_scope.add(v_lhs)
                else:
                    v_lhs = lhs
                    if isinstance(target, ast.Attribute) or isinstance(target, ast.Subscript): emit_fn(f"{self._indent()}{lhs} = {rhs}")
                    else:
                        if emit_fn == self.output.append:
                            if not self.in_main and v_lhs in self._local_vars_in_scope:
                                opt_type = getattr(self, '_cond_optional_var_type', {}).get(v_lhs)
                                if opt_type and rhs != 'none' and not rhs.startswith('?'):
                                    if opt_type == '?Any':
                                        rhs = f'Any({rhs})'
                                    else:
                                        rhs = f'{opt_type}({rhs})'
                                emit_fn(f"{self._indent()}{v_lhs} = {rhs}")
                            else:
                                is_mut = False
                                if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                                    mut_info = self.type_inference.mutability_map.get(f"{v_lhs}@{node.lineno}:{node.col_offset}") or self.type_inference.mutability_map.get(v_lhs)
                                    if mut_info: is_mut = (mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)) and not mut_info.get("is_final", False)
                                if not is_mut and isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "bytearray": is_mut = True
                                if is_mut and self._is_clonable_collection(v_type) and not (rhs.startswith("[") or rhs.startswith("map[") or rhs.startswith("{")): rhs = f"{rhs}.clone()"
                                mut_prefix = "mut " if is_mut else ""
                                emit_fn(f"{self._indent()}{mut_prefix}{v_lhs} := {rhs}")
                                if not self.in_main: self._local_vars_in_scope.add(v_lhs)
                        else: emit_fn(f"{self._indent()}{v_lhs} = {rhs}")

    def _visit_destructuring(self, target: ast.AST, source_expr: str, source_type: str = "unknown") -> None:
        if isinstance(target, (ast.Tuple, ast.List)):
             tmp_var = f"py_destruct_{self._zip_counter}"
             self._zip_counter += 1
             self.output.append(f"{self._indent()}{tmp_var} := {source_expr}")
             starred_idx = -1
             for i, elt in enumerate(target.elts):
                 if isinstance(elt, ast.Starred):
                     starred_idx = i
                     break
             is_tuple = self._is_tuple_struct(source_type)
             if starred_idx == -1:
                 for i, elt in enumerate(target.elts): self._visit_destructuring(elt, f"{tmp_var}.it_{i}" if is_tuple else f"{tmp_var}[{i}]")
             else:
                 for i in range(starred_idx): self._visit_destructuring(target.elts[i], f"{tmp_var}.it_{i}" if is_tuple else f"{tmp_var}[{i}]")
                 star_elt = target.elts[starred_idx]
                 if isinstance(star_elt, ast.Starred):
                     trailing = len(target.elts) - 1 - starred_idx
                     slice_expr = f"{tmp_var}[{starred_idx}..]" if trailing == 0 else f"{tmp_var}[{starred_idx}..({tmp_var}.len - {trailing})]"
                     self._visit_destructuring(star_elt.value, slice_expr)
                 for i in range(starred_idx + 1, len(target.elts)):
                     offset = len(target.elts) - i
                     self._visit_destructuring(target.elts[i], f"{tmp_var}.it_{i}" if is_tuple else f"{tmp_var}[({tmp_var}.len - {offset})]")
        elif isinstance(target, ast.Name):
            lhs = self.visit(target)
            if not self.in_main and lhs in self._local_vars_in_scope: self.output.append(f"{self._indent()}{lhs} = {source_expr}")
            else:
                is_mut = False
                if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                    mut_info = self.type_inference.mutability_map.get(f"{lhs}@{target.lineno}:{target.col_offset}") or self.type_inference.mutability_map.get(lhs)
                    if mut_info: is_mut = (mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)) and not mut_info.get("is_final", False)
                v_type = getattr(self, "_guess_type", lambda x: "unknown")(target)
                if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'raw_type_map'):
                    mypy_raw_type = self.type_inference.raw_type_map.get(f"{lhs}@{target.lineno}:{target.col_offset}")
                    if mypy_raw_type:
                        mapped_v_type = self._map_type(mypy_raw_type, register_sum_types=True)
                        if mapped_v_type: v_type = mapped_v_type
                if is_mut and self._is_clonable_collection(v_type) and not (source_expr.startswith("[") or source_expr.startswith("map[") or source_expr.startswith("{")): source_expr = f"{source_expr}.clone()"
                mut_prefix = "mut " if is_mut else ""
                self.output.append(f"{self._indent()}{mut_prefix}{lhs} := {source_expr}")
                if not self.in_main: self._local_vars_in_scope.add(lhs)
        elif isinstance(target, (ast.Attribute, ast.Subscript)): self.output.append(f"{self._indent()}{self.visit(target)} = {source_expr}")
        else: self.output.append(f"{self._indent()}//##LLM@@ Unsupported destructuring target")

    def _register_lambda_signature(self, name: str, lambda_node: ast.Lambda) -> None:
        """Register a lambda's call signature so the call-site default-injection works.

        Python's `power = lambda x, n=2: x**n` carries a real default (n=2).
        When the call `power(5)` is translated, the existing mechanism in
        calls.py:280-292 injects missing positional args from defaults — but only
        if the lambda's signature is recorded in type_inference.call_signatures.

        Notes on defaults_map alignment:
        - arguments.defaults covers the LAST N args of `posonlyargs + args` combined.
        - arguments.kw_defaults covers kwonlyargs 1-to-1 (None = no default).
        - i=i self-reference defaults are capture-by-value (Issue #35); they must
          NOT be injected at the call site — exclude them here.
        """
        if not hasattr(self, 'type_inference') or not hasattr(self.type_inference, 'call_signatures'):
            return

        args = lambda_node.args
        posonly = list(getattr(args, 'posonlyargs', []))
        positional = posonly + list(args.args)

        # Build defaults_map for positional args (last N of positional list)
        defaults_map: Dict[str, ast.expr] = {}
        if args.defaults:
            defaults_start = len(positional) - len(args.defaults)
            for idx, default in enumerate(args.defaults):
                arg_name = positional[defaults_start + idx].arg
                defaults_map[arg_name] = default

        # Build defaults_map for kwonly args (1-to-1 with kw_defaults, None = no default)
        for kwarg, kwdefault in zip(args.kwonlyargs, getattr(args, 'kw_defaults', [])):
            if kwdefault is not None:
                defaults_map[kwarg.arg] = kwdefault

        # Determine which args are i=i capture-by-value (Issue #35).
        # Those are NOT real callable parameters — skip them.
        capture_names: Set[str] = set()
        for arg_name, default in defaults_map.items():
            if isinstance(default, ast.Name) and default.id == arg_name:
                capture_names.add(arg_name)

        # Build ordered arg_names for non-capture positional + kwonly args
        arg_names = [a.arg for a in positional if a.arg not in capture_names]
        arg_names += [a.arg for a in args.kwonlyargs if a.arg not in capture_names]

        # Filter defaults_map to only real defaults (exclude capture-by-value ones)
        real_defaults = {k: v for k, v in defaults_map.items() if k not in capture_names}

        self.type_inference.call_signatures[name] = {
            "arg_names": arg_names,
            "defaults": real_defaults,
            "args": ["Any"] * len(arg_names),
            "return": "Any",
            "is_class": False,
            "has_vararg": args.vararg is not None,
            "has_kwarg": args.kwarg is not None,
        }

    def visit_NamedExpr(self, node: ast.NamedExpr) -> str:
        target = self._sanitize_name(node.target.id)
        value = self.visit(node.value)
        self._walrus_assignments.append(f"{target} := {value}")
        return target
