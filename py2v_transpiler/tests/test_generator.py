import pytest
from py2v_transpiler.core.generator import VCodeEmitter

def test_vcodeemitter_init():
    emitter = VCodeEmitter()
    assert emitter.imports == []
    assert emitter.structs == []
    assert emitter.functions == []
    assert emitter.main_body == []
    assert emitter.init_body == []
    assert emitter.globals == []
    assert emitter.constants == []
    assert emitter.helper_imports == []
    assert emitter.helper_structs == []
    assert emitter.helper_functions == []

def test_add_import():
    emitter = VCodeEmitter()
    emitter.add_import("os")
    assert emitter.imports == ["os"]
    # Test deduplication
    emitter.add_import("os")
    assert emitter.imports == ["os"]
    emitter.add_import("math")
    assert emitter.imports == ["os", "math"]

def test_add_helper_import():
    emitter = VCodeEmitter()
    emitter.add_helper_import("os")
    assert emitter.helper_imports == ["os"]
    # add_helper_import deduplicates on add
    emitter.add_helper_import("os")
    assert emitter.helper_imports == ["os"]
    assert emitter.get_helper_imports() == ["os"]

def test_add_global():
    emitter = VCodeEmitter()
    emitter.add_global("x int")
    assert emitter.globals == ["x int"]

def test_add_constant():
    emitter = VCodeEmitter()
    emitter.add_constant("pi = 3.14")
    assert emitter.constants == ["pi = 3.14"]

def test_add_struct():
    emitter = VCodeEmitter()
    emitter.add_struct("struct Point { x int }")
    assert emitter.structs == ["struct Point { x int }"]

def test_add_helper_struct():
    emitter = VCodeEmitter()
    emitter.add_helper_struct("struct Helper { val int }")
    assert emitter.helper_structs == ["struct Helper { val int }"]
    assert emitter.get_helper_structs() == ["struct Helper { val int }"]

def test_add_function():
    emitter = VCodeEmitter()
    emitter.add_function("fn foo() {}")
    assert emitter.functions == ["fn foo() {}"]

def test_add_helper_function():
    emitter = VCodeEmitter()
    emitter.add_helper_function("fn helper() {}")
    assert emitter.helper_functions == ["fn helper() {}"]
    assert emitter.get_helper_functions() == ["fn helper() {}"]

def test_add_init_statement():
    emitter = VCodeEmitter()
    emitter.add_init_statement("println('init')")
    assert emitter.init_body == ["println('init')"]

def test_add_main_statement():
    emitter = VCodeEmitter()
    emitter.add_main_statement("println('hello')")
    assert emitter.main_body == ["println('hello')"]

def test_emit_basic():
    emitter = VCodeEmitter()
    emitter.add_import("os")
    emitter.add_struct("struct Point {\n    x int\n}")
    emitter.add_global("g int")
    emitter.add_constant("C = 1")
    emitter.add_function("fn foo() {}")
    emitter.add_init_statement("println('init')")
    emitter.add_main_statement("println('main')")

    code = emitter.emit()
    assert "module main" in code
    assert "import os" in code
    assert "struct Point {" in code
    assert "__global g int" in code
    assert "const C = 1" in code
    assert "fn foo() {}" in code
    assert "fn init() {" in code
    assert "    println('init')" in code
    assert "fn main() {" in code
    assert "    println('main')" in code

def test_emit_empty():
    emitter = VCodeEmitter()
    code = emitter.emit()
    # Should only contain module declaration and potentially empty main if not careful
    # Looking at emitter.py, it always adds 'module main\n'
    assert code.strip() == "module main"

def test_emit_global_helpers():
    imports = ["os", "math", "os"]
    structs = ["struct S1{}", "struct S1{}"]
    functions = ["fn f1(){}", "fn f1(){}"]

    code = VCodeEmitter.emit_global_helpers(imports, structs, functions)

    assert "module main" in code
    assert "type Any = bool | int | i64 | f64 | string | []u8" in code
    # deduplicated and sorted
    assert "import math" in code
    assert "import os" in code
    assert code.count("import os") == 1

    assert code.count("struct S1{}") == 1
    assert code.count("fn f1(){}") == 1

def test_emit_helpers():
    emitter = VCodeEmitter()
    emitter.add_helper_import("os")
    emitter.add_helper_struct("struct H{}")
    emitter.add_helper_function("fn h(){}")

    code = emitter.emit_helpers()
    assert "import os" in code
    assert "struct H{}" in code
    assert "fn h(){}" in code
