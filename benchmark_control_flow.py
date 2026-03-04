import time
import ast

class DummyTranslator:
    def visit(self, node):
        return getattr(node, "id", "Exception")

class DummyHandler:
    def __init__(self, elts):
        self.type = type('obj', (object,), {'elts': elts})

# Create some dummy AST nodes
elts = [ast.Name(id=f'Exc{i}', ctx=ast.Load()) for i in range(10)]
handler = DummyHandler(elts)
exc_var = "_exc_1"
translator = DummyTranslator()

# Approach 1: List comprehension nested inside list comprehension + join
start_time = time.time()
for _ in range(100000):
    types = [str(translator.visit(t)) for t in handler.type.elts]
    type_str = " || ".join([f"{exc_var}.name == '{t}'" for t in types])
end_time = time.time()
print(f"Approach 1 (current): {end_time - start_time:.5f}s")

# Approach 2: Generator expression directly inside join
start_time = time.time()
for _ in range(100000):
    type_str = " || ".join(f"{exc_var}.name == '{translator.visit(t)}'" for t in handler.type.elts)
end_time = time.time()
print(f"Approach 2 (gen expr): {end_time - start_time:.5f}s")

# Approach 3: List comprehension directly inside join
start_time = time.time()
for _ in range(100000):
    type_str = " || ".join([f"{exc_var}.name == '{translator.visit(t)}'" for t in handler.type.elts])
end_time = time.time()
print(f"Approach 3 (list comp): {end_time - start_time:.5f}s")
