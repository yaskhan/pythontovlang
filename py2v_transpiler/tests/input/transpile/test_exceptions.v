module main

import div72.vexc

// @line: test_exceptions.py:1:0
pub fn test_basic_try_except() {
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    if C.try() {
        mut result := 10 / 2
        println('Result: ${result}')
        vexc.end_try()
    } else {
        py_exc_1 := vexc.get_curr_exc()
        if py_exc_1.name == 'ZeroDivisionError' {
            println('Division by zero!')
        }
        else {
            vexc.raise(py_exc_1.name, py_exc_1.msg)
        }
    }
}
// @line: test_exceptions.py:8:0
pub fn test_multiple_except() {
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    if C.try() {
        value := 'not a number'.int()
        vexc.end_try()
    } else {
        py_exc_3 := vexc.get_curr_exc()
        if py_exc_3.name == 'ValueError' {
            println('ValueError caught')
        }
        else if py_exc_3.name == 'TypeError' {
            println('TypeError caught')
        }
        else {
            vexc.raise(py_exc_3.name, py_exc_3.msg)
        }
    }
}
// @line: test_exceptions.py:16:0
pub fn test_except_with_as() {
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    if C.try() {
        mut result := 10 / 0
        vexc.end_try()
    } else {
        py_exc_5 := vexc.get_curr_exc()
        if py_exc_5.name == 'ZeroDivisionError' {
            e := py_exc_5
            println('Caught exception: ${e}')
        }
        else {
            vexc.raise(py_exc_5.name, py_exc_5.msg)
        }
    }
}
// @line: test_exceptions.py:22:0
pub fn test_else_clause() {
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    mut py_success_6 := false
    if C.try() {
        mut result := 10 / 2
        py_success_6 = true
        vexc.end_try()
    } else {
        py_exc_7 := vexc.get_curr_exc()
        if py_exc_7.name == 'ZeroDivisionError' {
            println('Division by zero')
        }
        else {
            vexc.raise(py_exc_7.name, py_exc_7.msg)
        }
    }
    if py_success_6 {
        println('Division successful: ${result}')
    }
}
// @line: test_exceptions.py:30:0
pub fn test_finally_clause() {
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    {
        defer {
            println('Finally block always executes')
        }
    if C.try() {
        println('Trying...')
        mut result := 10 / 2
        vexc.end_try()
    } else {
        py_exc_9 := vexc.get_curr_exc()
        if py_exc_9.name == 'ZeroDivisionError' {
            println('Error')
        }
        else {
            vexc.raise(py_exc_9.name, py_exc_9.msg)
        }
    }
    }
}
// @line: test_exceptions.py:39:0
pub fn test_raise_exception() {
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    if C.try() {
        vexc.raise('ValueError', 'Custom error message')
        vexc.end_try()
    } else {
        py_exc_11 := vexc.get_curr_exc()
        if py_exc_11.name == 'ValueError' {
            e := py_exc_11
            println('Caught: ${e}')
        }
        else {
            vexc.raise(py_exc_11.name, py_exc_11.msg)
        }
    }
}
// @line: test_exceptions.py:45:0
pub fn test_raise_with_cause() {
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    if C.try() {
        //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
        if C.try() {
            'invalid'.int()
            vexc.end_try()
        } else {
            py_exc_14 := vexc.get_curr_exc()
            if py_exc_14.name == 'ValueError' {
                e := py_exc_14
                vexc.raise('TypeError', 'Conversion failed')
            }
            else {
                vexc.raise(py_exc_14.name, py_exc_14.msg)
            }
        }
        vexc.end_try()
    } else {
        py_exc_15 := vexc.get_curr_exc()
        if py_exc_15.name == 'TypeError' {
            e := py_exc_15
            println('Caught with cause: ${e}')
            println('__cause__: ${e.__cause__}')
        }
        else {
            vexc.raise(py_exc_15.name, py_exc_15.msg)
        }
    }
}
// @line: test_exceptions.py:55:0
pub fn test_assert_statement() {
    x := 5
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    if C.try() {
        assert x == 5
        println('Assertion passed')
        vexc.end_try()
    } else {
        py_exc_17 := vexc.get_curr_exc()
        if py_exc_17.name == 'AssertionError' {
            e := py_exc_17
            println('Assertion failed: ${e}')
        }
        else {
            vexc.raise(py_exc_17.name, py_exc_17.msg)
        }
    }
}
// @line: test_exceptions.py:63:0
pub fn test_nested_exceptions() {
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    if C.try() {
        //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
        if C.try() {
            vexc.raise('ValueError', 'Inner error')
            vexc.end_try()
        } else {
            py_exc_20 := vexc.get_curr_exc()
            if py_exc_20.name == 'ValueError' {
                vexc.raise('RuntimeError', 'Outer error')
            }
            else {
                vexc.raise(py_exc_20.name, py_exc_20.msg)
            }
        }
        vexc.end_try()
    } else {
        py_exc_21 := vexc.get_curr_exc()
        if py_exc_21.name == 'RuntimeError' {
            e := py_exc_21
            println('Caught outer: ${e}')
        }
        else {
            vexc.raise(py_exc_21.name, py_exc_21.msg)
        }
    }
}
// @line: test_exceptions.py:72:0
pub fn test_exception_in_function() {
// @line: test_exceptions.py:73:4
    mut divide := fn (a Any, b Any) Any {
        if b == 0 {
            vexc.raise('ZeroDivisionError', 'Cannot divide by zero')
        }
        return a / b
    }
    //##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
    if C.try() {
        mut result := divide(10, 0)
        vexc.end_try()
    } else {
        py_exc_23 := vexc.get_curr_exc()
        if py_exc_23.name == 'ZeroDivisionError' {
            e := py_exc_23
            println('Function exception: ${e}')
        }
        else {
            vexc.raise(py_exc_23.name, py_exc_23.msg)
        }
    }
}
// @line: test_exceptions.py:83:0
pub fn test() {
    test_basic_try_except()
    test_multiple_except()
    test_except_with_as()
    test_else_clause()
    test_finally_clause()
    test_raise_exception()
    test_raise_with_cause()
    test_assert_statement()
    test_nested_exceptions()
    test_exception_in_function()
}

fn main() {
    // @line: test_exceptions.py:95:0
    // if __name__ == '__main__':
    test()
}