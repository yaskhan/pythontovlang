module main

// ==================== PARSER ====================

// Operator precedence levels
const prec_lowest      = 0
const prec_or          = 1
const prec_and         = 2
const prec_not         = 3
const prec_compare     = 4
const prec_bitor       = 5
const prec_bitxor      = 6
const prec_bitand      = 7
const prec_shift       = 8
const prec_add         = 9
const prec_mul         = 10
const prec_unary       = 11
const prec_power       = 12
const prec_call        = 13

struct Parser {
mut:
	lexer         Lexer
	current_token Token
	peek_tok       Token
	errors        []ParseError
}

fn new_parser(lexer Lexer) Parser {
	mut p := Parser{
		lexer: lexer
	}
	// Fill current and peek
	p.current_token = p.lexer.next_token()
	p.peek_tok = p.lexer.next_token()
	// Skip initial newlines
	for p.current_token.typ == .newline || p.current_token.typ == .indent || p.current_token.typ == .dedent {
		p.advance()
	}
	return p
}

fn (mut p Parser) advance() {
	p.current_token = p.peek_tok
	p.peek_tok = p.lexer.next_token()
}

fn (mut p Parser) skip_newlines() {
	for p.current_token.typ == .newline || p.current_token.typ == .semicolon {
		p.advance()
	}
}

fn (mut p Parser) expect(typ TokenType) bool {
	if p.current_token.typ == typ {
		p.advance()
		return true
	}
	p.errors << ParseError{
		message: 'expected ${typ}, got ${p.current_token.typ} ("${p.current_token.value}")'
		token:   p.current_token
	}
	return false
}

fn (mut p Parser) expect_keyword(kw string) bool {
	if p.current_token.is_keyword(kw) {
		p.advance()
		return true
	}
	p.errors << ParseError{
		message: 'expected keyword "${kw}", got "${p.current_token.value}"'
		token:   p.current_token
	}
	return false
}

fn (p &Parser) current_is(typ TokenType) bool {
	return p.current_token.typ == typ
}

fn (p &Parser) current_is_keyword(kw string) bool {
	return p.current_token.is_keyword(kw)
}

fn (p &Parser) peek_is(typ TokenType) bool {
	return p.peek_tok.typ == typ
}

fn (p &Parser) peek_is_keyword(kw string) bool {
	return p.peek_tok.is_keyword(kw)
}

// ──────────────────────────────────────────────────
// Entry point
// ──────────────────────────────────────────────────

fn (mut p Parser) parse() ?Module {
	m := p.parse_module()
	if p.errors.len > 0 {
		return none
	}
	return m
}

fn (mut p Parser) parse_module() Module {
	tok := p.current_token
	mut body := []Statement{}
	p.skip_newlines()
	for !p.current_is(.eof) {
		if stmt := p.parse_statement() {
			body << stmt
		} else {
			// Error recovery: skip to next newline
			for !p.current_is(.newline) && !p.current_is(.eof) {
				p.advance()
			}
			p.skip_newlines()
		}
	}
	return Module{token: tok, body: body, filename: tok.filename}
}

// ──────────────────────────────────────────────────
// Statements
// ──────────────────────────────────────────────────

fn (mut p Parser) parse_statement() ?Statement {
	p.skip_newlines()

	tok := p.current_token

	// Decorators
	if p.current_is(.at) {
		return p.parse_decorated()
	}

	// Async def / async for / async with
	if p.current_is_keyword('async') {
		return p.parse_async_stmt()
	}

	match true {
		p.current_is_keyword('def')      { return p.parse_function_def(false) }
		p.current_is_keyword('class')    { return p.parse_class_def() }
		p.current_is_keyword('if')       { return p.parse_if() }
		p.current_is_keyword('while')    { return p.parse_while() }
		p.current_is_keyword('for')      { return p.parse_for(false) }
		p.current_is_keyword('with')     { return p.parse_with(false) }
		p.current_is_keyword('try')      { return p.parse_try() }
		p.current_is_keyword('match')    { return p.parse_match() }
		p.current_is_keyword('return')   { return p.parse_return() }
		p.current_is_keyword('import')   { return p.parse_import() }
		p.current_is_keyword('from')     { return p.parse_import_from() }
		p.current_is_keyword('global')   { return p.parse_global() }
		p.current_is_keyword('nonlocal') { return p.parse_nonlocal() }
		p.current_is_keyword('assert')   { return p.parse_assert() }
		p.current_is_keyword('raise')    { return p.parse_raise() }
		p.current_is_keyword('del')      { return p.parse_delete() }
		p.current_is_keyword('pass')     {
			s := Pass{token: tok}
			p.advance(); p.skip_newlines()
			return s
		}
		p.current_is_keyword('break')    {
			s := Break{token: tok}
			p.advance(); p.skip_newlines()
			return s
		}
		p.current_is_keyword('continue') {
			s := Continue{token: tok}
			p.advance(); p.skip_newlines()
			return s
		}
		else { return p.parse_expression_stmt() }
	}
	_ = tok
	return none
}

