"""Special handling of calls: hasattr, getattr, setattr, open, six, threading, etc."""

import ast
from typing import Any


class SpecialCallsMixin:
    def _handle_special_builtin(self, node: ast.Call, module_name: str | None, func_name: str | None, args: list) -> str | None:
        """Handle special built-in functions."""

        if module_name != "builtins":
            return None

        # hasattr()
        if func_name == "hasattr":
            return self._handle_hasattr(node, args)

        # getattr()
        elif func_name == "getattr":
            return self._handle_getattr(node, args)

        # setattr()
        elif func_name == "setattr":
            return self._handle_setattr(node, args)

        # delattr()
        elif func_name == "delattr":
            return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n/* delattr({', '.join(args)}) - dynamic access not supported */"

        # eval(), exec(), compile()
        elif func_name in ("eval", "exec", "compile"):
            return f"//##LLM@@ Dynamic code execution via {func_name}() or exec() detected. This cannot be compiled in V. Please analyze the intended logic and replace it with explicit, statically compiled V code, or a custom parser if strictly necessary.\n/* {func_name}(...) - dynamic execution not supported */"

        # type()
        elif func_name == "type":
            if len(args) >= 1:
                return f"typeof({args[0]}).name"

        # super()
        elif func_name == "super":
            pass

        return None

    def _handle_hasattr(self, node: ast.Call, args: list) -> str:
        """Handle hasattr(obj, attr)."""
        if len(args) >= 2:
            obj_expr = args[0]
            obj_type = self._guess_type(node.args[0])
            
            if isinstance(node.args[1], ast.Constant) and isinstance(node.args[1].value, str):
                attr_name = node.args[1].value
                
                # Primitive types definitely don't have custom attributes
                if obj_type in ("int", "f64", "bool", "string", "[]u8"):
                    return "false"
                
                # If we know it's a specific struct and know its fields (dataclass)
                if obj_type != "Any" and hasattr(self, 'dataclasses') and obj_type in self.dataclasses:
                    if attr_name in self.dataclasses[obj_type]:
                        return "true"
                    else:
                        # We don't have all fields stored, so fallback to compile-time introspection
                        return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n$if {obj_expr}.has_field('{attr_name}') {{ true }} $else {{ false }}"
                
                # Unknown struct or Any/Union -> compile-time introspection fallback
                return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n$if {obj_expr}.has_field('{attr_name}') {{ true }} $else {{ false }}"
            
            return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n/* hasattr({', '.join(args)}) - reflection not fully supported */ false"
        return "false"

    def _handle_getattr(self, node: ast.Call, args: list) -> str:
        """Handle getattr(obj, attr, default)."""
        if len(args) >= 2:
            attr_name = args[1]
            if attr_name.startswith("'") and attr_name.endswith("'"):
                return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n{args[0]}.{attr_name[1:-1]}"
        return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n/* getattr({', '.join(args)}) - dynamic access not supported */"

    def _handle_setattr(self, node: ast.Call, args: list) -> str:
        """Handle setattr(obj, attr, value)."""
        if len(args) >= 3:
            attr_name = args[1]
            if attr_name.startswith("'") and attr_name.endswith("'"):
                return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n{args[0]}.{attr_name[1:-1]} = {args[2]}"
        return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n/* setattr({', '.join(args)}) - dynamic setting not supported */"

    def _handle_six_module(self, func_name: str, args: list) -> str | None:
        """Handle functions from six module."""
        if func_name == "u" and len(args) == 1:
            return args[0]
        elif func_name == "text_type" and len(args) == 1:
            return f"{args[0]}.str()"
        return None

    def _handle_os_open(self, node: ast.Call, args: list) -> str | None:
        """Handle open() -> os.open()."""
        if len(args) >= 1:
            path = args[0]
            mode = ""
            if len(node.args) > 1:
                mode_node = node.args[1]
                if isinstance(mode_node, ast.Constant) and isinstance(mode_node.value, str):
                    mode = mode_node.value
            elif len(node.keywords) > 0:
                for kw in node.keywords:
                    if kw.arg == "mode" and isinstance(kw.value, ast.Constant) and isinstance(kw.value.value, str):
                        mode = kw.value.value

            if "w" in mode:
                return f"os.create({path}) or {{ panic(err) }}"
            elif "a" in mode:
                return f"os.open_append({path}) or {{ panic(err) }}"
            else:
                return f"os.open({path}) or {{ panic(err) }}"
        return None

    def _handle_typing_cast(self, node: ast.Call, args: list) -> str | None:
        """Handle typing.cast()."""
        if len(args) == 2:
            try:
                type_str = ast.unparse(node.args[0])
                v_type = self._map_type(type_str)
            except Exception:
                v_type = str(self.visit(node.args[0]))
            val = args[1]
            return f"({val} as {v_type})"
        return f"/* typing.cast missing args */"

    def _handle_functools_partial(self, node: ast.Call, args: list) -> str | None:
        """Handle functools.partial()."""
        if len(args) >= 2:
            target_func = args[0]
            partial_args = args[1:]
            joined_partial = ", ".join(partial_args)
            return f"fn (rest ...int) int {{ return {target_func}({joined_partial}, ...rest) }}"
        return None

    def _handle_threading_lock(self, node: ast.Call, func_node: ast.AST) -> str | None:
        """Handle threading.Lock.acquire/release."""
        if "threading" not in getattr(self, 'imported_modules', {}).values():
            return None
        
        if not isinstance(func_node, ast.Attribute):
            return None
        
        if func_node.attr == "acquire":
            receiver = self.visit(func_node.value)
            return f"{receiver}.lock()"
        elif func_node.attr == "release":
            receiver = self.visit(func_node.value)
            return f"{receiver}.unlock()"
        
        return None
