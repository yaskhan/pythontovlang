#!/usr/bin/env python3
"""
Automated V compilation checker for transpiler output.
Categorizes failures and generates summary report.
"""

import subprocess
import re
import os
import sys
from pathlib import Path
from collections import defaultdict

ERROR_CATEGORIES = {
    'mutable_args': r'mutable arguments are only allowed',
    'redefinition': r'redefinition of',
    'uppercase_name': r'function names cannot contain uppercase',
    'missing_import': r'cannot import module',
    'deprecated_sum': r'inline sum types have been deprecated',
    'unexpected_token': r'unexpected token',
    'unexpected_number': r'unexpected number',
}

def categorize_error(stderr: str) -> str:
    for category, pattern in ERROR_CATEGORIES.items():
        if re.search(pattern, stderr, re.IGNORECASE):
            return category
    return 'unknown'

def main():
    # Directories to check
    test_dirs = [
        Path('py2v_transpiler/tests/translator'),
        Path('py2v_transpiler/tests/input/transpile')
    ]

    # Find all .py files
    py_files = []
    for d in test_dirs:
        if d.exists():
            py_files.extend(list(d.glob('*.py')))

    # Exclude __init__.py and utils.py
    py_files = sorted([f for f in py_files if f.name not in ('__init__.py', 'utils.py')])

    results = defaultdict(list)
    total_files = len(py_files)
    compiled_successfully = 0
    failed_compilation = 0
    transpilation_failed = 0

    print(f"Starting compilation check for {total_files} files...")

    # Ensure V is in path or use the one we installed
    v_bin = 'v'
    try:
        subprocess.run([v_bin, 'version'], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        v_bin = '/tmp/v/v'
        if not os.path.exists(v_bin):
            print("Error: V compiler not found. Please install V.")
            sys.exit(1)

    for i, py_file in enumerate(py_files):
        print(f"[{i+1}/{total_files}] Processing {py_file}...")

        # 1. Transpile
        # Use --no-mypy to speed up and avoid mypy dependency issues in CI
        transpile_cmd = [sys.executable, '-m', 'py2v_transpiler.main', str(py_file), '--no-mypy']

        transpile_res = subprocess.run(
            transpile_cmd,
            capture_output=True,
            text=True
        )

        if transpile_res.returncode != 0:
            results['transpilation_error'].append({
                'file': str(py_file),
                'error': transpile_res.stderr.strip().split('\n')[-1] if transpile_res.stderr else "Unknown error"
            })
            transpilation_failed += 1
            continue

        v_file = py_file.with_suffix('.v')
        if not v_file.exists():
            results['missing_output'].append({
                'file': str(py_file),
                'error': 'V file was not generated'
            })
            continue

        # 2. Check compilation
        compile_res = subprocess.run(
            [v_bin, '-check', str(v_file)],
            capture_output=True,
            text=True
        )

        if compile_res.returncode == 0:
            compiled_successfully += 1
        else:
            category = categorize_error(compile_res.stderr)
            first_line = compile_res.stderr.split('\n')[0]
            if 'error:' not in first_line and len(compile_res.stderr.split('\n')) > 1:
                for line in compile_res.stderr.split('\n'):
                    if 'error:' in line:
                        first_line = line
                        break

            results[category].append({
                'file': str(py_file),
                'error': first_line.strip()
            })
            failed_compilation += 1

        # Clean up generated .v files
        if v_file.exists():
            v_file.unlink()
        helpers_file = py_file.parent / f"{py_file.stem}_helpers.v"
        if helpers_file.exists():
            helpers_file.unlink()
        # Also clean up py2v_helpers.v if it was generated (directory mode)
        dir_helpers = py_file.parent / "py2v_helpers.v"
        if dir_helpers.exists():
            dir_helpers.unlink()

    print("\nCheck complete.\n")

    # Generate report
    report = []
    report.append("# V Compilation Failure Report\n")
    report.append(f"**Total files processed:** {total_files}")
    report.append(f"**Passed (V -check):** {compiled_successfully}")
    report.append(f"**Failed (V -check):** {failed_compilation}")
    report.append(f"**Transpilation Errors:** {transpilation_failed}\n")

    # Summary Table
    report.append("| Category | Count |")
    report.append("| :--- | :--- |")
    for category in sorted(results.keys()):
        report.append(f"| {category} | {len(results[category])} |")
    report.append("")

    for category in sorted(results.keys()):
        failures = results[category]
        report.append(f"### {category}: {len(failures)} files")
        for f in failures:
            report.append(f"- `{f['file']}`: {f['error']}")
        report.append("")

    report_content = "\n".join(report)

    # Save to docs
    docs_dir = Path('docs')
    docs_dir.mkdir(exist_ok=True)
    with open(docs_dir / 'test-compilation-status.md', 'w') as f:
        f.write(report_content)

    print(f"Report generated at docs/test-compilation-status.md")

if __name__ == '__main__':
    main()
