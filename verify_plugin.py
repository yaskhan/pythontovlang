import ast
import json
from py2v_transpiler.core.analyzer import TypeInference

code = """
from typing import Generic, TypeVar, List

T = TypeVar("T")

class Box(Generic[T]):
    def __init__(self, x: T):
        self.x = x

def main():
    items = [Box(10), Box(20)]
    print(items)
"""

with open("test_plugin_metadata.py", "w") as f:
    f.write(code)

ti = TypeInference()
ti.run_mypy("test_plugin_metadata.py")

print("--- Captured Call Signatures (Filtered) ---")
for k, v in ti.call_signatures.items():
    if "@" in k and "test_plugin_metadata" in k:
        print(f"{k}: {v}")
    elif ":" in k and "@" not in k:
         # Pure location keys
         print(f"{k}: {v}")

print("\n--- Captured Types (Filtered) ---")
for k, v in ti.type_map.items():
    if "test_plugin_metadata" in k and ":" in k:
        print(f"{k}: {v}")
    elif ":" in k and "@" not in k:
         # Pure location keys
         print(f"{k}: {v}")
