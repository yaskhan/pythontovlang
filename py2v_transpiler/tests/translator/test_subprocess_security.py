import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    if not isinstance(tree, ast.Module):
        raise ValueError("Parsed AST is not a Module")
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_subprocess_security_run():
    # Attempt injection in arguments
    source = """
import subprocess
res = subprocess.run(["ls", "; rm -rf /"])
"""
    v_code = translate(source)
    # After the fix, we expect os.new_process and set_args to be used
    # and NO naive joining with spaces.
    assert "os.new_process" in v_code
    assert "set_args" in v_code
    assert "args.join(' ')" not in v_code
    assert "os.execute" not in v_code

def test_subprocess_security_call():
    source = """
import subprocess
ret = subprocess.call(["echo", "hello; whoami"])
"""
    v_code = translate(source)
    assert "os.new_process" in v_code
    assert "set_args" in v_code
    assert "args.join(' ')" not in v_code
    assert "os.system" not in v_code
