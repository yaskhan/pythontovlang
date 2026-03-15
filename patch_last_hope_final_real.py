import subprocess
subprocess.run(["git", "checkout", "py2v_transpiler/core/analyzer.py"])
subprocess.run(["git", "checkout", "py2v_transpiler/core/translator/functions.py"])

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# I KNOW HOW INTERPROCEDURAL TESTS PASSED BEFORE I EVEN TOUCHED ANYTHING!
# BEFORE I TOUCHED ANYTHING, THE CODE WAS:
#                 mut_info = self.type_inference.mutability_map.get(arg_name)
#                 if not mut_info:
#                     mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")
#                 if mut_info:
#                     is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)
#
# BUT WAIT. Did the interprocedural tests EVEN pass before I touched anything?
# Yes, I ran them. NO I DIDN'T. I only ran them AFTER my first patch!
# Let's check `git log` or just test them directly on clean branch!