fn (mut p Parser) parse_block() []Statement {
	mut stmts := []Statement{}
	p.expect(.colon)
	p.skip_newlines()

	// Inline single statement: def f(): pass
	if !p.current_is(.indent) {
		if stmt := p.parse_statement() {
			stmts << stmt
		}
		return stmts
	}
	p.advance() // consume INDENT

	for !p.current_is(.dedent) && !p.current_is(.eof) {
		p.skip_newlines()
		if p.current_is(.dedent) || p.current_is(.eof) { break }
		if stmt := p.parse_statement() {
			stmts << stmt
		} else {
			for !p.current_is(.newline) && !p.current_is(.eof) {
				p.advance()
			}
		}
	}
	if p.current_is(.dedent) {
		p.advance()
	}
	return stmts
}

fn (mut p Parser) parse_decorated() ?Statement {
	mut decorators := []Expression{}
	for p.current_is(.at) {
		p.advance() // skip @
		if expr := p.parse_expression() {
			decorators << expr
		}
		p.skip_newlines()
	}
	if p.current_is_keyword('async') {
		p.advance()
	}
	if p.current_is_keyword('def') {
		mut fd := p.parse_function_def(false)?
		if mut fd is FunctionDef {
			return FunctionDef{...fd, decorators: decorators}
		}
		return fd
	}
	if p.current_is_keyword('class') {
		mut cd := p.parse_class_def()?
		return cd
	}
	p.errors << ParseError{message: 'expected def or class after decorator', token: p.current_token}
	return none
}

fn (mut p Parser) parse_async_stmt() ?Statement {
	p.advance() // skip 'async'
	if p.current_is_keyword('def') {
		mut stmt := p.parse_function_def(true)?
		return stmt
	}
	if p.current_is_keyword('for') {
		return p.parse_for(true)
	}
	if p.current_is_keyword('with') {
		return p.parse_with(true)
	}
	p.errors << ParseError{message: 'expected def/for/with after async', token: p.current_token}
	return none
}

fn (mut p Parser) parse_function_def(is_async bool) ?Statement {
	tok := p.current_token
	p.advance() // skip 'def'
	name := p.current_token.value
	p.expect(.identifier)
	params := p.parse_parameters()
	mut returns := ?Expression(none)
	if p.current_is(.arrow) {
		p.advance()
		returns = p.parse_expression()
	}
	body := p.parse_block()
	return FunctionDef{
		token:    tok
		name:     name
		params:   params
		body:     body
		returns:  returns
		is_async: is_async
	}
}

fn (mut p Parser) parse_parameters() []Parameter {
	mut params := []Parameter{}
	p.expect(.lparen)
	if p.current_is(.rparen) {
		p.advance()
		return params
	}
	mut kind := ParamKind.positional_or_keyword
	for !p.current_is(.rparen) && !p.current_is(.eof) {
		if p.current_is(.operator) && p.current_token.value == '*' {
			p.advance()
			if p.current_is(.comma) {
				// bare * => next params are keyword-only
				kind = .keyword_only
				p.advance()
				continue
			}
			name := p.current_token.value
			p.advance()
			params << Parameter{name: name, kind: .var_positional}
			kind = .keyword_only
		} else if p.current_is(.operator) && p.current_token.value == '**' {
			p.advance()
			name := p.current_token.value
			p.advance()
			params << Parameter{name: name, kind: .var_keyword}
		} else {
			name := p.current_token.value
			p.advance()
			mut annotation := ?Expression(none)
			mut default_ := ?Expression(none)
			if p.current_is(.colon) {
				p.advance()
				annotation = p.parse_expression()
			}
			if p.current_is(.operator) && p.current_token.value == '=' {
				p.advance()
				default_ = p.parse_expression()
			}
			params << Parameter{
				name:       name
				annotation: annotation
				default_:   default_
				kind:       kind
			}
		}
		if p.current_is(.comma) {
			p.advance()
		} else {
			break
		}
	}
	p.expect(.rparen)
	return params
}

fn (mut p Parser) parse_class_def() ?Statement {
	tok := p.current_token
	p.advance() // skip 'class'
	name := p.current_token.value
	p.expect(.identifier)
	mut bases := []Expression{}
	mut kwd_args := []KeywordArg{}
	if p.current_is(.lparen) {
		p.advance()
		for !p.current_is(.rparen) && !p.current_is(.eof) {
			// keyword arg: metaclass=Meta
			if p.current_is(.identifier) && p.peek_is(.operator) && p.peek_tok.value == '=' {
				kw_name := p.current_token.value
				p.advance(); p.advance()
				if val := p.parse_expression() {
					kwd_args << KeywordArg{name: kw_name, value: val}
				}
			} else {
				if expr := p.parse_expression() {
					bases << expr
				}
			}
			if p.current_is(.comma) { p.advance() } else { break }
		}
		p.expect(.rparen)
	}
	body := p.parse_block()
	return ClassDef{token: tok, name: name, bases: bases, keywords: kwd_args, body: body}
}

