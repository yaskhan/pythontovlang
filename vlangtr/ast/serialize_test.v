module ast

import math

// ============================================================================
// Helper function
// ============================================================================

fn serialize_source(source string, filename string) []u8 {
	mut l := new_lexer(source, filename)
	mut p := new_parser(l)
	mod := p.parse_module()

	mut s := Serializer.new()
	return s.serialize_module(mod)
}

// ============================================================================
// --- BinaryReader for testing ---
struct BinaryReader {
mut:
	data []u8
	pos  int
}

fn (mut r BinaryReader) read_tag() u8 {
	tag := r.data[r.pos]
	r.pos++
	return tag
}

fn (mut r BinaryReader) expect_tag(expected u8) {
	tag := r.read_tag()
	if tag != expected {
		panic('Expected tag ${expected}, but got ${tag} at pos ${r.pos-1}')
	}
}

fn (mut r BinaryReader) read_int_bare() int {
	mut res := u32(0)
	mut shift := u32(0)
	for {
		if r.pos >= r.data.len { break }
		byte := r.data[r.pos]
		r.pos++
		res |= (u32(byte & 0x7F) << shift)
		if (byte & 0x80) == 0 { break }
		shift += 7
	}
	return int(res)
}

fn (mut r BinaryReader) read_int() int {
	r.expect_tag(literal_int)
	return r.read_int_bare()
}

fn (mut r BinaryReader) read_str_bare() string {
	len := r.read_int_bare()
	if len <= 0 { return '' }
	start := r.pos
	r.pos += len
	return r.data[start..r.pos].bytestr()
}

fn (mut r BinaryReader) read_str() string {
	r.expect_tag(literal_str)
	return r.read_str_bare()
}

fn (mut r BinaryReader) skip_location() {
	r.expect_tag(location)
	r.read_int_bare() // line
	r.read_int_bare() // col
	r.read_int_bare() // end_line
	r.read_int_bare() // end_col
}

// ============================================================================
// Basic tests
// ============================================================================

fn test_serialize_simple() {
	source := 'x = 1\ndef f(y):\n    return y + 1\n'
	filename := 'test.py'

	bytes := serialize_source(source, filename)
	assert bytes.len > 0
	mut r := BinaryReader{data: bytes}
	assert r.read_int() == 2 // x=1 and def f
}

// ============================================================================
// Statement tests
// ============================================================================

// --- FunctionDef ---
fn test_serialize_functiondef() {
	source := 'def foo(a: int, b=10) -> int:\n    return a + b\n'
	bytes := serialize_source(source, 'func.py')
	assert bytes.len > 0
}

fn test_serialize_async_functiondef() {
	source := 'async def fetch(url):\n    return await aio.get(url)\n'
	bytes := serialize_source(source, 'async_func.py')
	assert bytes.len > 0
}

fn test_serialize_functiondef_with_decorators() {
	source := '@decorator\n@wrap(1, 2)\ndef f():\n    pass\n'
	bytes := serialize_source(source, 'decorated.py')
	assert bytes.len > 0
}

// --- ClassDef ---
fn test_serialize_classdef() {
	source := 'class MyClass(Base1, Base2):\n    def method(self):\n        pass\n'
	bytes := serialize_source(source, 'class.py')
	mut r := BinaryReader{data: bytes}
	r.read_int() // stmts
	r.expect_tag(nodes_class_def)
	assert r.read_str() == 'MyClass'
	// Type params (Python 3.12+)
	r.expect_tag(list_gen)
	assert r.read_int_bare() == 0
	// Bases
	r.expect_tag(list_gen)
	assert r.read_int_bare() == 2
}

fn test_serialize_classdef_with_decorators() {
	source := '@dataclass\nclass Point:\n    x: int\n    y: int\n'
	bytes := serialize_source(source, 'decorated_class.py')
	assert bytes.len > 0
}

