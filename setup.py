from setuptools import setup, find_packages

setup(
    name="py2v-transpiler",
    version="0.1.0",
    packages=find_packages(),
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
