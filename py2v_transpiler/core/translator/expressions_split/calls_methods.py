"""Handling object methods: append, extend, sort, count, clear, read, write, etc."""

import ast
from typing import Any, Set, TYPE_CHECKING


class MethodCallsMixin:
    """Mixin for handling method calls."""

    if TYPE_CHECKING:
        def _guess_type(self, node: ast.AST) -> str: ...
        def visit(self, node: ast.AST) -> str: ...
        used_builtins: Set[str]
        emitter: Any

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
        
        # list.clear() / dict.clear() / set.clear()
        elif attr == "clear":
            obj_type = self._guess_type(func_node.value)
            if (obj_type.startswith("map[") and obj_type.endswith("]bool")) or obj_type.startswith("datatypes.Set["):
                return self._handle_set_methods(node, func_node, args)
            obj = self.visit(func_node.value)
            empty_val = "[]" if obj_type.startswith("[]") else "{}"
            return f"/* {obj}.clear() */ {obj} = {empty_val}"

        # file.read() / file.write() / file.close()
        elif attr in ("read", "write", "close"):
            result = self._handle_file_methods(node, func_node, args)
            if result:
                return result

        # list.pop() / dict.pop()
        elif attr == "pop":
            obj_type = self._guess_type(func_node.value)
            obj = self.visit(func_node.value)
            if obj_type.startswith("[]"):
                if len(args) == 0:
                    return f"{obj}.pop()"
                elif len(args) == 1:
                    self.used_builtins.add("py_list_pop_at")
                    return f"py_list_pop_at(mut {obj}, {args[0]})"
            elif obj_type.startswith("map[") or obj_type.startswith("datatypes.Set["):
                if obj_type.endswith("]bool") or obj_type.startswith("datatypes.Set["):
                    self.used_builtins.add("py_set_pop")
                    return f"py_set_pop(mut {obj})"
                if len(args) >= 1:
                    self.used_builtins.add("py_dict_pop")
                    default = args[1] if len(args) == 2 else "none"
                    return f"py_dict_pop(mut {obj}, {args[0]}, {default})"
            elif obj_type == "Any":
                if len(args) == 0:
                    return f"{obj}.pop()"
                else:
                    self.used_builtins.add("py_dict_pop")
                    default = args[1] if len(args) == 2 else "none"
                    return f"py_dict_pop(mut {obj}, {args[0]}, {default})"

        # list.remove() / set.remove()
        elif attr == "remove" and len(args) == 1:
            obj_type = self._guess_type(func_node.value)
            if (obj_type.startswith("map[") and obj_type.endswith("]bool")) or obj_type.startswith("datatypes.Set["):
                return self._handle_set_methods(node, func_node, args)
            if obj_type.startswith("[]") or obj_type == "Any":
                obj = self.visit(func_node.value)
                self.used_builtins.add("py_list_remove")
                return f"py_list_remove(mut {obj}, {args[0]})"

        # list.count()
        elif attr == "count" and len(args) == 1:
            obj_type = self._guess_type(func_node.value)
            if obj_type.startswith("[]") or obj_type == "Any":
                obj = self.visit(func_node.value)
                return f"{obj}.filter(it == {args[0]}).len"

        # list.sort()
        elif attr == "sort":
            return self._handle_list_sort(node, func_node, args)

        # Set methods
        elif attr in ("add", "remove", "discard", "union", "intersection", "difference", "symmetric_difference", "intersection_update", "difference_update", "symmetric_difference_update", "issubset", "issuperset", "isdisjoint", "copy"):
            result = self._handle_set_methods(node, func_node, args)
            if result:
                return result

        # String methods: isdigit, isalpha, isalnum, etc.
        elif attr in (
            "isdigit", "isalpha", "isalnum", "isspace", "islower", "isupper", "istitle",
            "startswith", "endswith", "splitlines", "join", "strip", "lstrip", "rstrip",
            "lower", "upper", "capitalize", "title", "find", "index", "replace", "split", "format", "format_map"
        ):
            return self._handle_string_methods(node, func_node, args)

        # dict.get() / setdefault()
                # dict.get() / update() / setdefault()
        elif attr == "update":
            obj_type = self._guess_type(func_node.value)
            # Try set.update first if it is a set or Any
            if ((obj_type.startswith("map[") and obj_type.endswith("]bool")) or obj_type.startswith("datatypes.Set[")) or obj_type == "Any":
                res = self._handle_set_methods(node, func_node, args)
                if res: return res
            
            # Heuristic to avoid collision with hashlib
            if obj_type in ("PyHashSha256", "PyHashMd5"):
                 return None

            # Additional heuristic: hashlib objects usually start with 'h'
            if obj_type == "Any" and isinstance(func_node.value, ast.Name) and func_node.value.id.startswith("h"):
                 return None

            return self._handle_dict_update(node, func_node, args)

        elif attr == "setdefault":
            return self._handle_dict_setdefault(node, func_node, args)

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
        """Handle list.sort(key=..., reverse=True/False)."""
        _KEY_COMPARISONS = {
            "len": ("a.len", "b.len"),
            "str": ("a.str()", "b.str()"),
            "int": ("int(a)", "int(b)"),
        }

        reverse = False
        key_name = None
        for keyword in node.keywords:
            if keyword.arg == "reverse":
                if isinstance(keyword.value, ast.Constant) and keyword.value.value is True:
                    reverse = True
            elif keyword.arg == "key":
                if isinstance(keyword.value, ast.Name):
                    key_name = keyword.value.id

        obj = self.visit(func_node.value)

        if key_name is not None:
            if key_name in _KEY_COMPARISONS:
                lhs, rhs = _KEY_COMPARISONS[key_name]
                op = ">" if reverse else "<"
                return f"{obj}.sort({lhs} {op} {rhs})"
            else:
                return f"{obj}.sort()  // TODO: unsupported key={key_name}"

        if reverse:
            return f"{obj}.sort(a > b)"
        else:
            return f"{obj}.sort()"

    def _handle_string_methods(self, node: ast.Call, func_node: ast.Attribute, args: list) -> str | None:
        """Handle string methods."""
        attr = func_node.attr
        obj = self.visit(func_node.value)

        if attr == "isdigit":
            return f"{obj}.runes().all(it.is_digit())"
        elif attr == "isalpha":
            return f"{obj}.runes().all(it.is_letter())"
        elif attr == "isalnum":
            return f"{obj}.runes().all(it.is_letter() || it.is_digit())"
        elif attr == "isspace":
            return f"{obj}.runes().all(it.is_space())"
        elif attr == "islower":
            return f"{obj}.is_lower()"
        elif attr == "isupper":
            return f"{obj}.is_upper()"
        elif attr == "istitle":
            return f"{obj}.is_title()"
        elif attr == "lower":
            return f"{obj}.to_lower()"
        elif attr == "upper":
            return f"{obj}.to_upper()"
        elif attr == "capitalize":
            return f"{obj}.capitalize()"
        elif attr == "title":
            return f"{obj}.title()"
        elif attr == "strip":
            if len(args) == 0:
                return f"{obj}.trim_space()"
            return f"{obj}.trim({args[0]})"
        elif attr == "lstrip":
            if len(args) == 0:
                return f"{obj}.trim_left(' \\n\\r\\t\\v\\f')"
            return f"{obj}.trim_left({args[0]})"
        elif attr == "rstrip":
            if len(args) == 0:
                return f"{obj}.trim_right(' \\n\\r\\t\\v\\f')"
            return f"{obj}.trim_right({args[0]})"
        elif attr == "find":
            return f"{obj}.index({args[0]}) or {{ -1 }}"
        elif attr == "index":
            return f"{obj}.index({args[0]}) or {{ panic('ValueError: substring not found') }}"
        elif attr == "replace":
            if len(args) == 2:
                return f"{obj}.replace({args[0]}, {args[1]})"
            elif len(args) == 3:
                return f"{obj}.replace_n({args[0]}, {args[1]}, {args[2]})"
        elif attr == "split":
            if len(args) == 0:
                return f"{obj}.fields()"
            elif len(args) == 1:
                return f"{obj}.split({args[0]})"
            elif len(args) == 2:
                return f"{obj}.split_nth({args[0]}, {args[1]} + 1)"
        elif attr == "format":
            return f"/* {obj}.format(...) */ {obj} //##LLM@@ .format() is not supported, use interpolation"
        elif attr == "format_map" and len(args) == 1:
            self.used_builtins.add("py_string_format_map")
            self.used_builtins.add("py_format")
            return f"py_string_format_map({obj}, {args[0]})"
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
        if "map[" in obj_type or obj_type == "Any":
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

    def _handle_dict_update(self, node: ast.Call, func_node: ast.Attribute, args: list) -> str | None:
        """Handle dict.update(other, **kwargs)."""
        obj_type = self._guess_type(func_node.value)
        if "map[" in obj_type or obj_type == "Any":
            obj = self.visit(func_node.value)
            self.used_builtins.add("py_dict_update")

            other = args[0] if len(args) == 1 else "{}"

            # Handle kwargs if any
            if node.keywords:
                kw_pairs = []
                for kw in node.keywords:
                    if kw.arg:
                        val = self.visit(kw.value)
                        kw_pairs.append(f"'{kw.arg}': {val}")
                kwargs_dict = f"{{{', '.join(kw_pairs)}}}"
                if other == "{}":
                    return f"py_dict_update(mut {obj}, {kwargs_dict})"
                else:
                    return f"py_dict_update(mut {obj}, {other}, {kwargs_dict})"

            if other == "{}":
                 return None
            return f"py_dict_update(mut {obj}, {other})"
        return None

    def _handle_dict_setdefault(self, node: ast.Call, func_node: ast.Attribute, args: list) -> str | None:
        """Handle dict.setdefault(key, default)."""
        obj_type = self._guess_type(func_node.value)
        if "map[" in obj_type or obj_type == "Any":
            obj = self.visit(func_node.value)
            self.used_builtins.add("py_dict_setdefault")
            key = args[0]
            default = args[1] if len(args) == 2 else "none"
            return f"py_dict_setdefault(mut {obj}, {key}, {default})"
        return None

    def _handle_set_methods(self, node: ast.Call, func_node: ast.Attribute, args: list) -> str | None:
        """Handle set methods."""
        attr = func_node.attr
        obj = self.visit(func_node.value)
        obj_type = self._guess_type(func_node.value)
        
        # Ensure it's a set (map[K]bool)
        if not ((obj_type.startswith("map[") and obj_type.endswith("]bool")) or obj_type.startswith("datatypes.Set[")):
            if obj_type == "Any":
                if not isinstance(func_node.value, ast.Name) or not any(x in func_node.value.id.lower() for x in ("set", "s1", "s2", "s3")):
                    return None
            else:
                return None

        if attr == "add" and len(args) == 1:
            self.emitter.add_import("datatypes")
            return f"{obj}.add({args[0]})"
        elif attr == "remove" and len(args) == 1:
            obj_type = self._guess_type(func_node.value)
            self.used_builtins.add("py_set_remove")
            return f"py_set_remove(mut {obj}, {args[0]})"
        elif attr == "discard" and len(args) == 1:
            self.emitter.add_import("datatypes")
            return f"{obj}.elements.delete({args[0]})"
        elif attr == "pop" and len(args) == 0:
            self.used_builtins.add("py_set_pop")
            return f"py_set_pop(mut {obj})"
        elif attr == "clear" and len(args) == 0:
            self.emitter.add_import("datatypes")
            return f"{obj}.elements.clear()"
        elif attr == "copy" and len(args) == 0:
            return f"{obj}.clone()"
        
        # Set-theoretic operations
        elif attr in ("union", "intersection", "difference", "symmetric_difference"):
            helper_map = {
                "union": "py_set_union",
                "intersection": "py_set_intersection",
                "difference": "py_set_difference",
                "symmetric_difference": "py_set_xor"
            }
            helper = helper_map[attr]
            self.emitter.add_import("datatypes")
            self.used_builtins.add(helper)
            return f"{helper}({obj}, {args[0]})"
            
        # Update operations
        elif attr in ("update", "intersection_update", "difference_update", "symmetric_difference_update"):
            helper_map = {
                "update": "py_set_update",
                "intersection_update": "py_set_intersection_update",
                "difference_update": "py_set_difference_update",
                "symmetric_difference_update": "py_set_xor_update"
            }
            helper = helper_map[attr]
            self.emitter.add_import("datatypes")
            self.used_builtins.add(helper)
            return f"{helper}(mut {obj}, {args[0]})"
            
        # Comparisons
        elif attr in ("issubset", "issuperset", "isdisjoint"):
            helper_map = {
                "issubset": "py_set_subset",
                "issuperset": "py_set_superset",
                "isdisjoint": "py_set_isdisjoint"
            }
            helper = helper_map[attr]
            self.emitter.add_import("datatypes")
            self.used_builtins.add(helper)
            return f"{helper}({obj}, {args[0]})"
            
        return None
