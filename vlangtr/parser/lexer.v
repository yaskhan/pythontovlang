module main

// ==================== LEXER ====================

struct Lexer {
mut:
	source          string
	filename        string
	pos             int
	line            int
	column          int
	indent_stack    []int
	pending_dedents  int
	peeked          ?Token
}

fn new_lexer(source string, filename string) Lexer {
	return Lexer{
		source:       source
		filename:     filename
		pos:          0
		line:         1
		column:       1
		indent_stack: [0]
	}
}

fn (l &Lexer) make_token(typ TokenType, value string) Token {
	return Token{
		typ:      typ
		value:    value
		line:     l.line
		column:   l.column
		filename: l.filename
	}
}

fn (mut l Lexer) peek_char() u8 {
	if l.pos >= l.source.len {
		return 0
	}
	return l.source[l.pos]
}

fn (mut l Lexer) peek_char_at(offset int) u8 {
	idx := l.pos + offset
	if idx >= l.source.len {
		return 0
	}
	return l.source[idx]
}

fn (mut l Lexer) advance_char() u8 {
	if l.pos >= l.source.len {
		return 0
	}
	ch := l.source[l.pos]
	l.pos++
	if ch == `\n` {
		l.line++
		l.column = 1
	} else {
		l.column++
	}
	return ch
}

fn (mut l Lexer) skip_comment() {
	for l.pos < l.source.len && l.peek_char() != `\n` {
		l.advance_char()
	}
}

fn (mut l Lexer) skip_whitespace_inline() {
	for l.pos < l.source.len {
		ch := l.peek_char()
		if ch == ` ` || ch == `\t` || ch == `\r` {
			l.advance_char()
		} else if ch == `\\` && l.peek_char_at(1) == `\n` {
			l.advance_char()
			l.advance_char()
		} else {
			break
		}
	}
}

fn (mut l Lexer) handle_indentation() ?Token {
	// Count leading spaces/tabs
	indent := 0
	mut col := 0
	for l.pos < l.source.len {
		ch := l.peek_char()
		if ch == ` ` {
			col++
			l.advance_char()
		} else if ch == `\t` {
			col = (col / 8 + 1) * 8
			l.advance_char()
		} else {
			break
		}
	}
	_ = indent

	// Skip blank lines and comments
	if l.pos < l.source.len {
		ch := l.peek_char()
		if ch == `\n` || ch == `\r` || ch == `#` {
			return none
		}
	} else {
		// End of file - emit dedents
		for l.indent_stack.len > 1 {
			l.indent_stack.pop()
			l.pending_dedents++
		}
		return none
	}

	current_indent := l.indent_stack.last()

	if col > current_indent {
		l.indent_stack << col
		return l.make_token(.indent, '')
	} else if col < current_indent {
		for l.indent_stack.len > 1 && l.indent_stack.last() > col {
			l.indent_stack.pop()
			l.pending_dedents++
		}
		if l.pending_dedents > 0 {
			l.pending_dedents--
			return l.make_token(.dedent, '')
		}
	}
	return none
}

fn (mut l Lexer) scan_identifier() Token {
	start := l.pos
	start_col := l.column
	for l.pos < l.source.len {
		ch := l.peek_char()
		if ch.is_letter() || ch == `_` || ch.is_digit() {
			l.advance_char()
		} else {
			break
		}
	}
	value := l.source[start..l.pos]
	if is_keyword(value) {
		return Token{typ: .keyword, value: value, line: l.line, column: start_col, filename: l.filename}
	}
	return Token{typ: .identifier, value: value, line: l.line, column: start_col, filename: l.filename}
}

