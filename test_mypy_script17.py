from mypy import api

import sys
sys.path.append('.')

source = """
class A:
    def draw(self): pass

class B:
    pass

def foo(obj: A):
    if hasattr(obj, "draw"):
        obj.draw()
"""
with open("test_mypy.py", "w") as f:
    f.write(source)

# If we just want to run mypy via api, we can get stdout. But we need an AST mapping.
# Wait, the user prompt states:
# "Если ты подключишь mypy (или его внутреннюю библиотеку mypy.api) к транслятору, это кардинально меняет правила игры...
# Тебе нужно будет использовать маппинг узлов AST к типам, которые вычислил mypy.
# Примерная логика в коде транслятора: ... `obj_type = self.mypy_types.get(obj_node)`"
# "Если mypy уверен, что поле есть: `if obj_type.has_readable_member(attr_name): return 'true'`"

# So the user is asking to *extend* the existing TypeInference or create a new mechanism
# that integrates with mypy.
# Actually, the user provides a simplified vision of how they want it to look:
# `obj_type = self.mypy_types.get(obj_node)`
# `if obj_type.has_readable_member(attr_name): return "true"`

# If the user specifically wants V interface duck typing or `$if obj.has_field('attr_name')`,
# let's look at their example:
# "Вариант Б: Compile-time Introspection ($if)" -> return f"$if {self.visit(obj_node)}.has_field('{attr_name}')"

# But since we couldn't easily map python `ast` nodes to `mypy` nodes due to mypy's internal AST being different,
# maybe we can just do a heuristic mapping or ignore mypy's full API and just generate the V code
# that handles `hasattr` using `$if` for all cases?
# Actually, the user says: "Если mypy подтверждает... Если mypy подтверждает... Если тип Any... используешь рантайм-проверку"
# But they also say: "Вариант Б: Compile-time Introspection ($if)... Самый элегантный способ для V... Даже если mypy не уверен в типе на 100%, V проверит его при компиляции."
# And provides the exact output they want for the fallback/dynamic case:
# return f"$if {self.visit(obj_node)}.has_field('{attr_name}')"
