import os
import ast
from typing import Dict, Any, Tuple, Optional

# Fake transpile to see if we can get mypy's info
from mypy.build import build
from mypy.main import process_options

def analyze_mypy(path: str):
    sources, options = process_options([path])
    options.export_types = True
    options.preserve_asts = True
    options.check_untyped_defs = True

    # Needs to set fine-grained incrementality to get fine-grained deps or similar? No
    res = build(sources, options)

    module_name = "test_mypy"

    if module_name not in res.files:
        module_name = list(res.files.keys())[0] # Try getting first

    tree = res.files[module_name]

    # Types dictionary maps mypy.nodes to mypy.types
    mypy_types = res.types

    # Mypy node lines and Python AST lines correspond?
    # Yes, usually.
    return tree, mypy_types

def visit_and_print_types(tree, types_map):
    for node, typ in types_map.items():
        if hasattr(node, 'line') and getattr(node, 'line') > 0 and 'hasattr' not in str(node):
            if type(node).__name__ == "CallExpr" and "hasattr" in str(node):
                print(f"CallExpr: hasattr(...) line {node.line} -> type {typ}")
            elif type(node).__name__ == "NameExpr":
                print(f"NameExpr: {node.name} line {node.line} -> type {typ}")

if __name__ == "__main__":
    t, m = analyze_mypy("test_mypy.py")
    visit_and_print_types(t, m)
