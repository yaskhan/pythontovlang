import ast
from typing import Dict, Any
from ..base import TranslatorBase

class LoopsMixin(TranslatorBase):
    """Обработка циклов: for, async for, while"""
    
    def visit_While(self, node: ast.While) -> None:
        loop_ctx: Dict[str, Any] = {}
        flag_name = ""
        if node.orelse:
            flag_name = f"_loop_completed_{self.unique_id_counter}"
            self.unique_id_counter += 1
            self.output.append(f"{self._indent()}mut {flag_name} := true")
            loop_ctx['flag'] = flag_name
        loop_ctx['vexc_depth'] = self.vexc_depth

        self.loop_stack.append(loop_ctx)

        self._walrus_assignments = []
        test_expr = self._wrap_bool(node.test)

        if self._walrus_assignments:
             # Found walrus! Transform loop.
             self.output.append(f"{self._indent()}for {{")
             self._indent_level += 1

             for assign in self._walrus_assignments:
                 self.output.append(f"{self._indent()}{assign}")

             self.output.append(f"{self._indent()}if !({test_expr}) {{ break }}")
             self._walrus_assignments = []

             for stmt in node.body:
                 self.visit(stmt)

             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")
        else:
             # Normal while
             self.output.append(f"{self._indent()}for {test_expr} {{")
             self._indent_level += 1
             for stmt in node.body:
                 self.visit(stmt)
             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")

        self.loop_stack.pop()

        if node.orelse:
            self.output.append(f"{self._indent()}if {flag_name} {{")
            self._indent_level += 1
            for stmt in node.orelse:
                self.visit(stmt)
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

    def visit_AsyncFor(self, node: ast.AsyncFor) -> None:
        # Treat async for similar to for loop over channel
        # Assuming node.iter returns a channel (async generator call)
        target = self.visit(node.target)
        iter_expr = self.visit(node.iter)

        # Push loop context to stack for break handling
        self.loop_stack.append({'vexc_depth': self.vexc_depth})
