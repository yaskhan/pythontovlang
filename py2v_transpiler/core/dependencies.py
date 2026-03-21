import ast
import os
from typing import Dict, Set, List, Optional

class DependencyAnalyzer(ast.NodeVisitor):
    def __init__(self):
        self.dependencies: Set[str] = set()
        self._file_index: Set[str] = set()
        self._dir_index: Set[str] = set()

    def _index_project(self, root_path: str, skip_dirs: Optional[List[str]] = None) -> None:
        """Pre-indexes files and directories to speed up resolution."""
        self._file_index = set()
        self._dir_index = set()
        for root, dirs, files in os.walk(root_path):
            rel_root = os.path.relpath(root, root_path)
            if rel_root == ".":
                rel_root = ""
            
            # Skip ignored directories
            if skip_dirs:
                if any(os.path.normpath(rel_root).startswith(os.path.normpath(skip)) for skip in skip_dirs):
                    continue
                # Also filter 'dirs' to prevent walking into them
                dirs[:] = [d for d in dirs if os.path.join(rel_root, d).replace('\\', '/') not in [s.replace('\\', '/') for s in skip_dirs]]

            for d in dirs:
                self._dir_index.add(os.path.join(rel_root, d).replace('\\', '/'))
            for f in files:
                self._file_index.add(os.path.join(rel_root, f).replace('\\', '/'))

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
        except Exception:
            pass
        return self.dependencies

    def _resolve_module_to_path(self, module_name: str, root_path: str, current_file_path: str) -> Optional[str]:
        """Resolves a Python module name to a relative file path within the project."""
        parts = module_name.split(".")

        # 1. Try absolute project import or stripping components from the left
        for i in range(len(parts)):
            sub_parts = parts[i:]
            potential_rel = "/".join(sub_parts)
            
            # Check for .py / .pyi
            if (potential_rel + ".py") in self._file_index:
                return (potential_rel + ".py").replace('/', os.sep)
            if (potential_rel + ".pyi") in self._file_index:
                return (potential_rel + ".pyi").replace('/', os.sep)
            
            # Check for directory/__init__.py
            if potential_rel in self._dir_index:
                init_py = potential_rel + "/__init__.py"
                if init_py in self._file_index:
                    return init_py.replace('/', os.sep)
                init_pyi = potential_rel + "/__init__.pyi"
                if init_pyi in self._file_index:
                    return init_pyi.replace('/', os.sep)

        # 2. Try relative import (relative to current_file_path)
        current_dir_rel = os.path.dirname(current_file_path).replace('\\', '/')
        if current_dir_rel == ".": current_dir_rel = ""
        
        prefix = current_dir_rel + "/" if current_dir_rel else ""
        potential_rel = prefix + "/".join(parts)
        
        if (potential_rel + ".py") in self._file_index:
            return (potential_rel + ".py").replace('/', os.sep)
        if (potential_rel + ".pyi") in self._file_index:
            return (potential_rel + ".pyi").replace('/', os.sep)
        if potential_rel in self._dir_index:
            init_py = potential_rel + "/__init__.py"
            if init_py in self._file_index:
                return init_py.replace('/', os.sep)
            init_pyi = potential_rel + "/__init__.pyi"
            if init_pyi in self._file_index:
                return init_pyi.replace('/', os.sep)

        return None

    def analyze_project(self, root_path: str, recursive: bool = True, skip_dirs: Optional[List[str]] = None) -> Dict[str, Set[str]]:
        print(f"Indexing project: {root_path}")
        self._index_project(root_path, skip_dirs=skip_dirs)
        print(f"Index complete: {len(self._file_index)} files, {len(self._dir_index)} dirs")
        raw_graph: Dict[str, Set[str]] = {}
        
        # Use indexed files for analysis
        count = 0
        for f in self._file_index:
            if f.endswith(".py") or f.endswith(".pyi"):
                count += 1
                if count % 100 == 0:
                    print(f"Analyzing dependencies: {count}/{len(self._file_index)} files...")
                full_path = os.path.join(root_path, f.replace('/', os.sep))
                rel_path = f.replace('/', os.sep)
                
                # Support dot-notation keys for SCC lookup
                dot_path = rel_path
                if dot_path.endswith('.pyi'):
                    dot_path = dot_path[:-4]
                elif dot_path.endswith('.py'):
                    dot_path = dot_path[:-3]
                dot_path = dot_path.replace(os.sep, '.')
                deps = self.analyze_file(full_path)
                raw_graph[rel_path] = deps
                raw_graph[dot_path] = deps

        # Resolve dependencies to file paths
        resolved_graph: Dict[str, Set[str]] = {}
        for file, deps in raw_graph.items():
            if not (file.endswith(".py") or file.endswith(".pyi")): continue
            resolved_deps = set()
            for dep in deps:
                resolved_path = self._resolve_module_to_path(dep, root_path, file)
                if resolved_path and resolved_path in raw_graph:
                    resolved_deps.add(resolved_path)
                elif dep in raw_graph:
                    resolved_deps.add(dep)
            resolved_graph[file] = resolved_deps

        return resolved_graph

    def find_sccs(self, root_path: str, recursive: bool = True, skip_dirs: Optional[List[str]] = None) -> List[Set[str]]:
        graph = self.analyze_project(root_path, recursive, skip_dirs=skip_dirs)
        # ... rest of find_sccs code ...
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
