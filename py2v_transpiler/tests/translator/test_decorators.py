import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_decorators_basic():
    source = """
@my_decorator
def my_func():
    pass
"""
    # Should still emit comment
    expected_fragments = [
        "// @my_decorator",
        "fn my_func() {"
    ]

    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    for fragment in expected_fragments:
        assert fragment in code, f"Expected '{fragment}' in generated code:\n{code}"

def test_staticmethod():
    source = """
class MyClass:
    @staticmethod
    def static_method(arg):
        pass

    def instance_method(self):
        pass
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # static_method should NOT have receiver and should be prefixed with class name
    assert "fn MyClass_static_method(arg int)" in code, f"Code:\n{code}"
    # instance_method SHOULD have receiver
    assert "fn (self MyClass) instance_method()" in code, f"Code:\n{code}"

def test_lru_cache():
    source = """
from functools import lru_cache

@lru_cache(maxsize=None)
def fib(n) -> int:
    return n
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # Check for cache map declaration
    # Note: map decl might be inside the wrapper block or top level depending on emitter
    # Currently emitter appends wrapper code which includes map decl.
    assert "mut fib_cache := map[string]int{}" in code, f"Code:\n{code}"

    # Check for wrapper function
    assert "fn fib(n int) int {" in code
    assert "key := '${n}'" in code
    assert "if key in fib_cache {" in code
    assert "res := fib__impl(n)" in code
    assert "fib_cache[key] = res" in code

    # Check for implementation function
    assert "fn fib__impl(n int) int {" in code

def test_lru_cache_method():
    source = """
from functools import lru_cache

class Calc:
    @lru_cache
    def add(self, a, b) -> int:
        return a + b
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # Check wrapper signature (should have receiver)
    assert "fn (self Calc) add(a int, b int) int {" in code
    # Check key generation (should include self)
    assert "key := '${self}_${a}_${b}'" in code
    # Check implementation call (should have receiver)
    assert "res := self.add__impl(a, b)" in code

def test_timer_log():
    source = """
@timer
@log
def slow_func():
    pass
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    assert "fn slow_func() {" in code
    assert "println('Start slow_func...')" in code
    assert "defer { println('End slow_func...') }" in code

def test_classmethod():
    source = """
class MyClass:
    @classmethod
    def factory(cls):
        pass
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # Treated as static method (no receiver) and prefixed with class name
    # The argument 'cls' is removed.
    assert "fn MyClass_factory()" in code, f"Code:\n{code}"

    """Test PEP 702 @deprecated decorator on function"""
    source = """
from warnings import deprecated

@deprecated("Use new_func instead")

def old_func():
    pass
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # Check for [deprecated] attribute with message
    assert "[deprecated: 'Use new_func instead']" in code, f"Code:\n{code}"
    assert "fn old_func() {" in code, f"Code:\n{code}"

def test_deprecated_function_no_message():
    """Test @deprecated decorator without message"""
    source = """
@deprecated
def old_func():
    pass
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # Check for [deprecated] attribute without message
    assert "[deprecated]" in code, f"Code:\n{code}"
    assert "[deprecated: '" not in code, f"Code:\n{code}"

def test_deprecated_class():
    """Test PEP 702 @deprecated decorator on class"""
    source = """
from warnings import deprecated

@deprecated("Use NewClass instead")
class OldClass:
    pass
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # Check for [deprecated] attribute on struct
    assert "[deprecated: 'Use NewClass instead']" in code, f"Code:\n{code}"
    assert "struct OldClass {" in code, f"Code:\n{code}"

def test_deprecated_method():
    """Test @deprecated decorator on method"""
    source = """
from warnings import deprecated

class MyClass:
    @deprecated("Use new_method instead")
    def old_method(self):
        pass
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # Check for [deprecated] attribute on method
    assert "[deprecated: 'Use new_method instead']" in code, f"Code:\n{code}"
    assert "fn (self MyClass) old_method() {" in code, f"Code:\n{code}"

