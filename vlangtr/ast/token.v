module ast

// ==================== TOKEN TYPES ====================

pub enum TokenType {
	eof
	newline
	indent
	dedent
	identifier
	number
	string_tok
	keyword
	operator
	lparen
	rparen
	lbracket
	rbracket
	lbrace
	rbrace
	colon
	comma
	dot
	semicolon
	at
	arrow
	walrus
	ellipsis
	fstring_tok
	tstring_tok
}

// ==================== TOKEN ====================

pub struct Token {
pub:
	typ      TokenType
	value    string
	line     int
	column   int
	filename string
}

fn (t Token) str() string {
	return 'Token(${t.typ}, ${t.value.str()}, ${t.line}:${t.column})'
}

fn (t Token) is_keyword(kw string) bool {
	return t.typ == .keyword && t.value == kw
}

fn (t Token) is_op(op string) bool {
	return t.typ == .operator && t.value == op
}

// Python keywords
const keywords = [
	'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await',
	'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except',
	'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is',
	'lambda', 'nonlocal', 'not', 'or', 'pass', 'raise', 'return',
	'try', 'while', 'with', 'yield',
]

fn is_keyword(s string) bool {
	return s in keywords
}
