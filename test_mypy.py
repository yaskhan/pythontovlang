import subprocess
import sys
import os

code = "print(1)"
with open("tmp.py", "w") as f:
    f.write(code)

try:
    res = subprocess.run(["mypy", "tmp.py"], capture_output=True, text=True)
    print(f"Mypy return code: {res.returncode}")
    print(f"Mypy stdout: {res.stdout}")
    print(f"Mypy stderr: {res.stderr}")
finally:
    if os.path.exists("tmp.py"):
        os.remove("tmp.py")
