with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()
import re
# We need to ensure that the mutability heuristic isn't skipping mypy's exact mappings when the simple AST scanner misses things.
# The previous fix broke the interprocedural mutation tests where mypy correctly inferred mutability but `mut_idx` was empty!

search = """                # Also try mypy's exact method location mapping if available
                # Fallback to mypy's global mutability map if it's the only info left, but restrict it to known scoped names
                # or if we are sure it doesn't leak
                if not is_mut and hasattr(self.type_inference, 'mutability_map'):
                     # We can check mutability map for exactly f"{node.name}.{arg_name}"
                     pass"""

replace = """                if not is_mut and hasattr(self.type_inference, 'mutability_map'):
                    # Fallback to pure arg_name ONLY if it's explicitly tracked as mutated in mypy plugin
                    # Note: We must be careful not to pick up reassignments from other functions.
                    mut_info_global = self.type_inference.mutability_map.get(arg_name)
                    if mut_info_global and mut_info_global.get("is_mutated"):
                        is_mut = True"""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
