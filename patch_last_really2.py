import subprocess
subprocess.run(["git", "restore", "py2v_transpiler/core/translator/functions.py"])

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# Wait... the failures in `test_reassignment` and `test_conditional_mutation` were because I didn't restore `analyzer.py` properly after `patch_final.py`!
# Let me restore EVERYTHING.
