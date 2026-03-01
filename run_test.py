import subprocess
print(subprocess.run(["python", "-m", "pytest", "py2v_transpiler/tests/translator/test_typed_dict.py"], capture_output=True).stdout.decode('utf-8'))
