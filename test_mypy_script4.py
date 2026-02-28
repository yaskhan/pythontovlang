from mypy.build import build
from mypy.main import process_options

sources, options = process_options(["test_mypy.py"])
options.export_types = True
res = build(sources, options)
for file_name, file_node in res.files.items():
    if file_name.endswith("test_mypy"):
        for node, typ in res.types.items():
            if hasattr(node, "line") and node.line and getattr(node, "name", "") == "hasattr":
                print(f"hasattr: {typ}")
            elif hasattr(node, "line") and node.line and getattr(node, "name", "") == "obj":
                print(f"obj: {typ}")
            elif hasattr(node, "line") and node.line and getattr(node, "value", "") == "draw":
                print(f"draw: {typ}")
        break
print(res.types.keys())
