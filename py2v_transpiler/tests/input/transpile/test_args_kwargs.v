module main

// @line: test_args_kwargs.py:1:0
pub fn test_function_args() {
// @line: test_args_kwargs.py:2:4
    mut print_args := fn (args ...[]int) {
        for arg in args {
            println('arg=${arg}')
        }
    }
    print_args(1, 2, 3)
    print_args('a', 'b', 'c')
}
// @line: test_args_kwargs.py:9:0
pub fn test_function_kwargs() {
// @line: test_args_kwargs.py:10:4
    mut print_kwargs := fn (kwargs map[string]int) {
        for key, value in kwargs {
            println('${key}=${value}')
        }
    }
    print_kwargs({'a': 1, 'b': 2, 'c': 3})
    print_kwargs({'name': 'Alice', 'age': 30})
}
// @line: test_args_kwargs.py:17:0
pub fn test_function_args_kwargs() {
//##LLM@@ Function `func` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
// @line: test_args_kwargs.py:18:4
    mut func := fn (args ...[]int, kwargs map[string]int) {
        println('args=${args}')
        println('kwargs=${kwargs}')
    }
    func(1, 2, 3, {'name': 'test', 'value': 42})
}
// @line: test_args_kwargs.py:24:0
pub fn test_function_positional_only() {
// @line: test_args_kwargs.py:25:4
    mut func := fn (a Any, b Any, c Any, d Any) {
        println('a=${a}, b=${b}, c=${c}, d=${d}')
    }
    func(1, 2)
    func(1, 2, 3, 4)
}
// @line: test_args_kwargs.py:31:0
pub fn test_function_keyword_only() {
// @line: test_args_kwargs.py:32:4
    mut func := fn (a Any, b Any, c Any) {
        println('a=${a}, b=${b}, c=${c}')
    }
    func(1, 2, 3)
}
// @line: test_args_kwargs.py:37:0
pub fn test_function_mixed_params() {
// @line: test_args_kwargs.py:38:4
    mut func := fn (a Any, b Any, c Any, d Any, e Any, f int) {
        println('a=${a}, b=${b}, c=${c}, d=${d}, e=${e}, f=${f}')
    }
    func(1, 2, 3, 6)
}
// @line: test_args_kwargs.py:43:0
pub fn test_args_unpacking() {
// @line: test_args_kwargs.py:44:4
    mut func := fn (a Any, b Any, c Any) {
        println('a=${a}, b=${b}, c=${c}')
    }
    mut args := []int{cap: 3}
    args << 1
    args << 2
    args << 3
    func(...args)
}
// @line: test_args_kwargs.py:50:0
pub fn test_kwargs_unpacking() {
// @line: test_args_kwargs.py:51:4
    mut func := fn (a Any, b Any, c Any) {
        println('a=${a}, b=${b}, c=${c}')
    }
    mut kwargs := {'a': 1, 'b': 2, 'c': 3}
    func(kwargs)
}
// @line: test_args_kwargs.py:57:0
pub fn test_args_kwargs_unpacking() {
// @line: test_args_kwargs.py:58:4
    mut func := fn (a Any, b Any, c Any, d Any, e Any) {
        println('a=${a}, b=${b}, c=${c}, d=${d}, e=${e}')
    }
    mut args := []int{cap: 2}
    args << 1
    args << 2
    mut kwargs := {'c': 3, 'd': 4, 'e': 5}
    func(...args, kwargs)
}
// @line: test_args_kwargs.py:65:0
pub fn test_args_tuple() {
// @line: test_args_kwargs.py:66:4
    mut func := fn (args ...[]int) {
        println('args type: ${typeof(args).name}')
        println('args[0]: ${args[0]}')
        println('args[-1]: ${args[args.len - 1]}')
        for arg in args {
            println('  ${arg}')
        }
    }
    func(1, 2, 3, 4, 5)
}
// @line: test_args_kwargs.py:75:0
pub fn test_kwargs_dict() {
// @line: test_args_kwargs.py:76:4
    mut func := fn (kwargs map[string]int) {
        println('kwargs type: ${typeof(kwargs).name}')
        println('kwargs keys: ${[]Any(kwargs.keys())}')
        for key, value in kwargs {
            println('  ${key}=${value}')
        }
    }
    func({'a': 1, 'b': 2, 'c': 3})
}
// @line: test_args_kwargs.py:84:0
pub fn test_args_default_with_args() {
// @line: test_args_kwargs.py:85:4
    mut func := fn (a Any, b Any, args ...[]int) {
        println('a=${a}, b=${b}, args=${args}')
    }
    func(1, 10)
    func(1, 2)
    func(1, 2, 3, 4, 5)
}
// @line: test_args_kwargs.py:92:0
pub fn test_args_default_with_kwargs() {
// @line: test_args_kwargs.py:93:4
    mut func := fn (a Any, b Any, kwargs map[string]int) {
        println('a=${a}, b=${b}, kwargs=${kwargs}')
    }
    func(1, 10, {})
    func(1, 2, {})
    func(1, 2, {'c': 3, 'd': 4})
}
// @line: test_args_kwargs.py:100:0
pub fn test() {
    test_function_args()
    test_function_kwargs()
    test_function_args_kwargs()
    test_function_positional_only()
    test_function_keyword_only()
    test_function_mixed_params()
    test_args_unpacking()
    test_kwargs_unpacking()
    test_args_kwargs_unpacking()
    test_args_tuple()
    test_kwargs_dict()
    test_args_default_with_args()
    test_args_default_with_kwargs()
}

fn main() {
    // @line: test_args_kwargs.py:115:0
    // if __name__ == '__main__':
    test()
}