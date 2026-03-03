import ast
import os
from typing import Dict, Set, List, Optional

class DependencyAnalyzer(ast.NodeVisitor):
    def __init__(self):
        self.dependencies: Set[str] = set()

    def visit_Import(self, node: ast.Import) -> None:
        for alias in node.names:
            self.dependencies.add(alias.name)

    def visit_ImportFrom(self, node: ast.ImportFrom) -> None:
        if node.module:
            self.dependencies.add(node.module)

    def analyze_file(self, file_path: str) -> Set[str]:
        self.dependencies = set()
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                source = f.read()
            tree = ast.parse(source)
            self.visit(tree)
        except Exception as e:
            # print(f"Error parsing {file_path}: {e}")
            pass
        return self.dependencies

    def _resolve_module_to_path(self, module_name: str, root_path: str, current_file_path: str) -> Optional[str]:
        """Resolves a Python module name to a relative file path within the project."""
        parts = module_name.split(".")

        # 1. Try absolute project import or stripping components from the left
        for i in range(len(parts)):
            sub_parts = parts[i:]
            potential_path = os.path.join(root_path, *sub_parts)
            if os.path.exists(potential_path + ".py"):
                return os.path.relpath(potential_path + ".py", root_path)
            if os.path.isdir(potential_path) and os.path.exists(os.path.join(potential_path, "__init__.py")):
                return os.path.relpath(os.path.join(potential_path, "__init__.py"), root_path)

        # 2. Try relative import (relative to current_file_path)
        current_dir = os.path.dirname(os.path.join(root_path, current_file_path))
        potential_path = os.path.join(current_dir, *parts)
        if os.path.exists(potential_path + ".py"):
            return os.path.relpath(potential_path + ".py", root_path)
        if os.path.isdir(potential_path) and os.path.exists(os.path.join(potential_path, "__init__.py")):
            return os.path.relpath(os.path.join(potential_path, "__init__.py"), root_path)

        return None

    def analyze_project(self, root_path: str, recursive: bool = True) -> Dict[str, Set[str]]:
        raw_graph: Dict[str, Set[str]] = {}
        file_list: List[str] = []
        for root, dirs, files in os.walk(root_path):
            for file in files:
                if file.endswith(".py"):
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, root_path)
                    # Support dot-notation keys for SCC lookup
                    dot_path = rel_path.replace('.py', '').replace('/', '.').replace('\\', '.')
                    file_list.append(rel_path)
                    deps = self.analyze_file(full_path)
                    raw_graph[rel_path] = deps
                    raw_graph[dot_path] = deps
            if not recursive:
                break

        # Resolve dependencies to file paths
        resolved_graph: Dict[str, Set[str]] = {}
        for file, deps in raw_graph.items():
            if not file.endswith(".py"): continue
            resolved_deps = set()
            for dep in deps:
                resolved_path = self._resolve_module_to_path(dep, root_path, file)
                # print(f"Resolving {dep} from {file} -> {resolved_path}")
                if resolved_path and resolved_path in raw_graph:
                    resolved_deps.add(resolved_path)
                elif dep in raw_graph:
                    # Also check if the raw name is already a valid file key
                    resolved_deps.add(dep)
            resolved_graph[file] = resolved_deps

        return resolved_graph

    def find_sccs(self, root_path: str, recursive: bool = True) -> List[Set[str]]:
        graph = self.analyze_project(root_path, recursive)
        # print(f"Graph for SCC: {graph}")

        index = 0
        stack = []
        indices = {}
        lowlink = {}
        on_stack = {}
        sccs = []

        def strongconnect(v):
            nonlocal index
            indices[v] = index
            lowlink[v] = index
            index += 1
            stack.append(v)
            on_stack[v] = True

            for w in graph.get(v, []):
                if w not in indices:
                    strongconnect(w)
                    lowlink[v] = min(lowlink[v], lowlink[w])
                elif on_stack.get(w, False):
                    lowlink[v] = min(lowlink[v], indices[w])

            if lowlink[v] == indices[v]:
                scc = set()
                while True:
                    w = stack.pop()
                    on_stack[w] = False
                    scc.add(w)
                    if w == v:
                        break
                sccs.append(scc)

        for v in graph:
            if v not in indices:
                strongconnect(v)

        return sccs
