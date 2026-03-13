module main

// @line: test_none_type.py:1:0
pub fn test_none_check() {
    mut value := Any(NoneType{})
    println('value is None: ${value is NoneType}')
    println('value is not None: ${value !is NoneType}')
    value = 42
    println('42 is None: ${value is NoneType}')
}
// @line: test_none_type.py:9:0
pub fn test_none_default() {
// @line: test_none_type.py:10:4
    mut greet := fn (name Any) string {
        if name is NoneType {
            return 'Hello, guest!'
        }
        return 'Hello, ${name}!'
    }
    println('${greet()}')
    println('${greet('Alice')}')
}
// @line: test_none_type.py:18:0
pub fn test_none_in_list() {
    lst := [?Any(1), none, ?Any(3), none, ?Any(5)]
    println('None count: ${lst.filter(it == none).len}')
    println('None in list: ${lst.any(it == none)}')
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
    mut x := Any(NoneType{})
    mut y := 10
    println('x = ${x}')
    x = y
    println('After x = y, x = ${x}')
    y = Any(NoneType{})
    println('After y = None, y = ${y}, x = ${x}')
}
// @line: test_none_type.py:41:0
pub fn test_none_in_dict() {
    d := {'a': Any(1), 'b': Any(NoneType{}), 'c': Any(3)}
    println('Dict with None value: ${d}')
    println('d[\'b\'] is None: ${d["b"] is NoneType}')
    println('d.get(\'d\'): ${d["d"] or { Any(NoneType{}) }}')
    println('d.get(\'d\') is None: ${d["d"] or { Any(NoneType{}) } is NoneType}')
}
// @line: test_none_type.py:50:0
pub fn test_none_filter() {
    data := [?Any(1), none, ?Any(2), none, ?Any(3)]
    mut filtered := []Any{}
    for x in data {
        if x !is NoneType {
            filtered << x
        }
    }
    println('Filtered: ${filtered}')
}
// @line: test_none_type.py:55:0
pub fn test_none_or() {
    mut value := Any(NoneType{})
    mut result := if py_bool(value) { value } else { Any('default') }
    println('None or \'default\': ${result}')
    value = 'actual'
    result = if py_bool(value) { value } else { Any('default') }
    println('\'actual\' or \'default\': ${result}')
}
// @line: test_none_type.py:65:0
pub fn test_none_ternary() {
// @line: test_none_type.py:66:4
    mut get_value := fn (mut x Any) Any {
        return if x is NoneType { 'No value' } else { 'Value: ${x}' }
    }
    println('${get_value()}')
    println('${get_value(42)}')
}
// @line: test_none_type.py:72:0
pub fn test_none_comparison() {
    println('None == None: ${true}')
    println('None is None: ${true}')
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