module main

// @line: repro_iterators.py:2:4
pub struct Counter {
    current int
    end int
}

pub const Counter_new_counter__annotations__ = { 'start': 'int', 'end': 'int' }
pub const Counter_next__annotations__ = { 'return': 'int' }

// @line: repro_iterators.py:3:8
pub fn new_counter(start int, end int) Counter {
    mut self := Counter{}
    self.current = start
    self.end = end
    return self
}
// @line: repro_iterators.py:7:8
pub fn (self Counter) iter() Counter {
    return self
}
// @line: repro_iterators.py:10:8
pub fn (self Counter) next() ?int {
    if self.current >= self.end {
        return none
    }
    result := self.current
    self.current += 1
    return result
}
// @line: repro_iterators.py:1:0
pub fn test_custom_iterator() {
    counter := new_counter(0, 5)
    for num in counter {
        println('${num}')
    }
}
// @line: repro_iterators.py:21:0
pub fn test_iterator_consumption() {
    data := [1, 2, 3, 4, 5]
    it := py_iter(data)
    remaining := py_list_from_iter<[]Any>(it)
    println('Remaining: ${remaining}')
}
