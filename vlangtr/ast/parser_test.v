module ast

fn test_parse_literal() {
	mut l := new_lexer('123', 'test.py')
	mut p := new_parser(l)
	expr := p.parse_expression() or { panic(err.msg) }

	assert expr is Constant
	c := expr as Constant
	assert c.value == '123'
}

fn test_parse_binop() {
	mut l := new_lexer('1 + 2', 'test.py')
	mut p := new_parser(l)
	expr := p.parse_expression() or { panic(err.msg) }

	assert expr is BinaryOp
	b := expr as BinaryOp
	assert b.op.value == '+'
	assert b.left is Constant
	assert b.right is Constant
}

fn test_parse_tstring() {
	mut l := new_lexer('t"hello"', 'test.py')
	mut p := new_parser(l)
	expr := p.parse_expression() or { panic(err.msg) }

	assert expr is Constant
	c := expr as Constant
	assert c.value == "t'hello'"
}

fn test_parse_fstring() {
	mut l := new_lexer('f"hi {name}"', 'test.py')
	mut p := new_parser(l)
	expr := p.parse_expression() or { panic(err.msg) }

	assert expr is JoinedStr
	js := expr as JoinedStr
	assert js.values.len == 2
	assert js.values[0] is Constant
	assert js.values[1] is FormattedValue
}
