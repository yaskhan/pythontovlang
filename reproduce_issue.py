import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    return v_code

source = """
from typing import TypeVar, Generic, Protocol, Iterable, Iterator

T_co = TypeVar("T_co", covariant=True)
S_contra = TypeVar("S_contra", contravariant=True)
R_co = TypeVar("R_co", covariant=True)

class Generator(Generic[T_co, S_contra, R_co], Iterable[T_co]):
    def __next__(self) -> T_co: ...
    def __iter__(self) -> Iterator[T_co]: ...

class _SpecialForm:
    def __init__(self, name: str):
        self.name = name

TYPE_CHECKING = False
"""

print(translate(source))