fn (mut p Parser) parse_if() ?Statement {
	tok := p.current_token
	p.advance() // skip 'if'
	test := p.parse_expression() or {
		p.errors << ParseError{message: 'expected condition in if', token: tok}
		return none
	}
	body := p.parse_block()
	mut orelse := []Statement{}
	p.skip_newlines()
	if p.current_is_keyword('elif') {
		if elif_stmt := p.parse_if_elif() {
			orelse << elif_stmt
		}
	} else if p.current_is_keyword('else') {
		p.advance()
		orelse = p.parse_block()
	}
	return If{token: tok, test: test, body: body, orelse: orelse}
}

fn (mut p Parser) parse_if_elif() ?Statement {
	tok := p.current_token
	p.advance() // skip 'elif'
	test := p.parse_expression() or { return none }
	body := p.parse_block()
	mut orelse := []Statement{}
	p.skip_newlines()
	if p.current_is_keyword('elif') {
		if stmt := p.parse_if_elif() { orelse << stmt }
	} else if p.current_is_keyword('else') {
		p.advance()
		orelse = p.parse_block()
	}
	return If{token: tok, test: test, body: body, orelse: orelse}
}

fn (mut p Parser) parse_while() ?Statement {
	tok := p.current_token
	p.advance()
	test := p.parse_expression() or { return none }
	body := p.parse_block()
	mut orelse := []Statement{}
	p.skip_newlines()
	if p.current_is_keyword('else') {
		p.advance()
		orelse = p.parse_block()
	}
	return While{token: tok, test: test, body: body, orelse: orelse}
}

fn (mut p Parser) parse_for(is_async bool) ?Statement {
	tok := p.current_token
	p.advance() // skip 'for'
	target := p.parse_expression() or { return none }
	p.expect_keyword('in')
	iter := p.parse_expression() or { return none }
	body := p.parse_block()
	mut orelse := []Statement{}
	p.skip_newlines()
	if p.current_is_keyword('else') {
		p.advance()
		orelse = p.parse_block()
	}
	return For{token: tok, target: target, iter: iter, body: body, orelse: orelse, is_async: is_async}
}

fn (mut p Parser) parse_with(is_async bool) ?Statement {
	tok := p.current_token
	p.advance()
	mut items := []WithItem{}
	for !p.current_is(.colon) && !p.current_is(.eof) {
		ctx := p.parse_expression() or { break }
		mut opt_vars := ?Expression(none)
		if p.current_is_keyword('as') {
			p.advance()
			opt_vars = p.parse_expression()
		}
		items << WithItem{context_expr: ctx, optional_vars: opt_vars}
		if p.current_is(.comma) { p.advance() } else { break }
	}
	body := p.parse_block()
	return With{token: tok, items: items, body: body, is_async: is_async}
}

fn (mut p Parser) parse_try() ?Statement {
	tok := p.current_token
	p.advance()
	body := p.parse_block()
	mut handlers := []ExceptHandler{}
	mut orelse := []Statement{}
	mut finalbody := []Statement{}
	p.skip_newlines()
	for p.current_is_keyword('except') {
		htok := p.current_token
		p.advance()
		mut typ := ?Expression(none)
		mut hname := ?string(none)
		if !p.current_is(.colon) {
			typ = p.parse_expression()
			if p.current_is_keyword('as') {
				p.advance()
				hname = p.current_token.value
				p.advance()
			}
		}
		hbody := p.parse_block()
		handlers << ExceptHandler{token: htok, typ: typ, name: hname, body: hbody}
		p.skip_newlines()
	}
	if p.current_is_keyword('else') {
		p.advance()
		orelse = p.parse_block()
		p.skip_newlines()
	}
	if p.current_is_keyword('finally') {
		p.advance()
		finalbody = p.parse_block()
	}
	return Try{token: tok, body: body, handlers: handlers, orelse: orelse, finalbody: finalbody}
}

fn (mut p Parser) parse_match() ?Statement {
	tok := p.current_token
	p.advance()
	subject := p.parse_expression() or { return none }
	p.expect(.colon)
	p.skip_newlines()
	p.expect(.indent)
	mut cases := []MatchCase{}
	for !p.current_is(.dedent) && !p.current_is(.eof) {
		p.skip_newlines()
		if p.current_is(.dedent) || p.current_is(.eof) { break }
		if !p.current_is_keyword('case') {
			p.advance(); continue
		}
		p.advance() // skip 'case'
		pattern := p.parse_pattern()
		mut guard := ?Expression(none)
		if p.current_is_keyword('if') {
			p.advance()
			guard = p.parse_expression()
		}
		cbody := p.parse_block()
		cases << MatchCase{pattern: pattern, guard: guard, body: cbody}
		p.skip_newlines()
	}
	if p.current_is(.dedent) { p.advance() }
	return Match{token: tok, subject: subject, cases: cases}
}

