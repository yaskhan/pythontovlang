"""Handling generators, coroutines, and iterators."""

import ast
import re
from typing import Any, List


class GeneratorCallsMixin:
    def _handle_generator_call(self, node: ast.Call, func_name_str: str, args: list) -> str | None:
        """Handle generator calls."""

        if not self.coroutine_handler or not self.coroutine_handler.is_generator(func_name_str):
            return None

        # Generate unique names
        ch_out_name = self.coroutine_handler.get_temp_channel_name()
        ch_in_name = ch_out_name.replace("ch_", "ch_in_")
        gen_var_name = ch_out_name.replace("ch_", "gen_")

        yield_type = self.coroutine_handler.get_generator_type(func_name_str)

        # Emit setup code
        self.output.append(f"{self._indent()}{ch_out_name} := chan {yield_type}{{cap: 0}}")
        self.output.append(f"{self._indent()}{ch_in_name} := chan PyGeneratorInput{{cap: 0}}")
        self.output.append(f"{self._indent()}{gen_var_name} := PyGenerator[{yield_type}]{{out: {ch_out_name}, in_: {ch_in_name}}}")

        # Construct spawn arguments
        spawn_args = [ch_out_name, ch_in_name] + args
        self.output.append(f"{self._indent()}spawn {func_name_str}({', '.join(spawn_args)})")

        return gen_var_name

    def _handle_iterator_functions(self, node: ast.Call, func_name_str: str, args: list) -> str | None:
        """Handle iterator functions: next, sorted, reversed, map, filter, any, all."""
        
        # next(gen) -> gen.next()
        if func_name_str == "next" and len(args) >= 1:
            gen = args[0]
            return f"{gen}.next()"
        
        # sorted()
        if func_name_str == "sorted":
            self.used_builtins.add("sorted")
            return f"py_sorted({', '.join(args)})"
        
        # reversed()
        if func_name_str == "reversed":
            self.used_builtins.add("reversed")
            return f"py_reversed({', '.join(args)})"
        
        # map()
        if func_name_str == "map" and len(args) == 2:
            func = args[0]
            iterable = args[1]
            return f"{iterable}.map({func}(it))"
        
        # filter()
        if func_name_str == "filter" and len(args) == 2:
            func = args[0]
            iterable = args[1]
            if func == "None" or func == "none":
                return f"{iterable}.filter(it)"
            return f"{iterable}.filter({func}(it))"
        
        # any() / all()
        if func_name_str in ("any", "all") and len(node.args) == 1:
            return self._handle_any_all(node, func_name_str, args)
        
        return None

    def _handle_any_all(self, node: ast.Call, func_name_str: str, args: list) -> str:
        """Handle any() and all()."""
        arg = node.args[0]

        if isinstance(arg, ast.GeneratorExp):
            # any(expr for target in iter) -> iter.any(expr_with_it)
            comp_gen = arg.generators[0]
            target = comp_gen.target
            iter_expr = self.visit(comp_gen.iter)

            if isinstance(target, ast.Name):
                # Map target name to 'it'
                self.name_remap[target.id] = "it"
                elt = self.visit(arg.elt)
                del self.name_remap[target.id]
                return f"{iter_expr}.{func_name_str}({elt})"
        else:
            # any(iterable) -> iterable.any(it)
            val = self.visit(arg)
            return f"{val}.{func_name_str}(it)"

        # Fallback
        val = self.visit(arg)
        return f"{val}.{func_name_str}(it)"

    def _handle_len_function(self, node: ast.Call, func_name_str: str, args: list) -> str | None:
        """Handle len() -> obj.len."""

        if func_name_str not in ("len", "py_len") or len(args) != 1:
            return None

        # Create a dummy Attribute parent to handle precedence
        dummy_attr = ast.Attribute(value=node.args[0], attr="len")
        obj_str = self._visit_with_parens(dummy_attr, node.args[0])
        return f"{obj_str}.len"

    def _handle_round_function(self, node: ast.Call, func_name_str: str, args: list) -> str | None:
        """Handle round()."""

        if func_name_str != "round":
            return None

        self.emitter.add_import("math")

        if len(args) == 2:
            self.used_builtins.add("round")
            return f"py_round(f64({args[0]}), {args[1]})"
        elif len(args) == 1:
            return f"math.round({args[0]})"

        return None

    def _handle_isinstance(self, node: ast.Call, args: list) -> str | None:
        """Handle isinstance()."""

        if len(args) != 2:
            return None

        obj = args[0]
        types = args[1]

        # Check if second arg was a Tuple
        if isinstance(node.args[1], ast.Tuple):
            # It's a tuple of types: (int, float)
            type_checks = []
            for elt in node.args[1].elts:
                t_name = str(self.visit(elt))
                type_checks.append(f"{obj} is {t_name}")
            return f"({' || '.join(type_checks)})"

        if types.startswith("[") and types.endswith("]"):
            return f"/* isinstance({obj}, {types}) - multi-type check not supported */ false"

        return f"{obj} is {types}"

    def _handle_assert_never(self, func_name_str: str, args: list) -> str | None:
        """Handle assert_never()."""

        if func_name_str != "assert_never":
            return None

        if len(args) == 1:
            return f"panic('assert_never reached: ${{{args[0]}}}')"
        return "panic('assert_never reached')"

    def _handle_assert_type(self, node: ast.Call, func_name_str: str, args: list) -> str | None:
        """Handle assert_type()."""
        
        if func_name_str != "assert_type":
            return None
        
        if len(args) >= 2:
            expr_node = node.args[0]
            type_node = node.args[1]
            expr_type = self._guess_type(expr_node)
            
            try:
                type_str = ast.unparse(type_node)
                expected_type = self._map_type(type_str)
            except Exception:
                type_str = str(self.visit(type_node))
                expected_type = self._map_type(type_str)
            
            if expr_type == expected_type:
                return f"// assert_type({args[0]}, {expected_type}) passed statically"
            else:
                return f"$compile_error('assert_type failed: expected {expected_type} but got {expr_type}')"
        
        return "// assert_type requires 2 arguments"
