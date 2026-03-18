module main

import math

// @line: test_lambda_functions.py:1:0
pub fn test_lambda_basic() {
    add := fn (x int, y int) int { return x + y }
    println('${add(5, 3)}')
    multiply := fn (x int, y int) int { return x * y }
    println('${multiply(4, 7)}')
}
// @line: test_lambda_functions.py:8:0
pub fn test_lambda_with_default() {
    power := fn (x int, n int) int { return math.powi(x, n) }
    println('${power(5)}')
    println('${power(5, 3)}')
}
// @line: test_lambda_functions.py:13:0
pub fn test_lambda_in_sort() {
    pairs := [[1, 3], [4, 1], [2, 2], [3, 0]]
    sorted_pairs := py_sorted(pairs)
    println('${sorted_pairs}')
    sorted_desc := py_sorted(pairs)
    println('${sorted_desc}')
}
// @line: test_lambda_functions.py:22:0
pub fn test_lambda_filter_map() {
    mut nums := []int{cap: 10}
    nums << 1
    nums << 2
    nums << 3
    nums << 4
    nums << 5
    nums << 6
    nums << 7
    nums << 8
    nums << 9
    nums << 10
    evens := []Any(nums.filter(fn (x int) bool { return x % 2 == 0 }(it)))
    println('${evens}')
    squares := []Any(nums.map(fn (x int) int { return x * x }(it)))
    println('${squares}')
}
// @line: test_lambda_functions.py:33:0
pub fn test_lambda_reduce() {
    mut nums := []int{cap: 5}
    nums << 1
    nums << 2
    nums << 3
    nums << 4
    nums << 5
    total := py_reduce(fn (x int, y int) int { return x + y }, nums)
    println('Sum: ${total}')
    product := py_reduce(fn (x int, y int) int { return x * y }, nums)
    println('Product: ${product}')
    max_val := py_reduce(fn (x int, y int) int { return if x > y { x } else { y } }, nums)
    println('Max: ${max_val}')
}
// @line: test_lambda_functions.py:46:0
pub fn test_lambda_composition() {
    f := fn (x int) int { return x + 1 }
    g := fn (x int) int { return x * 2 }
    composed := fn [f, g] (x int) Any { return g(f(x)) }
    println('${composed(5)}')
}
// @line: test_lambda_functions.py:54:0
pub fn test_lambda_in_list_comprehension() {
    mut nums := []int{cap: 5}
    nums << 1
    nums << 2
    nums << 3
    nums << 4
    nums << 5
    mut funcs := []int{cap: 5}
    for i in 0..5 {
        funcs << fn (x int, i int) int { return x + i }
    }
    for f in funcs {
        println('${f(10)}')
    }
}
// @line: test_lambda_functions.py:61:0
pub fn test_lambda_with_args() {
    sum_all := fn () Any { return sum(args) }
    println('${sum_all(1, 2, 3, 4, 5)}')
    print_kwargs := fn () Any { return []Any(kwargs.keys()) }
    println('${print_kwargs()}')
}
// @line: test_lambda_functions.py:70:0
pub fn test_nested_lambda() {
    multiplier := fn (n int) int { return fn (x int) int { return x * n } }
    times_2 := multiplier(2)
    times_3 := multiplier(3)
    println('${times_2(5)}')
    println('${times_3(5)}')
}
// @line: test_lambda_functions.py:80:0
pub fn test() {
    test_lambda_basic()
    test_lambda_with_default()
    test_lambda_in_sort()
    test_lambda_filter_map()
    test_lambda_reduce()
    test_lambda_composition()
    test_lambda_in_list_comprehension()
    test_lambda_with_args()
    test_nested_lambda()
}

fn main() {
    // @line: test_lambda_functions.py:91:0
    // if __name__ == '__main__':
    test()
}