// --- Assign ---
fn test_serialize_assign() {
	source := 'x = 42\n'
	bytes := serialize_source(source, 'assign.py')
	assert bytes.len > 0
}

fn test_serialize_multi_assign() {
	source := 'a = b = c = 0\n'
	bytes := serialize_source(source, 'multi_assign.py')
	assert bytes.len > 0
}

// --- AnnAssign ---
fn test_serialize_annassign() {
	source := 'x: int = 5\n'
	bytes := serialize_source(source, 'ann_assign.py')
	assert bytes.len > 0
}

fn test_serialize_annassign_no_value() {
	source := 'x: int\n'
	bytes := serialize_source(source, 'ann_assign_no_val.py')
	assert bytes.len > 0
}

// --- AugAssign ---
fn test_serialize_augassign() {
	source := 'x += 1\ny *= 2\nz **= 3\n'
	bytes := serialize_source(source, 'aug_assign.py')
	assert bytes.len > 0
}

// --- Expr ---
fn test_serialize_expr_stmt() {
	source := '"docstring"\n42\n'
	bytes := serialize_source(source, 'expr.py')
	assert bytes.len > 0
}

// --- Return ---
fn test_serialize_return() {
	source := 'def f():\n    return\n'
	bytes := serialize_source(source, 'return.py')
	assert bytes.len > 0
}

fn test_serialize_return_value() {
	source := 'def f():\n    return 42\n'
	bytes := serialize_source(source, 'return_val.py')
	assert bytes.len > 0
}

// --- If ---
fn test_serialize_if() {
	source := 'if x > 0:\n    print("positive")\n'
	bytes := serialize_source(source, 'if.py')
	assert bytes.len > 0
}

fn test_serialize_if_elif_else() {
	source := 'if x > 0:\n    print("pos")\nelif x < 0:\n    print("neg")\nelse:\n    print("zero")\n'
	bytes := serialize_source(source, 'if_elif_else.py')
	assert bytes.len > 0
}

// --- While ---
fn test_serialize_while() {
	source := 'while x > 0:\n    x -= 1\n'
	bytes := serialize_source(source, 'while.py')
	assert bytes.len > 0
}

fn test_serialize_while_else() {
	source := 'while x > 0:\n    x -= 1\nelse:\n    print("done")\n'
	bytes := serialize_source(source, 'while_else.py')
	assert bytes.len > 0
}

// --- For ---
fn test_serialize_for() {
	source := 'for i in range(10):\n    print(i)\n'
	bytes := serialize_source(source, 'for.py')
	mut r := BinaryReader{data: bytes}
	r.read_int() // stmts
	r.expect_tag(nodes_for_stmt)
	// target
	r.expect_tag(nodes_name_expr)
	assert r.read_str() == 'i'
}

fn test_serialize_async_for() {
	source := 'async def f():\n    async for item in aiter():\n        print(item)\n'
	bytes := serialize_source(source, 'async_for.py')
	assert bytes.len > 0
}

fn test_serialize_for_else() {
	source := 'for i in items:\n    if i == x:\n        break\nelse:\n    print("not found")\n'
	bytes := serialize_source(source, 'for_else.py')
	assert bytes.len > 0
}

// --- With ---
fn test_serialize_with() {
	source := 'with open("f.txt") as f:\n    data = f.read()\n'
	bytes := serialize_source(source, 'with.py')
	mut r := BinaryReader{data: bytes}
	r.read_int() // stmts
	r.expect_tag(nodes_with_stmt)
	r.expect_tag(list_gen)
	assert r.read_int_bare() == 1 // 1 withitem
}

fn test_serialize_async_with() {
	source := 'async def f():\n    async with aiohttp.ClientSession() as session:\n        pass\n'
	bytes := serialize_source(source, 'async_with.py')
	assert bytes.len > 0
}

fn test_serialize_with_multiple_items() {
	source := 'with open("a.txt") as a, open("b.txt") as b:\n    pass\n'
	bytes := serialize_source(source, 'with_multi.py')
	assert bytes.len > 0
}

