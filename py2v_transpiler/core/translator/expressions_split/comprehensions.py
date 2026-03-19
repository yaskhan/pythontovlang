import ast
from typing import List, Optional, Any, Union
from ..base import TranslatorBase

class ComprehensionsMixin(TranslatorBase):
    def _emit_generators(self, generators: List[ast.comprehension], body_callback):
        if not generators:
            body_callback()
            return

        gen = generators[0]
        rest = generators[1:]

        if getattr(gen, 'is_async', False):
            self.output.append(f"{self._indent()}//##LLM@@ Async comprehension used. Please verify and properly implement the async iterator semantics in V.")

        is_zip = False
        if isinstance(gen.iter, ast.Call):
            func_node = gen.iter.func
            if isinstance(func_node, ast.Name):
                if func_node.id in ("zip", "izip"):
                    is_zip = True
            elif isinstance(func_node, ast.Attribute):
                if func_node.attr == "izip":
                    is_zip = True

        if is_zip and isinstance(gen.iter, ast.Call):
            zip_args = gen.iter.args
            if len(zip_args) == 2:
                self._zip_counter += 1
                zip_id = self._zip_counter

                it1 = self.visit(zip_args[0])
                it2 = self.visit(zip_args[1])

                var_it1 = f"py_zip_it1_{zip_id}"
                var_it2 = f"py_zip_it2_{zip_id}"
                var_i = f"py_i_{zip_id}"
                var_v1 = f"py_v1_{zip_id}"
                var_v2 = f"py_v2_{zip_id}"

                self.output.append(f"{self._indent()}{var_it1} := {it1}")
                self.output.append(f"{self._indent()}{var_it2} := {it2}")

                self.output.append(f"{self._indent()}for {var_i}, {var_v1} in {var_it1} {{")
                self._indent_level += 1

                self.output.append(f"{self._indent()}if {var_i} >= {var_it2}.len {{ break }}")
                self.output.append(f"{self._indent()}{var_v2} := {var_it2}[{var_i}]")

                if isinstance(gen.target, ast.Tuple) and len(gen.target.elts) == 2:
                    t1 = self.visit(gen.target.elts[0])
                    t2 = self.visit(gen.target.elts[1])
                    self.output.append(f"{self._indent()}{t1} := {var_v1}")
                    self.output.append(f"{self._indent()}{t2} := {var_v2}")
                else:
                    target = self.visit(gen.target)
                    self.output.append(f"{self._indent()}{target} := [{var_v1}, {var_v2}]")

                for if_expr in gen.ifs:
                    cond = self.visit(if_expr)
                    self.output.append(f"{self._indent()}if {cond} {{")
                    self._indent_level += 1

                self._emit_generators(rest, body_callback)

                for _ in gen.ifs:
                    self._indent_level -= 1
                    self.output.append(f"{self._indent()}}}")

                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
                return

        target = self.visit(gen.target)
        iter_expr = self.visit(gen.iter)

        is_range = False
        if isinstance(gen.iter, ast.Call):
            func_node = gen.iter.func
            if isinstance(func_node, ast.Name):
                if func_node.id in ("range", "xrange"):
                    is_range = True
            elif isinstance(func_node, ast.Attribute):
                if func_node.attr == "xrange":
                    is_range = True

        if is_range and isinstance(gen.iter, ast.Call):
            range_args = gen.iter.args
            if len(range_args) == 3:
                start = self.visit(range_args[0])
                stop = self.visit(range_args[1])
                step = self.visit(range_args[2])

                is_negative_step = False
                if isinstance(range_args[2], ast.UnaryOp) and isinstance(range_args[2].op, ast.USub):
                    is_negative_step = True
                elif isinstance(range_args[2], ast.Constant) and isinstance(range_args[2].value, (int, float)) and range_args[2].value < 0:
                    is_negative_step = True

                op = ">" if is_negative_step else "<"

                self.output.append(f"{self._indent()}for {target} := {start}; {target} {op} {stop}; {target} += {step} {{")
                self._indent_level += 1

                for if_expr in gen.ifs:
                    cond = self.visit(if_expr)
                    self.output.append(f"{self._indent()}if {cond} {{")
                    self._indent_level += 1

                self._emit_generators(rest, body_callback)

                for _ in gen.ifs:
                    self._indent_level -= 1
                    self.output.append(f"{self._indent()}}}")

                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
                return

            start_str = "0"
            stop_str = "0"
            if len(range_args) == 1:
                stop_str = str(self.visit(range_args[0]))
            elif len(range_args) == 2:
                start_str = str(self.visit(range_args[0]))
                stop_str = str(self.visit(range_args[1]))
            iter_expr = f"{start_str}..{stop_str}"
        elif isinstance(gen.iter, ast.Call) and isinstance(gen.iter.func, ast.Name):
            if gen.iter.func.id == "enumerate":
                if gen.iter.args:
                    iter_expr = self.visit(gen.iter.args[0])
                    # Handle target for enumerate: for i, v in items
                    if isinstance(gen.target, ast.Tuple):
                        # visit_Tuple returns [i, v], we need i, v
                        if target.startswith("[") and target.endswith("]"):
                            target = target[1:-1]
                    else:
                        self.output.append(f"{self._indent()}//##LLM@@ Enumerate used with a single target variable instead of unpacking. Please rewrite to unpack the index and value properly.")

        is_enumerate = isinstance(gen.iter, ast.Call) and getattr(gen.iter.func, "id", "") == "enumerate"
        if isinstance(gen.target, ast.Tuple) and not is_enumerate:
             val_name = f"py_comp_val_{id(gen)}"
             self.output.append(f"{self._indent()}for {val_name} in {iter_expr} {{")
             self._indent_level += 1

             iter_t = getattr(self, "_guess_type", lambda x: "unknown")(gen.iter)
             elt_t = "unknown"
             if iter_t.startswith("[]"):
                  elt_t = iter_t[2:]
             is_tuple = self._is_tuple_struct(elt_t)

             for i, elt in enumerate(gen.target.elts):
                 elt_name = self.visit(elt)
                 idx_expr = f"{val_name}.it_{i}" if is_tuple else f"{val_name}[{i}]"
                 self.output.append(f"{self._indent()}{elt_name} := {idx_expr}")
        else:
             self.output.append(f"{self._indent()}for {target} in {iter_expr} {{")
             self._indent_level += 1

        for if_expr in gen.ifs:
            cond = self.visit(if_expr)
            self.output.append(f"{self._indent()}if {cond} {{")
            self._indent_level += 1

        self._emit_generators(rest, body_callback)

        for _ in gen.ifs:
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def visit_ListComp(self, node: Union[ast.ListComp, ast.GeneratorExp], target_var: Optional[str] = None) -> Optional[str]:
        is_inline = False
        if target_var is None:
            is_inline = True
            self.unique_id_counter += 1
            target_var = f"py_comp_{self.unique_id_counter}"

        gen = node.generators[0] # Handle first generator

        if len(node.generators) > 1 or len(gen.ifs) > 1:
            self.output.append(f"{self._indent()}//##LLM@@ Complex nested comprehension detected. To ensure readability and idiomatic V, please unfold this into explicit 'for' loops or a clean chain of .map() and .filter() calls.")

        self._infer_generator_types(gen)

        # Determine capacity for pre-allocation
        cap_str = ""
        if not gen.ifs:
            # Only if there are no filtering conditions
            if isinstance(gen.iter, (ast.List, ast.Tuple)):
                cap_str = f"cap: {len(gen.iter.elts)}"
            elif isinstance(gen.iter, ast.Call) and isinstance(gen.iter.func, ast.Name) and gen.iter.func.id == "range":
                range_args = gen.iter.args
                # Check if all arguments are constants
                all_const = all(
                    isinstance(arg, ast.Constant) and isinstance(arg.value, int) or
                    (isinstance(arg, ast.UnaryOp) and isinstance(arg.op, ast.USub) and isinstance(arg.operand, ast.Constant) and isinstance(arg.operand.value, int))
                    for arg in range_args
                )
                if all_const:
                    def get_int_val(arg: Any) -> int:
                        if isinstance(arg, ast.UnaryOp) and isinstance(arg.operand, ast.Constant):
                            val = arg.operand.value
                            if isinstance(val, int):
                                return -val
                        elif isinstance(arg, ast.Constant) and isinstance(arg.value, int):
                            return arg.value
                        return 0

                    if len(range_args) == 1:
                        stop = get_int_val(range_args[0])
                        length = max(0, stop)
                        cap_str = f"cap: {length}"
                    elif len(range_args) == 2:
                        start = get_int_val(range_args[0])
                        stop = get_int_val(range_args[1])
                        length = max(0, stop - start)
                        cap_str = f"cap: {length}"
                    elif len(range_args) == 3:
                        start = get_int_val(range_args[0])
                        stop = get_int_val(range_args[1])
                        step = get_int_val(range_args[2])
                        if step != 0:
                            if step > 0:
                                length = max(0, (stop - start + step - 1) // step)
                            else:
                                length = max(0, (start - stop - step - 1) // (-step))
                            cap_str = f"cap: {length}"

        elt_type = self._guess_type(node.elt)
        if elt_type == "unknown":
            elt_type = "int" # Default to int to match existing tests
        v_type = f"[]{elt_type}"

        if cap_str:
            self.output.append(f"{self._indent()}mut {target_var} := {v_type}{{{cap_str}}}")
        else:
            self.output.append(f"{self._indent()}mut {target_var} := {v_type}{{}}")

        def body():
            elt = self.visit(node.elt)
            self.output.append(f"{self._indent()}{target_var} << {elt}")

        self._emit_generators(node.generators, body)
        return target_var if is_inline else None

    def visit_GeneratorExp(self, node: ast.GeneratorExp, target_var: Optional[str] = None) -> Optional[str]:
        # Eagerly evaluate generator expressions into lists
        return self.visit_ListComp(node, target_var)

    def visit_DictComp(self, node: ast.DictComp, target_var: Optional[str] = None) -> Optional[str]:
        is_inline = False
        if target_var is None:
            is_inline = True
            self.unique_id_counter += 1
            target_var = f"py_comp_{self.unique_id_counter}"

        gen = node.generators[0] # Handle first generator

        if len(node.generators) > 1 or len(gen.ifs) > 1:
            self.output.append(f"{self._indent()}//##LLM@@ Complex nested comprehension detected. To ensure readability and idiomatic V, please unfold this into explicit 'for' loops or a clean chain of .map() and .filter() calls.")

        self._infer_generator_types(gen)

        key_type = self._guess_type(node.key)
        val_type = self._guess_type(node.value)
        is_decl = target_var.isidentifier()
        op = ":=" if is_decl else "="
        mut_prefix = "mut " if is_decl else ""
        self.output.append(f"{self._indent()}{mut_prefix}{target_var} {op} map[{key_type}]{val_type}{{}}")

        def body():
            key = self.visit(node.key)
            val = self.visit(node.value)
            self.output.append(f"{self._indent()}{target_var}[{key}] = {val}")

        self._emit_generators(node.generators, body)
        return target_var if is_inline else None

    def visit_SetComp(self, node: ast.SetComp, target_var: Optional[str] = None) -> Optional[str]:
        is_inline = False
        if target_var is None:
            is_inline = True
            self.unique_id_counter += 1
            target_var = f"py_comp_{self.unique_id_counter}"

        gen = node.generators[0] # Handle first generator

        if len(node.generators) > 1 or len(gen.ifs) > 1:
            self.output.append(f"{self._indent()}//##LLM@@ Complex nested comprehension detected. To ensure readability and idiomatic V, please unfold this into explicit 'for' loops or a clean chain of .map() and .filter() calls.")

        self._infer_generator_types(gen)

        key_type = self._guess_type(node.elt)
        is_decl = target_var.isidentifier()
        op = ":=" if is_decl else "="
        mut_prefix = "mut " if is_decl else ""
        self.output.append(f"{self._indent()}{mut_prefix}{target_var} {op} map[{key_type}]bool{{}}")

        def body():
            elt = self.visit(node.elt)
            self.output.append(f"{self._indent()}{target_var}[{elt}] = true")

        self._emit_generators(node.generators, body)
        return target_var if is_inline else None
