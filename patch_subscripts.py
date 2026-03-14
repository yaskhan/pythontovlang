with open("py2v_transpiler/core/translator/expressions_split/subscripts.py", "r") as f:
    code = f.read()

import re
code = code.replace(
    '''             if getattr(self, "type_inference", None) and hasattr(self.type_inference, "resolve_type") and self.type_inference.resolve_type(node.slice) != "Any": idx_type = self.type_inference.resolve_type(node.slice)
             if hasattr(node.slice, "id") and getattr(self, "type_inference", None) and getattr(self.type_inference, "type_map", None) and node.slice.id in self.type_inference.type_map: idx_type = self.type_inference.type_map[node.slice.id]''',
    '''             if getattr(self, "type_inference", None):
                  res = getattr(self.type_inference, "resolve_type", lambda x: "Any")(node.slice)
                  if res != "Any":
                       idx_type = res
                  elif hasattr(node.slice, "id") and getattr(self.type_inference, "type_map", None) and node.slice.id in self.type_inference.type_map:
                       idx_type = self.type_inference.type_map[node.slice.id]
                  elif hasattr(node.slice, "id") and getattr(self, "name_remap", None) and node.slice.id in self.name_remap:
                       remapped = self.name_remap[node.slice.id]
                       if getattr(self.type_inference, "type_map", None) and remapped in self.type_inference.type_map:
                            idx_type = self.type_inference.type_map[remapped]'''
)

with open("py2v_transpiler/core/translator/expressions_split/subscripts.py", "w") as f:
    f.write(code)
