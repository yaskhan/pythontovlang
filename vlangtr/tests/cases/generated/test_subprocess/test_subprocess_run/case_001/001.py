import subprocess
res = subprocess.run(["ls", "-l"])
print(res.returncode)
