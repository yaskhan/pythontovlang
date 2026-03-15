import subprocess
print("Running full tests:")
subprocess.run(["pytest", "py2v_transpiler/tests/input/transpile/test_none_type.py"])