fn (mut l Lexer) scan_number() Token {
	start := l.pos
	start_col := l.column
	// Hex, octal, binary
	if l.peek_char() == `0` && l.pos + 1 < l.source.len {
		next := l.peek_char_at(1)
		if next == `x` || next == `X` || next == `o` || next == `O` || next == `b` || next == `B` {
			l.advance_char()
			l.advance_char()
			for l.pos < l.source.len {
				ch := l.peek_char()
				if ch.is_hex_digit() || ch == `_` {
					l.advance_char()
				} else {
					break
				}
			}
			return Token{typ: .number, value: l.source[start..l.pos], line: l.line, column: start_col, filename: l.filename}
		}
	}
	for l.pos < l.source.len {
		ch := l.peek_char()
		if ch.is_digit() || ch == `_` {
			l.advance_char()
		} else {
			break
		}
	}
	if l.pos < l.source.len && l.peek_char() == `.` && l.peek_char_at(1).is_digit() {
		l.advance_char()
		for l.pos < l.source.len {
			ch := l.peek_char()
			if ch.is_digit() || ch == `_` {
				l.advance_char()
			} else {
				break
			}
		}
	}
	// Exponent
	if l.pos < l.source.len {
		ch := l.peek_char()
		if ch == `e` || ch == `E` {
			l.advance_char()
			if l.pos < l.source.len && (l.peek_char() == `+` || l.peek_char() == `-`) {
				l.advance_char()
			}
			for l.pos < l.source.len && l.peek_char().is_digit() {
				l.advance_char()
			}
		}
	}
	// Complex
	if l.pos < l.source.len && (l.peek_char() == `j` || l.peek_char() == `J`) {
		l.advance_char()
	}
	return Token{typ: .number, value: l.source[start..l.pos], line: l.line, column: start_col, filename: l.filename}
}

fn (mut l Lexer) scan_string(prefix string) Token {
	start_col := l.column - prefix.len
	quote := l.peek_char()
	mut typ := if prefix.to_lower().contains('f') { TokenType.fstring_tok } else { TokenType.string_tok }
	
	// Check for triple quote
	if l.pos + 2 < l.source.len && l.peek_char() == quote && l.peek_char_at(1) == quote && l.peek_char_at(2) == quote {
		// Triple quoted string
		l.advance_char()
		l.advance_char()
		l.advance_char()
		start := l.pos
		for l.pos < l.source.len {
			if l.peek_char() == quote && l.peek_char_at(1) == quote && l.peek_char_at(2) == quote {
				break
			}
			if l.peek_char() == `\\` {
				l.advance_char()
			}
			l.advance_char()
		}
		value := l.source[start..l.pos]
		if l.pos < l.source.len {
			l.advance_char()
			l.advance_char()
			l.advance_char()
		}
		return Token{typ: typ, value: value, line: l.line, column: start_col, filename: l.filename}
	}
	// Single quoted
	l.advance_char()
	start := l.pos
	for l.pos < l.source.len {
		ch := l.peek_char()
		if ch == quote {
			break
		}
		if ch == `\\` {
			l.advance_char()
		}
		if ch == `\n` && (prefix.to_lower() != 'f' && prefix.to_lower() != 'r') {
			// Actually Python strings can't have raw newlines unless triple quoted
			break
		}
		l.advance_char()
	}
	value := l.source[start..l.pos]
	if l.pos < l.source.len {
		l.advance_char() // closing quote
	}
	return Token{typ: typ, value: value, line: l.line, column: start_col, filename: l.filename}
}

fn (mut l Lexer) scan_operator() Token {
	start_col := l.column
	ch := l.peek_char()
	two := if l.pos + 1 < l.source.len { l.source[l.pos..l.pos + 2] } else { '' }
	three := if l.pos + 2 < l.source.len { l.source[l.pos..l.pos + 3] } else { '' }

	three_ops := ['**=', '//=', '>>=', '<<=', '...']
	two_ops := ['->', ':=', '**', '//', '==', '!=', '<=', '>=', '<<', '>>', '+=', '-=', '*=',
		'/=', '%=', '&=', '|=', '^=', '@=']

	if three in three_ops {
		l.advance_char()
		l.advance_char()
		l.advance_char()
		return Token{typ: .operator, value: three, line: l.line, column: start_col, filename: l.filename}
	}
	if two in two_ops {
		l.advance_char()
		l.advance_char()
		typ := if two == '->' { TokenType.arrow } else { .operator }
		return Token{typ: typ, value: two, line: l.line, column: start_col, filename: l.filename}
	}
	l.advance_char()
	return Token{typ: .operator, value: ch.ascii_str(), line: l.line, column: start_col, filename: l.filename}
}

