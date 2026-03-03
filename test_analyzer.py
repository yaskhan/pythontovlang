import ast
from py2v_transpiler.core.analyzer import TypeInference

code = """
import dataclasses
from typing import InitVar

@dataclasses.dataclass
class Point:
    x: int
    y: int
    z: InitVar[int] = 0

p = Point(1, 2, 3)
"""

with open("test_dc_analyzer.py", "w") as f:
    f.write(code)

tree = ast.parse(code)
inferer = TypeInference()
inferer.analyze(tree)
res, err, exit_code = inferer.run_mypy("test_dc_analyzer.py")
print("res:", res)
print("err:", err)
print("type_map keys:", list(inferer.type_map.keys()))
