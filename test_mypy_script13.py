import json
import subprocess

source = """
from typing import Union

class A:
    def draw(self): pass

class B:
    pass

def foo(obj: Union[A, B], obj2: A):
    if hasattr(obj, "draw"):
        pass
    if hasattr(obj2, "draw"):
        pass
    if hasattr(obj, "other"):
        pass
"""

with open("test_mypy.py", "w") as f:
    f.write(source)

# Using dump-type-data to get types? Not directly supported maybe
# Let's run python -m mypy test_mypy.py --html-report
try:
    subprocess.run(["python", "-m", "pip", "install", "lxml"])
    subprocess.run(["python", "-m", "mypy", "test_mypy.py", "--html-report", "html_out"])

    with open("html_out/index.html", "r") as f:
        print("HTML report generated")
except Exception as e:
    print(e)