// --- Try/Except ---
fn test_serialize_try_except() {
	source := 'try:\n    risky()\nexcept ValueError:\n    handle()\n'
	bytes := serialize_source(source, 'try_except.py')
	assert bytes.len > 0
}

fn test_serialize_try_except_as() {
	source := 'try:\n    risky()\nexcept ValueError as e:\n    handle(e)\n'
	bytes := serialize_source(source, 'try_except_as.py')
	assert bytes.len > 0
}

fn test_serialize_try_except_finally() {
	source := 'try:\n    risky()\nexcept:\n    handle()\nfinally:\n    cleanup()\n'
	bytes := serialize_source(source, 'try_finally.py')
	assert bytes.len > 0
}

fn test_serialize_try_else() {
	source := 'try:\n    risky()\nexcept:\n    handle()\nelse:\n    success()\n'
	bytes := serialize_source(source, 'try_else.py')
	assert bytes.len > 0
}

// --- TryStar (Python 3.11+) ---
fn test_serialize_trystar() {
	source := 'try:\n    raise_group()\nexcept* ValueError:\n    handle()\n'
	bytes := serialize_source(source, 'trystar.py')
	assert bytes.len > 0
}

// --- Assert ---
fn test_serialize_assert() {
	source := 'assert x > 0\n'
	bytes := serialize_source(source, 'assert.py')
	assert bytes.len > 0
}

fn test_serialize_assert_msg() {
	source := 'assert x > 0, "must be positive"\n'
	bytes := serialize_source(source, 'assert_msg.py')
	assert bytes.len > 0
}

// --- Raise ---
fn test_serialize_raise() {
	source := 'raise ValueError("bad")\n'
	bytes := serialize_source(source, 'raise.py')
	assert bytes.len > 0
}

fn test_serialize_raise_from() {
	source := 'raise NewError from old_error\n'
	bytes := serialize_source(source, 'raise_from.py')
	assert bytes.len > 0
}

// --- Pass, Break, Continue ---
fn test_serialize_pass() {
	source := 'def f():\n    pass\n'
	bytes := serialize_source(source, 'pass.py')
	assert bytes.len > 0
}

fn test_serialize_break() {
	source := 'while True:\n    break\n'
	bytes := serialize_source(source, 'break.py')
	assert bytes.len > 0
}

fn test_serialize_continue() {
	source := 'for i in range(10):\n    if i == 5:\n        continue\n'
	bytes := serialize_source(source, 'continue.py')
	assert bytes.len > 0
}

// --- Delete ---
fn test_serialize_delete() {
	source := 'del x\n'
	bytes := serialize_source(source, 'delete.py')
	assert bytes.len > 0
}

fn test_serialize_delete_multi() {
	source := 'del x, y, z\n'
	bytes := serialize_source(source, 'delete_multi.py')
	assert bytes.len > 0
}

fn test_serialize_delete_subscript() {
	source := 'del items[0]\n'
	bytes := serialize_source(source, 'delete_subscript.py')
	assert bytes.len > 0
}

// --- Import ---
fn test_serialize_import() {
	source := 'import os\nimport sys as system\n'
	bytes := serialize_source(source, 'import.py')
	assert bytes.len > 0
}

fn test_serialize_import_from() {
	source := 'from os.path import join, exists\nfrom typing import Optional as Opt\n'
	bytes := serialize_source(source, 'import_from.py')
	assert bytes.len > 0
}

fn test_serialize_import_relative() {
	source := 'from . import module\nfrom ..pkg import item\n'
	bytes := serialize_source(source, 'import_relative.py')
	assert bytes.len > 0
}

// --- Global/Nonlocal ---
fn test_serialize_global() {
	source := 'def f():\n    global x\n'
	bytes := serialize_source(source, 'global.py')
	assert bytes.len > 0
}

