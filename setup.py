import os
from setuptools import setup, find_packages

USE_MYPYC = os.environ.get("USE_MYPYC", "0") == "1"
ext_modules = []

if USE_MYPYC:
    from mypyc.build import mypycify

    files_to_compile = []
    for root, _, files in os.walk("py2v_transpiler"):
        if "tests" in root.split(os.sep):
            continue
        for file in files:
            if file.endswith(".py"):
                if root == "py2v_transpiler" and file == "main.py":
                    continue
                if not file.startswith("__"):
                    files_to_compile.append(os.path.join(root, file))

    ext_modules = mypycify(files_to_compile, opt_level="3")

setup(
    name="py2v-transpiler",
    version="0.1.0",
    packages=find_packages(),
    ext_modules=ext_modules,
    entry_points={
        "console_scripts": [
            "py2v=py2v_transpiler.main:main",
        ],
    },
    install_requires=[
        "mypy",
    ],
    extras_require={
        "dev": [
            "pytest",
        ],
    },
    python_requires=">=3.8",
)
