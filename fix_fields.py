import sys
import ast

def fix_file(path):
    with open(path, 'r') as f:
        lines = f.readlines()

    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]

        # 1. collect_init_fields arg_type_map
        if 'init_self_name = stmt.args.args[0].arg' in line:
            new_lines.append(line)
            indent = '                    '
            new_lines.append(f'{indent}# Build arg name to annotation map for __init__\n')
            new_lines.append(f'{indent}arg_type_map = {{}}\n')
            new_lines.append(f'{indent}for arg in stmt.args.args[1:]: # Skip self\n')
            new_lines.append(f'{indent}    if arg.annotation:\n')
            new_lines.append(f'{indent}        try:\n')
            new_lines.append(f'{indent}            arg_type_map[arg.arg] = ast.unparse(arg.annotation)\n')
            new_lines.append(f'{indent}        except:\n')
            new_lines.append(f'{indent}            pass\n')

        # 2. collect_init_fields f_type mapping logic
        elif 'f_type = self.translator._guess_type(sub_node.value)' in line:
            # We are inside collect_init_fields -> walk(stmt) -> Assign -> walk(target) -> Attribute
            # indent should be 40 spaces
            indent = '                                            '
            new_lines.append(f'{indent}if isinstance(sub_node.value, ast.Name) and sub_node.value.id in arg_type_map:\n')
            new_lines.append(f'{indent}    f_type = arg_type_map[sub_node.value.id]\n')
            new_lines.append(f'{indent}else:\n')
            new_lines.append(f'{indent}    f_type = self.translator._guess_type(sub_node.value)\n')
            new_lines.append(f'{indent}f_type = self.translator._map_type(f_type, struct_name)\n')

        # 3. Regular field_type guessing + mapping in process_class_attributes and collect_mixin_fields
        elif 'field_type = self.translator._guess_type(stmt.value)' in line:
            new_lines.append(line)
            # Find current indent
            indent = line[:line.find('field_type')]
            new_lines.append(f'{indent}field_type = self.translator._map_type(field_type, struct_name)\n')

        else:
            new_lines.append(line)

        i += 1

    with open(path, 'w') as f:
        f.writelines(new_lines)

if __name__ == "__main__":
    fix_file(sys.argv[1])