fn test_serialize_nonlocal() {
	source := 'def outer():\n    def inner():\n        nonlocal x\n'
	bytes := serialize_source(source, 'nonlocal.py')
	assert bytes.len > 0
}

// --- Match (Python 3.10+) ---
fn test_serialize_match_value() {
	source := 'match x:\n    case 1:\n        print("one")\n'
	bytes := serialize_source(source, 'match_value.py')
	mut r := BinaryReader{data: bytes}
	r.read_int() // stmts
	r.expect_tag(nodes_match_stmt)
	r.expect_tag(nodes_name_expr)
	assert r.read_str() == 'x'
	r.skip_location()
	r.expect_tag(end_tag)
	// cases
	r.expect_tag(list_gen)
	assert r.read_int_bare() == 1
}

fn test_serialize_match_singleton() {
	source := 'match x:\n    case True:\n        pass\n    case None:\n        pass\n'
	bytes := serialize_source(source, 'match_singleton.py')
	assert bytes.len > 0
}

fn test_serialize_match_sequence() {
	source := 'match items:\n    case [first, *rest]:\n        print(first)\n'
	bytes := serialize_source(source, 'match_sequence.py')
	assert bytes.len > 0
}

fn test_serialize_match_mapping() {
	source := 'match data:\n    case {"key": value}:\n        print(value)\n'
	bytes := serialize_source(source, 'match_mapping.py')
	assert bytes.len > 0
}

fn test_serialize_match_class() {
	source := 'match point:\n    case Point(x=0, y=0):\n        print("origin")\n'
	bytes := serialize_source(source, 'match_class.py')
	assert bytes.len > 0
}

fn test_serialize_match_as() {
	source := 'match x:\n    case [1, 2] as pair:\n        print(pair)\n'
	bytes := serialize_source(source, 'match_as.py')
	assert bytes.len > 0
}

fn test_serialize_match_or() {
	source := 'match x:\n    case 1 | 2 | 3:\n        print("small")\n'
	bytes := serialize_source(source, 'match_or.py')
	assert bytes.len > 0
}

fn test_serialize_match_wildcard() {
	source := 'match x:\n    case _:\n        print("default")\n'
	bytes := serialize_source(source, 'match_wildcard.py')
	assert bytes.len > 0
}

fn test_serialize_match_guard() {
	source := 'match x:\n    case n if n > 0:\n        print("positive")\n'
	bytes := serialize_source(source, 'match_guard.py')
	assert bytes.len > 0
}

// --- TypeAlias (Python 3.12+) ---
fn test_serialize_typealias() {
	source := 'type IntList = list[int]\n'
	bytes := serialize_source(source, 'typealias.py')
	assert bytes.len > 0
}

// ============================================================================
// Expression tests
// ============================================================================

// --- Name ---
fn test_serialize_name_expr() {
	source := 'x = y\n'
	bytes := serialize_source(source, 'name.py')
	mut r := BinaryReader{data: bytes}
	r.read_int() // stmts
	r.expect_tag(nodes_assignment_stmt)
	r.expect_tag(list_gen)
	r.read_int_bare() // targets len
	r.expect_tag(nodes_name_expr)
	assert r.read_str() == 'x'
}

// --- Constant (int, str, float, bool, None) ---
fn test_serialize_int() {
	source := 'x = 42\n'
	bytes := serialize_source(source, 'int.py')
	mut r := BinaryReader{data: bytes}
	r.read_int() // stmts
	r.expect_tag(nodes_assignment_stmt)
	r.expect_tag(list_gen)
	r.read_int_bare() // targets
	r.expect_tag(nodes_name_expr)
	assert r.read_str() == 'x'
	r.skip_location()
	r.expect_tag(end_tag)
	r.expect_tag(nodes_int_expr)
	assert r.read_int_bare() == 42
}

