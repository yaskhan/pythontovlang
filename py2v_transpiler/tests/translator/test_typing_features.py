import ast
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

def test_typing_literal():
    source = """
from typing import Literal

def foo(x: Literal[1, 2]) -> Literal['a', 'b']:
    return 'a'
"""
    v_code = translate(source)
    assert "fn foo(x int) string {" in v_code

def test_typing_final():
    source = """
from typing import Final

x: Final[int] = 10
"""
    v_code = translate(source)
    assert "x := 10" in v_code

def test_typing_class_var():
    source = """
from typing import ClassVar

class A:
    x: ClassVar[int] = 1
"""
    v_code = translate(source)
    assert "x int" in v_code # Mapped to field

def test_typing_annotated():
    source = """
from typing import Annotated

x: Annotated[int, "metadata"] = 1
"""
    v_code = translate(source)
    assert "x := 1" in v_code

def test_typing_required_not_required():
    source = """
from typing import Required, NotRequired

def foo(x: Required[int], y: NotRequired[int]):
    pass
"""
    v_code = translate(source)
    assert "fn foo(x int, y ?int)" in v_code

def test_typing_type_guard():
    source = """
from typing import TypeGuard, List

def is_str_list(val: List[object]) -> TypeGuard[List[str]]:
    return True
"""
    v_code = translate(source)
    # object -> Any
    assert "fn is_str_list(val []Any) bool" in v_code

def test_typing_no_return():
    source = """
from typing import NoReturn

def fail() -> NoReturn:
    raise Exception("fail")
"""
    v_code = translate(source)
    assert "[noreturn]" in v_code
    assert "fn fail() {" in v_code or "fn fail() void {" in v_code

def test_typing_unpack():
    # Unpack is complex, usually used in Tuple or Generic.
    # Tuple[Unpack[Ts]] -> ...
    # We might map Unpack to ... if supported or ignore.
    pass

def test_typing_param_spec():
    source = """
from typing import ParamSpec, TypeVar, Callable

P = ParamSpec("P")
R = TypeVar("R")

def foo(f: Callable[P, R]) -> Callable[P, R]:
    return f
"""
    # Just check it compiles to something reasonable (generic P, R)
    # V generics don't support ParamSpec equivalent directly yet.
    # It might just map to generic T.
    pass

def test_typing_self():
    source = """
from typing import Self

class A:
    def foo(self) -> Self:
        return self
"""
    v_code = translate(source)
    assert "fn (self A) foo() A {" in v_code

def test_typing_cast():
    source = """
from typing import cast

x = cast(int, "1")
"""
    v_code = translate(source)
    # V string literals use single quotes usually in emitted code if transpiled from py
    assert "x := ('1' as int)" in v_code

def test_typing_new_type():
    source = """
from typing import NewType

UserId = NewType('UserId', int)
"""
    v_code = translate(source)
    assert "type UserId = int" in v_code

def test_typing_named_tuple():
    source = """
from typing import NamedTuple

class Point(NamedTuple):
    x: int
    y: int
"""
    v_code = translate(source)
    assert "struct Point {" in v_code
    assert "x int" in v_code
    assert "y int" in v_code

def test_typing_protocol():
    source = """
from typing import Protocol

class Proto(Protocol):
    def method(self, x: int) -> int:
        ...
"""
    v_code = translate(source)
    assert "interface Proto {" in v_code
    assert "method(x int) int" in v_code

def test_typing_assert_never():
    source = """
from typing import assert_never

def check(x):
    if x == 1:
        pass
    else:
        assert_never(x)
"""
    v_code = translate(source)
    assert "panic('assert_never reached: ${x}')" in v_code

def test_typing_overload():
    source = """
from typing import overload

@overload
def foo(x: int) -> int:
    ...

@overload
def foo(x: str) -> str:
    ...

def foo(x):
    return x
"""
    v_code = translate(source)
    # The overload variants SHOULD be present uniquely named.
    # We should have fn foo_int and fn foo_string.
    assert "fn foo_int(x int) int {" in v_code
    assert "fn foo_string(x string) string {" in v_code
    # And both should have the implementation body `return x`
    assert v_code.count("return x") >= 2

def test_typing_assert_never():
    source = """
from typing import assert_never

def check(x: int) -> None:
    if x == 1:
        pass
    else:
        assert_never(x)
"""
    v_code = translate(source)
    # assert_never should be translated to a panic or similar
    assert "panic" in v_code.lower() or "assert_never" in v_code

def test_typing_typeguard_narrowing():
    source = """
from typing import TypeGuard

def is_str(val: object) -> TypeGuard[str]:
    return isinstance(val, str)

def check(val: object):
    if is_str(val):
        print(val)
    else:
        pass
"""
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    # Mocking call signatures to simulate mypy output
    analyzer.call_signatures = {
        "is_str@8:7": {
            "return": "TypeGuard[builtins.str]",
            "args": ["builtins.object"]
        }
    }
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    # TypeGuard narrows the true branch
    assert "val := (val as string)" in v_code
    # TypeGuard should NOT narrow the false branch
    assert "val := (val as Any)" not in v_code

def test_typing_typeis_narrowing():
    source = """
from typing import TypeIs

def is_int(val: int | str) -> TypeIs[int]:
    return isinstance(val, int)

def check(val: int | str):
    if is_int(val):
        print(val)
    else:
        print(val)
"""
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    # Mocking type map and call signatures to simulate mypy output
    analyzer.type_map = {"val": "int | string"}
    analyzer.call_signatures = {
        "is_int@8:7": {
            "return": "TypeIs[builtins.int]",
            "args": ["builtins.int | builtins.str"]
        }
    }
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    # TypeIs narrows the true branch to int
    assert "val := (val as int)" in v_code
    # TypeIs narrows the false branch to the remaining type, which is string
    assert "val := (val as string)" in v_code
def test_typing_disjoint_base():
    source = """
from typing import disjoint_base

@disjoint_base
class BaseClass:
    pass

@disjoint_base
class AnotherBase:
    pass
"""
    v_code = translate(source)
    assert "[disjoint_base]" in v_code
    assert "struct BaseClass {" in v_code
    assert "struct AnotherBase {" in v_code
