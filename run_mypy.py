import subprocess
import json

with open("mypy.ini", "w") as f:
    f.write("[mypy]\nplugins = py2v_transpiler.core.mypy_plugin\n")

print(subprocess.check_output(["python3", "-m", "mypy", "--config-file", "mypy.ini", "test_mypy_plugin.py"]).decode('utf-8'))