fn (mut p Parser) parse_return() ?Statement {
	tok := p.current_token
	p.advance()
	mut value := ?Expression(none)
	if !p.current_is(.newline) && !p.current_is(.semicolon) && !p.current_is(.eof) {
		value = p.parse_expression()
	}
	p.skip_newlines()
	return Return{token: tok, value: value}
}

fn (mut p Parser) parse_import() ?Statement {
	tok := p.current_token
	p.advance()
	mut names := []Alias{}
	for {
		name := p.current_token.value
		p.advance()
		mut asname := ?string(none)
		if p.current_is_keyword('as') {
			p.advance()
			asname = p.current_token.value
			p.advance()
		}
		names << Alias{name: name, asname: asname}
		if p.current_is(.comma) { p.advance() } else { break }
	}
	p.skip_newlines()
	return Import{token: tok, names: names}
}

fn (mut p Parser) parse_import_from() ?Statement {
	tok := p.current_token
	p.advance() // skip 'from'
	mut level := 0
	for p.current_is(.dot) { level++; p.advance() }
	module_name := if p.current_is(.identifier) { n := p.current_token.value; p.advance(); n } else { '' }
	p.expect_keyword('import')
	mut names := []Alias{}
	if p.current_is(.operator) && p.current_token.value == '*' {
		names << Alias{name: '*'}
		p.advance()
	} else {
		in_parens := p.current_is(.lparen)
		if in_parens { p.advance() }
		for !p.current_is(.rparen) && !p.current_is(.newline) && !p.current_is(.eof) {
			n := p.current_token.value; p.advance()
			mut asname := ?string(none)
			if p.current_is_keyword('as') { p.advance(); asname = p.current_token.value; p.advance() }
			names << Alias{name: n, asname: asname}
			if p.current_is(.comma) { p.advance() } else { break }
		}
		if in_parens { p.expect(.rparen) }
	}
	p.skip_newlines()
	return ImportFrom{token: tok, module: module_name, names: names, level: level}
}

fn (mut p Parser) parse_global() ?Statement {
	tok := p.current_token; p.advance()
	mut names := []string{}
	names << p.current_token.value; p.advance()
	for p.current_is(.comma) { p.advance(); names << p.current_token.value; p.advance() }
	p.skip_newlines()
	return Global{token: tok, names: names}
}

fn (mut p Parser) parse_nonlocal() ?Statement {
	tok := p.current_token; p.advance()
	mut names := []string{}
	names << p.current_token.value; p.advance()
	for p.current_is(.comma) { p.advance(); names << p.current_token.value; p.advance() }
	p.skip_newlines()
	return Nonlocal{token: tok, names: names}
}

fn (mut p Parser) parse_assert() ?Statement {
	tok := p.current_token; p.advance()
	test := p.parse_expression() or { return none }
	mut msg := ?Expression(none)
	if p.current_is(.comma) { p.advance(); msg = p.parse_expression() }
	p.skip_newlines()
	return Assert{token: tok, test: test, msg: msg}
}

fn (mut p Parser) parse_raise() ?Statement {
	tok := p.current_token; p.advance()
	mut exception := ?Expression(none)
	mut cause := ?Expression(none)
	if !p.current_is(.newline) && !p.current_is(.eof) {
		exception = p.parse_expression()
		if p.current_is_keyword('from') { p.advance(); cause = p.parse_expression() }
	}
	p.skip_newlines()
	return Raise{token: tok, exception: exception, cause: cause}
}

fn (mut p Parser) parse_delete() ?Statement {
	tok := p.current_token; p.advance()
	mut targets := []Expression{}
	if expr := p.parse_expression() { targets << expr }
	for p.current_is(.comma) { p.advance(); if e := p.parse_expression() { targets << e } }
	p.skip_newlines()
	return Delete{token: tok, targets: targets}
}

