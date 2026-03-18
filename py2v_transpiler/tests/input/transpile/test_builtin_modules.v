module main

import math
import rand
import os

// @line: test_builtin_modules.py:5:0
pub fn test_math_functions() {
    println('Pi: ${math.pi}')
    println('E: ${math.e}')
    println('Sqrt(16): ${math.sqrt(f64(16))}')
    println('Pow(2, 3): ${math.pow(f64(2), f64(3))}')
    println('Ceil(3.2): ${math.ceil(f64(3.2))}')
    println('Floor(3.8): ${math.floor(f64(3.8))}')
    println('Abs(-5): ${abs(-5)}')
    println('Round(3.5): ${math.round(3.5)}')
    println('Round(3.14159, 2): ${py_round(f64(3.14159), 2)}')
    println('Sin(0): ${math.sin(f64(0))}')
    println('Cos(0): ${math.cos(f64(0))}')
    println('Tan(0): ${math.tan(f64(0))}')
    println('Log(e): ${math.log(f64(math.e))}')
    println('Log10(100): ${math.log10(f64(100))}')
    println('Exp(1): ${math.exp(f64(1))}')
}
// @line: test_builtin_modules.py:27:0
pub fn test_random_functions() {
    rand.seed(42)
    println('Random: ${rand.f64()}')
    println('Random int 1-10: ${rand.intn(10 - 1 + 1) + 1}')
    println('Random int 1-10: ${rand.intn(10 - 1 + 1) + 1}')
    choices := ['apple', 'banana', 'cherry']
    println('Choice: ${choices[rand.intn(choices.len)]}')
    println('Sample: ${random.sample(choices, 2)}')
    random.shuffle(choices)
    println('Shuffled: ${choices}')
}
// @line: test_builtin_modules.py:42:0
pub fn test_os_functions() {
    cwd := os.getwd()
    println('CWD: ${cwd}')
    path := os.join_path('folder', 'subfolder', 'file.txt')
    println('Joined path: ${path}')
    py_destruct_0 := os.path.split(path)
    dirname := py_destruct_0[0]
    basename := py_destruct_0[1]
    println('Dir: ${dirname}, Base: ${basename}')
    py_destruct_1 := os.path.splitext('file.txt')
    root := py_destruct_1[0]
    ext := py_destruct_1[1]
    println('Root: ${root}, Ext: ${ext}')
    println('Exists: ${os.exists(cwd)}')
    println('Is dir: ${os.is_dir(cwd)}')
    println('Is file: ${os.is_file(cwd)}')
}
// @line: test_builtin_modules.py:64:0
pub fn test_builtin_functions() {
    println('Len: ${[1, 2, 3, 4, 5].len}')
    println('Range: ${[]Any(range(5))}')
    println('Range with start: ${[]Any(range(2, 7))}')
    println('Range with step: ${[]Any(range(0, 10, 2))}')
    nums := [5, 2, 8, 1, 9]
    println('Sum: ${sum(nums)}')
    println('Min: ${min(nums)}')
    println('Max: ${max(nums)}')
    println('Abs: ${abs(-10)}')
    println('Pow: ${pow(2, 10)}')
    py_destruct_2 := divmod(17, 5)
    q := py_destruct_2[0]
    r := py_destruct_2[1]
    println('Divmod: quotient=${q}, remainder=${r}')
    println('All True: ${py_all([true, true, true])}')
    println('All with False: ${py_all([true, false, true])}')
    println('Any True: ${py_any([false, false, true])}')
    println('Any False: ${py_any([false, false, false])}')
    println('Ord(\'A\'): ${ord("A")}')
    println('Chr(65): ${chr(65)}')
}
// @line: test_builtin_modules.py:97:0
pub fn test_string_builtin() {
    s := 'Hello, World!'
    println('Len: ${s.len}')
    println('Upper: ${s.to_upper()}')
    println('Lower: ${s.to_lower()}')
    println('Replace: ${s.replace("World", "Universe")}')
    println('Split: ${s.split(", ")}')
}
// @line: test_builtin_modules.py:106:0
pub fn test_list_builtin() {
    lst := [3, 1, 4, 1, 5, 9, 2, 6]
    println('Sorted: ${py_sorted(lst)}')
    println('Sorted desc: ${py_sorted(lst)}')
    println('Reversed: ${[]Any(py_reversed(lst))}')
    names := ['Alice', 'Bob', 'Charlie']
    ages := [25, 30, 35]
    println('Zipped: ${[]Any(zip(names, ages))}')
    println('Enumerated: ${[]Any(enumerate(["a", "b", "c"]))}')
}
// @line: test_builtin_modules.py:121:0
pub fn test() {
    test_math_functions()
    test_random_functions()
    test_os_functions()
    test_builtin_functions()
    test_string_builtin()
    test_list_builtin()
}

fn main() {
    // @line: test_builtin_modules.py:129:0
    // if __name__ == '__main__':
    test()
}