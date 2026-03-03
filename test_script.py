from py2v_transpiler.tests.translator.test_array import translate

source = """
from typing import Optional

class Task:
    pass

a: list[Optional[Task]] = [None] * 5
b: list[Task] = [None] * 10
c = [None] * 15
"""

v_code = translate(source)
print(v_code)
