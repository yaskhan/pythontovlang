module ast

// ==================== PARSE ERROR ====================

pub struct ParseError {
pub:
	message string
	token   Token
}

pub fn (e &ParseError) str() string {
	return 'ParseError at ${e.token.filename}:${e.token.line}:${e.token.column}: ${e.message} (got ${e.token.typ}: "${e.token.value}")'
}

pub struct LexError {
pub:
	message  string
	line     int
	column   int
	filename string
}

pub fn (e &LexError) str() string {
	return 'LexError at ${e.filename}:${e.line}:${e.column}: ${e.message}'
}
