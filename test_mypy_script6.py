import ast

def get_mypy_types(source_code, file_path):
    import ast
    from mypy.build import build
    from mypy.main import process_options

    with open(file_path, "w") as f:
        f.write(source_code)

    # We need to run mypy programmatically and extract the AST and types
    sources, options = process_options([file_path])

    # Enable exporting types
    options.export_types = True

    res = build(sources, options)

    for module, tree in res.files.items():
        if module == "test_mypy":
            print(f"Found test_mypy: {tree}")
            for node in res.types:
                if "test_mypy" in str(node):
                    print(node, res.types[node])

source_code = """
class A:
    def draw(self): pass

def foo(obj: A):
    if hasattr(obj, "draw"):
        obj.draw()
"""
get_mypy_types(source_code, "test_mypy.py")
