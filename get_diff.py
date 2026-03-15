import subprocess
print(subprocess.run(["git", "diff"], capture_output=True, text=True).stdout)
