import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def translate(code: str) -> str:
    tree = ast.parse(code)
    if not isinstance(tree, ast.Module):
        raise ValueError("Code must be a module")

    analyzer = TypeInference()
    visitor = VNodeVisitor(analyzer)
    return visitor.visit_Module(tree)

def test_generator_definition():
    py_code = """
def gen():
    yield 1
"""
    v_code = translate(py_code)
    # Check for signature change and body
    # It might be indented differently or have comments
    assert "fn gen(ch_out chan ?int, ch_in chan PyGeneratorInput) {" in v_code
    assert "py_yield(ch_out, ch_in, 1)" in v_code
    assert "ch_out.close()" in v_code

def test_generator_with_args():
    py_code = """
def gen(n):
    for i in range(n):
        yield i
"""
    v_code = translate(py_code)
    # fn gen(ch chan int, n int)
    assert "fn gen(ch_out chan ?int, ch_in chan PyGeneratorInput, n int) {" in v_code
    # Loop checks
    # Range translation: 0..n or similar
    assert "0..n" in v_code or "range(n)" in v_code # V uses 0..n usually
    assert "py_yield(ch_out, ch_in, i)" in v_code
    assert "ch_out.close()" in v_code

def test_generator_usage_in_for_loop():
    py_code = """
def gen(max):
    for i in range(max):
        yield i

def main():
    for x in gen(5):
        print(x)
"""
    v_code = translate(py_code)

    # Check generator def
    assert "fn gen(ch_out chan ?int, ch_in chan PyGeneratorInput, max int) {" in v_code

    # Check main
    # Should see channel creation and spawn
    assert "chan ?int{cap: 0}" in v_code
    assert "spawn gen(" in v_code
    # check that we loop over the channel
    # The channel name is generated, e.g. ch_1
    # We can regex or just check fragments
    assert "for x in gen_" in v_code
    # print(x) -> println('${x}')
    assert "println('${x}')" in v_code

def test_yield_from_list():
    py_code = """
def gen():
    yield from [1, 2, 3]
"""
    v_code = translate(py_code)
    # Should emit a loop over list
    assert "for v in [1, 2, 3] {" in v_code
    assert "py_yield(ch_out, ch_in, v)" in v_code

def test_generator_yield_expression_as_statement():
    # yield 1 as statement
    py_code = """
def gen():
    yield 1
    yield 2
"""
    v_code = translate(py_code)
    assert "py_yield(ch_out, ch_in, 1)" in v_code
    assert "py_yield(ch_out, ch_in, 2)" in v_code

def test_generator_with_params_ordering():
    # params should be preserved after ch
    py_code = """
def gen(a, b):
    yield a + b
"""
    v_code = translate(py_code)
    assert "fn gen(ch_out chan ?int, ch_in chan PyGeneratorInput, a int, b int) {" in v_code
    assert "py_yield(ch_out, ch_in, a + b)" in v_code

def test_generator_with_type_annotation():
    py_code = """
from typing import Iterator

def gen() -> Iterator[str]:
    yield "a"
"""
    v_code = translate(py_code)
    assert "fn gen(ch_out chan ?string, ch_in chan PyGeneratorInput) {" in v_code
    assert "py_yield(ch_out, ch_in, 'a')" in v_code

def test_generator_usage_with_type():
    py_code = """
from typing import Iterator

def gen() -> Iterator[str]:
    yield "a"

def main():
    for x in gen():
        print(x)
"""
    v_code = translate(py_code)
    assert "chan ?string{cap: 0}" in v_code
