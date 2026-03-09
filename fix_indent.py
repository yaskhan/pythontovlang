import sys

def fix_indentation(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()

    new_lines = []
    for line in lines:
        if not line.strip():
            new_lines.append('\n')
            continue

        # Check if line starts with space
        lspace = len(line) - len(line.lstrip(' '))
        # If it's not a multiple of 4, try to fix common 5/13 etc.
        if lspace % 4 != 0:
            # Simple heuristic: round to nearest multiple of 4
            new_lspace = (lspace // 4) * 4
            if lspace % 4 > 2:
                new_lspace += 4
            new_lines.append(' ' * new_lspace + line.lstrip(' '))
        else:
            new_lines.append(line)

    with open(filepath, 'w') as f:
        f.writelines(new_lines)

if __name__ == "__main__":
    fix_indentation(sys.argv[1])
