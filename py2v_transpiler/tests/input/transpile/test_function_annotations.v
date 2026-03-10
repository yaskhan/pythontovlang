module main

//##LLM@@ Please review this generated sum type. If a semantically identical sum type already exists, replace this definition and its usages with the existing one, and give it a more meaningful name.
type SumType_IntString = int | string

// @line: test_function_annotations.py:1:0
pub fn test_function_annotations() {
// @line: test_function_annotations.py:2:4
    mut greet := fn (name string, age int) string {
        return '${name} is ${age} years old'
    }
    println('${greet('Alice', 30)}')
}
// @line: test_function_annotations.py:7:0
pub fn test_function_annotations_types() {
// @line: test_function_annotations.py:8:4
    mut process := fn (nums []int, data map[string]int, point [2]int) []int {
        return nums
    }
    println('${process([1, 2, 3], {'a': 1}, [0, 0])}')
}
// @line: test_function_annotations.py:17:0
pub fn test_function_annotations_optional() {
// @line: test_function_annotations.py:20:4
    mut greet := fn (name ?string) string {
        if name == none {
            return 'Hello, guest!'
        }
        return 'Hello, ${name}!'
    }
    println('${greet(none)}')
    println('${greet('Alice')}')
}
// @line: test_function_annotations.py:28:0
pub fn test_function_annotations_union() {
// @line: test_function_annotations.py:31:4
    mut process := fn (value SumType_IntString) string {
        if value is int {
            narrowed_value := int(value)
            return 'Number: ${narrowed_value}'
        }
        return 'String: ${value}'
    }
    println('${process(42)}')
    println('${process('hello')}')
}
// @line: test_function_annotations.py:39:0
pub fn test_function_annotations_any() {
// @line: test_function_annotations.py:42:4
    mut identity := fn (x Any) Any {
        return x
    }
    println('${identity(42)}')
    println('${identity('hello')}')
    println('${identity([1, 2, 3])}')
}
// @line: test_function_annotations.py:49:0
pub fn test_function_annotations_callable() {
// @line: test_function_annotations.py:52:4
    mut apply := fn (func fn (int) int, value int) int {
        return func(value)
    }
// @line: test_function_annotations.py:55:4
    mut double := fn (x int) int {
        return x * 2
    }
    println('${apply(double, 10)}')
}
// @line: test_function_annotations.py:60:0
pub fn test_function_annotations_list() {
// @line: test_function_annotations.py:63:4
    mut process := fn (nums []int) []int {
        mut py_comp_1 := []int{}
        for x in nums {
            py_comp_1 << x * 2
        }
        return py_comp_1
    }
    println('${process([1, 2, 3, 4, 5])}')
}
// @line: test_function_annotations.py:68:0
pub fn test_function_annotations_dict() {
// @line: test_function_annotations.py:71:4
    mut process := fn (data map[string]int) map[string]int {
        mut py_comp_2 := map[int]int{}
        for [k, v] in data.items() {
            py_comp_2[k] = v * 2
        }
        return py_comp_2
    }
    println('${process({'a': 1, 'b': 2})}')
}
// @line: test_function_annotations.py:76:0
pub fn test_function_annotations_tuple() {
// @line: test_function_annotations.py:79:4
    mut process := fn (point [2]int) int {
        py_destruct_0 := point
        x := py_destruct_0[0]
        y := py_destruct_0[1]
        return x + y
    }
    println('${process([3, 4])}')
}
// @line: test_function_annotations.py:85:0
pub fn test_function_annotations_nested() {
// @line: test_function_annotations.py:88:4
    mut process := fn (data map[string][]int) []int {
        mut result := []Any{}
        for values in data.values() {
            result << ...values
        }
        return result
    }
    println('${process({'a': [1, 2], 'b': [3, 4]})}')
}
// @line: test_function_annotations.py:96:0
pub fn test_function_annotations_default() {
// @line: test_function_annotations.py:97:4
    mut greet := fn (name string) string {
        return 'Hello, ${name}!'
    }
    println('${greet()}')
    println('${greet('Alice')}')
}
// @line: test_function_annotations.py:103:0
pub fn test_function_annotations_mixed() {
// @line: test_function_annotations.py:106:4
    mut process := fn (name string, nums ?[]int, multiplier int) []int {
        if nums == none {
            nums = []Any{}
        }
        mut py_comp_3 := []int{}
        for x in nums {
            py_comp_3 << x * multiplier
        }
        return py_comp_3
    }
    println('${process('test')}')
    println('${process('test', [1, 2, 3], 2)}')
}
// @line: test_function_annotations.py:118:0
pub fn test() {
    test_function_annotations()
    test_function_annotations_types()
    test_function_annotations_optional()
    test_function_annotations_union()
    test_function_annotations_any()
    test_function_annotations_callable()
    test_function_annotations_list()
    test_function_annotations_dict()
    test_function_annotations_tuple()
    test_function_annotations_nested()
    test_function_annotations_default()
    test_function_annotations_mixed()
}

fn main() {
    // @line: test_function_annotations.py:132:0
    // if __name__ == '__main__':
    test()
}