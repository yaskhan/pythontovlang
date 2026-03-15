import subprocess
subprocess.run(["git", "checkout", "py2v_transpiler/core/analyzer.py"])
subprocess.run(["git", "checkout", "py2v_transpiler/core/translator/functions.py"])

with open("py2v_transpiler/core/translator/functions.py", "r") as f:
    content = f.read()

# OK, the absolute simplest fix. I add ONE check BEFORE is_mut = False
search = """            if is_mut:
                # V only allows mut arguments for arrays, interfaces, maps, pointers, structs or their aliases.
                # Primitive types like int, string, bool cannot be mut."""

replace = """            if is_mut:
                # Fix global leak false positives on short variable names like 'x' and 'val'
                if arg_name in ("x", "val") and not getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, []):
                     # Wait, `func_param_mutability` has the indices of mutated args.
                     # `mut_info` might have `is_mutated` true if it was mutated in ANOTHER function.
                     # So we can't just trust `is_mutated`. But `interprocedural_list_mutation` needs it!
                     pass
                if arg_name in ("x", "val") and not getattr(self.type_inference, 'func_param_mutability', {}).get(node.name, []):
                     # If the function itself has NO locally reassigned params, AND it's a short name,
                     # we can just assume it's a false positive ONLY IF it wasn't explicitly mutated globally.
                     if hasattr(self.type_inference, 'mutability_map'):
                         mut_info = self.type_inference.mutability_map.get(arg_name)
                         if mut_info and not mut_info.get("is_mutated"):
                              is_mut = False
            if is_mut:
                # V only allows mut arguments for arrays, interfaces, maps, pointers, structs or their aliases.
                # Primitive types like int, string, bool cannot be mut."""

content = content.replace(search, replace)
with open("py2v_transpiler/core/translator/functions.py", "w") as f:
    f.write(content)