fn (mut p Parser) parse_expression_stmt() ?Statement {
	tok := p.current_token
	expr := p.parse_expression() or { return none }

	// Augmented assignment: x += 1
	if p.current_is(.operator) {
		aug_ops := ['+=', '-=', '*=', '/=', '//=', '%=', '**=', '&=', '|=', '^=', '>>=', '<<=', '@=']
		if p.current_token.value in aug_ops {
			op := p.current_token
			p.advance()
			val := p.parse_expression() or { return none }
			p.skip_newlines()
			return AugmentedAssignment{token: tok, target: expr, operator: op, value: val}
		}
	}

	// Annotated assignment: x: int = 5
	if p.current_is(.colon) {
		p.advance()
		ann := p.parse_expression() or { return none }
		mut value := ?Expression(none)
		if p.current_is(.operator) && p.current_token.value == '=' {
			p.advance()
			value = p.parse_expression()
		}
		p.skip_newlines()
		return AnnAssignment{token: tok, target: expr, annotation: ann, value: value}
	}

	// Regular assignment: a = b = expr
	if p.current_is(.operator) && p.current_token.value == '=' {
		mut targets := [expr]
		mut val := expr
		for p.current_is(.operator) && p.current_token.value == '=' {
			p.advance()
			val = p.parse_expression() or { return none }
			if p.current_is(.operator) && p.current_token.value == '=' {
				targets << val
			}
		}
		p.skip_newlines()
		return Assignment{token: tok, targets: targets, value: val}
	}

	p.skip_newlines()
	return ExpressionStmt{token: tok, expression: expr}
}

// ──────────────────────────────────────────────────
// Expressions — Pratt parser
// ──────────────────────────────────────────────────

fn token_precedence(tok Token) int {
	if tok.typ == .keyword {
		match tok.value {
			'or'  { return prec_or }
			'and' { return prec_and }
			'not' { return prec_not }
			'in', 'is' { return prec_compare }
			else  { return prec_lowest }
		}
	}
	if tok.typ == .operator {
		match tok.value {
			'|'       { return prec_bitor }
			'^'       { return prec_bitxor }
			'&'       { return prec_bitand }
			'<<', '>>'{ return prec_shift }
			'+', '-'  { return prec_add }
			'*', '/', '//', '%', '@' { return prec_mul }
			'**'      { return prec_power }
			'==', '!=', '<', '>', '<=', '>=' { return prec_compare }
			else { return prec_lowest }
		}
	}
	if tok.typ == .lparen || tok.typ == .lbracket || tok.typ == .dot {
		return prec_call
	}
	return prec_lowest
}

fn (mut p Parser) parse_expression() ?Expression {
	return p.parse_binary_expr(prec_lowest)
}

fn (mut p Parser) parse_binary_expr(precedence int) ?Expression {
	mut left := p.parse_unary_expr() or { return none }

	for {
		// Ternary (if-expr): x if cond else y
		if p.current_is_keyword('if') {
			p.advance()
			test := p.parse_expression() or { return left }
			p.expect_keyword('else')
			orelse := p.parse_expression() or { return left }
			left = IfExpr{token: left.get_token(), test: test, body: left, orelse: orelse}
			continue
		}

		// 'not in' and 'is not'
		if p.current_is_keyword('not') && p.peek_is_keyword('in') {
			op1 := p.current_token; p.advance(); p.advance()
			right := p.parse_unary_expr() or { break }
			left = BinaryOp{token: op1, left: left, operator: Token{typ: .keyword, value: 'not in'}, right: right}
			continue
		}
		if p.current_is_keyword('is') && p.peek_is_keyword('not') {
			op1 := p.current_token; p.advance(); p.advance()
			right := p.parse_unary_expr() or { break }
			left = BinaryOp{token: op1, left: left, operator: Token{typ: .keyword, value: 'is not'}, right: right}
			continue
		}

		prec := token_precedence(p.current_token)
		if prec <= precedence { break }

		op := p.current_token
		p.advance()
		right := p.parse_binary_expr(prec) or { break }
		left = BinaryOp{token: op, left: left, operator: op, right: right}
	}
	return left
}

fn (mut p Parser) parse_unary_expr() ?Expression {
	tok := p.current_token
	if p.current_is_keyword('not') {
		p.advance()
		operand := p.parse_unary_expr() or { return none }
		return UnaryOp{token: tok, operator: tok, operand: operand}
	}
	if p.current_is(.operator) && (tok.value == '-' || tok.value == '+' || tok.value == '~') {
		p.advance()
		operand := p.parse_unary_expr() or { return none }
		return UnaryOp{token: tok, operator: tok, operand: operand}
	}
	if p.current_is_keyword('await') {
		p.advance()
		val := p.parse_unary_expr() or { return none }
		return Await{token: tok, value: val}
	}
	if p.current_is_keyword('yield') {
		p.advance()
		if p.current_is_keyword('from') {
			p.advance()
			val := p.parse_expression() or { return none }
			return YieldFrom{token: tok, value: val}
		}
		mut yval := ?Expression(none)
		if !p.current_is(.newline) && !p.current_is(.rparen) && !p.current_is(.eof) {
			yval = p.parse_expression()
		}
		return Yield{token: tok, value: yval}
	}
	if p.current_is_keyword('lambda') {
		return p.parse_lambda()
	}
	return p.parse_postfix_expr()
}

