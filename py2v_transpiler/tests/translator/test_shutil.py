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

def test_shutil_copy():
    source = """
import shutil
shutil.copy("src.txt", "dst.txt")
"""
    v_code = translate(source)
    assert "os.cp('src.txt', 'dst.txt') or { panic(err) }" in v_code
    assert "import os" in v_code

def test_shutil_move():
    source = """
import shutil
shutil.move("src", "dst")
"""
    v_code = translate(source)
    assert "os.mv('src', 'dst') or { panic(err) }" in v_code

def test_shutil_rmtree():
    source = """
import shutil
shutil.rmtree("dir")
"""
    v_code = translate(source)
    assert "os.rmdir_all('dir') or { panic(err) }" in v_code

def test_shutil_copytree():
    source = """
import shutil
shutil.copytree("src_dir", "dst_dir")
"""
    v_code = translate(source)
    assert "os.cp_all('src_dir', 'dst_dir', true) or { panic(err) }" in v_code

def test_shutil_which():
    source = """
import shutil
shutil.which("python")
"""
    v_code = translate(source)
    assert "os.find_abs_path_of_executable('python') or { '' }" in v_code

def test_shutil_chown():
    source = """
import shutil
shutil.chown("file", "user", "group")
"""
    v_code = translate(source)
    # Basic mapping, might change if we decide to comment it out or handle differently
    assert "os.chown('file', 'user', 'group')" in v_code
