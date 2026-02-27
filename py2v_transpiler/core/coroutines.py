import ast
import sys
from typing import Dict, Set, Optional, Any, Union

class YieldFinder(ast.NodeVisitor):
    def __init__(self):
        self.found = False

    def visit_Yield(self, node: ast.Yield) -> None:
        self.found = True

    def visit_YieldFrom(self, node: ast.YieldFrom) -> None:
        self.found = True

    # Stop recursion at nested boundaries
    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        pass

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        pass

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        pass

class CoroutineHandler:
    def __init__(self):
        self.generators: Dict[str, str] = {} # name -> yield_type
        self.active_channel: Optional[str] = None
        self._temp_var_counter = 0

    def scan_module(self, node: ast.Module) -> None:
        """Scan the module to identify generator functions."""
        for n in ast.walk(node):
            if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if self._has_yield(n):
                    y_type = self.get_yield_type(n)
                    self.generators[n.name] = y_type

    def _has_yield(self, node: Union[ast.FunctionDef, ast.AsyncFunctionDef]) -> bool:
        finder = YieldFinder()
        for stmt in node.body:
            finder.visit(stmt)
            if finder.found:
                return True
        return False

    def is_generator(self, name: str) -> bool:
        return name in self.generators

    def enter_generator(self, channel_name: str = "ch", in_channel_name: str = "ch_in") -> None:
        self.active_channel = channel_name
        self.active_in_channel = in_channel_name

    def exit_generator(self) -> None:
        self.active_channel = None
        self.active_in_channel = None

    def get_temp_channel_name(self) -> str:
        self._temp_var_counter += 1
        return f"ch_{self._temp_var_counter}"

    def get_yield_type(self, node: Union[ast.FunctionDef, ast.AsyncFunctionDef]) -> str:
        """Attempt to infer yield type from return annotation."""
        if not node.returns:
             return "int" # Default

        # Check for Iterator[T] or Generator[T, ...]
        if isinstance(node.returns, ast.Subscript):
             base = node.returns.value
             if isinstance(base, ast.Name) and base.id in ("Iterator", "Generator", "Iterable"):
                 slice_node = node.returns.slice

                 # Handle python < 3.9 Index wrapper
                 if sys.version_info < (3, 9) and hasattr(ast, 'Index') and isinstance(slice_node, ast.Index):
                      slice_node = slice_node.value

                 # Generator[YieldType, SendType, ReturnType] -> Tuple
                 # Iterator[YieldType] -> Type

                 if isinstance(slice_node, ast.Tuple):
                     if slice_node.elts:
                         return self._map_type(slice_node.elts[0])
                 else:
                     return self._map_type(slice_node)

        return "int" # Default

    def get_generator_type(self, name: str) -> str:
        return self.generators.get(name, "int")

    def _map_type(self, node: ast.AST) -> str:
        if isinstance(node, ast.Name):
            if node.id == "str": return "string"
            if node.id == "int": return "int"
            if node.id == "bool": return "bool"
            if node.id == "float": return "f64"
            return node.id
        elif isinstance(node, ast.Constant) and isinstance(node.value, str):
            if node.value == "str": return "string"
            if node.value == "int": return "int"
            if node.value == "bool": return "bool"
            if node.value == "float": return "f64"
            return node.value
        return "int"
