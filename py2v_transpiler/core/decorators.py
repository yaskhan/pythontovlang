import ast
from dataclasses import dataclass, field
from typing import List, Optional, Any

@dataclass
class DecoratorInfo:
    is_static: bool = False
    is_property: bool = False
    is_setter: bool = False
    is_classmethod: bool = False
    decorators_to_handle: List[str] = field(default_factory=list)
    cache_wrapper_needed: bool = False
    cache_map_name: Optional[str] = None
    cache_key_type: str = "string" # Default key type for cache
    wrapper_code: List[str] = field(default_factory=list)
    injected_start: List[str] = field(default_factory=list)
    injected_end: List[str] = field(default_factory=list)
    implementation_name: Optional[str] = None
    # PEP 702: @deprecated decorator support
    deprecated: bool = False
    deprecated_message: Optional[str] = None

class DecoratorProcessor:
    def __init__(self, visitor: Any):
        # Visitor is passed to access helper methods if needed, but we try to be independent
        self.visitor = visitor

    def analyze(self, node: ast.FunctionDef, current_class: Optional[str]) -> DecoratorInfo:
        from py2v_transpiler.pydantic_support.detector import PydanticDetector

        info = DecoratorInfo()

        for decorator in node.decorator_list:
            if PydanticDetector.is_validator_decorator(decorator):
                # We can handle or flag validator decorators here
                # For now, just mark it so it doesn't get ignored
                info.decorators_to_handle.append(self._get_decorator_name(decorator))
                continue

            dec_name = self._get_decorator_name(decorator)

            if dec_name == "staticmethod":
                info.is_static = True
                info.decorators_to_handle.append(dec_name)
            elif dec_name == "classmethod":
                info.is_classmethod = True
                info.is_static = True # Treat as static method in V (no receiver)
                info.decorators_to_handle.append(dec_name)
            elif dec_name == "property":
                info.is_property = True
                # Properties are methods in V
                info.decorators_to_handle.append(dec_name)
            elif dec_name == "setter":
                # Check if it's an attribute access like @name.setter
                # _get_decorator_name returns 'setter' for 'name.setter' because it recurses on Attribute.attr
                # We assume any decorator ending in .setter is a property setter
                info.is_setter = True
                info.decorators_to_handle.append(dec_name)
            elif dec_name == "lru_cache":
                info.cache_wrapper_needed = True
                info.decorators_to_handle.append(dec_name)
            elif dec_name in ("timer", "log"):
                # Inject logging
                info.injected_start.append(f"println('Start {node.name}...')")
                # Using defer for end logging is idiomatic in V
                info.injected_end.append(f"defer {{ println('End {node.name}...') }}")
                info.decorators_to_handle.append(dec_name)
            elif dec_name == "deprecated":
                # PEP 702: @warnings.deprecated decorator
                info.deprecated = True
                # Extract the message from the decorator call
                if isinstance(decorator, ast.Call) and decorator.args:
                    msg_arg = decorator.args[0]
                    if isinstance(msg_arg, ast.Constant) and isinstance(msg_arg.value, str):
                        info.deprecated_message = msg_arg.value
                info.decorators_to_handle.append(dec_name)
            else:
                # Custom or unknown -> emit as comment in visitor
                if self.visitor and hasattr(self.visitor, "warnings"):
                    self.visitor.warnings.append(f"Custom decorator '{dec_name}' at line {getattr(node, 'lineno', '?')} is not fully supported and might generate invalid code.")

        if info.cache_wrapper_needed:
            func_name = node.name
            if self.visitor.renamed_functions and func_name in self.visitor.renamed_functions:
                 func_name = self.visitor.renamed_functions[func_name]

            info.implementation_name = f"{func_name}__impl"
            # Cache map name should be unique enough
            if current_class:
                info.cache_map_name = f"{current_class.lower()}_{func_name}_cache"
            else:
                info.cache_map_name = f"{func_name}_cache"

        return info

    def _get_decorator_name(self, node: ast.AST) -> str:
        if isinstance(node, ast.Name):
            return node.id
        elif isinstance(node, ast.Call):
            return self._get_decorator_name(node.func)
        elif isinstance(node, ast.Attribute):
            return node.attr
        return ""

    def generate_cache_wrapper(self, info: DecoratorInfo, func_name: str, args_str: str, ret_type: str, args_names: List[str], receiver_str: str = "") -> str:
        """
        Generates the wrapper function and cache map declaration for lru_cache.
        """
        if not info.cache_map_name:
            return ""

        # Parse receiver to find variable name (e.g. "s" from "(s Struct) ")
        receiver_name = ""
        if receiver_str:
            parts = receiver_str.strip().split()
            # Expecting "(name Type)"
            if len(parts) >= 1 and parts[0].startswith("("):
                receiver_name = parts[0][1:] # Remove '('

        # Determine Key Type
        # Using string key for everything is safest: key = "${receiver}_${arg1}_${arg2}"

        key_parts = []
        if receiver_name:
            key_parts.append(f"${{{receiver_name}}}")

        for arg in args_names:
            key_parts.append(f"${{{arg}}}")

        key_gen = ""
        if not key_parts:
            key_gen = "'__no_args__'"
        elif len(key_parts) == 1:
            key_gen = f"'{key_parts[0]}'"
        else:
            key_gen = f"'{'_'.join(key_parts)}'"

        map_decl = f"mut {info.cache_map_name} := map[string]{ret_type}{{}}"

        call_prefix = ""
        if receiver_name:
            call_prefix = f"{receiver_name}."

        call_args = ", ".join(args_names)

        wrapper = f"""
{map_decl}

fn {receiver_str}{func_name}({args_str}) {ret_type} {{
    key := {key_gen}
    if key in {info.cache_map_name} {{
        return {info.cache_map_name}[key]
    }}
    res := {call_prefix}{info.implementation_name}({call_args})
    {info.cache_map_name}[key] = res
    return res
}}
"""
        return wrapper
