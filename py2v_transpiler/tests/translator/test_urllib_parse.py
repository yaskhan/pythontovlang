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
    return translator.visit_Module(tree)

def test_urllib_parse_quote():
    source = """
import urllib.parse
encoded = urllib.parse.quote('hello world')
"""
    v_code = translate(source)
    assert "import net.urllib" in v_code
    # V's query_escape is closest to quote_plus usually, but for now we map quote to it or similar.
    # The plan says map quote -> urllib.query_escape
    assert "encoded := urllib.query_escape('hello world')" in v_code

def test_urllib_parse_unquote():
    source = """
import urllib.parse
decoded = urllib.parse.unquote('hello%20world')
"""
    v_code = translate(source)
    assert "import net.urllib" in v_code
    # Plan says map unquote -> py_urllib_unquote because it returns Result
    assert "decoded := py_urllib_unquote('hello%20world')" in v_code

def test_urllib_parse_quote_plus():
    source = """
import urllib.parse
encoded = urllib.parse.quote_plus('hello world')
"""
    v_code = translate(source)
    assert "import net.urllib" in v_code
    assert "encoded := urllib.query_escape('hello world')" in v_code

def test_urllib_parse_unquote_plus():
    source = """
import urllib.parse
decoded = urllib.parse.unquote_plus('hello+world')
"""
    v_code = translate(source)
    assert "import net.urllib" in v_code
    assert "decoded := py_urllib_unquote('hello+world')" in v_code

def test_urllib_parse_urlencode():
    source = """
import urllib.parse
params = {'q': 'python', 'v': 'lang'}
query = urllib.parse.urlencode(params)
"""
    v_code = translate(source)
    assert "import net.urllib" in v_code
    assert "query := py_urlencode(params)" in v_code

def test_urllib_parse_urlparse():
    source = """
import urllib.parse
u = urllib.parse.urlparse('https://example.com/path?q=v')
"""
    v_code = translate(source)
    assert "import net.urllib" in v_code
    # urlparse returns Result in V? urllib.parse(s) !URL
    # If mapped directly: urllib.parse(s) -> returns Result.
    # Python doesn't raise usually.
    # We might need py_urlparse helper or handle result inline?
    # If mapped to urllib.parse, it emits `urllib.parse(...)`.
    # Let's assume for now direct mapping and see. Or maybe py_urlparse.
    # Given V's result handling requirement, mapping to raw function that returns !T is risky if used in expression.
    # But let's start with helper `py_urlparse` to be safe.
    assert "u := py_urlparse('https://example.com/path?q=v')" in v_code
