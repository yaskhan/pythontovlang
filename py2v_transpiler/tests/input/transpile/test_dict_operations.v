module main

// @line: test_dict_operations.py:1:0
pub fn test_dict_creation() {
    mut d1 := {'a': 1, 'b': 2}
    println('${d1}')
    mut d2 := map[string]int{}
    println('${d2}')
    d3 := map[string]Any([['x', 10], ['y', 20]])
    println('${d3}')
}
// @line: test_dict_operations.py:14:0
pub fn test_dict_access() {
    mut d := {'name': Any('Alice'), 'age': Any(30), 'city': Any('NYC')}
    println('${d['name']}')
    println('${d['age'] or { 0 }}')
    println('${d['country'] or { 'USA' }}')
}
// @line: test_dict_operations.py:20:0
pub fn test_dict_modification() {
    mut d := {'a': 1}
    d['b'] = 2
    d['a'] = 10
    println('${d}')
}
// @line: test_dict_operations.py:26:0
pub fn test_dict_deletion() {
    mut d := {'a': 1, 'b': 2, 'c': 3}
    mut val := d.pop('b')
    println('Popped: ${val}, Dict: ${d}')
    d.delete('a')
    println('After del: ${d}')
    /* d.clear() */ d = {}
    println('Cleared: ${d}')
}
// @line: test_dict_operations.py:37:0
pub fn test_dict_keys_values_items() {
    mut d := {'x': 1, 'y': 2, 'z': 3}
    println('Keys: ${[]Any(d.keys())}')
    println('Values: ${[]Any(d.values())}')
    println('Items: ${[]Any(d.items())}')
    for key in d {
        println('Key: ${key}')
    }
    for key, value in d {
        println('${key}: ${value}')
    }
}
// @line: test_dict_operations.py:51:0
pub fn test_dict_update() {
    mut d1 := {'a': 1, 'b': 2}
    mut d2 := {'b': 20, 'c': 3}
    d1.update(d2)
    println('Updated: ${d1}')
    d1.update()
    println('Updated with kwargs: ${d1}')
}
// @line: test_dict_operations.py:60:0
pub fn test_dict_comprehension() {
    mut squares := map[int]int{}
    for x in 0..5 {
        squares[x] = x * x
    }
    println('${squares}')
    mut even_squares := map[int]int{}
    for x in 0..10 {
        if x % 2 == 0 {
            even_squares[x] = x * x
        }
    }
    println('${even_squares}')
}
// @line: test_dict_operations.py:68:0
pub fn test_dict_fromkeys() {
    keys := ['a', 'b', 'c']
    mut d := dict.fromkeys(keys, 0).clone()
    println('From keys: ${d}')
    mut d2 := dict.fromkeys(keys, []Any{}).clone()
    println('From keys with list: ${d2}')
}
// @line: test_dict_operations.py:76:0
pub fn test_dict_setdefault() {
    mut d := {'a': 1}
    mut val := d.setdefault('b', 2)
    println('Setdefault result: ${val}, Dict: ${d}')
    val2 := d.setdefault('a', 100)
    println('Setdefault existing: ${val2}, Dict: ${d}')
}
// @line: test_dict_operations.py:84:0
pub fn test_dict_membership() {
    mut d := {'x': 1, 'y': 2}
    println('${'x' in d}')
    println('${'z' !in d}')
}
// @line: test_dict_operations.py:89:0
pub fn test() {
    test_dict_creation()
    test_dict_access()
    test_dict_modification()
    test_dict_deletion()
    test_dict_keys_values_items()
    test_dict_update()
    test_dict_comprehension()
    test_dict_fromkeys()
    test_dict_setdefault()
    test_dict_membership()
}

fn main() {
    // @line: test_dict_operations.py:101:0
    // if __name__ == '__main__':
    test()
}