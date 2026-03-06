import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

code = """
def is_str(val: object) -> bool:
    return isinstance(val, str)

def foo(val: object):
    if is_str(val):
        print(val.upper())
    else:
        print(val)
"""

tree = ast.parse(code)
if_node = tree.body[1].body[0]

analyzer = TypeInference()
analyzer.call_signatures = {
    f"{if_node.lineno}:{if_node.test.col_offset}": {"return": "TypeGuard[builtins.str]"}
}
analyzer.visit(tree)

visitor = VNodeVisitor(type_inference=analyzer)
# Pre-register 'val' as local so narrowing logic uses narrowed_ prefix
visitor._scope_stack.append({'val'})

visitor.visit(tree)
v_code = visitor.emitter.emit()
print(v_code)
