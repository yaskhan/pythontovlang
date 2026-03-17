module main

// @line: test_function_defs.py:1:0
pub fn test_function_basic() {
// @line: test_function_defs.py:2:4
    mut greet := fn () {
        println('Hello!')
    }
    greet()
}
// @line: test_function_defs.py:7:0
pub fn test_function_with_params() {
// @line: test_function_defs.py:8:4
    mut greet := fn (name string, age int) {
        println('Name: ${name}, Age: ${age}')
    }
    greet('Alice', 30)
}
// @line: test_function_defs.py:13:0
pub fn test_function_default_params() {
// @line: test_function_defs.py:14:4
    mut greet := fn (name string, greeting string) {
        println('${greeting}, ${name}!')
    }
    greet('Alice', 'Hello')
    greet('Bob', 'Hi')
}
// @line: test_function_defs.py:20:0
pub fn test_function_keyword_args() {
// @line: test_function_defs.py:21:4
    mut describe := fn (name string, age int, city string) {
        println('${name}, ${age}, ${city}')
    }
    describe('Alice', 30, 'NYC')
    describe('Bob', 25, 'LA')
}
// @line: test_function_defs.py:27:0
pub fn test_function_mixed_args() {
// @line: test_function_defs.py:28:4
    mut func := fn (a int, b int, c Any, d Any) {
        println('a=${a}, b=${b}, c=${c}, d=${d}')
    }
    func(1, 2, 10, 20)
    func(1, 2, 10, 30)
}
// @line: test_function_defs.py:34:0
pub fn test_function_varargs() {
// @line: test_function_defs.py:35:4
    mut sum_all := fn (args ...int) Any {
        mut total := 0
        for arg in args {
            total += arg
        }
        return total
    }
    println('${sum_all(1, 2, 3)}')
    println('${sum_all(1, 2, 3, 4, 5)}')
}
// @line: test_function_defs.py:44:0
pub fn test_function_kwargs() {
// @line: test_function_defs.py:45:4
    mut print_kwargs := fn (kwargs map[string]string) {
        for key, value in kwargs {
            println('${key}=${value}')
        }
    }
    print_kwargs({'name': 'Alice', 'age': 30, 'city': 'NYC'})
}
// @line: test_function_defs.py:51:0
pub fn test_function_args_kwargs() {
//##LLM@@ Function `func` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
// @line: test_function_defs.py:52:4
    mut func := fn (a int, args ...int, kwargs map[string]string) {
        println('a=${a}')
        println('args=${args}')
        println('kwargs=${kwargs}')
    }
    func(1, 2, 3, 4, {'name': 'test', 'value': 42})
}
// @line: test_function_defs.py:59:0
pub fn test_function_return() {
// @line: test_function_defs.py:60:4
    mut add := fn (a int, b int) int {
        return a + b
    }
    mut result := add(3, 4)
    println('Result: ${result}')
}
// @line: test_function_defs.py:66:0
pub fn test_function_multiple_returns() {
// @line: test_function_defs.py:67:4
    mut min_max := fn (nums Any) Any {
        return [min(nums), max(nums)]
    }
    mut result := min_max([3, 1, 4, 1, 5, 9])
    println('Min and max: ${result}')
    py_destruct_0 := min_max([3, 1, 4, 1, 5, 9])
    min_val := py_destruct_0[0]
    max_val := py_destruct_0[1]
    println('min=${min_val}, max=${max_val}')
}
// @line: test_function_defs.py:76:0
pub fn test_function_no_return() {
// @line: test_function_defs.py:77:4
    mut no_return := fn () {
    }
    mut result := no_return()
    println('Result: ${result}')
}
// @line: test_function_defs.py:83:0
pub fn test_function_nested() {
// @line: test_function_defs.py:84:4
    mut outer := fn (x int) Any {
// @line: test_function_defs.py:85:8
        mut inner := fn [x] (y int) int {
            return x + y
        }
        return inner
    }
    add_5 := outer(5)
    println('${add_5(10)}')
}
// @line: test_function_defs.py:92:0
pub fn test_function_recursive() {
// @line: test_function_defs.py:93:4
    mut factorial := fn (n int) int {
        if n <= 1 {
            return 1
        }
        return n * factorial(n - 1)
    }
    println('5! = ${factorial(5)}')
}
// @line: test_function_defs.py:100:0
pub fn test_function_recursive_fibonacci() {
// @line: test_function_defs.py:101:4
    mut fibonacci := fn (n int) int {
        if n <= 1 {
            return n
        }
        return fibonacci(n - 1) + fibonacci(n - 2)
    }
    for i in 0..10 {
        print('fib(${i})=${fibonacci(i)} ')
    }
    println('')
}
// @line: test_function_defs.py:110:0
pub fn test() {
    test_function_basic()
    test_function_with_params()
    test_function_default_params()
    test_function_keyword_args()
    test_function_mixed_args()
    test_function_varargs()
    test_function_kwargs()
    test_function_args_kwargs()
    test_function_return()
    test_function_multiple_returns()
    test_function_no_return()
    test_function_nested()
    test_function_recursive()
    test_function_recursive_fibonacci()
}

fn main() {
    // @line: test_function_defs.py:126:0
    // if __name__ == '__main__':
    test()
}