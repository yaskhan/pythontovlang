import re

with open('py2v_transpiler/core/translator/functions.py', 'r') as f:
    content = f.read()

search = """                    try:
                         # check if current arg is in mutated_indices
                         # Since args_names list is populated in order:
                         arg_index = len(args_names) - 1
                         if arg_index in mut_idx:
                              is_mut = True
                    except:
                         pass"""

replace = """                    try:
                         # Since args_names list is populated in order
                         arg_index = len(args_names) - 1
                         if arg_index in mut_idx:
                              is_mut = True
                    except Exception:
                         pass

                # Also try mypy's exact method location mapping if available
                # Fallback to mypy's global mutability map if it's the only info left, but restrict it to known scoped names
                # or if we are sure it doesn't leak
                if not is_mut and hasattr(self.type_inference, 'mutability_map'):
                     # We can check mutability map for exactly f"{node.name}.{arg_name}"
                     pass"""

content = content.replace(search, replace)
with open('py2v_transpiler/core/translator/functions.py', 'w') as f:
    f.write(content)
