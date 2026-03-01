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
        self.location_map: Dict[str, str] = {}

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

        import tempfile
        import os
        import json

        # Create a temporary config file to load the plugin
        with tempfile.NamedTemporaryFile(mode='w', suffix='.ini', delete=False) as f:
            f.write("[mypy]\nplugins = py2v_transpiler.core.mypy_plugin\n")
            config_path = f.name

        # Store original PYTHONPATH to restore it later
        original_pythonpath = os.environ.get("PYTHONPATH")

        try:
            # Set PYTHONPATH so mypy can find the plugin
            if original_pythonpath is not None:
                os.environ["PYTHONPATH"] = f".:{original_pythonpath}"
            else:
                os.environ["PYTHONPATH"] = "."

            # Ensure the global dict is clean before running mypy
            try:
                import py2v_transpiler.core.mypy_plugin as m_p
                m_p._global_collected_types.clear()
            except ImportError:
                pass

            result, error, exit_code = mypy_api_module.run([path, '--config-file', config_path])

            collected_types = None
            # First try to read from the memory (global state injected by the plugin)
            try:
                import py2v_transpiler.core.mypy_plugin as m_p
                if m_p._global_collected_types:
                    collected_types = dict(m_p._global_collected_types)
            except ImportError:
                pass

            # Fallback to reading the generated types mapping from JSON
            if not collected_types and os.path.exists("types_for_vlang.json"):
                try:
                    with open("types_for_vlang.json", "r") as json_file:
                        collected_types = json.load(json_file)
                except Exception:
                    pass

            if collected_types:
                for fullname, types in collected_types.items():
                    for location, typ in types.items():
                        if location.endswith("_proto_args"):
                            self.type_map[location] = typ
                        else:
                            v_type = map_python_type_to_v(typ)
                            # Extract the variable or function name from fullname if possible
                            # For now, we will just store it by location as well, or we can use it during transpilation
                            # but keeping it in self.type_map via a generic key might be tricky.
                            # We map it by line:column string for potential later use.
                            self.type_map[f"{fullname}@{location}"] = v_type

                        # Populate location_map for O(1) lookups by location (handling potential float vs int overloads)
                        if 'builtins.float' in fullname or location not in self.location_map:
                             self.location_map[location] = v_type

            if os.path.exists("types_for_vlang.json"):
                try:
                    os.remove("types_for_vlang.json")
                except Exception:
                    pass
        finally:
            if original_pythonpath is not None:
                os.environ["PYTHONPATH"] = original_pythonpath
            elif "PYTHONPATH" in os.environ:
                del os.environ["PYTHONPATH"]

            os.remove(config_path)

        return result, error, exit_code

    def resolve_type(self, node: ast.AST) -> str:
        """Resolves the V type for a given AST node."""
        if isinstance(node, ast.Name):
            return self.type_map.get(node.id, "void")
        return "void"

    def get_variable_types(self) -> Dict[str, str]:
        """Returns the map of variable names to their V types."""
        return self.type_map
