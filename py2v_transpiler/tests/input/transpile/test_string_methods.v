module main

// @line: test_string_methods.py:1:0
pub fn test_basic_string_methods() {
    mut s := '  Hello, World!  '
    println('${s.strip()}')
    println('${s.lstrip()}')
    println('${s.rstrip()}')
    println('${s.lower()}')
    println('${s.upper()}')
    println('${s.capitalize()}')
    println('${s.title()}')
}
// @line: test_string_methods.py:12:0
pub fn test_string_split_join() {
    text := 'apple,banana,cherry'
    parts := text.split(',')
    println('${parts}')
    joined := parts.join('-')
    println('${joined}')
    limited := text.split(',', 1)
    println('${limited}')
}
// @line: test_string_methods.py:24:0
pub fn test_string_replace() {
    mut s := 'hello world'
    replaced := s.replace('world', 'universe')
    println('${replaced}')
    mut s2 := 'aaaabaaa'
    replaced2 := s2.replace('a', 'x', 3)
    println('${replaced2}')
}
// @line: test_string_methods.py:34:0
pub fn test_string_find_index() {
    mut s := 'hello world'
    println('${s.find('world')}')
    println('${s.find('python')}')
    println('${s.index('world')}')
    println('${s.starts_with('hello')}')
    println('${s.ends_with('world')}')
}
// @line: test_string_methods.py:44:0
pub fn test_string_format() {
    name := 'Alice'
    age := 30
    msg := 'My name is {} and I am {}'.format(name, age)
    println('${msg}')
    msg2 := 'My name is {name} and I am {age}'.format()
    println('${msg2}')
    pi := 3.14159265359
    println('${'Pi: {:.2f}'.format(pi)}')
    println('${'Number: {:05d}'.format(42)}')
}
// @line: test_string_methods.py:61:0
pub fn test_string_slicing() {
    mut s := 'Programming'
    println('${s[0..4]}')
    println('${s[4..]}')
    println('${s[..4]}')
    println('${s[s.len - 3..]}')
    println('${py_str_slice(s, none, none, 2)}')
    println('${py_str_reverse(s)}')
}
// @line: test_string_methods.py:70:0
pub fn test_string_checks() {
    s1 := 'hello123'
    mut s2 := 'HELLO'
    s3 := 'hello'
    s4 := '123'
    s5 := 'Hello World'
    println('${s1.bytes().all(it.is_alnum())}')
    println('${s2.is_upper()}')
    println('${s3.is_lower()}')
    println('${s4.bytes().all(it.is_digit())}')
    println('${s5.is_title()}')
    println('${s5.bytes().all(it.is_letter())}')
}
// @line: test_string_methods.py:84:0
pub fn test() {
    test_basic_string_methods()
    test_string_split_join()
    test_string_replace()
    test_string_find_index()
    test_string_format()
    test_string_slicing()
    test_string_checks()
}

fn main() {
    // @line: test_string_methods.py:93:0
    // if __name__ == '__main__':
    test()
}