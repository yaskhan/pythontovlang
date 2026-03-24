import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_import():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "import math"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "import math" in result

def test_translator_import_multiple():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "import os, sys"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "import os" in result
    # sys is mapped to os, so we don't expect 'import sys'

def test_translator_import_from():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "from math import sqrt"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # We map "from x import y" to just "import x" for now
    assert "import math" in result

def test_translator_relative_import_from_dot():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "from . import sibling"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "import sibling" in result

def test_translator_relative_star_import_is_ignored():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "from . import *"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "import *" not in result
