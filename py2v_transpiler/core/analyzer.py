import ast
from typing import Dict, Any, Tuple, Optional
from py2v_transpiler.models.v_types import map_python_type_to_v

try:
    from mypy import api as mypy_api_module
except ImportError:
    mypy_api_module = None # type: ignore

class TypeInference(ast.NodeVisitor):
    def __init__(self):
        self.type_map: Dict[str, str] = {}

    def analyze(self, tree: ast.AST) -> Dict[str, str]:
        """Analyzes the AST to infer variable types."""
        self.visit(tree)
        return self.type_map

    def visit_AnnAssign(self, node: ast.AnnAssign) -> Any:
        # Check if the target is a simple variable name (ast.Name)
        if isinstance(node.target, ast.Name):
            if node.annotation:
                try:
                    # Use ast.unparse to get the full type string (e.g. List[int])
                    # This works for Python 3.9+
                    type_str = ast.unparse(node.annotation)
                    v_type = map_python_type_to_v(type_str)
                    self.type_map[node.target.id] = v_type
                except AttributeError:
                    # Fallback for older python without ast.unparse (though we are on 3.12)
                    # or if unparse fails
                    if isinstance(node.annotation, ast.Name):
                        v_type = map_python_type_to_v(node.annotation.id)
                        self.type_map[node.target.id] = v_type
                    elif isinstance(node.annotation, ast.Constant) and isinstance(node.annotation.value, str):
                        v_type = map_python_type_to_v(node.annotation.value)
                        self.type_map[node.target.id] = v_type
                except Exception:
                    pass

        self.generic_visit(node)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> Any:
        for arg in node.args.args:
            if arg.annotation:
                try:
                    type_str = ast.unparse(arg.annotation)
                    v_type = map_python_type_to_v(type_str)
                    self.type_map[arg.arg] = v_type
                except AttributeError:
                    if isinstance(arg.annotation, ast.Name):
                        v_type = map_python_type_to_v(arg.annotation.id)
                        self.type_map[arg.arg] = v_type
                    elif isinstance(arg.annotation, ast.Constant) and isinstance(arg.annotation.value, str):
                        v_type = map_python_type_to_v(arg.annotation.value)
                        self.type_map[arg.arg] = v_type
                except Exception:
                    pass

        self.generic_visit(node)

    def run_mypy(self, path: str) -> Tuple[str, str, int]:
        """Runs mypy on the given file path and returns the output."""
        if not mypy_api_module:
            return ("Mypy not installed.", "", 1)

        result, error, exit_code = mypy_api_module.run([path])
        return result, error, exit_code

    def resolve_type(self, node: ast.AST) -> str:
        """Resolves the V type for a given AST node."""
        if isinstance(node, ast.Name):
            return self.type_map.get(node.id, "void")
        return "void"

    def get_variable_types(self) -> Dict[str, str]:
        """Returns the map of variable names to their V types."""
        return self.type_map
