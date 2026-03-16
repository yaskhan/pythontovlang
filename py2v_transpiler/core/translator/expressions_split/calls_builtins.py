import ast
from typing import Any, List, Optional

class CallsBuiltinsMixin:
    def _handle_builtin_call(self, node: ast.Call, module_name: str, func_name: str, args: List[str]) -> Optional[str]:
        if module_name == "six":
            if func_name == "u" and len(args) == 1:
                return args[0]
            elif func_name == "text_type" and len(args) == 1:
                return f"{args[0]}.str()"

        if module_name == "os" and func_name == "open":
             self.emitter.add_import("os")
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

        if module_name == "builtins":
            if func_name == "hasattr":
                 if len(args) >= 2:
                     obj_expr = args[0]
                     obj_type = self._guess_type(node.args[0])

                     if isinstance(node.args[1], ast.Constant) and isinstance(node.args[1].value, str):
                         attr_name = node.args[1].value
                         if obj_type in ("int", "f64", "bool", "string", "[]u8"):
                             return "false"

                         if obj_type != "Any" and hasattr(self, 'dataclasses') and obj_type in self.dataclasses:
                             if attr_name in self.dataclasses[obj_type]:
                                 return "true"
                             else:
                                 return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n$if {obj_expr}.has_field('{attr_name}') {{ true }} $else {{ false }}"

                         return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n$if {obj_expr}.has_field('{attr_name}') {{ true }} $else {{ false }}"

                     return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n/* hasattr({', '.join(args)}) - reflection not fully supported */ false"
                 return "false"
            elif func_name == "getattr":
                if len(args) >= 2:
                    return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n/* getattr({', '.join(args)}) - reflection not fully supported */"
            elif func_name == "setattr":
                if len(args) >= 3:
                    return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n/* setattr({', '.join(args)}) - reflection not fully supported */"
            elif func_name == "delattr":
                if len(args) >= 2:
                    return f"//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n/* delattr({', '.join(args)}) - reflection not fully supported */"
            elif func_name in ("eval", "exec", "compile"):
                return f"/* {func_name}({', '.join(args)}) - dynamic execution not supported in V */"
            elif func_name == "type":
                if len(args) == 1:
                     return f"typeof({args[0]}).name"
                elif len(args) == 3:
                     return f"/* type({', '.join(args)}) - dynamic class creation not supported */"
            elif func_name == "super":
                return "self"
            elif func_name == "Exception":
                return "vexc.Exception{}"

            if module_name == "typing":
                if func_name == "cast":
                    if len(args) == 2:
                        return f"Any({args[1]})"

        if module_name == "functools" and func_name == "partial":
             if len(args) >= 2:
                 func_expr = args[0]
                 partial_args = args[1:]
                 return f"/* functools.partial({func_expr}, {', '.join(partial_args)}) - implement closure manually */"

        if module_name == "unittest" and func_name == "main":
             return "// unittest.main() ignored"

        return None
