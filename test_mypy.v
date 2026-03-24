module main

import os
import div72.vexc

pub const code = 'print(1)'

fn init() {
    // @line: test_mypy.py:5:0
    // @line: test_mypy.py:6:0
    f := os.create('tmp.py') or { panic(err) }
    defer { f.close() }
    f.write_string(code) or { panic(err) }
    // @line: test_mypy.py:9:0
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    {
    defer {
    if os.exists('tmp.py') {
    os.rm('tmp.py') or { panic(err) }
    }
    }
    if C.try() {
    res := py_subprocess_run(['mypy', 'tmp.py'])
    println('Mypy return code: ${res.returncode}')
    println('Mypy stdout: ${res.stdout}')
    println('Mypy stderr: ${res.stderr}')
    vexc.end_try()
    } else {
    py_exc := vexc.get_curr_exc()
    vexc.raise(py_exc.name, py_exc.msg)
    }
    }
}
