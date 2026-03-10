module main

//##LLM@@ Please review this generated sum type. If a semantically identical sum type already exists, replace this definition and its usages with the existing one, and give it a more meaningful name.
type SumType_IntString = int | string

// @line: test_type_annotations.py:3:0
pub fn basic_types(x int, y f64, name string, active bool) int {
    mut result := x + int(y)
    println('Name: ${name}, Active: ${active}')
    return result
}
// @line: test_type_annotations.py:8:0
pub fn optional_type(value ?int) string {
    if value == none {
        return 'No value'
    }
    return 'Value is ${value}'
}
// @line: test_type_annotations.py:13:0
pub fn union_type(x SumType_IntString) string {
    if x is int {
        narrowed_x := int(x)
        return 'Number: ${narrowed_x}'
    }
    return 'String: ${x}'
}
// @line: test_type_annotations.py:18:0
pub fn any_type(data Any) Any {
    return data
}
// @line: test_type_annotations.py:21:0
pub fn list_operations(nums []int) []int {
    mut result := []int{}
    for n in nums {
        result << n * 2
    }
    return result
}
// @line: test_type_annotations.py:27:0
pub fn dict_operations(data map[string]int) map[string]int {
    mut result := map[string]int{}
    for key, value in data {
        result[key] = value * 2
    }
    return result
}
// @line: test_type_annotations.py:33:0
pub fn tuple_unpack(coords [2]int) int {
    py_destruct_0 := coords
    x := py_destruct_0[0]
    y := py_destruct_0[1]
    return x + y
}
// @line: test_type_annotations.py:37:0
pub fn nested_types(matrix [][]int) []int {
    mut flat := []int{}
    for row in matrix {
        for val in row {
            flat << val
        }
    }
    return flat
}
// @line: test_type_annotations.py:44:0
pub fn complex_dict(data map[string][]int) []int {
    mut result := []int{}
    for key, values in data {
        result << ...values
    }
    return result
}
// @line: test_type_annotations.py:50:0
pub fn return_none(x int) {
    if x > 0 {
        println('Positive: ${x}')
    } else {
        println('Non-positive: ${x}')
    }
}
// @line: test_type_annotations.py:56:0
pub fn function_type(f fn, x int) int {
    return f(x)
}
// @line: test_type_annotations.py:59:0
pub fn apply_function(f fn, values []int) []int {
    mut result := []int{}
    for v in values {
        result << f(v)
    }
    return result
}
// @line: test_type_annotations.py:65:0
pub fn run_test() {
    println('${basic_types(5, 3.14, 'Alice', true)}')
    println('${optional_type(none)}')
    println('${optional_type(42)}')
    println('${union_type(10)}')
    println('${union_type('hello')}')
    println('${any_type(123)}')
    println('${any_type('anything')}')
    println('${list_operations([1, 2, 3, 4])}')
    println('${dict_operations({'a': 1, 'b': 2})}')
    println('${tuple_unpack([2]int{3, 4})}')
    println('${nested_types([[1, 2], [3, 4], [5, 6]])}')
    println('${complex_dict({'nums1': [1, 2], 'nums2': [3, 4]})}')
    return_none(10)
    return_none(-5)
// @line: test_type_annotations.py:81:4
    mut square := fn (x int) int {
        return x * x
    }
    println('${apply_function(square, [1, 2, 3, 4, 5])}')
}

fn main() {
    // @line: test_type_annotations.py:86:0
    // if __name__ == '__main__':
    run_test()
}