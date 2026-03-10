module main

// @line: test_none_type.py:1:0
pub fn test_none_check() {
    mut value := (none as ?Any)
    println('value is None: ${value == none}')
    println('value is not None: ${value != none}')
    value = 42
    println('42 is None: ${value == none}')
}
// @line: test_none_type.py:9:0
pub fn test_none_default() {
// @line: test_none_type.py:10:4
    mut greet := fn (name Any) string {
        if name == none {
            return 'Hello, guest!'
        }
        return 'Hello, ${name}!'
    }
    println('${greet()}')
    println('${greet('Alice')}')
}
// @line: test_none_type.py:18:0
pub fn test_none_in_list() {
    lst := [1, none, 3, none, 5]
    println('None count: ${lst.count(none)}')
    println('None in list: ${none in lst}')
}
// @line: test_none_type.py:23:0
pub fn test_none_return() {
// @line: test_none_type.py:24:4
    mut no_return := fn () {
    }
    mut result := no_return()
    println('No return result: ${result}')
    println('Is None: ${result == none}')
}
// @line: test_none_type.py:31:0
pub fn test_none_assignment() {
    mut x := (none as ?Any)
    mut y := 10
    println('x = ${x}')
    x = y
    println('After x = y, x = ${x}')
    y = none
    println('After y = None, y = ${y}, x = ${x}')
}
// @line: test_none_type.py:41:0
pub fn test_none_in_dict() {
    d := map[string]Any{'a': (1 as Any), 'b': (none as Any), 'c': (3 as Any)}
    println('Dict with None value: ${d}')
    println('d[\'b\'] is None: ${d["b"] == none}')
    println('d.get(\'d\'): ${d["d"] or { none }}')
    println('d.get(\'d\') is None: ${d["d"] or { none } == none}')
}
// @line: test_none_type.py:50:0
pub fn test_none_filter() {
    data := [1, none, 2, none, 3]
    mut filtered := []Any{}
    for x in data {
        if x != none {
            filtered << x
        }
    }
    println('Filtered: ${filtered}')
}
// @line: test_none_type.py:55:0
pub fn test_none_or() {
    mut value := (none as ?Any)
    mut result := value || 'default'.len > 0
    println('None or \'default\': ${result}')
    value = 'actual'
    result = value || 'default'.len > 0
    println('\'actual\' or \'default\': ${result}')
}
// @line: test_none_type.py:65:0
pub fn test_none_ternary() {
// @line: test_none_type.py:66:4
    mut get_value := fn (mut x Any) Any {
        return if x == none { 'No value' } else { 'Value: ${x}' }
    }
    println('${get_value()}')
    println('${get_value(42)}')
}
// @line: test_none_type.py:72:0
pub fn test_none_comparison() {
    println('None == None: ${none == none}')
    println('None is None: ${none == none}')
}
// @line: test_none_type.py:80:0
pub fn test() {
    test_none_check()
    test_none_default()
    test_none_in_list()
    test_none_return()
    test_none_assignment()
    test_none_in_dict()
    test_none_filter()
    test_none_or()
    test_none_ternary()
    test_none_comparison()
}

fn main() {
    // @line: test_none_type.py:92:0
    // if __name__ == '__main__':
    test()
}