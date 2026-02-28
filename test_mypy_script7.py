import json
from mypy import api

source = """
class A:
    def draw(self): pass

class B:
    pass

def foo(obj: A):
    if hasattr(obj, "draw"):
        pass
"""
with open("test_mypy.py", "w") as f:
    f.write(source)

# Using dump-type-data to get types? Not directly supported maybe
# Or perhaps using the JSON report
res, err, ext = api.run(["test_mypy.py", "--html-report", "report", "--show-error-context"])
print(res)
print(err)