fn test_serialize_str() {
	source := 's = "hello"\n'
	bytes := serialize_source(source, 'str.py')
	assert bytes.len > 0
}

fn test_serialize_bytes() {
	source := 'b = b"binary"\n'
	bytes := serialize_source(source, 'bytes.py')
	assert bytes.len > 0
}

fn test_serialize_float() {
	source := 'f = 3.14\n'
	bytes := serialize_source(source, 'float.py')
	assert bytes.len > 0
}

fn test_serialize_bool() {
	source := 't = True\nf = False\n'
	bytes := serialize_source(source, 'bool.py')
	assert bytes.len > 0
}

fn test_serialize_none() {
	source := 'n = None\n'
	bytes := serialize_source(source, 'none.py')
	assert bytes.len > 0
}

// --- BinaryOp ---
fn test_serialize_binop_arithmetic() {
	source := 'x = a + b - c * d / e\n'
	bytes := serialize_source(source, 'binop_arith.py')
	assert bytes.len > 0
}

fn test_serialize_binop_power() {
	source := 'x = a ** b\n'
	bytes := serialize_source(source, 'binop_power.py')
	assert bytes.len > 0
}

fn test_serialize_binop_bitwise() {
	source := 'x = a & b | c ^ d\n'
	bytes := serialize_source(source, 'binop_bitwise.py')
	assert bytes.len > 0
}

fn test_serialize_binop_shift() {
	source := 'x = a << 2 >> 1\n'
	bytes := serialize_source(source, 'binop_shift.py')
	assert bytes.len > 0
}

fn test_serialize_binop_matrix_mult() {
	source := 'x = A @ B\n'
	bytes := serialize_source(source, 'binop_matmul.py')
	assert bytes.len > 0
}

fn test_serialize_binop_floor_div() {
	source := 'x = a // b\n'
	bytes := serialize_source(source, 'binop_floordiv.py')
	assert bytes.len > 0
}

// --- UnaryOp ---
fn test_serialize_unary_not() {
	source := 'x = not y\n'
	bytes := serialize_source(source, 'unary_not.py')
	assert bytes.len > 0
}

fn test_serialize_unary_neg() {
	source := 'x = -y\n'
	bytes := serialize_source(source, 'unary_neg.py')
	assert bytes.len > 0
}

fn test_serialize_unary_pos() {
	source := 'x = +y\n'
	bytes := serialize_source(source, 'unary_pos.py')
	assert bytes.len > 0
}

fn test_serialize_unary_invert() {
	source := 'x = ~y\n'
	bytes := serialize_source(source, 'unary_invert.py')
	assert bytes.len > 0
}

// --- Compare ---
fn test_serialize_compare_single() {
	source := 'x = a == b\n'
	bytes := serialize_source(source, 'cmp_single.py')
	assert bytes.len > 0
}

fn test_serialize_compare_chained() {
	source := 'if 1 < x <= 10:\n    print("in range")\n'
	bytes := serialize_source(source, 'cmp_chained.py')
	assert bytes.len > 0
}

fn test_serialize_compare_is() {
	source := 'x = a is b\ny = a is not b\n'
	bytes := serialize_source(source, 'cmp_is.py')
	assert bytes.len > 0
}

fn test_serialize_compare_in() {
	source := 'x = a in b\ny = a not in b\n'
	bytes := serialize_source(source, 'cmp_in.py')
	assert bytes.len > 0
}

// --- Call ---
fn test_serialize_call() {
	source := 'result = func(a, b, c)\n'
	bytes := serialize_source(source, 'call.py')
	assert bytes.len > 0
}

fn test_serialize_call_kwargs() {
	source := 'result = func(a=1, b=2)\n'
	bytes := serialize_source(source, 'call_kwargs.py')
	assert bytes.len > 0
}

fn test_serialize_call_starred() {
	source := 'result = func(*args, **kwargs)\n'
	bytes := serialize_source(source, 'call_starred.py')
	assert bytes.len > 0
}

