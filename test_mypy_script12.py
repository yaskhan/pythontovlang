from mypy.build import build
from mypy.main import process_options

sources, options = process_options(["test_mypy.py"])
options.export_types = True
options.check_untyped_defs = True
options.preserve_asts = True
res = build(sources, options)
print(res.files.keys())
for name in res.files:
    if "test_mypy" in name:
        tree = res.files[name]
        for node, typ in res.types.items():
            if getattr(node, 'line', -1) > 0:
                print(f"Line {node.line}: {type(node)} -> {typ} | code: {node}")
        break
