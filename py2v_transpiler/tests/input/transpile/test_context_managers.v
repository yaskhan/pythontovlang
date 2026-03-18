module main

import os
import div72.vexc

// @line: test_context_managers.py:2:4
pub struct FileManager {
    filename string
    mode string
    file Any
}
// @line: test_context_managers.py:23:4
pub struct SimpleContext {
}
// @line: test_context_managers.py:35:4
pub struct ValueContext {
}
// @line: test_context_managers.py:47:4
pub struct SuppressErrors {
}
// @line: test_context_managers.py:62:4
pub struct LogErrors {
}
// @line: test_context_managers.py:79:4
pub struct ContextA {
}
// @line: test_context_managers.py:87:4
pub struct ContextB {
}
// @line: test_context_managers.py:99:4
pub struct FailingEnter {
}
// @line: test_context_managers.py:114:4
pub struct FailingExit {
}

// @line: test_context_managers.py:1:0
pub fn test_context_manager() {
// @line: test_context_managers.py:3:8
    mut new_ := fn (filename string, mode string)  {
        mut self := {}
        self.filename = filename
        self.mode = mode
        self.file = Any(NoneType{})
        return self
    }
// @line: test_context_managers.py:8:8
    mut enter := fn () Any {
        println('Opening ${self.filename}')
        self.file = os.open(self.filename) or { panic(err) }
        return self.file
    }
// @line: test_context_managers.py:13:8
    mut exit := fn (exc_type Any, exc_val Any, exc_tb Any) int {
        println('Closing ${self.filename}')
        self.file.close()
        return false
    }
}
// @line: test_context_managers.py:22:0
pub fn test_simple_context() {
// @line: test_context_managers.py:24:8
    mut enter := fn () Any {
        println('Entering')
        return self
    }
// @line: test_context_managers.py:28:8
    mut exit := fn (args ...int) int {
        println('Exiting')
    }
    ctx_mgr_0 := SimpleContext{}
    defer { ctx_mgr_0.exit(none, none, none) }
    ctx := ctx_mgr_0.enter()
    println('Inside context')
}
// @line: test_context_managers.py:34:0
pub fn test_context_with_value() {
// @line: test_context_managers.py:36:8
    mut enter := fn () Any {
        println('Getting value')
        return 42
    }
// @line: test_context_managers.py:40:8
    mut exit := fn (args ...int) int {
        println('Cleaning up')
    }
    ctx_mgr_1 := ValueContext{}
    defer { ctx_mgr_1.exit(none, none, none) }
    value := ctx_mgr_1.enter()
    println('Got value: ${value}')
}
// @line: test_context_managers.py:46:0
pub fn test_context_suppress_exception() {
// @line: test_context_managers.py:48:8
    mut enter := fn () Any {
        println('Entering (suppressing errors)')
        return self
    }
// @line: test_context_managers.py:52:8
    mut exit := fn (exc_type Any, exc_val Any, exc_tb Any) int {
        println('Caught exception: ${exc_type}')
        return true
    }
    ctx_mgr_2 := SuppressErrors{}
    defer { ctx_mgr_2.exit(none, none, none) }
    ctx_mgr_2.enter()
    println('About to raise error')
    vexc.raise('ValueError', 'This error is suppressed')
    println('After context (error was suppressed)')
}
// @line: test_context_managers.py:61:0
pub fn test_context_propagate_exception() {
// @line: test_context_managers.py:63:8
    mut enter := fn () Any {
        println('Entering')
        return self
    }
// @line: test_context_managers.py:67:8
    mut exit := fn (exc_type Any, exc_val Any, exc_tb Any) int {
        if (exc_type) !is NoneType {
            println('Logging error: ${exc_val}')
        }
        return false
    }
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    if C.try() {
        ctx_mgr_3 := LogErrors{}
        defer { ctx_mgr_3.exit(none, none, none) }
        ctx_mgr_3.enter()
        vexc.raise('ValueError', 'This error propagates')
        vexc.end_try()
    } else {
        py_exc_1 := vexc.get_curr_exc()
        if py_exc_1.name == 'ValueError' {
            println('Exception was propagated')
        }
        else {
            vexc.raise(py_exc_1.name, py_exc_1.msg)
        }
    }
}
// @line: test_context_managers.py:78:0
pub fn test_nested_contexts() {
// @line: test_context_managers.py:80:8
    mut enter := fn () Any {
        println('Context A enter')
        return 'A'
    }
// @line: test_context_managers.py:84:8
    mut exit := fn (args ...int) int {
        println('Context A exit')
    }
// @line: test_context_managers.py:88:8
    mut enter = fn () Any {
        println('Context B enter')
        return 'B'
    }
// @line: test_context_managers.py:92:8
    mut exit = fn (args ...int) int {
        println('Context B exit')
    }
    ctx_mgr_4 := ContextA{}
    defer { ctx_mgr_4.exit(none, none, none) }
    a := ctx_mgr_4.enter()
    ctx_mgr_5 := ContextB{}
    defer { ctx_mgr_5.exit(none, none, none) }
    b := ctx_mgr_5.enter()
    println('Inside: ${a}, ${b}')
}
// @line: test_context_managers.py:98:0
pub fn test_context_exception_in_enter() {
// @line: test_context_managers.py:100:8
    mut enter := fn () Any {
        println('About to fail')
        vexc.raise('RuntimeError', 'Enter failed')
    }
// @line: test_context_managers.py:104:8
    mut exit := fn (args ...int) int {
        println('Exit called (cleanup)')
    }
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    if C.try() {
        ctx_mgr_6 := FailingEnter{}
        defer { ctx_mgr_6.exit(none, none, none) }
        ctx_mgr_6.enter()
        println('Never reached')
        vexc.end_try()
    } else {
        py_exc_3 := vexc.get_curr_exc()
        if py_exc_3.name == 'RuntimeError' {
            println('Caught RuntimeError')
        }
        else {
            vexc.raise(py_exc_3.name, py_exc_3.msg)
        }
    }
}
// @line: test_context_managers.py:113:0
pub fn test_context_exception_in_exit() {
// @line: test_context_managers.py:115:8
    mut enter := fn () Any {
        println('Enter OK')
        return self
    }
// @line: test_context_managers.py:119:8
    mut exit := fn (args ...int) int {
        println('About to fail in exit')
        vexc.raise('RuntimeError', 'Exit failed')
    }
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    if C.try() {
        ctx_mgr_7 := FailingExit{}
        defer { ctx_mgr_7.exit(none, none, none) }
        ctx_mgr_7.enter()
        println('Inside')
        vexc.end_try()
    } else {
        py_exc_5 := vexc.get_curr_exc()
        if py_exc_5.name == 'RuntimeError' {
            println('Caught RuntimeError from exit')
        }
        else {
            vexc.raise(py_exc_5.name, py_exc_5.msg)
        }
    }
}
// @line: test_context_managers.py:129:0
pub fn test() {
    test_simple_context()
    test_context_with_value()
    test_context_suppress_exception()
    test_context_propagate_exception()
    test_nested_contexts()
    test_context_exception_in_enter()
    test_context_exception_in_exit()
}

fn main() {
    // @line: test_context_managers.py:138:0
    // if __name__ == '__main__':
    test()
}