// --- Attribute ---
fn test_serialize_attribute() {
	source := 'x = obj.attr\n'
	bytes := serialize_source(source, 'attr.py')
	assert bytes.len > 0
}

// --- Subscript ---
fn test_serialize_subscript_index() {
	source := 'x = items[0]\n'
	bytes := serialize_source(source, 'subscript_index.py')
	assert bytes.len > 0
}

fn test_serialize_subscript_slice() {
	source := 'x = items[1:10:2]\n'
	bytes := serialize_source(source, 'subscript_slice.py')
	assert bytes.len > 0
}

// --- List, Tuple, Set, Dict ---
fn test_serialize_list() {
	source := 'x = [1, 2, 3]\n'
	bytes := serialize_source(source, 'list.py')
	assert bytes.len > 0
}

fn test_serialize_tuple() {
	source := 'x = (1, 2, 3)\n'
	bytes := serialize_source(source, 'tuple.py')
	assert bytes.len > 0
}

fn test_serialize_set() {
	source := 'x = {1, 2, 3}\n'
	bytes := serialize_source(source, 'set.py')
	assert bytes.len > 0
}

fn test_serialize_dict() {
	source := 'x = {"a": 1, "b": 2}\n'
	bytes := serialize_source(source, 'dict.py')
	assert bytes.len > 0
}

// --- BoolOp (And, Or) ---
fn test_serialize_boolop_and() {
	source := 'x = a and b and c\n'
	bytes := serialize_source(source, 'boolop_and.py')
	assert bytes.len > 0
}

fn test_serialize_boolop_or() {
	source := 'x = a or b or c\n'
	bytes := serialize_source(source, 'boolop_or.py')
	assert bytes.len > 0
}

// --- IfExp (conditional expression) ---
fn test_serialize_ifexp() {
	source := 'x = "pos" if n > 0 else "neg"\n'
	bytes := serialize_source(source, 'ifexp.py')
	assert bytes.len > 0
}

// --- Lambda ---
fn test_serialize_lambda() {
	source := 'f = lambda x, y=5: x + y\n'
	bytes := serialize_source(source, 'lambda.py')
	assert bytes.len > 0
}

// --- NamedExpr (Walrus) ---
fn test_serialize_namedexpr() {
	source := 'if (n := len(items)) > 0:\n    print(n)\n'
	bytes := serialize_source(source, 'namedexpr.py')
	assert bytes.len > 0
}

// --- Yield ---
fn test_serialize_yield() {
	source := 'def gen():\n    yield 1\n'
	bytes := serialize_source(source, 'yield.py')
	assert bytes.len > 0
}

// --- YieldFrom ---
fn test_serialize_yieldfrom() {
	source := 'def gen():\n    yield from other()\n'
	bytes := serialize_source(source, 'yieldfrom.py')
	assert bytes.len > 0
}

// --- Await ---
fn test_serialize_await() {
	source := 'async def fetch():\n    return await aiohttp.get(url)\n'
	bytes := serialize_source(source, 'await.py')
	assert bytes.len > 0
}

// --- Starred ---
fn test_serialize_starred() {
	source := '*rest, = [1, 2, 3]\n'
	bytes := serialize_source(source, 'starred.py')
	assert bytes.len > 0
}

fn test_serialize_starred_in_call() {
	source := 'func(*args)\n'
	bytes := serialize_source(source, 'starred_call.py')
	assert bytes.len > 0
}

// --- Slice ---
fn test_serialize_slice_lower() {
	source := 'x = items[1:]\n'
	bytes := serialize_source(source, 'slice_lower.py')
	assert bytes.len > 0
}

fn test_serialize_slice_upper() {
	source := 'x = items[:10]\n'
	bytes := serialize_source(source, 'slice_upper.py')
	assert bytes.len > 0
}

fn test_serialize_slice_full() {
	source := 'x = items[1:10:2]\n'
	bytes := serialize_source(source, 'slice_full.py')
	assert bytes.len > 0
}

