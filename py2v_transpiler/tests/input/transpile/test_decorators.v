module main

import div72.vexc

// @line: test_decorators.py:81:4
pub struct CountCalls {
    func fn (...Any) Any = unsafe { nil }
    count int
}
// @line: test_decorators.py:118:4
pub struct Temperature {
    _celsius fn (...Any) Any = unsafe { nil }
}

// @line: test_decorators.py:1:0
pub fn test_simple_decorator() {
// @line: test_decorators.py:2:4
    mut decorator := fn (func fn (...Any) Any) fn (...Any) Any {
// @line: test_decorators.py:3:8
        mut wrapper := fn [func] () Any {
            println('Before')
            func()
            println('After')
        }
        return wrapper
    }
// @decorator
// @line: test_decorators.py:10:4
    mut say_hello := fn [decorator] () {
        println('Hello!')
    }
    say_hello()
}
// @line: test_decorators.py:15:0
pub fn test_decorator_with_args() {
// @line: test_decorators.py:16:4
    mut decorator := fn (func fn (...Any) Any) fn (...Any) Any {
//##LLM@@ Function `wrapper` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
// @line: test_decorators.py:17:8
        mut wrapper := fn [func] (args ...Any, kwargs map[string]string) Any {
            println('Calling with args: ${args}, kwargs: ${kwargs}')
            return func(...args, kwargs)
        }
        return wrapper
    }
// @decorator
// @line: test_decorators.py:23:4
    mut greet := fn [decorator] (name string, age int) {
        println('Name: ${name}, Age: ${age}')
    }
    greet('Alice', 30)
}
// @line: test_decorators.py:28:0
pub fn test_decorator_return_value() {
// @line: test_decorators.py:29:4
    mut decorator := fn (func fn (...Any) Any) fn (...Any) Any {
//##LLM@@ Function `wrapper` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
// @line: test_decorators.py:30:8
        mut wrapper := fn [func] (args ...Any, kwargs map[string]string) Any {
            mut result := func(...args, kwargs)
            return result * 2
        }
        return wrapper
    }
// @decorator
// @line: test_decorators.py:36:4
    mut add := fn [decorator] (a int, b int) int {
        return a + b
    }
    println('${add(3, 4)}')
}
// @line: test_decorators.py:41:0
pub fn test_multiple_decorators() {
// @line: test_decorators.py:42:4
    mut decorator1 := fn (func fn (...Any) Any) fn (...Any) Any {
//##LLM@@ Function `wrapper` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
// @line: test_decorators.py:43:8
        mut wrapper := fn [func] (args ...Any, kwargs map[string]string) Any {
            println('Decorator 1 before')
            mut result := func(...args, kwargs)
            println('Decorator 1 after')
            return result
        }
        return wrapper
    }
// @line: test_decorators.py:50:4
    mut decorator2 := fn (func fn (...Any) Any) fn (...Any) Any {
//##LLM@@ Function `wrapper` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
// @line: test_decorators.py:51:8
        mut wrapper := fn [func] (args ...Any, kwargs map[string]string) Any {
            println('Decorator 2 before')
            mut result := func(...args, kwargs)
            println('Decorator 2 after')
            return result
        }
        return wrapper
    }
// @decorator1
// @decorator2
// @line: test_decorators.py:60:4
    mut test_func := fn [decorator1, decorator2] () {
        println('Inside function')
    }
    test_func()
}
// @line: test_decorators.py:65:0
pub fn test_decorator_with_params() {
// @line: test_decorators.py:66:4
    mut repeat := fn (times int) fn (...Any) Any {
// @line: test_decorators.py:67:8
        mut decorator := fn [times] (func fn (...Any) Any) fn (...Any) Any {
//##LLM@@ Function `wrapper` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
// @line: test_decorators.py:68:12
            mut wrapper := fn [func, times] (args ...Any, kwargs map[string]string) Any {
                for _ in 0..times {
                    func(...args, kwargs)
                }
            }
            return wrapper
        }
        return decorator
    }
// @repeat(3)
// @line: test_decorators.py:75:4
    mut say_hi := fn [repeat] () {
        println('Hi!')
    }
    say_hi()
}
// @line: test_decorators.py:80:0
pub fn test_class_decorator() {
// @line: test_decorators.py:82:8
    mut new_ := fn (func fn (...Any) Any)  {
        mut self := {}
        self.func = func
        self.count = 0
        return self
    }
//##LLM@@ Function `__call__` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
// @line: test_decorators.py:86:8
    //##LLM@@ Unmapped Python dunder method (e.g., __call__, __getitem__) detected. V handles object behavior and operator overloading differently. Please implement the equivalent V logic or refactor the calling code.
    mut __call__ := fn (args ...Any, kwargs map[string]string) Any {
        self.count += 1
        println('Call ${self.count}')
        return self.func(...args, kwargs)
    }
// @CountCalls
// @line: test_decorators.py:92:4
    mut greet := fn (name string) {
        println('Hello, ${name}!')
    }
    greet('Alice')
    greet('Bob')
    greet('Charlie')
}
// @line: test_decorators.py:99:0
pub fn test_functools_wraps() {
// @line: test_decorators.py:102:4
    mut decorator := fn (func fn (...Any) Any) fn (...Any) Any {
// @functools.wraps(func)
//##LLM@@ Function `wrapper` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
// @line: test_decorators.py:104:8
        mut wrapper := fn [func] (args ...Any, kwargs map[string]string) Any {
            // Wrapper docstring
            return func(...args, kwargs)
        }
        return wrapper
    }
// @decorator
// @line: test_decorators.py:110:4
    mut original_func := fn [decorator] () {
        // Original docstring
    }
    println('Name: ${original_func____name__}')
    println('Doc: ${original_func____doc__}')
}
// @line: test_decorators.py:117:0
pub fn test_property_decorator() {
// @line: test_decorators.py:119:8
    mut new_ := fn (celsius f64)  {
        mut self := {}
        self._celsius = celsius
        return self
    }
// @property
// @line: test_decorators.py:123:8
    mut celsius := fn () f64 {
        return self._celsius
    }
// @celsius__setter
// @line: test_decorators.py:127:8
    mut set_celsius := fn [celsius] (value f64) f64 {
        if value < -273.15 {
            vexc.raise('ValueError', 'Below absolute zero')
        }
        self._celsius = value
    }
// @property
// @line: test_decorators.py:133:8
    mut fahrenheit := fn () f64 {
        return f64((self._celsius as f64) * f64(9)) / f64(5) + f64(32)
    }
    temp := new_temperature(25)
    println('Celsius: ${temp.celsius}')
    println('Fahrenheit: ${temp.fahrenheit}')
    temp.celsius = 30
    println('New Celsius: ${temp.celsius}')
}
// @line: test_decorators.py:142:0
pub fn test() {
    test_simple_decorator()
    test_decorator_with_args()
    test_decorator_return_value()
    test_multiple_decorators()
    test_decorator_with_params()
    test_class_decorator()
    test_functools_wraps()
    test_property_decorator()
}

fn main() {
    // @line: test_decorators.py:152:0
    // if __name__ == '__main__':
    test()
}