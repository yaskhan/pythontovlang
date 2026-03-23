module mypy

import os

pub struct ParseState {
pub mut:
	options Options
	errors  []RawParseError
}

pub fn (mut s ParseState) add_error(message string, line int, column int, blocker bool, code ?string) {
	s.errors << RawParseError{
		message: message
		line:    line
		column:  column
		blocker: blocker
		code:    code
	}
}

pub struct ASTReadBuffer {
pub mut:
	data []u8
	pos  int
}

pub fn ASTReadBuffer.new(data []u8) ASTReadBuffer {
	return ASTReadBuffer{
		data: data.clone()
		pos:  0
	}
}

pub fn (mut b ASTReadBuffer) read_tag() u8 {
	return b.read_u8_or_zero()
}

pub fn (mut b ASTReadBuffer) read_int_bare() int {
	if b.pos + 4 > b.data.len {
		return 0
	}
	v := int(b.data[b.pos]) | (int(b.data[b.pos + 1]) << 8) | (int(b.data[b.pos + 2]) << 16) | (int(b.data[b.pos + 3]) << 24)
	b.pos += 4
	return v
}

pub fn (mut b ASTReadBuffer) read_int() int {
	return b.read_int_bare()
}

pub fn (mut b ASTReadBuffer) read_bool() bool {
	return b.read_u8_or_zero() != 0
}

pub fn (mut b ASTReadBuffer) read_float_bare() f64 {
	return 0.0
}

pub fn (mut b ASTReadBuffer) read_str_bare() string {
	length := b.read_int_bare()
	if length <= 0 || b.pos + length > b.data.len {
		return ''
	}
	s := b.data[b.pos..b.pos + length].bytestr()
	b.pos += length
	return s
}

pub fn (mut b ASTReadBuffer) read_str() string {
	return b.read_str_bare()
}

pub fn (mut b ASTReadBuffer) read_str_opt() ?string {
	value := b.read_str_bare()
	return if value.len == 0 { none } else { value }
}

pub fn (mut b ASTReadBuffer) read_loc(mut node NodeBase) {
	node.ctx.set_line_int(0, 0)
}

pub fn (mut b ASTReadBuffer) expect_tag(expected u8) {
	_ = expected
}

pub fn (mut b ASTReadBuffer) expect_end_tag() {}

pub fn native_parse(filename string, options Options, skip_function_bodies bool, imports_only bool) !(MypyFile, []RawParseError, map[int][]string) {
	_ = skip_function_bodies
	source := os.read_file(filename)!
	mut errors := new_errors(options)
	tree := parse(source, filename, none, mut errors, options, false, imports_only)
	return tree, []RawParseError{}, map[int][]string{}
}

fn (mut b ASTReadBuffer) read_u8_or_zero() u8 {
	if b.pos >= b.data.len {
		return 0
	}
	v := b.data[b.pos]
	b.pos++
	return v
}
