import os
import ast
from typing import Dict, Any, Tuple, Optional

# Fake transpile to see if we can get mypy's info
from mypy.build import build
from mypy.main import process_options
from mypy.types import Instance, UnionType, AnyType
from mypy.nodes import TypeInfo

def analyze_mypy(path: str):
    sources, options = process_options([path])
    options.export_types = True
    options.preserve_asts = True
    options.check_untyped_defs = True

    res = build(sources, options)

    module_name = "test_mypy"

    if module_name not in res.files:
        module_name = list(res.files.keys())[0] # Try getting first

    tree = res.files[module_name]
    mypy_types = res.types

    return tree, mypy_types

def check_hasattr(typ, attr_name):
    # Determine if typ has attribute attr_name
    if isinstance(typ, Instance):
        if attr_name in typ.type.names:
            return True
        for base in typ.type.mro:
            if attr_name in base.names:
                return True
        return False
    elif isinstance(typ, UnionType):
        # Could be true for some, false for others
        results = [check_hasattr(item, attr_name) for item in typ.items]
        if all(results):
            return True
        if not any(results):
            return False
        return "mixed"
    return "unknown"

def visit_and_check(tree, types_map):
    for node, typ in types_map.items():
        if getattr(node, 'line', -1) > 0 and 'hasattr' not in str(node):
             if type(node).__name__ == "CallExpr" and "hasattr" in str(node):
                  # Find the argument and string literal?
                  # Mypy node structure
                  pass
             elif type(node).__name__ == "NameExpr":
                  if "obj" in node.name:
                       print(f"NameExpr: {node.name} line {node.line} -> type {typ}")
                       print(f"  hasattr 'draw': {check_hasattr(typ, 'draw')}")
                       print(f"  hasattr 'other': {check_hasattr(typ, 'other')}")

if __name__ == "__main__":
    t, m = analyze_mypy("test_mypy.py")
    visit_and_check(t, m)
