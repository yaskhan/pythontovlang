import subprocess
subprocess.run(["git", "checkout", "py2v_transpiler/core/analyzer.py"])
subprocess.run(["git", "checkout", "py2v_transpiler/core/translator/functions.py"])

# Interprocedural testing PASSES if I don't modify functions.py.
# WAIT. I didn't verify that! Let's check BEFORE patching anything.
