module main

// @line: test_comprehensions.py:1:0
pub fn test_list_comprehension() {
    mut squares := []int{cap: 10}
    for x in 0..10 {
        squares << x * x
    }
    println('${squares}')
    mut evens := []int{}
    for x in 0..20 {
        if x % 2 == 0 {
            evens << x
        }
    }
    println('${evens}')
    mut matrix := []int{cap: 3}
    for i in 0..3 {
        mut py_comp_1 := []int{cap: 3}
        for j in 0..3 {
            py_comp_1 << i * j
        }
        matrix << py_comp_1
    }
    println('${matrix}')
}
// @line: test_comprehensions.py:14:0
pub fn test_dict_comprehension() {
    mut square_map := map[int]int{}
    for x in 0..5 {
        square_map[x] = x * x
    }
    println('${square_map}')
    mut even_map := map[int]int{}
    for x in 0..10 {
        if x % 2 == 0 {
            even_map[x] = x * 2
        }
    }
    println('${even_map}')
}
// @line: test_comprehensions.py:23:0
pub fn test_set_comprehension() {
    mut unique_squares := map[int]bool{}
    for x in -3..4 {
        unique_squares[x * x] = true
    }
    println('${unique_squares}')
}
// @line: test_comprehensions.py:28:0
pub fn test_generator_expression() {
    mut gen := []int{cap: 5}
    for x in 0..5 {
        gen << x * x
    }
    for val in gen {
        println('${val}')
    }
    mut filtered_gen := []int{}
    for x in 0..10 {
        if x > 5 {
            filtered_gen << x
        }
    }
    for val in filtered_gen {
        println('${val}')
    }
}
// @line: test_comprehensions.py:39:0
pub fn test_nested_loops_in_comprehension() {
    //##LLM@@ Complex nested comprehension detected. To ensure readability and idiomatic V, please unfold this into explicit 'for' loops or a clean chain of .map() and .filter() calls.
    mut pairs := [][]int{cap: 3}
    for x in 0..3 {
        for y in 0..3 {
            pairs << [x, y]
        }
    }
    println('${pairs}')
    //##LLM@@ Complex nested comprehension detected. To ensure readability and idiomatic V, please unfold this into explicit 'for' loops or a clean chain of .map() and .filter() calls.
    mut filtered_pairs := [][]int{cap: 5}
    for x in 0..5 {
        for y in 0..5 {
            if x + y < 5 {
                filtered_pairs << [x, y]
            }
        }
    }
    println('${filtered_pairs}')
}
// @line: test_comprehensions.py:48:0
pub fn test() {
    test_list_comprehension()
    test_dict_comprehension()
    test_set_comprehension()
    test_generator_expression()
    test_nested_loops_in_comprehension()
}

fn main() {
    // @line: test_comprehensions.py:55:0
    // if __name__ == '__main__':
    test()
}