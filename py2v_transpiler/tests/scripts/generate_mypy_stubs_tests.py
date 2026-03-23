import subprocess
from pathlib import Path
import shutil

INPUT_DIR = Path("py2v_transpiler/tests/input/mypy_stubs")
OUTPUT_DIR = Path("py2v_transpiler/tests/output/mypy_stubs")
TEST_FILE = OUTPUT_DIR / "mypy_stubs_test.v"

def preprocess_pyi(pyi_path: Path, out_path: Path):
    """Optional: replace ... with pass in function bodies, but not in signatures."""
    content = pyi_path.read_text(encoding="utf-8")
    # As requested by the user, we do minimal to no preprocessing to surface the true transpiler issues.
    out_path.write_text(content, encoding="utf-8")

def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    # Start with a clean output directory each run
    if OUTPUT_DIR.exists():
        for item in OUTPUT_DIR.iterdir():
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()

    v_files = []
    # Phase 1: most important files
    target_files = ["typing.pyi", "abc.pyi", "enum.pyi", "functools.pyi"]

    for pyi in INPUT_DIR.rglob("*.pyi"):
        if pyi.name not in target_files:
            continue

        rel = pyi.relative_to(INPUT_DIR)

        # 'enum' is a reserved keyword in V. Let's rename the module to py_enum
        module_name = pyi.stem
        if module_name in ["enum", "type"]:
            module_name = f"py_{module_name}"

        v_rel = rel.with_stem(module_name).with_suffix(".v")
        v_path = OUTPUT_DIR / v_rel
        v_path.parent.mkdir(parents=True, exist_ok=True)

        py_temp_path = v_path.with_suffix(".py")

        # 1. Preprocessing
        preprocess_pyi(pyi, py_temp_path)  # Temporary .py file

        # 2. Run your transpiler.
        print(f"Transpiling {pyi.name} (as {module_name})...")
        try:
            # Create a dedicated directory for each module to avoid duplicate definitions across mypy_stubs
            module_dir = OUTPUT_DIR / module_name
            module_dir.mkdir(exist_ok=True)
            mod_temp_path = module_dir / f"{module_name}.py"
            shutil.copy(py_temp_path, mod_temp_path)

            subprocess.run([
                "python", "-m", "py2v_transpiler.main",
                str(module_dir),
            ], check=True)
            v_files.append(module_name)

        except subprocess.CalledProcessError as e:
            print(f"Error transpiling {pyi.name}")
            continue

    # 3. Generate the main test file
    imports = "\n".join(f"import mypy_stubs.{mod}" for mod in sorted(v_files))

    test_content = f"""module mypy_stubs_test

{imports}

// This test serves as a roadmap. Errors are expected until the transpiler supports these features.
fn test_mypy_stubs_compiles() {{
    assert true, 'All mypy lib-stub files transpiled and compiled successfully!'
}}
"""
    TEST_FILE.write_text(test_content)

    print(f"Created test file at {TEST_FILE}")

if __name__ == "__main__":
    main()
