import math
from py2v_transpiler.stdlib_map.mapper import StdLibMapper

def test_mapper_math_log():
    mapper = StdLibMapper()

    # math.log(x) -> math.log(f64(x))
    assert mapper.get_mapping("math", "log", ["10"]) == "math.log(f64(10))"

    # math.log(x, base) -> math.log_n(f64(x), f64(base))
    assert mapper.get_mapping("math", "log", ["10", "2"]) == "math.log_n(f64(10), f64(2))"

    # math.log10(x) -> math.log10(f64(x))
    assert mapper.get_mapping("math", "log10", ["100"]) == "math.log10(f64(100))"

def test_mapper_math_unary():
    mapper = StdLibMapper()
    assert mapper.get_mapping("math", "sin", ["90"]) == "math.sin(f64(90))"
    assert mapper.get_mapping("math", "sqrt", ["16"]) == "math.sqrt(f64(16))"
    assert mapper.get_mapping("math", "ceil", ["4.2"]) == "math.ceil(f64(4.2))"

def test_mapper_math_binary():
    mapper = StdLibMapper()
    assert mapper.get_mapping("math", "pow", ["2", "3"]) == "math.pow(f64(2), f64(3))"
    assert mapper.get_mapping("math", "atan2", ["1", "1"]) == "math.atan2(f64(1), f64(1))"
