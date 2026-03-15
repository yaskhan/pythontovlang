import re

with open('py2v_transpiler/core/translator/functions.py', 'r') as f:
    content = f.read()

search = """            is_mut = False
            if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                # Heuristic: check for both arg_name and func_name.arg_name
                mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")
                if not mut_info:
                    mut_info = self.type_inference.mutability_map.get(arg_name)

                if mut_info:
                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)"""

replace = """            is_mut = False
            if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                # Avoid taking global variable mutability for parameters if they are not specifically tracked.
                # Only trust the scoped mutability, OR if the function itself is mapped via func_param_mutability
                mut_info = self.type_inference.mutability_map.get(f"{node.name}.{arg_name}")
                if mut_info:
                    is_mut = mut_info.get("is_reassigned", False) or mut_info.get("is_mutated", False)
                elif hasattr(self.type_inference, 'func_param_mutability'):
                    # Fallback to function parameter mutability index tracked by analyzer
                    mut_idx = self.type_inference.func_param_mutability.get(node.name, [])
                    try:
                         # check if current arg is in mutated_indices
                         # Since args_names list is populated in order:
                         arg_index = len(args_names) - 1
                         if arg_index in mut_idx:
                              is_mut = True
                    except:
                         pass"""
content = content.replace(search, replace)
with open('py2v_transpiler/core/translator/functions.py', 'w') as f:
    f.write(content)
