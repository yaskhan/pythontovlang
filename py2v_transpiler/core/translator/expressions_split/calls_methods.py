"""Handling object methods: append, extend, sort, count, clear, read, write, etc."""

import ast
from typing import Any


class MethodCallsMixin:
    def _handle_object_method_call(self, node: ast.Call, func_node: ast.AST, func_name_str: str, args: list) -> str | None:
        """Handle object method calls."""

        if not isinstance(func_node, ast.Attribute):
            return None

        attr = func_node.attr

        # list.append() / list.extend()
        if attr == "append" and len(args) == 1:
            obj_type = self._guess_type(func_node.value)
            if obj_type.startswith("[]") or obj_type == "Any":
                obj = self.visit(func_node.value)
                return f"{obj} << {args[0]}"
        
        elif attr == "extend" and len(args) == 1:
            obj_type = self._guess_type(func_node.value)
            if obj_type.startswith("[]") or obj_type == "Any":
                obj = self.visit(func_node.value)
                return f"{obj} << {args[0]}"
        
        # list.clear() / dict.clear()
        elif attr == "clear":
            obj = self.visit(func_node.value)
            return f"/* {obj}.clear() */ {obj} = {{}}"

        # file.read() / file.write() / file.close()
        elif attr in ("read", "write", "close"):
            result = self._handle_file_methods(node, func_node, args)
            if result:
                return result

        # list.count()
        elif attr == "count" and len(args) == 1:
            obj = self.visit(func_node.value)
            # Only translate if argument is 'none' to avoid breaking string.count()
            if args[0] == "none":
                return f"{obj}.filter(it == {args[0]}).len"

        # list.sort()
        elif attr == "sort":
            return self._handle_list_sort(node, func_node, args)

        # String methods: isdigit, isalpha, isalnum, etc.
        elif attr in (
            "isdigit", "isalpha", "isalnum", "isspace", "islower", "isupper", "istitle",
            "startswith", "endswith", "splitlines", "join"
        ):
            return self._handle_string_methods(node, func_node, args)

        # dict.get()
        elif attr == "get":
            return self._handle_dict_get(node, func_node, args)

        return None

    def _handle_file_methods(self, node: ast.Call, func_node: ast.Attribute, args: list) -> str | None:
        """Handle file methods: read, write, close."""
        obj_type = self._guess_type(func_node.value)

        # Optimization: open(path).read() -> os.read_file(path)
        if isinstance(func_node.value, ast.Call):
            inner = func_node.value
            if isinstance(inner.func, ast.Name) and inner.func.id == "open" and len(inner.args) >= 1:
                path_expr = self.visit(inner.args[0])
                if func_node.attr == "read" and len(args) == 0:
                    return f"os.read_file({path_expr}) or {{ panic(err) }}"
                elif func_node.attr == "write" and len(args) == 1:
                    return f"os.write_file({path_expr}, {args[0]}) or {{ panic(err) }}"

        # Heuristic for os.File
        is_file = (obj_type == "os.File" or
                   (isinstance(func_node.value, ast.Name) and
                    func_node.value.id in ("f", "fp", "file")))

        if is_file:
            obj = self.visit(func_node.value)
            if func_node.attr == "read":
                if len(args) == 1:
                    # Python f.read(size) -> V f.read_bytes(size).bytestr()
                    return f"{obj}.read_bytes({args[0]}).bytestr()"
                else:
                    # Python f.read() -> py_file_read_all(mut f)
                    self.used_builtins.add("py_file_read_all")
                    return f"py_file_read_all(mut {obj})"
            elif func_node.attr == "write":
                if len(args) >= 1:
                    arg_type = self._guess_type(node.args[0])
                    write_arg = args[0]
                    if arg_type == "string":
                        return f"{obj}.write_string({write_arg}) or {{ panic(err) }}"
                    return f"{obj}.write({write_arg}) or {{ panic(err) }}"
                return f"0"
            else:
                # close
                return f"{obj}.close()"

        return None

    def _handle_list_sort(self, node: ast.Call, func_node: ast.Attribute, args: list) -> str:
        """Handle list.sort(reverse=True)."""
        # Check keywords for reverse=True
        reverse = False
        for keyword in node.keywords:
            if keyword.arg == "reverse":
                if isinstance(keyword.value, ast.Constant) and keyword.value.value is True:
                    reverse = True
        
        obj = self.visit(func_node.value)
        if reverse:
            return f"{obj}.sort(a > b)"
        else:
            return f"{obj}.sort()"

    def _handle_string_methods(self, node: ast.Call, func_node: ast.Attribute, args: list) -> str | None:
        """Handle string methods."""
        attr = func_node.attr
        obj = self.visit(func_node.value)

        if attr == "isdigit":
            return f"{obj}.bytes().all(it.is_digit())"
        elif attr == "isalpha":
            return f"{obj}.bytes().all(it.is_letter())"
        elif attr == "isalnum":
            return f"{obj}.bytes().all(it.is_alnum())"
        elif attr == "isspace":
            return f"{obj}.bytes().all(it.is_space())"
        elif attr == "islower":
            return f"{obj}.is_lower()"
        elif attr == "isupper":
            return f"{obj}.is_upper()"
        elif attr == "istitle":
            return f"{obj}.is_title()"
        elif attr == "splitlines":
            return f"{obj}.split_into_lines()"
        elif attr == "join":
            if len(args) == 1:
                return f"{args[0]}.join({obj})"
        elif attr in ("startswith", "endswith"):
            v_method = "starts_with" if attr == "startswith" else "ends_with"
            if len(node.args) == 1 and isinstance(node.args[0], ast.Tuple):
                checks = []
                for elt in node.args[0].elts:
                    elt_str = self.visit(elt)
                    checks.append(f"{obj}.{v_method}({elt_str})")
                return f"({' || '.join(checks)})"
            else:
                if len(node.args) == 1:
                    elt_str = self.visit(node.args[0])
                    return f"{obj}.{v_method}({elt_str})"

        return None

    def _handle_dict_get(self, node: ast.Call, func_node: ast.Attribute, args: list) -> str | None:
        """Handle dict.get(key, default)."""
        obj_type = self._guess_type(func_node.value)
        if obj_type.startswith("map[") or obj_type == "Any":
            obj = self.visit(func_node.value)
            key = args[0]
            if len(args) == 2:
                default = args[1]
            else:
                val_type = "Any"
                if obj_type.startswith("map["):
                    parts = obj_type.split("]", 1)
                    if len(parts) > 1:
                        val_type = parts[1]
                
                if val_type == "Any" or obj_type == "Any":
                    default = "Any(NoneType{})"
                elif val_type in ("int", "i64", "u32", "u64", "i8", "i16", "u8", "u16"):
                    default = "0"
                elif val_type in ("f64", "f32"):
                    default = "0.0"
                elif val_type == "bool":
                    default = "false"
                elif val_type == "string":
                    default = "''"
                elif val_type.startswith("[]"):
                    default = f"{val_type}{{}}"
                elif val_type.startswith("map["):
                    default = f"{val_type}{{}}"
                else:
                    default = "none"
            return f"{obj}[{key}] or {{ {default} }}"
        
        return None