fn (mut p Parser) parse_postfix_expr() ?Expression {
	mut expr := p.parse_primary_expr() or { return none }

	for {
		if p.current_is(.lparen) {
			expr = p.parse_call(expr)
		} else if p.current_is(.lbracket) {
			expr = p.parse_subscript(expr)
		} else if p.current_is(.dot) {
			expr = p.parse_attribute(expr)
		} else {
			break
		}
	}
	return expr
}

fn (mut p Parser) parse_primary_expr() ?Expression {
	tok := p.current_token

	match true {
		p.current_is(.identifier) {
			p.advance()
			match tok.value {
				'True'  { return BoolLiteral{token: tok, value: true} }
				'False' { return BoolLiteral{token: tok, value: false} }
				'None'  { return NoneLiteral{token: tok} }
				else    { return Identifier{token: tok, name: tok.value} }
			}
		}
		p.current_is(.keyword) && tok.value in ['True', 'False', 'None'] {
			p.advance()
			match tok.value {
				'True'  { return BoolLiteral{token: tok, value: true} }
				'False' { return BoolLiteral{token: tok, value: false} }
				else    { return NoneLiteral{token: tok} }
			}
		}
		p.current_is(.number) {
			p.advance()
			raw := tok.value
			is_int := !raw.contains('.') && !raw.to_lower().contains('e') && !raw.ends_with('j')
			val := raw.f64()
			return NumberLiteral{token: tok, value: val, is_int: is_int, raw: raw}
		}
		p.current_is(.string_tok) {
			mut val := tok.value
			p.advance()
			// Concatenate adjacent strings
			for p.current_is(.string_tok) {
				val += p.current_token.value
				p.advance()
			}
			return StringLiteral{token: tok, value: val, raw: val}
		}
		p.current_is(.ellipsis) {
			p.advance()
			return NoneLiteral{token: tok} // represent Ellipsis as NoneLiteral for simplicity
		}
		p.current_is(.lbracket) { return p.parse_list() }
		p.current_is(.lbrace)   { return p.parse_dict_or_set() }
		p.current_is(.lparen)   { return p.parse_paren_expr() }
		p.current_is(.operator) && tok.value == '*' {
			p.advance()
			val := p.parse_expression() or { return none }
			return StarredExpr{token: tok, value: val}
		}
		else {
			p.errors << ParseError{message: 'unexpected token in expression: ${tok.value}', token: tok}
			return none
		}
	}
}

fn (mut p Parser) parse_paren_expr() ?Expression {
	tok := p.current_token
	p.advance() // (
	if p.current_is(.rparen) {
		p.advance()
		return TupleLiteral{token: tok, elements: []}
	}
	expr := p.parse_expression() or { return none }

	// Generator expression
	if p.current_is_keyword('for') {
		gens := p.parse_comprehensions()
		p.expect(.rparen)
		return GeneratorExp{token: tok, elt: expr, generators: gens}
	}

	// Tuple
	if p.current_is(.comma) {
		mut elems := [expr]
		for p.current_is(.comma) {
			p.advance()
			if p.current_is(.rparen) { break }
			if e := p.parse_expression() { elems << e }
		}
		p.expect(.rparen)
		return TupleLiteral{token: tok, elements: elems}
	}
	p.expect(.rparen)
	return expr
}

fn (mut p Parser) parse_list() ?Expression {
	tok := p.current_token
	p.advance() // [
	if p.current_is(.rbracket) {
		p.advance()
		return ListLiteral{token: tok, elements: []}
	}
	first := p.parse_expression() or { return none }
	// List comprehension
	if p.current_is_keyword('for') {
		gens := p.parse_comprehensions()
		p.expect(.rbracket)
		return ListComp{token: tok, elt: first, generators: gens}
	}
	mut elems := [first]
	for p.current_is(.comma) {
		p.advance()
		if p.current_is(.rbracket) { break }
		if e := p.parse_expression() { elems << e }
	}
	p.expect(.rbracket)
	return ListLiteral{token: tok, elements: elems}
}

fn (mut p Parser) parse_dict_or_set() ?Expression {
	tok := p.current_token
	p.advance() // {
	if p.current_is(.rbrace) {
		p.advance()
		return DictLiteral{token: tok, pairs: []}
	}
	first := p.parse_expression() or { return none }
	// Dict
	if p.current_is(.colon) {
		p.advance()
		fval := p.parse_expression() or { return none }
		// Dict comprehension
		if p.current_is_keyword('for') {
			gens := p.parse_comprehensions()
			p.expect(.rbrace)
			return DictComp{token: tok, key: first, value: fval, generators: gens}
		}
		mut pairs := [DictEntry{key: first, value: fval}]
		for p.current_is(.comma) {
			p.advance()
			if p.current_is(.rbrace) { break }
			k := p.parse_expression() or { break }
			p.expect(.colon)
			v := p.parse_expression() or { break }
			pairs << DictEntry{key: k, value: v}
		}
		p.expect(.rbrace)
		return DictLiteral{token: tok, pairs: pairs}
	}
	// Set / set comprehension
	if p.current_is_keyword('for') {
		gens := p.parse_comprehensions()
		p.expect(.rbrace)
		return SetComp{token: tok, elt: first, generators: gens}
	}
	mut elems := [first]
	for p.current_is(.comma) {
		p.advance()
		if p.current_is(.rbrace) { break }
		if e := p.parse_expression() { elems << e }
	}
	p.expect(.rbrace)
	return SetLiteral{token: tok, elements: elems}
}

