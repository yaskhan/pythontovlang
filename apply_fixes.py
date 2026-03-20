import sys
import ast
import os

def fix_type_guessing():
    path = 'py2v_transpiler/core/translator/base_split/type_guessing.py'
    with open(path, 'r') as f:
        content = f.read()

    if 'type_vars: Set[str]' not in content:
        content = content.replace('type_inference: Any', 'type_inference: Any\n        type_vars: Set[str]')

    old_target = 'return self.type_inference.type_map[node.id]'
    new_logic = '''t = self.type_inference.type_map.get(node.id, "void")
            if t == "int" and node.id in getattr(self, "type_vars", set()):
                return node.id
            return t'''
    if old_target in content:
        content = content.replace(old_target, new_logic)

    with open(path, 'w') as f:
        f.write(content)

def fix_class_fields():
    path = 'py2v_transpiler/core/translator/classes/class_fields.py'
    with open(path, 'r') as f:
        lines = f.readlines()

    new_lines = []
    for line in lines:
        if 'init_self_name = stmt.args.args[0].arg' in line:
            new_lines.append(line)
            indent = line[:line.find('init_self_name')]
            new_lines.append(f'{indent}# Build arg name to annotation map for __init__\n')
            new_lines.append(f'{indent}arg_type_map = {{}}\n')
            new_lines.append(f'{indent}for arg in stmt.args.args[1:]: # Skip self\n')
            new_lines.append(f'{indent}    if arg.annotation:\n')
            new_lines.append(f'{indent}        try:\n')
            new_lines.append(f'{indent}            import ast as py_ast\n')
            new_lines.append(f'{indent}            arg_type_map[arg.arg] = py_ast.unparse(arg.annotation)\n')
            new_lines.append(f'{indent}        except:\n')
            new_lines.append(f'{indent}            pass\n')
        elif 'f_type = self.translator._guess_type(sub_node.value)' in line:
            indent = line[:line.find('f_type')]
            new_lines.append(f'{indent}import ast as py_ast\n')
            new_lines.append(f'{indent}if isinstance(sub_node.value, py_ast.Name) and sub_node.value.id in arg_type_map:\n')
            new_lines.append(f'{indent}    f_type = arg_type_map[sub_node.value.id]\n')
            new_lines.append(f'{indent}else:\n')
            new_lines.append(f'{indent}    f_type = self.translator._guess_type(sub_node.value)\n')
            new_lines.append(f'{indent}f_type = self.translator._map_type(f_type, struct_name)\n')
        elif 'field_type = self.translator._guess_type(stmt.value)' in line:
            new_lines.append(line)
            indent = line[:line.find('field_type')]
            new_lines.append(f'{indent}field_type = self.translator._map_type(field_type, struct_name)\n')
        else:
            new_lines.append(line)

    with open(path, 'w') as f:
        f.writelines(new_lines)

if __name__ == "__main__":
    fix_type_guessing()
    fix_class_fields()
