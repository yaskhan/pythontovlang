import os

def replace_in_file(filepath, search, replace):
    with open(filepath, 'r') as f:
        content = f.read()
    new_content = content.replace(search, replace)
    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")
    else:
        print(f"No changes for {filepath}")

# 1. Modify analyzer_split/utils.py
replace_in_file('py2v_transpiler/core/analyzer_split/utils.py',
                'return "unknown"',
                'return "Any"')
replace_in_file('py2v_transpiler/core/analyzer_split/utils.py',
                'return "[]unknown"',
                'return "[]Any"')
replace_in_file('py2v_transpiler/core/analyzer_split/utils.py',
                'map[string]unknown',
                'map[string]Any')

# 2. Modify translator/base_split/type_guessing.py
replace_in_file('py2v_transpiler/core/translator/base_split/type_guessing.py',
                'return "unknown"',
                'return "Any"')
replace_in_file('py2v_transpiler/core/translator/base_split/type_guessing.py',
                '"[]unknown"',
                '"[]Any"')
replace_in_file('py2v_transpiler/core/translator/base_split/type_guessing.py',
                'map[string]unknown',
                'map[string]Any')