fn (mut p Parser) parse_comprehensions() []Comprehension {
	mut gens := []Comprehension{}
	for p.current_is_keyword('for') {
		p.advance()
		target := p.parse_expression() or { break }
		p.expect_keyword('in')
		iter := p.parse_expression() or { break }
		mut ifs := []Expression{}
		for p.current_is_keyword('if') {
			p.advance()
			if cond := p.parse_expression() { ifs << cond }
		}
		gens << Comprehension{target: target, iter: iter, ifs: ifs}
	}
	return gens
}

fn (mut p Parser) parse_call(func Expression) Expression {
	tok := p.current_token
	p.advance() // (
	mut args := []Expression{}
	mut kwd_args := []KeywordArg{}
	for !p.current_is(.rparen) && !p.current_is(.eof) {
		// **kwargs
		if p.current_is(.operator) && p.current_token.value == '**' {
			p.advance()
			if e := p.parse_expression() { kwd_args << KeywordArg{name: '**', value: e} }
		} else if p.current_is(.operator) && p.current_token.value == '*' {
			p.advance()
			if e := p.parse_expression() { args << StarredExpr{token: tok, value: e} }
		} else if p.current_is(.identifier) && p.peek_is(.operator) && p.peek_tok.value == '=' {
			kname := p.current_token.value; p.advance(); p.advance()
			if v := p.parse_expression() { kwd_args << KeywordArg{name: kname, value: v} }
		} else {
			if e := p.parse_expression() { args << e }
		}
		if p.current_is(.comma) { p.advance() } else { break }
	}
	p.expect(.rparen)
	return Call{token: tok, func: func, args: args, keywords: kwd_args}
}

fn (mut p Parser) parse_subscript(value Expression) Expression {
	tok := p.current_token
	p.advance() // [
	// Slice
	if p.current_is(.colon) {
		p.advance()
		mut upper := ?Expression(none)
		mut step := ?Expression(none)
		if !p.current_is(.colon) && !p.current_is(.rbracket) { upper = p.parse_expression() }
		if p.current_is(.colon) { p.advance(); if !p.current_is(.rbracket) { step = p.parse_expression() } }
		p.expect(.rbracket)
		sl := Slice{token: tok, lower: none, upper: upper, step: step}
		return Subscript{token: tok, value: value, slice: sl}
	}
	idx := p.parse_expression() or { return value }
	if p.current_is(.colon) {
		p.advance()
		mut upper := ?Expression(none)
		mut step := ?Expression(none)
		if !p.current_is(.colon) && !p.current_is(.rbracket) { upper = p.parse_expression() }
		if p.current_is(.colon) { p.advance(); if !p.current_is(.rbracket) { step = p.parse_expression() } }
		p.expect(.rbracket)
		sl := Slice{token: tok, lower: idx, upper: upper, step: step}
		return Subscript{token: tok, value: value, slice: sl}
	}
	p.expect(.rbracket)
	return Subscript{token: tok, value: value, slice: idx}
}

fn (mut p Parser) parse_attribute(value Expression) Expression {
	tok := p.current_token
	p.advance() // .
	attr := p.current_token.value
	p.advance()
	return Attribute{token: tok, value: value, attr: attr}
}

fn (mut p Parser) parse_lambda() ?Expression {
	tok := p.current_token
	p.advance() // skip 'lambda'
	mut params := []Parameter{}
	for !p.current_is(.colon) && !p.current_is(.eof) {
		name := p.current_token.value; p.advance()
		mut def_ := ?Expression(none)
		if p.current_is(.operator) && p.current_token.value == '=' { p.advance(); def_ = p.parse_expression() }
		params << Parameter{name: name, kind: .positional_or_keyword, default_: def_}
		if p.current_is(.comma) { p.advance() } else { break }
	}
	p.expect(.colon)
	body := p.parse_expression() or { return none }
	return Lambda{token: tok, params: params, body: body}
}

// ──────────────────────────────────────────────────
// Patterns (match statement)
// ──────────────────────────────────────────────────

