import os
import pytest
from py2v_transpiler.core.dependencies import DependencyAnalyzer

def test_scc_detection(tmp_path):
    # a.py -> b.py
    # b.py -> a.py
    # c.py -> a.py (outside the cycle)

    (tmp_path / "a.py").write_text("import b", encoding="utf-8")
    (tmp_path / "b.py").write_text("import a", encoding="utf-8")
    (tmp_path / "c.py").write_text("import a", encoding="utf-8")

    analyzer = DependencyAnalyzer()
    sccs = analyzer.find_sccs(str(tmp_path))

    # Expected SCCs: {a.py, b.py} and {c.py}
    assert any(set(["a.py", "b.py"]) == set(scc) for scc in sccs)
    assert any(set(["c.py"]) == set(scc) for scc in sccs)
    assert len(sccs) == 2

def test_nested_scc_detection(tmp_path):
    # models/user.py -> models/order.py
    # models/order.py -> models/user.py

    models_dir = tmp_path / "models"
    models_dir.mkdir()
    (models_dir / "user.py").write_text("from models.order import Order", encoding="utf-8")
    (models_dir / "order.py").write_text("from models.user import User", encoding="utf-8")

    analyzer = DependencyAnalyzer()
    sccs = analyzer.find_sccs(str(tmp_path))

    # In V, these would be in the same package 'models'
    # Our analyzer should find them as an SCC
    expected_scc = set([os.path.join("models", "user.py"), os.path.join("models", "order.py")])
    assert any(expected_scc == set(scc) for scc in sccs)
