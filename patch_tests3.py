import re

with open("py2v_transpiler/tests/translator/test_classes.py", "r") as f:
    data = f.read()

data = data.replace('assert "self.x := x" in result', 'assert "self.x = x" in result')
data = data.replace('assert "self.x := self.x + dx" in result', 'assert "self.x = self.x + dx" in result')

with open("py2v_transpiler/tests/translator/test_classes.py", "w") as f:
    f.write(data)

with open("py2v_transpiler/tests/translator/test_control_flow.py", "r") as f:
    data = f.read()

data = data.replace('assert "x := x + 1" in result', 'assert "x = x + 1" in result')

with open("py2v_transpiler/tests/translator/test_control_flow.py", "w") as f:
    f.write(data)

with open("py2v_transpiler/tests/translator/test_property_setter.py", "r") as f:
    data = f.read()

data = data.replace('"self._name :="', '"self._name ="')

with open("py2v_transpiler/tests/translator/test_property_setter.py", "w") as f:
    f.write(data)
