import os
import pytest
from py2v_transpiler.core.dependencies import DependencyAnalyzer

def test_analyze_file_imports(tmp_path):
    d = tmp_path / "subdir"
    d.mkdir()
    p = d / "test_module.py"
    p.write_text("import os\nfrom sys import argv", encoding="utf-8")

    analyzer = DependencyAnalyzer()
    deps = analyzer.analyze_file(str(p))

    assert "os" in deps
    assert "sys" in deps

def test_analyze_project_graph(tmp_path):
    # Setup project structure
    # root/
    #   main.py (imports utils)
    #   utils.py (imports math)

    p1 = tmp_path / "main.py"
    p1.write_text("import utils", encoding="utf-8")

    p2 = tmp_path / "utils.py"
    p2.write_text("import math", encoding="utf-8")

    analyzer = DependencyAnalyzer()
    graph = analyzer.analyze_project(str(tmp_path))

    assert "main.py" in graph
    assert "utils.py" in graph

    assert "utils" in graph["main.py"]
    assert "math" in graph["utils.py"]
