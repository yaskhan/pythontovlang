import ast
from typing import Any, List, Optional

class CallsStringsMixin:
    def _handle_string_call(self, func_node: ast.Attribute, args: List[str], keyword_args: dict, node: ast.Call) -> Optional[str]:
        if func_node.attr in (
            "isdigit", "isalpha", "isalnum", "isspace", "islower", "isupper", "istitle", "startswith", "endswith",
            "count", "find", "rfind", "index", "rindex", "replace", "split", "rsplit", "splitlines",
            "lower", "upper", "title", "capitalize", "swapcase", "strip", "lstrip", "rstrip",
            "ljust", "rjust", "center", "zfill", "join", "encode", "format"
        ):
            receiver_type = self._guess_type(func_node.value)
            if self._is_string_type(receiver_type) or receiver_type == "Any":
                receiver = self.visit(func_node.value)

                if func_node.attr in ("isdigit", "isalpha", "isalnum", "isspace"):
                    if func_node.attr == "isdigit":
                        return f"{receiver}.bytes().all(it.is_digit())"
                    elif func_node.attr == "isalpha":
                        return f"{receiver}.bytes().all(it.is_letter())"
                    elif func_node.attr == "isalnum":
                        return f"{receiver}.bytes().all(it.is_alnum())"
                    elif func_node.attr == "isspace":
                        return f"{receiver}.bytes().all(it.is_space())"

                elif func_node.attr == "islower":
                    return f"{receiver}.is_lower()"
                elif func_node.attr == "isupper":
                    return f"{receiver}.is_upper()"
                elif func_node.attr == "istitle":
                    return f"{receiver}.is_title()"
                elif func_node.attr == "startswith":
                    if isinstance(node.args[0], ast.Tuple):
                        # Handle startswith(('a', 'b'))
                        checks = []
                        for elt in node.args[0].elts:
                            elt_val = self.visit(elt)
                            checks.append(f"{receiver}.starts_with({elt_val})")
                        return f"({' || '.join(checks)})"
                    else:
                        return f"{receiver}.starts_with({args[0]})"
                elif func_node.attr == "endswith":
                    if isinstance(node.args[0], ast.Tuple):
                        # Handle endswith(('a', 'b'))
                        checks = []
                        for elt in node.args[0].elts:
                            elt_val = self.visit(elt)
                            checks.append(f"{receiver}.ends_with({elt_val})")
                        return f"({' || '.join(checks)})"
                    else:
                        return f"{receiver}.ends_with({args[0]})"

                elif func_node.attr == "count":
                     if len(args) == 1:
                         return f"{receiver}.count({args[0]})"
                elif func_node.attr == "find":
                     if len(args) == 1:
                         return f"({receiver}.index({args[0]}) or {{ -1 }})"
                elif func_node.attr == "rfind":
                     if len(args) == 1:
                         return f"({receiver}.last_index({args[0]}) or {{ -1 }})"
                elif func_node.attr == "index":
                     if len(args) == 1:
                         return f"({receiver}.index({args[0]}) or {{ panic('ValueError: substring not found') }})"
                elif func_node.attr == "rindex":
                     if len(args) == 1:
                         return f"({receiver}.last_index({args[0]}) or {{ panic('ValueError: substring not found') }})"
                elif func_node.attr == "replace":
                     if len(args) == 2:
                         return f"{receiver}.replace({args[0]}, {args[1]})"
                     elif len(args) == 3:
                         return f"{receiver}.replace_each([{args[0]}, {args[1]}]) /* limit {args[2]} not fully supported */"
                elif func_node.attr == "split":
                     if len(args) == 1:
                         return f"{receiver}.split({args[0]})"
                     elif len(args) == 0:
                         return f"{receiver}.split(' ') /* default split */"
                elif func_node.attr == "rsplit":
                     if len(args) == 1:
                         return f"{receiver}.rsplit({args[0]})"
                     elif len(args) == 0:
                         return f"{receiver}.rsplit(' ') /* default rsplit */"
                elif func_node.attr == "splitlines":
                     return f"{receiver}.split_into_lines()"
                elif func_node.attr == "lower":
                     return f"{receiver}.to_lower()"
                elif func_node.attr == "upper":
                     return f"{receiver}.to_upper()"
                elif func_node.attr == "capitalize":
                     return f"{receiver}.capitalize()"
                elif func_node.attr == "title":
                     return f"{receiver}.title()"
                elif func_node.attr == "swapcase":
                     return f"/* swapcase not natively supported */ {receiver}"
                elif func_node.attr == "strip":
                     if len(args) == 1:
                         return f"{receiver}.trim({args[0]})"
                     return f"{receiver}.trim_space()"
                elif func_node.attr == "lstrip":
                     if len(args) == 1:
                         return f"{receiver}.trim_left({args[0]})"
                     return f"{receiver}.trim_left(' \t\n\r')"
                elif func_node.attr == "rstrip":
                     if len(args) == 1:
                         return f"{receiver}.trim_right({args[0]})"
                     return f"{receiver}.trim_right(' \t\n\r')"
                elif func_node.attr == "ljust":
                     if len(args) >= 1:
                         return f"/* ljust not natively supported */ {receiver}"
                elif func_node.attr == "rjust":
                     if len(args) >= 1:
                         return f"/* rjust not natively supported */ {receiver}"
                elif func_node.attr == "center":
                     if len(args) >= 1:
                         return f"/* center not natively supported */ {receiver}"
                elif func_node.attr == "zfill":
                     if len(args) >= 1:
                         return f"/* zfill not natively supported */ {receiver}"
                elif func_node.attr == "encode":
                     # V strings are UTF-8 by default, usually encode is just casting to bytes
                     if len(args) == 0 or (len(args) > 0 and args[0] in ("'utf-8'", '"utf-8"')):
                         return f"{receiver}.bytes()"
                     return f"/* encode({', '.join(args)}) not supported */ {receiver}.bytes()"

                elif func_node.attr == "format":
                    if isinstance(func_node.value, ast.Constant) and isinstance(func_node.value.value, str):
                        pass
                    else:
                        return f"/* {receiver}.format({', '.join(args)}) - dynamic string formatting not natively supported in V, use string interpolation '${{var}}' */ {receiver}"

        return None
