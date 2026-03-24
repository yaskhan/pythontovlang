import ast
import re

filepath = 'py2v_transpiler/core/translator/expressions_split/operators.py'
with open(filepath, 'r') as f:
    content = f.read()

# Restore the correct helper usage for all parts
content = content.replace('if left.endswith("}")', 'if str(left).endswith("}")')
content = content.replace('if right.endswith("}")', 'if str(right).endswith("}")')

with open(filepath, 'w') as f:
    f.write(content)