# 1. Сначала проверяем на деструктуризацию кортежа (из feat-ветки)
        if isinstance(node.target, ast.Tuple) and target.startswith("[") and target.endswith("]"):
            val_name = f"_val_{id(node)}"
            self.output.append(f"{self._indent()}for {val_name} in {iter_expr} {{")
            self._indent_level += 1
            for i, elt in enumerate(node.target.elts):
                elt_name = self.visit(elt)
                self.output.append(f"{self._indent()}{elt_name} := {val_name}[{i}]")
            for stmt in node.body:
                self.visit(stmt)
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")
            self.loop_stack.pop()
            if node.orelse:
                self.output.append(f"{self._indent()}// else clause in async for not supported yet")
            return

        # 2. Если это не кортеж, проверяем итерацию по строке (из main-ветки)
        is_string_iter = False
        if isinstance(node.iter, ast.Call) and getattr(node.iter.func, 'id', '') == "str":
            is_string_iter = True
        elif hasattr(self, '_guess_type') and self._guess_type(node.iter) == "string":
            is_string_iter = True

        if is_string_iter:
            # Специфичная логика V: u8 -> string
            self.output.append(f"{self._indent()}for {target}_u8 in {iter_expr} {{")
            self._indent_level += 1
            self.output.append(f"{self._indent()}{target} := {target}_u8.ascii_str()")
            for stmt in node.body:
                self.visit(stmt)
        else:
            # Стандартный цикл для всех остальных случаев
            self.output.append(f"{self._indent()}for {target} in {iter_expr} {{")
            self._indent_level += 1
            for stmt in node.body:
                self.visit(stmt)

        # 3. Закрываем блок (это было общим в обеих ветках)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

        self.loop_stack.pop()

        if node.orelse:
            self.output.append(f"{self._indent()}// else clause in async for not supported yet")

    def visit_For(self, node: ast.For) -> None:
        loop_ctx: Dict[str, Any] = {}
        flag_name = ""
        if node.orelse:
            flag_name = f"_loop_completed_{self.unique_id_counter}"
            self.unique_id_counter += 1
            self.output.append(f"{self._indent()}mut {flag_name} := true")
            loop_ctx['flag'] = flag_name
        loop_ctx['vexc_depth'] = self.vexc_depth

        self.loop_stack.append(loop_ctx)

        # Helper to check if a call is zip or izip
        is_zip = False
        if isinstance(node.iter, ast.Call):
            func_node = node.iter.func
            if isinstance(func_node, ast.Name):
                if func_node.id in ("zip", "izip"):
                    is_zip = True
            elif isinstance(func_node, ast.Attribute):
                if func_node.attr == "izip":
                    is_zip = True

        # Zip handling
        if is_zip and isinstance(node.iter, ast.Call):
            zip_args = node.iter.args
            if len(zip_args) == 2:
                self._zip_counter += 1
                zip_id = self._zip_counter
                it1 = self.visit(zip_args[0])
                it2 = self.visit(zip_args[1])
                var_it1 = f"_zip_it1_{zip_id}"
                var_it2 = f"_zip_it2_{zip_id}"
                var_i = f"_i_{zip_id}"
                var_v1 = f"_v1_{zip_id}"
                var_v2 = f"_v2_{zip_id}"
                self.output.append(f"{self._indent()}{var_it1} := {it1}")
                self.output.append(f"{self._indent()}{var_it2} := {it2}")
                self.output.append(f"{self._indent()}for {var_i}, {var_v1} in {var_it1} {{")
                self._indent_level += 1
                self.output.append(f"{self._indent()}if {var_i} >= {var_it2}.len {{ break }}")
                self.output.append(f"{self._indent()}{var_v2} := {var_it2}[{var_i}]")
                if isinstance(node.target, ast.Tuple) and len(node.target.elts) == 2:
                    t1 = self.visit(node.target.elts[0])
                    t2 = self.visit(node.target.elts[1])
                    self.output.append(f"{self._indent()}{t1} := {var_v1}")
                    self.output.append(f"{self._indent()}{t2} := {var_v2}")
                else:
                    target = self.visit(node.target)
                    self.output.append(f"{self._indent()}{target} := [{var_v1}, {var_v2}]")
                for stmt in node.body:
                    self.visit(stmt)
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")

                self.loop_stack.pop()
                if node.orelse:
                     self.output.append(f"{self._indent()}if {flag_name} {{")
                     self._indent_level += 1
                     for stmt in node.orelse:
                         self.visit(stmt)
                     self._indent_level -= 1
                     self.output.append(f"{self._indent()}}}")
                return

        target = self.visit(node.target)
        iter_expr = self.visit(node.iter)

        is_range = False
        if isinstance(node.iter, ast.Call):
            func_node = node.iter.func
            if isinstance(func_node, ast.Name):
                if func_node.id in ("range", "xrange"):
                    is_range = True
            elif isinstance(func_node, ast.Attribute):
                # Поддержка six.moves.xrange или подобных конструкций
                if func_node.attr == "xrange":
                    is_range = True

        # Логика для dict.items() из main
        if isinstance(node.iter, ast.Call) and isinstance(node.iter.func, ast.Attribute) and node.iter.func.attr == "items":
            if isinstance(node.target, ast.Tuple):
                if target.startswith("[") and target.endswith("]"):
                    target = target[1:-1]
            iter_expr = self.visit(node.iter.func.value)

        if is_range and isinstance(node.iter, ast.Call):
                 range_args = node.iter.args
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
                     for stmt in node.body:
                         self.visit(stmt)
                     self._indent_level -= 1
                     self.output.append(f"{self._indent()}}}")

                     self.loop_stack.pop()
                     if node.orelse:
                         self.output.append(f"{self._indent()}if {flag_name} {{")
                         self._indent_level += 1
                         for stmt in node.orelse:
                             self.visit(stmt)
                         self._indent_level -= 1
                         self.output.append(f"{self._indent()}}}")
                     return
                 start = "0"
                 stop = "0"
                 if len(range_args) == 1:
                      stop = self.visit(range_args[0])
                 elif len(range_args) == 2:
                      start = self.visit(range_args[0])
                      stop = self.visit(range_args[1])
                 iter_expr = f"{start}..{stop}"
        elif isinstance(node.iter, ast.Call) and isinstance(node.iter.func, ast.Name):
             if node.iter.func.id == "enumerate":
                 if node.iter.args:
                     iter_expr = self.visit(node.iter.args[0])
                     if isinstance(node.target, ast.Tuple):
                         if target.startswith("[") and target.endswith("]"):
                             target = target[1:-1]
                     else:
                         self.output.append(f"{self._indent()}// TODO: handle enumerate with single target variable")

        # Определяем вспомогательные флаги из обеих веток
        is_enumerate = isinstance(node.iter, ast.Call) and getattr(node.iter.func, "id", "") == "enumerate"
        is_dict_items = isinstance(node.iter, ast.Call) and isinstance(node.iter.func, ast.Attribute) and node.iter.func.attr == "items"

        is_string_iter = False
        iter_to_check = node.iter
        if is_enumerate and isinstance(node.iter, ast.Call) and node.iter.args:
            iter_to_check = node.iter.args[0]

        if isinstance(iter_to_check, ast.Call) and getattr(iter_to_check.func, 'id', '') == "str":
            is_string_iter = True
        elif hasattr(self, '_guess_type') and self._guess_type(iter_to_check) == "string":
            is_string_iter = True

        # 1. Обработка деструктуризации кортежа (кроме случаев с enumerate/dict.items)
        if isinstance(node.target, ast.Tuple) and target.startswith("[") and target.endswith("]") and not is_enumerate and not is_dict_items:
            val_name = f"_val_{id(node)}"
            self.output.append(f"{self._indent()}for {val_name} in {iter_expr} {{")
            self._indent_level += 1
            for i, elt in enumerate(node.target.elts):
                elt_name = self.visit(elt)
                self.output.append(f"{self._indent()}{elt_name} := {val_name}[{i}]")
            for stmt in node.body:
                self.visit(stmt)
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")
            self.loop_stack.pop()

            # Обработка orelse (из feat ветки)
            if node.orelse:
                self.output.append(f"{self._indent()}if {flag_name} {{")
                self._indent_level += 1
                for stmt in node.orelse:
                    self.visit(stmt)
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
            return

        # 2. Подготовка таргета для dict.items
        if is_dict_items and target.startswith("[") and target.endswith("]"):
            target = target[1:-1]

        # 3. Генерация основного цикла (с учетом специфики строк в V)
        if is_string_iter:
            if is_enumerate and "," in target:
                parts = [p.strip() for p in target.split(",")]
                idx_var = parts[0]
                val_var = parts[1]
                self.output.append(f"{self._indent()}for {idx_var}, {val_var}_u8 in {iter_expr} {{")
                self._indent_level += 1
                self.output.append(f"{self._indent()}{val_var} := {val_var}_u8.ascii_str()")
            else:
                self.output.append(f"{self._indent()}for {target}_u8 in {iter_expr} {{")
                self._indent_level += 1
                self.output.append(f"{self._indent()}{target} := {target}_u8.ascii_str()")
        else:
            self.output.append(f"{self._indent()}for {target} in {iter_expr} {{")
            self._indent_level += 1

        # Тело цикла (общее для строк и обычного случая)
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

        self.loop_stack.pop()
        if node.orelse:
            self.output.append(f"{self._indent()}if {flag_name} {{")
            self._indent_level += 1
            for stmt in node.orelse:
                self.visit(stmt)
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")
