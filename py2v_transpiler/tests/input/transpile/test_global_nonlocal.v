module main

// @line: test_global_nonlocal.py:1:0
pub fn test_global_variable() {
    mut counter := 0
// @line: test_global_nonlocal.py:4:4
    mut increment := fn () int {
        //##LLM@@ Python 'global' or 'nonlocal' scope modification detected. V heavily discourages global state and has strict mutability rules for closures. Please refactor state management, possibly by passing mutable parameters (mut) explicitly.
        // nonlocal counter
        counter += 1
        return counter
    }
    println('${increment()}')
    println('${increment()}')
    println('${increment()}')
}
// @line: test_global_nonlocal.py:13:0
pub fn test_global_in_multiple_functions() {
    mut total := 100
// @line: test_global_nonlocal.py:16:4
    mut add := fn (x int) []Any {
        //##LLM@@ Python 'global' or 'nonlocal' scope modification detected. V heavily discourages global state and has strict mutability rules for closures. Please refactor state management, possibly by passing mutable parameters (mut) explicitly.
        // nonlocal total
        total += x
    }
// @line: test_global_nonlocal.py:20:4
    mut subtract := fn (x int) {
        //##LLM@@ Python 'global' or 'nonlocal' scope modification detected. V heavily discourages global state and has strict mutability rules for closures. Please refactor state management, possibly by passing mutable parameters (mut) explicitly.
        // nonlocal total
        total -= x
    }
// @line: test_global_nonlocal.py:24:4
    mut get_total := fn [total] () int {
        return total
    }
    add(50)
    println('${get_total()}')
    subtract(30)
    println('${get_total()}')
}
// @line: test_global_nonlocal.py:32:0
pub fn test_nested_function() {
// @line: test_global_nonlocal.py:33:4
    mut outer := fn (x int) Any {
// @line: test_global_nonlocal.py:34:8
        mut inner := fn [x] (y int) int {
            return x + y
        }
        return inner
    }
    add_5 := outer(5)
    println('${add_5(10)}')
    add_10 := outer(10)
    println('${add_10(20)}')
}
// @line: test_global_nonlocal.py:44:0
pub fn test_closure_with_state() {
// @line: test_global_nonlocal.py:45:4
    mut make_accumulator := fn () Any {
        mut total := 0
// @line: test_global_nonlocal.py:48:8
        mut accumulate := fn (value int) int {
            //##LLM@@ Python 'global' or 'nonlocal' scope modification detected. V heavily discourages global state and has strict mutability rules for closures. Please refactor state management, possibly by passing mutable parameters (mut) explicitly.
            // nonlocal total
            total += value
            return total
        }
        return accumulate
    }
    acc := make_accumulator()
    println('${acc(5)}')
    println('${acc(10)}')
    println('${acc(15)}')
}
// @line: test_global_nonlocal.py:60:0
pub fn test_closure_in_loop() {
    mut funcs := []Any{}
    for i in 0..5 {
// @line: test_global_nonlocal.py:63:8
        mut func := fn [i] (x Any) Any {
            return x
        }
        (funcs as string).append(func)
    }
    for f in funcs {
        println('${f()}')
    }
}
// @line: test_global_nonlocal.py:70:0
pub fn test_closure_proper_capture() {
    mut funcs := []fn (...Any) Any{}
    for i in 0..5 {
// @line: test_global_nonlocal.py:73:8
        mut func := fn [i] () Any {
            nonlocal_i := i
            return nonlocal_i
        }
        funcs << func
    }
    println('Closure in loop (all return last value):')
}
// @line: test_global_nonlocal.py:84:0
pub fn test_multiple_closures() {
// @line: test_global_nonlocal.py:85:4
    mut make_counters := fn () Any {
        mut count_a := 0
        mut count_b := 0
// @line: test_global_nonlocal.py:89:8
        mut increment_a := fn () int {
            //##LLM@@ Python 'global' or 'nonlocal' scope modification detected. V heavily discourages global state and has strict mutability rules for closures. Please refactor state management, possibly by passing mutable parameters (mut) explicitly.
            // nonlocal count_a
            count_a += 1
            return count_a
        }
// @line: test_global_nonlocal.py:94:8
        mut increment_b := fn () int {
            //##LLM@@ Python 'global' or 'nonlocal' scope modification detected. V heavily discourages global state and has strict mutability rules for closures. Please refactor state management, possibly by passing mutable parameters (mut) explicitly.
            // nonlocal count_b
            count_b += 1
            return count_b
        }
// @line: test_global_nonlocal.py:99:8
        mut get_counts := fn [count_a, count_b] () Any {
            return [count_a, count_b]
        }
        return [increment_a, increment_b, get_counts]
    }
    py_destruct_0 := make_counters()
    inc_a := py_destruct_0[0]
    inc_b := py_destruct_0[1]
    get := py_destruct_0[2]
    println('${inc_a()}')
    println('${inc_a()}')
    println('${inc_b()}')
    println('${inc_a()}')
    println('${get()}')
}
// @line: test_global_nonlocal.py:111:0
pub fn test_closure_with_list() {
// @line: test_global_nonlocal.py:112:4
    mut make_history := fn () Any {
        mut history := []Any{}
// @line: test_global_nonlocal.py:115:8
        mut add := fn [history] (item Any) []Any {
            //##LLM@@ Python 'global' or 'nonlocal' scope modification detected. V heavily discourages global state and has strict mutability rules for closures. Please refactor state management, possibly by passing mutable parameters (mut) explicitly.
            // nonlocal history
            history << item
            return history
        }
// @line: test_global_nonlocal.py:120:8
        mut get_history := fn [history] () Any {
            return history.copy()
        }
        return [add, get_history]
    }
    py_destruct_1 := make_history()
    add := py_destruct_1[0]
    get := py_destruct_1[1]
    add(1)
    add(2)
    add(3)
    println('${get()}')
}
// @line: test_global_nonlocal.py:131:0
pub fn test() {
    test_global_variable()
    test_global_in_multiple_functions()
    test_nested_function()
    test_closure_with_state()
    test_closure_in_loop()
    test_multiple_closures()
    test_closure_with_list()
}

fn main() {
    // @line: test_global_nonlocal.py:140:0
    // if __name__ == '__main__':
    test()
}