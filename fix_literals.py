with open("py2v_transpiler/core/translator/literals.py", "r") as f:
    content = f.read()

old_code = """             mapped_elements = []
             for elt in elements:
                 if elt != "none":
                     mapped_elements.append(f"{base_type}({elt})")
                 else:
                     mapped_elements.append(elt)"""

new_code = """             mapped_elements: List[str] = []
             for element in elements:
                 if element != "none":
                     mapped_elements.append(f"{base_type}({element})")
                 else:
                     mapped_elements.append(element)"""

content = content.replace(old_code, new_code)

with open("py2v_transpiler/core/translator/literals.py", "w") as f:
    f.write(content)
