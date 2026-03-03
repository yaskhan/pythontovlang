import ast
import os
from typing import Dict, Set

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
            print(f"Error parsing {file_path}: {e}")
        return self.dependencies

    def analyze_project(self, root_path: str) -> Dict[str, Set[str]]:
        graph: Dict[str, Set[str]] = {}
        for root, _, files in os.walk(root_path):
            for file in files:
                if file.endswith(".py"):
                    full_path = os.path.join(root, file)
                    # Use relative path as key
                    rel_path = os.path.relpath(full_path, root_path)
                    deps = self.analyze_file(full_path)
                    graph[rel_path] = deps
        return graph
