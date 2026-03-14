with open("py2v_transpiler/core/translator/variables_split/assignments.py", "r") as f:
    code = f.read()

import re
code = code.replace(
    '''                if hasattr(self, 'known_v_types') and assigned_type != "unknown" and "Any" in assigned_type:
                    # If we assigned a literal list that we emit as `[]?Any`, register it!
                    if isinstance(node.value, (ast.List, ast.Tuple)) and assigned_type.startswith("[]?"):
                        self.known_v_types[target.id] = assigned_type''',
    '''                if hasattr(self, 'known_v_types') and assigned_type != "unknown":
                    # If we assigned a literal list that we emit as `[]?`, register it!
                    if isinstance(node.value, (ast.List, ast.Tuple)) and assigned_type.startswith("[]?"):
                        self.known_v_types[target.id] = assigned_type'''
)

with open("py2v_transpiler/core/translator/variables_split/assignments.py", "w") as f:
    f.write(code)
