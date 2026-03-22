module ast

// serialize.v — Serializes a V AST into the binary format used by nativeparse.v

// ---------------------------------------------------------------------------
// Binary tags (Must match nativeparse.v)
// ---------------------------------------------------------------------------
const literal_false = u8(0)
const literal_true = u8(1)
const literal_none = u8(2)
const literal_int = u8(3)
const literal_str = u8(4)
const literal_bytes = u8(5)
const literal_float = u8(6)
const list_gen = u8(20)
const list_int = u8(21)
const list_str = u8(22)
const location = u8(152)
const end_tag = u8(255)

// Node tags (Placeholders)
const nodes_func_def_stmt = u8(1)
const nodes_decorator = u8(2)
const nodes_expr_stmt = u8(3)
const nodes_assignment_stmt = u8(4)
const nodes_if_stmt = u8(6)
const nodes_while_stmt = u8(7)
const nodes_for_stmt = u8(8)
const nodes_return_stmt = u8(9)
const nodes_pass_stmt = u8(14)
const nodes_try_stmt = u8(16)
const nodes_block = u8(24)

const nodes_name_expr = u8(100)
const nodes_int_expr = u8(101)
const nodes_str_expr = u8(102)
const nodes_call_expr = u8(105)
const nodes_member_expr = u8(106)
const nodes_op_expr = u8(107)
const nodes_bool_op_expr = u8(114)
const nodes_yield_expr = u8(120)

// ---------------------------------------------------------------------------
// Serializer
// ---------------------------------------------------------------------------

pub struct Serializer {
pub mut:
	buf []u8
}

pub fn Serializer.new() &Serializer {
	return &Serializer{
		buf: []u8{cap: 1024}
	}
}

pub fn (mut s Serializer) serialize_module(node &Module) []u8 {
	s.write_int(node.body.len)
	for stmt in node.body {
		s.write_statement(stmt)
	}
	return s.buf
}

pub fn (mut s Serializer) write_statement(node Statement) {
	// Decorators in nativeparse are handled specially (DECORATOR tag wrapping FuncDef)
	if node is FunctionDef {
		if node.decorator_list.len > 0 {
			s.write_tag(nodes_decorator)
			s.write_tag(list_gen)
			s.write_int_bare(node.decorator_list.len)
			for d in node.decorator_list {
				s.write_expression(d)
			}
			s.write_int(node.get_token().line)
			s.write_int(node.get_token().column)
			// Now write the actual FuncDef as a normal statement
		}
	}

	match node {
		FunctionDef {
			s.write_tag(nodes_func_def_stmt)
			s.write_str(node.name)
			// Arguments
			s.write_tag(list_gen)
			s.write_int_bare(node.args.args.len)
			for arg in node.args.args {
				s.write_str(arg.arg)
				s.write_int_bare(0) // arg kind - simplify to pos
				s.write_tag(literal_false) // no annotation
				s.write_tag(literal_false) // no default
				s.write_tag(literal_false) // no pos_only
				s.write_loc(arg.token)
			}
			s.write_block(node.body)
			s.write_tag(if node.is_async { literal_true } else { literal_false })
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		If {
			s.write_tag(nodes_if_stmt)
			s.write_expression(node.test)
			s.write_statements_as_block(node.body)
			// elif/else logic in mypy is complicated, simplified here
			s.write_int(0) // num_elif
			if node.orelse.len > 0 {
				s.write_tag(literal_true)
				s.write_statements_as_block(node.orelse)
			} else {
				s.write_tag(literal_false)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		While {
			s.write_tag(nodes_while_stmt)
			s.write_expression(node.test)
			s.write_statements_as_block(node.body)
			if node.orelse.len > 0 {
				s.write_statements_as_block(node.orelse)
			} else {
				s.write_tag(literal_none)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Assign {
			s.write_tag(nodes_assignment_stmt)
			// Lvalues
			s.write_tag(list_gen)
			s.write_int_bare(node.targets.len)
			for t in node.targets {
				s.write_expression(t)
			}
			s.write_expression(node.value)
			s.write_tag(literal_false) // no type
			s.write_tag(literal_false) // new_syntax
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Expr {
			s.write_tag(nodes_expr_stmt)
			s.write_expression(node.value)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Return {
			s.write_tag(nodes_return_stmt)
			if val := node.value {
				s.write_tag(literal_true)
				s.write_expression(val)
			} else {
				s.write_tag(literal_false)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Pass {
			s.write_tag(nodes_pass_stmt)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		else {
			// Skip other statements for now
		}
	}
}

pub fn (mut s Serializer) write_expression(node Expression) {
	match node {
		Name {
			s.write_tag(nodes_name_expr)
			s.write_str(node.id)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Constant {
			if node.token.typ == .number {
				s.write_tag(nodes_int_expr)
				s.write_int_bare(node.value.int())
			} else {
				s.write_tag(nodes_str_expr)
				s.write_str_bare(node.value)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Call {
			s.write_tag(nodes_call_expr)
			s.write_expression(node.func)
			s.write_tag(list_gen)
			s.write_int_bare(node.args.len)
			for a in node.args {
				s.write_expression(a)
			}
			// arg kinds placeholder
			s.write_tag(list_int)
			s.write_int_bare(node.args.len)
			for _ in 0 .. node.args.len {
				s.write_int_bare(0) // pos
			}
			// arg names placeholder
			s.write_tag(list_gen)
			s.write_int_bare(0)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		BinaryOp {
			s.write_tag(nodes_op_expr)
			// map operator to index
			s.write_int_bare(0) // placeholder for '+'
			s.write_expression(node.left)
			s.write_expression(node.right)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		else {
			// Placeholder
		}
	}
}

pub fn (mut s Serializer) write_block(body []Statement) {
	s.write_tag(nodes_block)
	s.write_tag(list_gen)
	s.write_int_bare(body.len)
	s.write_tag(literal_false) // is_unreachable
	for stmt in body {
		s.write_statement(stmt)
	}
	if body.len == 0 {
		s.write_loc(Token{}) // Empty loc
	}
	s.write_tag(end_tag)
}

pub fn (mut s Serializer) write_statements_as_block(body []Statement) {
	s.write_block(body)
}

// ---------------------------------------------------------------------------
// Low-level helpers
// ---------------------------------------------------------------------------

pub fn (mut s Serializer) write_tag(tag u8) {
	s.buf << tag
}

pub fn (mut s Serializer) write_int_bare(v int) {
	mut val := v
	for {
		mut b := u8(val & 0x7f)
		val >>= 7
		if val != 0 {
			b |= 0x80
		}
		s.buf << b
		if val == 0 {
			break
		}
	}
}

pub fn (mut s Serializer) write_int(v int) {
	s.write_tag(literal_int)
	s.write_int_bare(v)
}

pub fn (mut s Serializer) write_str_bare(v string) {
	s.write_int_bare(v.len)
	for c in v {
		s.buf << u8(c)
	}
}

pub fn (mut s Serializer) write_str(v string) {
	s.write_tag(literal_str)
	s.write_str_bare(v)
}

pub fn (mut s Serializer) write_loc(t Token) {
	s.write_tag(location)
	s.write_int_bare(t.line)
	s.write_int_bare(t.column)
	s.write_int_bare(t.line) // end_line placeholder
	s.write_int_bare(t.column + t.value.len) // end_column placeholder
}