fn test_serialize_joinedstr() {
	source := 'f"{x}"\n'
	bytes := serialize_source(source, 'joinedstr.py')
	mut r := BinaryReader{data: bytes}
	r.read_int() // stmts
	r.expect_tag(nodes_expr_stmt)
	r.expect_tag(nodes_joined_str)
	r.expect_tag(list_gen)
	assert r.read_int_bare() == 1
	r.expect_tag(nodes_formatted_value)
	r.expect_tag(nodes_name_expr)
	assert r.read_str() == 'x'
}

fn test_serialize_joinedstr_format_spec() {
	source := 'f"{x:10.2f}"\n'
	bytes := serialize_source(source, 'joinedstr_spec.py')
	mut r := BinaryReader{data: bytes}
	r.read_int() // stmts
	r.expect_tag(nodes_expr_stmt)
	r.expect_tag(nodes_joined_str)
	r.expect_tag(list_gen)
	assert r.read_int_bare() == 1
	r.expect_tag(nodes_formatted_value)
	r.expect_tag(nodes_name_expr)
	assert r.read_str() == 'x'
	r.skip_location()
	r.expect_tag(end_tag)
	r.expect_tag(literal_int) // conversion
	r.read_int_bare()
	r.expect_tag(literal_true) // has format_spec
	// Format spec is an expression (usually JoinedStr)
	r.expect_tag(nodes_joined_str)
}

fn test_serialize_dict_unpacking() {
	source := '{**d, "a": 1}\n'
	bytes := serialize_source(source, 'dict_unpack.py')
	mut r := BinaryReader{data: bytes}
	r.read_int() // stmts
	r.expect_tag(nodes_expr_stmt)
	r.expect_tag(nodes_dict_expr)
	r.expect_tag(list_gen)
	assert r.read_int_bare() == 2
	r.expect_tag(nodes_none_expr) // unpack key placeholder
}

// --- ListComp, DictComp, SetComp, GeneratorExp ---
fn test_serialize_listcomp() {
	source := '[x * 2 for x in range(10)]\n'
	bytes := serialize_source(source, 'listcomp.py')
	assert bytes.len > 0
}

fn test_serialize_dictcomp() {
	source := '{k: v * 2 for k, v in items}\n'
	bytes := serialize_source(source, 'dictcomp.py')
	assert bytes.len > 0
}

fn test_serialize_setcomp() {
	source := '{x * 2 for x in range(10)}\n'
	bytes := serialize_source(source, 'setcomp.py')
	assert bytes.len > 0
}

fn test_serialize_generatorexp() {
	source := '(x * 2 for x in range(10))\n'
	bytes := serialize_source(source, 'genexp.py')
	assert bytes.len > 0
}

// --- Comprehension with if ---
fn test_serialize_comprehension_with_if() {
	source := '[x for x in range(10) if x % 2 == 0]\n'
	bytes := serialize_source(source, 'comp_if.py')
	assert bytes.len > 0
}

fn test_serialize_comprehension_multiple_ifs() {
	source := '[x for x in range(20) if x % 2 == 0 if x % 3 == 0]\n'
	bytes := serialize_source(source, 'comp_multi_if.py')
	assert bytes.len > 0
}

fn test_serialize_comprehension_nested() {
	source := '[(x, y) for x in range(3) for y in range(3)]\n'
	bytes := serialize_source(source, 'comp_nested.py')
	assert bytes.len > 0
}

// --- Async comprehension ---
fn test_serialize_async_comprehension() {
	source := 'async def f():\n    return [x async for x in aiter()]\n'
	bytes := serialize_source(source, 'async_comp.py')
	assert bytes.len > 0
}

// ============================================================================
// Type annotation tests
// ============================================================================

fn test_serialize_type_annotation() {
	source := 'x: list[int] = [1, 2, 3]\n'
	bytes := serialize_source(source, 'type_ann.py')
	assert bytes.len > 0
}

