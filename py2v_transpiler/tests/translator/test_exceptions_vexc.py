import ast
import pytest
import sys
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_exceptions_vexc_basic():
    code = """
def test_successful_try():
    try:
        pass
    except Exception:
        pass
"""
    parser = PyASTParser()
    ast_tree = parser.parse(code)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    analyzer.analyze(ast_tree)
    v_code = translator.visit_Module(ast_tree)

    assert "import div72.vexc" in v_code
    assert "if C.try() {" in v_code
    assert "vexc.end_try()" in v_code
    assert "} else {" in v_code
    assert "vexc.get_curr_exc()" in v_code

def test_exceptions_vexc_nested():
    code = """
def test_inner():
    flag = False
    try:
        try:
            try:
                raise RuntimeError("invalid country NZ")
            except Exception:
                pass
        except Exception:
            pass
        raise Exception("")
    except Exception:
        flag = True
"""
    parser = PyASTParser()
    ast_tree = parser.parse(code)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    analyzer.analyze(ast_tree)
    v_code = translator.visit_Module(ast_tree)

    assert v_code.count("if C.try() {") >= 3
    assert v_code.count("vexc.end_try()") >= 3
    assert 'vexc.raise(\'RuntimeError\', \'invalid country NZ\')' in v_code

def test_exceptions_vexc_return_unwind():
    code = """
def test_return():
    try:
        try:
            return 1
        except Exception:
            pass
    except Exception:
        pass
"""
    parser = PyASTParser()
    ast_tree = parser.parse(code)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    analyzer.analyze(ast_tree)
    v_code = translator.visit_Module(ast_tree)

    # In the try block, vexc_depth is 2 before return
    assert v_code.count("vexc.end_try()") >= 2

def test_exceptions_vexc_finally():
    code = """
def test_finally():
    try:
        pass
    finally:
        pass
"""
    parser = PyASTParser()
    ast_tree = parser.parse(code)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    analyzer.analyze(ast_tree)
    v_code = translator.visit_Module(ast_tree)

    assert "defer {" in v_code

def test_exceptions_vexc_bracketless_pep758():
    code = """
def test_bracketless():
    try:
        pass
    except ValueError, TypeError as e:
        pass
"""
    # Exception groups (except*) are only valid syntax in Python 3.11+
    if sys.version_info >= (3, 11):
        code += """
    try:
        pass
    except* OSError, IOError:
        pass
"""
    else:
        code += """
    try:
        pass
    except OSError, IOError:
        pass
"""

    parser = PyASTParser()
    ast_tree = parser.parse(code)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    analyzer.analyze(ast_tree)
    v_code = translator.visit_Module(ast_tree)

    # Make sure we generate valid code checking for exceptions
    # The `except ValueError, TypeError` should have been transpiled to checking `name == 'ValueError' || name == 'TypeError'`
    assert "name == 'ValueError'" in v_code
    assert "name == 'TypeError'" in v_code
    assert "name == 'OSError'" in v_code
    assert "name == 'IOError'" in v_code

def test_exceptions_vexc_nested_func_bare_except_else():
    code = """
def outer():
    try:
        def nested():
            pass
        print("try")
    except:
        print("except")
    else:
        print("else")
"""
    parser = PyASTParser()
    ast_tree = parser.parse(code)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    analyzer.analyze(ast_tree)
    v_code = translator.visit_Module(ast_tree)

    # Check for indentation and structure
    # The 'if C.try()' and its 'else' should be at same indent level
    # The nested function should be an anonymous function
    assert "mut nested := fn () {" in v_code
    assert "mut _success_0 := false" in v_code
    assert "if C.try() {" in v_code
    assert "_success_0 = true" in v_code
    assert "vexc.end_try()" in v_code
    # Ensure no redundant 'else {' after '_exc_1 := vexc.get_curr_exc()' for bare except
    assert "} else {\n        _exc_1 := vexc.get_curr_exc()\n        println('except')\n    }" in v_code or \
           "} else {\n        _exc_1 := vexc.get_curr_exc()\n        println('except')\n    }" in v_code.replace("    ", "    ")

    # Check for correct orelse handling
    assert "if _success_0 {" in v_code
    assert "println('else')" in v_code
