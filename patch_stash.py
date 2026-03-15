import subprocess
subprocess.run(["git", "checkout", "origin/main", "--", "py2v_transpiler/core/analyzer.py"])
subprocess.run(["git", "checkout", "origin/main", "--", "py2v_transpiler/core/translator/functions.py"])

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# I will NOT touch `functions.py` anymore.