fn test_serialize_union_type() {
	source := 'x: int | str = 5\n'
	bytes := serialize_source(source, 'union.py')
	assert bytes.len > 0
}

// ============================================================================
// Binary format specific tests
// ============================================================================

fn test_serialize_float_uses_ieee754_binary() {
	source := 'x = 3.5\n'
	filename := 'test_float.py'

	mut l := new_lexer(source, filename)
	mut p := new_parser(l)
	mod := p.parse_module()

	mut s := Serializer.new()
	bytes := s.serialize_module(mod)

	mut float_tag_index := bytes.index(literal_float)
	assert float_tag_index >= 0
	if float_tag_index < 0 { return }

	expected_bits := math.f64_bits(3.5)
	mut expected := []u8{len: 8}
	for i in 0 .. 8 {
		expected[i] = u8((expected_bits >> (i * 8)) & u64(0xff))
	}

	assert float_tag_index + 8 < bytes.len
	assert bytes[float_tag_index + 1..float_tag_index + 9] == expected
}

fn test_collect_function_arg_kinds() {
	source := 'def f(a, /, b=1, *args, c, d=2, **kwargs):\n    return a\n'
	filename := 'test_arg_kinds.py'

	mut l := new_lexer(source, filename)
	mut p := new_parser(l)
	mod := p.parse_module()

	assert mod.body.len == 1
	assert mod.body[0] is FunctionDef
	func := mod.body[0] as FunctionDef

	s := Serializer.new()
	params := s.collect_parameters(func.args)

	assert params.len == 6
	assert params[0].kind == arg_kind_pos
	assert params[0].pos_only
	assert params[1].kind == arg_kind_opt
	assert !params[1].pos_only
	assert params[2].kind == arg_kind_star
	assert params[3].kind == arg_kind_named
	assert params[4].kind == arg_kind_named_opt
	assert params[5].kind == arg_kind_star2
}

fn test_collect_call_arg_kinds_and_names() {
	source := 'result = f(a, *xs, b=1, **kw)\n'
	filename := 'test_call_arg_kinds.py'

	mut l := new_lexer(source, filename)
	mut p := new_parser(l)
	mod := p.parse_module()

	assert mod.body.len == 1
	assert mod.body[0] is Assign
	assign := mod.body[0] as Assign
	assert assign.value is Call
	call := assign.value as Call

	s := Serializer.new()
	args := s.collect_call_args(call)

	assert args.len == 4
	assert args[0].kind == arg_kind_pos
	assert args[0].name == none
	assert args[1].kind == arg_kind_star
	assert args[1].name == none
	assert args[2].kind == arg_kind_named
	assert args[2].name or { '' } == 'b'
	assert args[3].kind == arg_kind_star2
	assert args[3].name == none
}

fn test_serialize_classdef_keywords() {
	source := 'class Example(Base, metaclass=Meta, abc=helper()):\n    pass\n'
	filename := 'test_class_keywords.py'

	mut l := new_lexer(source, filename)
	mut p := new_parser(l)
	mod := p.parse_module()

	assert mod.body.len == 1
	assert mod.body[0] is ClassDef
	class_def := mod.body[0] as ClassDef

	assert class_def.keywords.len == 2
	assert class_def.keywords[0].arg == 'metaclass'
	assert class_def.keywords[1].arg == 'abc'

	mut s := Serializer.new()
	bytes := s.serialize_module(mod)

	mut metaclass_hits := 0
	mut abc_hits := 0
	for i, b in bytes {
		if b == literal_str && i + 1 < bytes.len {
			if bytes[i + 1] == 'metaclass'.len {
				metaclass_hits++
			}
			if bytes[i + 1] == 'abc'.len {
				abc_hits++
			}
		}
	}

	assert metaclass_hits > 0
	assert abc_hits > 0
}
