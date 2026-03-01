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

def test_logging_basics():
    source = """
import logging
logging.info("info")
logging.warning("warn")
logging.error("error")
logging.debug("debug")
logging.critical("critical")
"""
    v_code = translate(source)
    assert "log.info('info')" in v_code
    assert "log.warn('warn')" in v_code
    assert "log.error('error')" in v_code
    assert "log.debug('debug')" in v_code
    assert "log.error('critical')" in v_code # Mapped to error
    assert "import log" in v_code

def test_get_logger():
    source = """
import logging
logger = logging.getLogger("my_logger")
logger.info("msg")
"""
    v_code = translate(source)
    assert "logger := py_get_logger('my_logger')" in v_code
    assert "logger.info('msg')" in v_code
    assert "fn py_get_logger" in v_code

def test_basic_config():
    source = """
import logging
logging.basicConfig()
"""
    v_code = translate(source)
    # Should be ignored or commented
    assert "/* logging.basicConfig ignored */" in v_code
