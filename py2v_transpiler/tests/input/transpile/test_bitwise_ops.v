module main

import math

// @line: test_bitwise_ops.py:1:0
pub fn test_bitwise_and() {
    mut a := 12
    mut b := 10
    mut result := a & b
    println('${a} & ${b} = ${result}')
}
// @line: test_bitwise_ops.py:7:0
pub fn test_bitwise_or() {
    mut a := 12
    mut b := 10
    mut result := a | b
    println('${a} | ${b} = ${result}')
}
// @line: test_bitwise_ops.py:13:0
pub fn test_bitwise_xor() {
    mut a := 12
    mut b := 10
    mut result := a ^ b
    println('${a} ^ ${b} = ${result}')
}
// @line: test_bitwise_ops.py:19:0
pub fn test_bitwise_not() {
    mut a := 5
    mut result := ~a
    println('~${a} = ${result}')
}
// @line: test_bitwise_ops.py:24:0
pub fn test_bitwise_shift_left() {
    mut a := 4
    mut result := a << 2
    println('${a} << 2 = ${result}')
}
// @line: test_bitwise_ops.py:29:0
pub fn test_bitwise_shift_right() {
    mut a := 16
    mut result := a >> 2
    println('${a} >> 2 = ${result}')
}
// @line: test_bitwise_ops.py:34:0
pub fn test_bitwise_operations() {
    mut num := 13
    bit_mask := 4
    is_set := num & bit_mask != 0
    println('Bit 2 is set in ${num}: ${is_set}')
    mut result := num | 2
    println('Set bit 1 in ${num}: ${result}')
    result = num & ~4
    println('Clear bit 2 in ${num}: ${result}')
    result = num ^ 1
    println('Toggle bit 0 in ${num}: ${result}')
}
// @line: test_bitwise_ops.py:53:0
pub fn test_bitwise_flags() {
    read := 1
    write := 2
    execute := 4
    mut permissions := read | write
    println('Permissions: ${permissions}')
    has_read := permissions & read != 0
    has_execute := permissions & execute != 0
    println('Has read: ${has_read}, Has execute: ${has_execute}')
    permissions |= execute
    println('New permissions: ${permissions}')
    permissions &= ~write
    println('Final permissions: ${permissions}')
}
// @line: test_bitwise_ops.py:74:0
pub fn test_floor_division() {
    mut a := 17
    mut b := 5
    mut result := int(math.floor(f64(a) / f64(b)))
    println('${a} // ${b} = ${result}')
    result_neg := int(math.floor(f64(-17) / f64(5)))
    println('-17 // 5 = ${result_neg}')
}
// @line: test_bitwise_ops.py:84:0
pub fn test_modulo() {
    mut a := 17
    mut b := 5
    mut result := a % b
    println('${a} % ${b} = ${result}')
    mut num := 10
    is_even := num % 2 == 0
    println('${num} is even: ${is_even}')
}
// @line: test_bitwise_ops.py:95:0
pub fn test_power() {
    base := 2
    exp := 10
    mut result := int(math.powi(f64(base), exp))
    println('${base} ** ${exp} = ${result}')
    result_sqrt := math.pow(f64(16), 0.5)
    println('16 ** 0.5 = ${result_sqrt}')
}
// @line: test_bitwise_ops.py:105:0
pub fn test_augmented_assignment() {
    mut x := 10
    x += 5
    println('x += 5: ${x}')
    x -= 3
    println('x -= 3: ${x}')
    x *= 2
    println('x *= 2: ${x}')
    x = int(math.floor(f64(x) / f64(3)))
    println('x //= 3: ${x}')
    x = int(math.powi(f64(x), 2))
    println('x **= 2: ${x}')
    x %= 7
    println('x %= 7: ${x}')
    x &= 3
    println('x &= 3: ${x}')
    x |= 5
    println('x |= 5: ${x}')
    x ^= 2
    println('x ^= 2: ${x}')
    x >>= 1
    println('x >>= 1: ${x}')
    x <<= 2
    println('x <<= 2: ${x}')
}
// @line: test_bitwise_ops.py:140:0
pub fn test() {
    test_bitwise_and()
    test_bitwise_or()
    test_bitwise_xor()
    test_bitwise_not()
    test_bitwise_shift_left()
    test_bitwise_shift_right()
    test_bitwise_operations()
    test_bitwise_flags()
    test_floor_division()
    test_modulo()
    test_power()
    test_augmented_assignment()
}

fn main() {
    // @line: test_bitwise_ops.py:154:0
    // if __name__ == '__main__':
    test()
}