with open("py2v_transpiler/core/translator/expressions_split/operators.py", "r") as f:
    content = f.read()

old_code_1 = """            elif isinstance(op, ast.In) and str(left) == "none":
                 right_type = self._guess_type(node.comparators[0] if len(node.ops) == 1 else node.comparators[i])
                 if right_type.startswith("map["):
                      return f"none in {right}"
                 return f"{right}.any(it == none)"
            elif isinstance(op, ast.NotIn) and str(left) == "none":
                 right_type = self._guess_type(node.comparators[0] if len(node.ops) == 1 else node.comparators[i])
                 if right_type.startswith("map["):
                      return f"none !in {right}"
                 return f"!{right}.any(it == none)\""""

new_code_1 = """            elif isinstance(op, ast.In) and str(left) == "none":
                 right_type = self._guess_type(node.comparators[0])
                 if right_type.startswith("map["):
                      return f"none in {right}"
                 return f"{right}.any(it == none)"
            elif isinstance(op, ast.NotIn) and str(left) == "none":
                 right_type = self._guess_type(node.comparators[0])
                 if right_type.startswith("map["):
                      return f"none !in {right}"
                 return f"!{right}.any(it == none)\""""

content = content.replace(old_code_1, new_code_1, 1)


old_code_2 = """            elif isinstance(op, ast.In) and str(left) == "none":
                 right_type = self._guess_type(node.comparators[0] if len(node.ops) == 1 else node.comparators[i])
                 if right_type.startswith("map["):
                      return f"none in {right}"
                 return f"{right}.any(it == none)"
            elif isinstance(op, ast.NotIn) and str(left) == "none":
                 right_type = self._guess_type(node.comparators[0] if len(node.ops) == 1 else node.comparators[i])
                 if right_type.startswith("map["):
                      return f"none !in {right}"
                 return f"!{right}.any(it == none)\""""

new_code_2 = """            elif isinstance(op, ast.In) and str(left) == "none":
                 right_type = self._guess_type(node.comparators[i])
                 if right_type.startswith("map["):
                      return f"none in {right}"
                 return f"{right}.any(it == none)"
            elif isinstance(op, ast.NotIn) and str(left) == "none":
                 right_type = self._guess_type(node.comparators[i])
                 if right_type.startswith("map["):
                      return f"none !in {right}"
                 return f"!{right}.any(it == none)\""""

content = content.replace(old_code_2, new_code_2)

with open("py2v_transpiler/core/translator/expressions_split/operators.py", "w") as f:
    f.write(content)