fn (mut l Lexer) next_token() Token {
	// Return pending dedents
	if l.pending_dedents > 0 {
		l.pending_dedents--
		return l.make_token(.dedent, '')
	}

	// Return peeked token if exists
	if tok := l.peeked {
		l.peeked = none
		return tok
	}

	for {
		if l.pos >= l.source.len {
			return l.make_token(.eof, '')
		}

		ch := l.peek_char()

		// Newline => handle indentation on next line
		if ch == `\n` {
			l.advance_char()
			tok := l.make_token(.newline, '\\n')
			// handle indentation at start of next line
			if indent_tok := l.handle_indentation() {
				l.peeked = indent_tok
			}
			return tok
		}

		if ch == `\r` {
			l.advance_char()
			continue
		}

		// Whitespace
		if ch == ` ` || ch == `\t` {
			l.skip_whitespace_inline()
			continue
		}

		// Comment
		if ch == `#` {
			l.skip_comment()
			continue
		}

		// String prefixes: r, b, f, u, rb, br, fr, rf
		if ch == `r` || ch == `b` || ch == `f` || ch == `u` {
			next := l.peek_char_at(1)
			if next == `'` || next == `"` {
				p := ch.ascii_str()
				l.advance_char() // skip prefix
				return l.scan_string(p)
			}
			if (ch == `r` || ch == `b` || ch == `f`) && (next == `b` || next == `r` || next == `f`) {
				next2 := l.peek_char_at(2)
				if next2 == `'` || next2 == `"` {
					p := l.source[l.pos..l.pos + 2]
					l.advance_char()
					l.advance_char()
					return l.scan_string(p)
				}
			}
		}

		// Identifier / keyword
		if ch.is_letter() || ch == `_` {
			return l.scan_identifier()
		}

		// Number
		if ch.is_digit() || (ch == `.` && l.peek_char_at(1).is_digit()) {
			return l.scan_number()
		}

		// String
		if ch == `'` || ch == `"` {
			return l.scan_string('')
		}

		// Single-char tokens
		match ch {
			`(` { l.advance_char(); return l.make_token(.lparen, '(') }
			`)` { l.advance_char(); return l.make_token(.rparen, ')') }
			`[` { l.advance_char(); return l.make_token(.lbracket, '[') }
			`]` { l.advance_char(); return l.make_token(.rbracket, ']') }
			`{` { l.advance_char(); return l.make_token(.lbrace, '{') }
			`}` { l.advance_char(); return l.make_token(.rbrace, '}') }
			`:` {
				if l.peek_char_at(1) == `=` {
					l.advance_char(); l.advance_char()
					return l.make_token(.walrus, ':=')
				}
				l.advance_char()
				return l.make_token(.colon, ':')
			}
			`,` { l.advance_char(); return l.make_token(.comma, ',') }
			`.` {
				if l.peek_char_at(1) == `.` && l.peek_char_at(2) == `.` {
					l.advance_char(); l.advance_char(); l.advance_char()
					return l.make_token(.ellipsis, '...')
				}
				l.advance_char()
				return l.make_token(.dot, '.')
			}
			`;` { l.advance_char(); return l.make_token(.semicolon, ';') }
			`@` { l.advance_char(); return l.make_token(.at, '@') }
			else { return l.scan_operator() }
		}
	}
	return l.make_token(.eof, '')
}

fn (mut l Lexer) peek_token() Token {
	if tok := l.peeked {
		return tok
	}
	tok := l.next_token()
	l.peeked = tok
	return tok
}
