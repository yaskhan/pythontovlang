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

fn test_parse_match_or_as_pattern() {
	source := 'match value:\n    case int() | float() as number if number < 0:\n        pass\n'
	mut l := new_lexer(source, 'test.py')
	mut p := new_parser(l)
	mod := p.parse_module()

	assert p.errors.len == 0
	assert mod.body.len == 1
	assert mod.body[0] is Match

	match_stmt := mod.body[0] as Match
	assert match_stmt.cases.len == 1

	pattern := match_stmt.cases[0].pattern
	assert pattern is MatchAs

	match_as := pattern as MatchAs
	assert match_as.name or { '' } == 'number'
	assert match_as.pattern or { panic('expected inner pattern') } is MatchOr

	match_or := match_as.pattern or { panic('expected inner pattern') } as MatchOr
	assert match_or.patterns.len == 2
}
