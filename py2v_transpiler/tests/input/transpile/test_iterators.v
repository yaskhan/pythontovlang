module main

// @line: test_iterators.py:14:4
pub struct Counter {
    current int
    end int
}

pub const Counter_new_counter__annotations__ = { 'start': 'int', 'end': 'int' }
pub const Counter_next__annotations__ = { 'return': 'int' }

// @line: test_iterators.py:1:0
pub fn test_iter_next() {
    lst := [10, 20, 30, 40]
    mut it := py_iter(lst)
    println('${(it.next() or { panic('StopIteration') })}')
    println('${(it.next() or { panic('StopIteration') })}')
    println('${(it.next() or { panic('StopIteration') })}')
    println('${(it.next() or { panic('StopIteration') })}')
    println('${(it.next() or { 'Exhausted' })}')
}
// @line: test_iterators.py:15:8
pub fn new_counter(start int, end int) Counter {
    mut self := Counter{}
    self.current = start
    self.end = end
    return self
}
// @line: test_iterators.py:19:8
pub fn (self Counter) iter() Counter {
    return self
}
// @line: test_iterators.py:22:8
pub fn (self Counter) next() ?int {
    if self.current >= self.end {
        return none
    }
    result := self.current
    self.current += 1
    return result
}
// @line: test_iterators.py:13:0
pub fn test_custom_iterator() {
    counter := new_counter(0, 5)
    for num in counter {
        println('${num}')
    }
}
// @line: test_iterators.py:33:0
pub fn test_iterator_consumption() {
    mut data := []int{cap: 5}
    data << 1
    data << 2
    data << 3
    data << 4
    data << 5
    mut it := py_iter(data)
    remaining := py_list_from_iter<[]Any>(it)
    println('Remaining: ${remaining}')
}
// @line: test_iterators.py:41:0
pub fn test_zip_iterator() {
    names := ['Alice', 'Bob', 'Charlie']
    ages := [25, 30, 35]
    py_zip_it1_1 := names
    py_zip_it2_1 := ages
    for py_i_1, py_v1_1 in py_zip_it1_1 {
        if py_i_1 >= py_zip_it2_1.len { break }
        py_v2_1 := py_zip_it2_1[py_i_1]
        name := py_v1_1
        age := py_v2_1
        println('${name} is ${age} years old')
    }
    scores := [100, 90]
    for py_val_140469766582672 in py_zip(names, ages, scores) {
        name := py_val_140469766582672[0]
        age := py_val_140469766582672[1]
        score := py_val_140469766582672[2]
        println('${name}: ${age} years, ${score} points')
    }
}
// @line: test_iterators.py:53:0
pub fn test_enumerate_iterator() {
    items := ['apple', 'banana', 'cherry']
    for index, item in items {
        println('${index}: ${item}')
    }
    for index, item in items {
        println('${index}: ${item}')
    }
}
// @line: test_iterators.py:63:0
pub fn test_reversed_iterator() {
    mut data := []int{cap: 5}
    data << 1
    data << 2
    data << 3
    data << 4
    data << 5
    for item in py_reversed(data) {
        println('${item}')
    }
    text := 'hello'
    for char in py_reversed(text) {
        print('${char}')
    }
    println('')
}
// @line: test_iterators.py:75:0
pub fn test_sorted_iterator() {
    mut data := []int{cap: 8}
    data << 3
    data << 1
    data << 4
    data << 1
    data << 5
    data << 9
    data << 2
    data << 6
    for item in py_sorted(data) {
        print('${item} ')
    }
    println('')
    for item in py_sorted(data) {
        print('${item} ')
    }
    println('')
    words := ['banana', 'pie', 'Washington', 'book']
    for word in py_sorted(words) {
        print('${word} ')
    }
    println('')
}
// @line: test_iterators.py:93:0
pub fn test_filter_iterator() {
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
    for n in nums.filter(fn (x int) bool { return x % 2 == 0 }) {
        print('${n} ')
    }
    println('')
}
// @line: test_iterators.py:100:0
pub fn test_map_iterator() {
    mut nums := []int{cap: 5}
    nums << 1
    nums << 2
    nums << 3
    nums << 4
    nums << 5
    for n in nums.map(fn (x int) int { return x * x }) {
        print('${n} ')
    }
    println('')
}
// @line: test_iterators.py:107:0
pub fn test() {
    test_iter_next()
    test_custom_iterator()
    test_iterator_consumption()
    test_zip_iterator()
    test_enumerate_iterator()
    test_reversed_iterator()
    test_sorted_iterator()
    test_filter_iterator()
    test_map_iterator()
}

fn main() {
    // @line: test_iterators.py:118:0
    // if __name__ == '__main__':
    test()
}