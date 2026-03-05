module main

import math

pub fn fibonacci(n int) []int {
    // Generate Fibonacci sequence.
    if n <= 0 {
        return []Any{}
    } else if n == 1 {
        return [0]
    }
    mut seq := []int{cap: 2}
    seq << 0
    seq << 1
    for i in 2..n {
        seq.append(seq[-1] + seq[-2])
    }
    return seq
}

fn main() {
    // if __name__ == '__main__':
    println('${fibonacci(10)}')
}