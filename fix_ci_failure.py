with open('py2v_transpiler/core/translator/variables_split/assignments.py', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'rhs = self.visit(node.value)' in line and 'chained assignment' in lines[lines.index(line)-1]:
        new_lines.append(line)
        new_lines.append('            rhs_type = self._guess_type(node.value)\n')
    else:
        new_lines.append(line)

with open('py2v_transpiler/core/translator/variables_split/assignments.py', 'w') as f:
    f.writelines(new_lines)