fn (mut p Parser) parse_pattern() Pattern {
	tok := p.current_token
	mut pat := p.parse_pattern_atom()

	// OR pattern: p1 | p2
	if p.current_is(.operator) && p.current_token.value == '|' {
		mut patterns := [pat]
		for p.current_is(.operator) && p.current_token.value == '|' {
			p.advance()
			patterns << p.parse_pattern_atom()
		}
		return MatchOr{token: tok, patterns: patterns}
	}

	// AS pattern
	if p.current_is_keyword('as') {
		p.advance()
		name := p.current_token.value; p.advance()
		return MatchAs{token: tok, pattern: pat, name: name}
	}

	return pat
}

fn (mut p Parser) parse_pattern_atom() Pattern {
	tok := p.current_token

	// Wildcard _
	if p.current_is(.identifier) && tok.value == '_' {
		p.advance()
		return MatchAs{token: tok, pattern: none, name: none}
	}

	// Capture variable
	if p.current_is(.identifier) {
		name := tok.value; p.advance()
		// Class pattern: Name(...)
		if p.current_is(.lparen) {
			cls := Identifier{token: tok, name: name}
			p.advance()
			mut patterns := []Pattern{}
			mut kwd_attrs := []string{}
			mut kwd_patterns := []Pattern{}
			for !p.current_is(.rparen) && !p.current_is(.eof) {
				if p.current_is(.identifier) && p.peek_is(.operator) && p.peek_tok.value == '=' {
					kname := p.current_token.value; p.advance(); p.advance()
					kwd_attrs << kname
					kwd_patterns << p.parse_pattern_atom()
				} else {
					patterns << p.parse_pattern_atom()
				}
				if p.current_is(.comma) { p.advance() } else { break }
			}
			p.expect(.rparen)
			return MatchClass{token: tok, cls: cls, patterns: patterns, kwd_attrs: kwd_attrs, kwd_patterns: kwd_patterns}
		}
		// Dotted name => MatchValue
		if p.current_is(.dot) {
			mut expr := Expression(Identifier{token: tok, name: name})
			for p.current_is(.dot) {
				p.advance()
				attr := p.current_token.value; p.advance()
				expr = Attribute{token: tok, value: expr, attr: attr}
			}
			return MatchValue{token: tok, value: expr}
		}
		return MatchAs{token: tok, pattern: none, name: name}
	}

	// Literals
	if p.current_is(.number) || p.current_is(.string_tok) {
		if expr := p.parse_expression() {
			return MatchValue{token: tok, value: expr}
		}
	}

	// Singleton None/True/False
	if p.current_is(.keyword) && tok.value in ['None', 'True', 'False'] {
		vtok := tok; p.advance()
		return MatchSingleton{token: vtok, value: vtok}
	}

	// Sequence pattern [...]
	if p.current_is(.lbracket) {
		p.advance()
		mut patterns := []Pattern{}
		for !p.current_is(.rbracket) && !p.current_is(.eof) {
			patterns << p.parse_pattern()
			if p.current_is(.comma) { p.advance() } else { break }
		}
		p.expect(.rbracket)
		return MatchSequence{token: tok, patterns: patterns}
	}

	// Sequence pattern (...)
	if p.current_is(.lparen) {
		p.advance()
		mut patterns := []Pattern{}
		for !p.current_is(.rparen) && !p.current_is(.eof) {
			patterns << p.parse_pattern()
			if p.current_is(.comma) { p.advance() } else { break }
		}
		p.expect(.rparen)
		return MatchSequence{token: tok, patterns: patterns}
	}

	// Mapping pattern {k: p, ...}
	if p.current_is(.lbrace) {
		p.advance()
		mut keys := []Expression{}
		mut patterns := []Pattern{}
		mut rest := ?string(none)
		for !p.current_is(.rbrace) && !p.current_is(.eof) {
			if p.current_is(.operator) && p.current_token.value == '**' {
				p.advance(); rest = p.current_token.value; p.advance()
				break
			}
			if k := p.parse_expression() { keys << k }
			p.expect(.colon)
			patterns << p.parse_pattern()
			if p.current_is(.comma) { p.advance() } else { break }
		}
		p.expect(.rbrace)
		return MatchMapping{token: tok, keys: keys, patterns: patterns, rest: rest}
	}

	// Star pattern: *name
	if p.current_is(.operator) && tok.value == '*' {
		p.advance()
		mut sname := ?string(none)
		if p.current_is(.identifier) { sname = p.current_token.value; p.advance() }
		return MatchStar{token: tok, name: sname}
	}

	// Negative number
	if p.current_is(.operator) && tok.value == '-' {
		p.advance()
		if expr := p.parse_expression() {
			neg := UnaryOp{token: tok, operator: tok, operand: expr}
			return MatchValue{token: tok, value: neg}
		}
	}

	return MatchAs{token: tok, pattern: none, name: none}
}
