module mypy

import os


// Node tags
pub const tag_func_def = u8(30)
pub const tag_class_def = u8(32)
pub const tag_decorator = u8(33)
pub const tag_var = u8(34)
pub const tag_block = u8(35)
pub const tag_import = u8(36)
pub const tag_import_from = u8(37)
pub const tag_import_all = u8(38)
pub const tag_expression_stmt = u8(39)
pub const tag_assignment_stmt = u8(40)
pub const tag_operator_assignment_stmt = u8(41)
pub const tag_while_stmt = u8(42)
pub const tag_for_stmt = u8(43)
pub const tag_return_stmt = u8(44)
pub const tag_if_stmt = u8(45)
pub const tag_break_stmt = u8(46)
pub const tag_continue_stmt = u8(47)
pub const tag_pass_stmt = u8(48)
pub const tag_raise_stmt = u8(49)
pub const tag_try_stmt = u8(50)
pub const tag_with_stmt = u8(51)
pub const tag_del_stmt = u8(52)
pub const tag_global_decl = u8(53)
pub const tag_nonlocal_decl = u8(54)
pub const tag_assert_stmt = u8(55)
pub const tag_match_stmt = u8(56)
pub const tag_type_alias_stmt = u8(57)

pub const tag_name_expr = u8(60)
pub const tag_member_expr = u8(61)
pub const tag_index_expr = u8(62)
pub const tag_call_expr = u8(63)
pub const tag_int_expr = u8(64)
pub const tag_str_expr = u8(65)
pub const tag_bytes_expr = u8(66)
pub const tag_float_expr = u8(67)
pub const tag_complex_expr = u8(68)
pub const tag_ellipsis_expr = u8(69)
pub const tag_star_expr = u8(70)
pub const tag_yield_expr = u8(71)
pub const tag_yield_from_expr = u8(72)
pub const tag_op_expr = u8(73)
pub const tag_comparison_expr = u8(74)
pub const tag_unary_expr = u8(75)
pub const tag_cast_expr = u8(76)
pub const tag_reveal_expr = u8(77)
pub const tag_super_expr = u8(78)
pub const tag_assignment_expr = u8(79)
pub const tag_list_expr = u8(80)
pub const tag_dict_expr = u8(81)
pub const tag_tuple_expr = u8(82)
pub const tag_set_expr = u8(83)
pub const tag_generator_expr = u8(84)
pub const tag_list_comprehension = u8(85)
pub const tag_set_comprehension = u8(86)
pub const tag_dictionary_comprehension = u8(87)
pub const tag_conditional_expr = u8(88)
pub const tag_type_application = u8(89)
pub const tag_lambda_expr = u8(90)
pub const tag_type_var_expr = u8(91)
pub const tag_paramspec_expr = u8(92)
pub const tag_type_var_tuple_expr = u8(93)
pub const tag_type_alias_expr = u8(94)
pub const tag_namedtuple_expr = u8(95)
pub const tag_enum_call_expr = u8(96)
pub const tag_typeddict_expr = u8(97)
pub const tag_newtype_expr = u8(98)
pub const tag_promote_expr = u8(99)
pub const tag_await_expr = u8(100)
pub const tag_slice_expr = u8(101)

pub const tag_as_pattern = u8(110)
pub const tag_or_pattern = u8(111)
pub const tag_value_pattern = u8(112)
pub const tag_singleton_pattern = u8(113)
pub const tag_sequence_pattern = u8(114)
pub const tag_starred_pattern = u8(115)
pub const tag_mapping_pattern = u8(116)
pub const tag_class_pattern = u8(117)

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
	mut val := u32(0)
	mut shift := u32(0)
	for {
		if b.pos >= b.data.len { break }
		bt := b.data[b.pos]
		b.pos++
		val |= u32(bt & 0x7f) << shift
		if (bt & 0x80) == 0 { break }
		shift += 7
	}
	return int(val)
}

pub fn (mut b ASTReadBuffer) read_int() int {
	tag := b.read_tag()
	if tag != literal_int { return 0 }
	return b.read_int_bare()
}

pub fn (mut b ASTReadBuffer) read_bool() bool {
	tag := b.read_tag()
	return tag == literal_true
}

pub fn (mut b ASTReadBuffer) read_str_bare() string {
	length := b.read_int_bare()
	if length <= 0 || b.pos + length > b.data.len { return '' }
	s := b.data[b.pos..b.pos + length].bytestr()
	b.pos += length
	return s
}

pub fn (mut b ASTReadBuffer) read_str() string {
	tag := b.read_tag()
	if tag != literal_str { return '' }
	return b.read_str_bare()
}

pub fn (mut b ASTReadBuffer) read_str_opt() ?string {
	tag := b.read_tag()
	if tag == literal_none { return none }
	return b.read_str_bare()
}

pub fn (mut b ASTReadBuffer) read_loc(mut node NodeBase) {
	tag := b.read_tag()
	if tag == location {
		node.line = b.read_int_bare()
		node.column = b.read_int_bare()
		node.end_line = b.read_int_bare()
		node.end_column = b.read_int_bare()
		node.ctx = Context{
			line:       node.line
			column:     node.column
			end_line:   node.end_line
			end_column: node.end_column
		}
	}
}

pub fn (mut b ASTReadBuffer) expect_tag(expected u8) {
	tag := b.read_tag()
	if tag != expected { /* handle error */ }
}

pub fn (mut b ASTReadBuffer) expect_end_tag() {
	b.expect_tag(end_tag)
}

// ---------------------------------------------------------------------------
// Collection readers
// ---------------------------------------------------------------------------

fn (mut b ASTReadBuffer) read_list_int() []int {
	tag := b.read_tag()
	if tag != list_int { return []int{} }
	len := b.read_int_bare()
	mut res := []int{cap: len}
	for _ in 0 .. len { res << b.read_int_bare() }
	return res
}

fn (mut b ASTReadBuffer) read_list_str() []string {
	tag := b.read_tag()
	if tag != list_str { return []string{} }
	len := b.read_int_bare()
	mut res := []string{cap: len}
	for _ in 0 .. len { res << b.read_str_bare() }
	return res
}

fn (mut b ASTReadBuffer) read_list_node() []MypyNode {
	tag := b.read_tag()
	if tag != list_gen { return []MypyNode{} }
	len := b.read_int_bare()
	mut res := []MypyNode{cap: len}
	for _ in 0 .. len {
		if node := b.read_node() { res << node }
	}
	return res
}

fn (mut b ASTReadBuffer) read_list_stmt() []Statement {
	tag := b.read_tag()
	if tag != list_gen { return []Statement{} }
	len := b.read_int_bare()
	mut res := []Statement{cap: len}
	for _ in 0 .. len {
		if node := b.read_statement() { res << node }
	}
	return res
}

fn (mut b ASTReadBuffer) read_list_expr() []Expression {
	tag := b.read_tag()
	if tag != list_gen { return []Expression{} }
	len := b.read_int_bare()
	mut res := []Expression{cap: len}
	for _ in 0 .. len {
		if node := b.read_expression() { res << node }
	}
	return res
}

fn (mut b ASTReadBuffer) read_list_expr_opt() []?Expression {
	tag := b.read_tag()
	if tag != list_gen { return []?Expression{} }
	len := b.read_int_bare()
	mut res := []?Expression{cap: len}
	for _ in 0 .. len { res << b.read_expression() }
	return res
}

fn (mut b ASTReadBuffer) read_list_block() []Block {
	tag := b.read_tag()
	if tag != list_gen { return []Block{} }
	len := b.read_int_bare()
	mut res := []Block{cap: len}
	for _ in 0 .. len {
		tag_inner := b.read_tag()
		if tag_inner == tag_block {
			res << b.read_block()
			b.expect_end_tag()
		}
	}
	return res
}

fn (mut b ASTReadBuffer) read_list_import_alias() []ImportAlias {
	tag := b.read_tag()
	if tag != list_gen { return []ImportAlias{} }
	len := b.read_int_bare()
	mut res := []ImportAlias{cap: len}
	for _ in 0 .. len {
		res << ImportAlias{
			name: b.read_str()
			alias: b.read_str_opt()
		}
	}
	return res
}
fn (mut b ASTReadBuffer) read_list_type_param() []TypeParam {
	tag := b.read_tag()
	if tag != list_gen { return []TypeParam{} }
	len := b.read_int_bare()
	mut res := []TypeParam{cap: len}
	for _ in 0 .. len {
		res << b.read_type_param()
	}
	return res
}

fn (mut b ASTReadBuffer) read_list_argument() []Argument {
	tag := b.read_tag()
	if tag != list_gen { return []Argument{} }
	len := b.read_int_bare()
	mut res := []Argument{cap: len}
	for _ in 0 .. len {
		res << b.read_argument()
		b.expect_end_tag()
	}
	return res
}

fn (mut b ASTReadBuffer) read_list_name_expr_opt() []?NameExpr {
	tag := b.read_tag()
	if tag != list_gen { return []?NameExpr{} }
	len := b.read_int_bare()
	mut res := []?NameExpr{cap: len}
	for _ in 0 .. len {
		if b.read_bool() {
			if node := b.read_expression() {
				if node is NameExpr {
					res << node
				} else {
					res << none
				}
			} else {
				res << none
			}
		} else {
			res << none
		}
	}
	return res
}

fn (mut b ASTReadBuffer) read_list_import_base() []ImportBase {
	tag := b.read_tag()
	if tag != list_gen { return []ImportBase{} }
	len := b.read_int_bare()
	mut res := []ImportBase{cap: len}
	for _ in 0 .. len {
		tag_inner := b.read_tag()
		match tag_inner {
			tag_import {
				res << b.read_import()
				b.expect_end_tag()
			}
			tag_import_from {
				res << b.read_import_from()
				b.expect_end_tag()
			}
			tag_import_all {
				res << b.read_import_all()
				b.expect_end_tag()
			}
			else {}
		}
	}
	return res
}

fn (mut b ASTReadBuffer) read_list_arg_kind() []ArgKind {
	tag := b.read_tag()
	if tag != list_int { return []ArgKind{} }
	len := b.read_int_bare()
	mut res := []ArgKind{cap: len}
	for _ in 0 .. len { res << unsafe { ArgKind(b.read_int_bare()) } }
	return res
}

fn (mut b ASTReadBuffer) read_list_str_opt() []?string {
	tag := b.read_tag()
	if tag != list_gen { return []?string{} }
	len := b.read_int_bare()
	mut res := []?string{cap: len}
	for _ in 0 .. len { res << b.read_str_opt() }
	return res
}

fn (mut b ASTReadBuffer) read_list_pattern() []Pattern {
	tag := b.read_tag()
	if tag != list_gen { return []Pattern{} }
	len := b.read_int_bare()
	mut res := []Pattern{cap: len}
	for _ in 0 .. len {
		if node := b.read_pattern() {
			res << node
			b.expect_end_tag()
		}
	}
	return res
}

// ---------------------------------------------------------------------------
// Dispatchers
// ---------------------------------------------------------------------------

pub fn (mut b ASTReadBuffer) read_node() ?MypyNode {
	tag := b.read_tag()
	if tag == literal_none || tag == end_tag { return none }
	node := b.read_node_tagged(tag)
	b.expect_end_tag()
	return node
}

fn (mut b ASTReadBuffer) read_node_tagged(tag u8) ?MypyNode {
	match tag {
		tag_func_def { return MypyNode(b.read_func_def()) }
		tag_class_def { return MypyNode(b.read_class_def()) }
		tag_decorator { return MypyNode(b.read_decorator()) }
		tag_var { return MypyNode(b.read_var()) }
		tag_block { return MypyNode(b.read_block()) }
		tag_import { return MypyNode(b.read_import()) }
		tag_import_from { return MypyNode(b.read_import_from()) }
		tag_import_all { return MypyNode(b.read_import_all()) }
		tag_expression_stmt { return MypyNode(b.read_expression_stmt()) }
		tag_assignment_stmt { return MypyNode(b.read_assignment_stmt()) }
		tag_operator_assignment_stmt { return MypyNode(b.read_operator_assignment_stmt()) }
		tag_while_stmt { return MypyNode(b.read_while_stmt()) }
		tag_for_stmt { return MypyNode(b.read_for_stmt()) }
		tag_return_stmt { return MypyNode(b.read_return_stmt()) }
		tag_if_stmt { return MypyNode(b.read_if_stmt()) }
		tag_break_stmt { return MypyNode(b.read_break_stmt()) }
		tag_continue_stmt { return MypyNode(b.read_continue_stmt()) }
		tag_pass_stmt { return MypyNode(b.read_pass_stmt()) }
		tag_raise_stmt { return MypyNode(b.read_raise_stmt()) }
		tag_try_stmt { return MypyNode(b.read_try_stmt()) }
		tag_with_stmt { return MypyNode(b.read_with_stmt()) }
		tag_del_stmt { return MypyNode(b.read_del_stmt()) }
		tag_global_decl { return MypyNode(b.read_global_decl()) }
		tag_nonlocal_decl { return MypyNode(b.read_nonlocal_decl()) }
		tag_assert_stmt { return MypyNode(b.read_assert_stmt()) }
		tag_match_stmt { return MypyNode(b.read_match_stmt()) }
		tag_type_alias_stmt { return MypyNode(b.read_type_alias_stmt()) }
		tag_name_expr { return MypyNode(b.read_name_expr()) }
		tag_member_expr { return MypyNode(b.read_member_expr()) }
		tag_index_expr { return MypyNode(b.read_index_expr()) }
		tag_call_expr { return MypyNode(b.read_call_expr()) }
		tag_int_expr { return MypyNode(b.read_int_expr()) }
		tag_str_expr { return MypyNode(b.read_str_expr()) }
		tag_bytes_expr { return MypyNode(b.read_bytes_expr()) }
		tag_float_expr { return MypyNode(b.read_float_expr()) }
		tag_complex_expr { return MypyNode(b.read_complex_expr()) }
		tag_ellipsis_expr { return MypyNode(b.read_ellipsis_expr()) }
		tag_star_expr { return MypyNode(b.read_star_expr()) }
		tag_yield_expr { return MypyNode(b.read_yield_expr()) }
		tag_yield_from_expr { return MypyNode(b.read_yield_from_expr()) }
		tag_op_expr { return MypyNode(b.read_op_expr()) }
		tag_comparison_expr { return MypyNode(b.read_comparison_expr()) }
		tag_unary_expr { return MypyNode(b.read_unary_expr()) }
		tag_cast_expr { return MypyNode(b.read_cast_expr()) }
		tag_reveal_expr { return MypyNode(b.read_reveal_expr()) }
		tag_super_expr { return MypyNode(b.read_super_expr()) }
		tag_assignment_expr { return MypyNode(b.read_assignment_expr()) }
		tag_list_expr { return MypyNode(b.read_list_expr_node()) }
		tag_dict_expr { return MypyNode(b.read_dict_expr()) }
		tag_tuple_expr { return MypyNode(b.read_tuple_expr()) }
		tag_set_expr { return MypyNode(b.read_set_expr()) }
		tag_generator_expr { return MypyNode(b.read_generator_expr()) }
		tag_list_comprehension { return MypyNode(b.read_list_comprehension()) }
		tag_set_comprehension { return MypyNode(b.read_set_comprehension()) }
		tag_dictionary_comprehension { return MypyNode(b.read_dictionary_comprehension()) }
		tag_conditional_expr { return MypyNode(b.read_conditional_expr()) }
		tag_type_application { return MypyNode(b.read_type_application()) }
		tag_lambda_expr { return MypyNode(b.read_lambda_expr()) }
		tag_type_var_expr { return MypyNode(b.read_type_var_expr()) }
		tag_paramspec_expr { return MypyNode(b.read_paramspec_expr()) }
		tag_type_var_tuple_expr { return MypyNode(b.read_type_var_tuple_expr()) }
		tag_type_alias_expr { return MypyNode(b.read_type_alias_expr()) }
		tag_namedtuple_expr { return MypyNode(b.read_namedtuple_expr()) }
		tag_enum_call_expr { return MypyNode(b.read_enum_call_expr()) }
		tag_typeddict_expr { return MypyNode(b.read_typeddict_expr()) }
		tag_newtype_expr { return MypyNode(b.read_newtype_expr()) }
		tag_promote_expr { return MypyNode(b.read_promote_expr()) }
		tag_await_expr { return MypyNode(b.read_await_expr()) }
		tag_slice_expr { return MypyNode(b.read_slice_expr()) }
		else { return none }
	}
}

pub fn (mut b ASTReadBuffer) read_statement() ?Statement {
	tag := b.read_tag()
	if tag == literal_none || tag == end_tag { return none }
	node := b.read_node_tagged(tag) or { return none }
	b.expect_end_tag()
	if st := node.as_statement() { return st }
	return none
}

pub fn (mut b ASTReadBuffer) read_expression() ?Expression {
	tag := b.read_tag()
	if tag == literal_none || tag == end_tag { return none }
	node := b.read_node_tagged(tag) or { return none }
	b.expect_end_tag()
	if ex := node.as_expression() { return ex }
	return none
}

// ---------------------------------------------------------------------------
// Node Readers
// ---------------------------------------------------------------------------

fn (mut b ASTReadBuffer) read_block() Block {
	mut node := Block{}
	b.read_loc(mut node.base)
	node.body = b.read_list_stmt()
	return node
}

fn (mut b ASTReadBuffer) read_expression_stmt() ExpressionStmt {
	mut node := ExpressionStmt{}
	b.read_loc(mut node.base)
	node.expr = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_assignment_stmt() AssignmentStmt {
	mut node := AssignmentStmt{}
	b.read_loc(mut node.base)
	node.lvalues = b.read_list_expr()
	node.rvalue = b.read_expression() or { NameExpr{name: 'None'} }
	node.is_final_def = b.read_bool()
	node.is_alias_def = b.read_bool()
	return node
}

fn (mut b ASTReadBuffer) read_name_expr() NameExpr {
	mut node := NameExpr{}
	b.read_loc(mut node.base)
	node.name = b.read_str()
	node.kind = b.read_int()
	node.fullname = b.read_str()
	node.is_inferred_def = b.read_bool()
	node.is_special_form = b.read_bool()
	return node
}

fn (mut b ASTReadBuffer) read_int_expr() IntExpr {
	mut node := IntExpr{}
	b.read_loc(mut node.base)
	node.value = i64(b.read_int())
	return node
}

fn (mut b ASTReadBuffer) read_str_expr() StrExpr {
	mut node := StrExpr{}
	b.read_loc(mut node.base)
	node.value = b.read_str()
	return node
}

fn (mut b ASTReadBuffer) read_member_expr() MemberExpr {
	mut node := MemberExpr{}
	b.read_loc(mut node.base)
	node.expr = b.read_expression() or { NameExpr{name: 'None'} }
	node.name = b.read_str()
	node.fullname = b.read_str()
	node.kind = b.read_int()
	return node
}

fn (mut b ASTReadBuffer) read_call_expr() CallExpr {
	mut node := CallExpr{}
	b.read_loc(mut node.base)
	node.callee = b.read_expression() or { NameExpr{name: 'None'} }
	node.args = b.read_list_expr()
	node.arg_kinds = b.read_list_arg_kind()
	node.arg_names = b.read_list_str_opt()
	return node
}

fn (mut b ASTReadBuffer) read_if_stmt() IfStmt {
	mut node := IfStmt{}
	b.read_loc(mut node.base)
	node.expr = b.read_list_expr()
	node.body = b.read_list_block()
	if b.read_bool() {
		node.else_body = b.read_block()
		b.expect_end_tag()
	}
	return node
}

fn (mut b ASTReadBuffer) read_func_def() FuncDef {
	mut node := FuncDef{}
	b.read_loc(mut node.base)
	node.name = b.read_str()
	node.arguments = b.read_list_argument()
	node.arg_names = b.read_list_str_opt()
	node.arg_kinds = b.read_list_arg_kind()
	node.body = b.read_block()
	b.expect_end_tag()
	node.is_generator = b.read_bool()
	node.is_coroutine = b.read_bool()
	node.is_async_generator = b.read_bool()
	node.is_decorated = b.read_bool()
	node.is_stub = b.read_bool()
	node.is_final = b.read_bool()
	node.is_class = b.read_bool()
	node.is_static = b.read_bool()
	node.is_property = b.read_bool()
	node.fullname = b.read_str()
	node.max_pos = b.read_int()
	return node
}

fn (mut b ASTReadBuffer) read_argument() Argument {
	mut node := Argument{}
	b.read_loc(mut node.base)
	node.variable = b.read_var()
	if b.read_bool() {
		node.initializer = b.read_expression()
	}
	node.kind = unsafe { ArgKind(b.read_int()) }
	node.pos_only = b.read_bool()
	return node
}

fn (mut b ASTReadBuffer) read_var() Var {
	mut node := Var{}
	b.read_loc(mut node.base)
	node.name = b.read_str()
	node.fullname = b.read_str()
	node.is_self = b.read_bool()
	node.is_cls = b.read_bool()
	node.is_final = b.read_bool()
	node.is_property = b.read_bool()
	return node
}

fn (mut b ASTReadBuffer) read_class_def() ClassDef {
	mut node := ClassDef{}
	b.read_loc(mut node.base)
	node.name = b.read_str()
	node.fullname = b.read_str()
	node.defs = b.read_block()
	b.expect_end_tag()
	node.base_type_exprs = b.read_list_expr()
	node.metaclass = b.read_str_opt()
	node.is_protocol = b.read_bool()
	node.is_abstract = b.read_bool()
	return node
}

fn (mut b ASTReadBuffer) read_decorator() Decorator {
	mut node := Decorator{}
	b.read_loc(mut node.base)
	node.func = b.read_func_def()
	b.expect_end_tag()
	node.decorators = b.read_list_expr()
	node.var_ = b.read_var()
	node.is_overload = b.read_bool()
	return node
}

fn (mut b ASTReadBuffer) read_import() Import {
	mut node := Import{}
	b.read_loc(mut node.base)
	node.ids = b.read_list_import_alias()
	return node
}

fn (mut b ASTReadBuffer) read_import_from() ImportFrom {
	mut node := ImportFrom{}
	b.read_loc(mut node.base)
	node.id = b.read_str()
	node.relative = b.read_int()
	node.names = b.read_list_import_alias()
	return node
}

fn (mut b ASTReadBuffer) read_import_all() ImportAll {
	mut node := ImportAll{}
	b.read_loc(mut node.base)
	node.id = b.read_str()
	node.relative = b.read_int()
	return node
}

fn (mut b ASTReadBuffer) read_while_stmt() WhileStmt {
	mut node := WhileStmt{}
	b.read_loc(mut node.base)
	node.expr = b.read_expression() or { NameExpr{name: 'True'} }
	node.body = b.read_block()
	b.expect_end_tag()
	if b.read_bool() {
		node.else_body = b.read_block()
		b.expect_end_tag()
	}
	return node
}

fn (mut b ASTReadBuffer) read_for_stmt() ForStmt {
	mut node := ForStmt{}
	b.read_loc(mut node.base)
	node.index = b.read_expression() or { NameExpr{name: '_'} }
	node.expr = b.read_expression() or { NameExpr{name: '[]'} }
	node.body = b.read_block()
	b.expect_end_tag()
	if b.read_bool() {
		node.else_body = b.read_block()
		b.expect_end_tag()
	}
	node.is_async = b.read_bool()
	return node
}

fn (mut b ASTReadBuffer) read_try_stmt() TryStmt {
	mut node := TryStmt{}
	b.read_loc(mut node.base)
	node.body = b.read_block()
	b.expect_end_tag()
	node.types = b.read_list_expr_opt()
	node.vars = b.read_list_name_expr_opt()
	node.handlers = b.read_list_block()
	if b.read_bool() {
		node.else_body = b.read_block()
		b.expect_end_tag()
	}
	if b.read_bool() {
		node.finally_body = b.read_block()
		b.expect_end_tag()
	}
	node.is_star = b.read_bool()
	return node
}

fn (mut b ASTReadBuffer) read_with_stmt() WithStmt {
	mut node := WithStmt{}
	b.read_loc(mut node.base)
	node.expr = b.read_list_expr()
	node.target = b.read_list_expr_opt()
	node.body = b.read_block()
	b.expect_end_tag()
	node.is_async = b.read_bool()
	return node
}

fn (mut b ASTReadBuffer) read_match_stmt() MatchStmt {
	mut node := MatchStmt{}
	b.read_loc(mut node.base)
	node.subject = b.read_expression() or { NameExpr{name: '_'} }
	node.patterns = b.read_list_pattern()
	node.guards = b.read_list_expr_opt()
	node.bodies = b.read_list_block()
	return node
}

fn (mut b ASTReadBuffer) read_op_expr() OpExpr {
	mut node := OpExpr{}
	b.read_loc(mut node.base)
	node.op = b.read_str()
	node.left = b.read_expression() or { NameExpr{name: 'None'} }
	node.right = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_comparison_expr() ComparisonExpr {
	mut node := ComparisonExpr{}
	b.read_loc(mut node.base)
	node.operators = b.read_list_str()
	node.operands = b.read_list_expr()
	return node
}

fn (mut b ASTReadBuffer) read_unary_expr() UnaryExpr {
	mut node := UnaryExpr{}
	b.read_loc(mut node.base)
	node.op = b.read_str()
	node.expr = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_list_expr_node() ListExpr {
	mut node := ListExpr{}
	b.read_loc(mut node.base)
	node.items = b.read_list_expr()
	return node
}

fn (mut b ASTReadBuffer) read_dict_expr() DictExpr {
	mut node := DictExpr{}
	b.read_loc(mut node.base)
	len := b.read_int_bare()
	for _ in 0 .. len {
		key := b.read_expression() or { NameExpr{name: 'None'} }
		val := b.read_expression() or { NameExpr{name: 'None'} }
		node.items << DictEntry{key: key, value: val}
	}
	return node
}

fn (mut b ASTReadBuffer) read_tuple_expr() TupleExpr {
	mut node := TupleExpr{}
	b.read_loc(mut node.base)
	node.items = b.read_list_expr()
	return node
}

fn (mut b ASTReadBuffer) read_set_expr() SetExpr {
	mut node := SetExpr{}
	b.read_loc(mut node.base)
	node.items = b.read_list_expr()
	return node
}

fn (mut b ASTReadBuffer) read_generator_expr() GeneratorExpr {
	mut node := GeneratorExpr{}
	b.read_loc(mut node.base)
	node.left_expr = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_lambda_expr() LambdaExpr {
	mut node := LambdaExpr{}
	b.read_loc(mut node.base)
	node.arguments = b.read_list_argument()
	node.arg_names = b.read_list_str_opt()
	node.arg_kinds = b.read_list_arg_kind()
	node.body = b.read_expression() or { NameExpr{name: 'None'} }
	node.is_generator = b.read_bool()
	return node
}

fn (mut b ASTReadBuffer) read_conditional_expr() ConditionalExpr {
	mut node := ConditionalExpr{}
	b.read_loc(mut node.base)
	node.cond = b.read_expression() or { NameExpr{name: 'None'} }
	node.if_expr = b.read_expression() or { NameExpr{name: 'None'} }
	node.else_expr = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_slice_expr() SliceExpr {
	mut node := SliceExpr{}
	b.read_loc(mut node.base)
	if b.read_bool() { node.begin = b.read_expression() }
	if b.read_bool() { node.end = b.read_expression() }
	if b.read_bool() { node.step = b.read_expression() }
	return node
}

fn (mut b ASTReadBuffer) read_return_stmt() ReturnStmt {
	mut node := ReturnStmt{}
	b.read_loc(mut node.base)
	if b.read_bool() { node.expr = b.read_expression() }
	return node
}

fn (mut b ASTReadBuffer) read_break_stmt() BreakStmt {
	mut node := BreakStmt{}
	b.read_loc(mut node.base)
	return node
}

fn (mut b ASTReadBuffer) read_continue_stmt() ContinueStmt {
	mut node := ContinueStmt{}
	b.read_loc(mut node.base)
	return node
}

fn (mut b ASTReadBuffer) read_pass_stmt() PassStmt {
	mut node := PassStmt{}
	b.read_loc(mut node.base)
	return node
}

fn (mut b ASTReadBuffer) read_raise_stmt() RaiseStmt {
	mut node := RaiseStmt{}
	b.read_loc(mut node.base)
	if b.read_bool() { node.expr = b.read_expression() }
	if b.read_bool() { node.from = b.read_expression() }
	return node
}

fn (mut b ASTReadBuffer) read_del_stmt() DelStmt {
	mut node := DelStmt{}
	b.read_loc(mut node.base)
	node.expr = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_global_decl() GlobalDecl {
	mut node := GlobalDecl{}
	b.read_loc(mut node.base)
	node.names = b.read_list_str()
	return node
}

fn (mut b ASTReadBuffer) read_nonlocal_decl() NonlocalDecl {
	mut node := NonlocalDecl{}
	b.read_loc(mut node.base)
	node.names = b.read_list_str()
	return node
}

fn (mut b ASTReadBuffer) read_assert_stmt() AssertStmt {
	mut node := AssertStmt{}
	b.read_loc(mut node.base)
	node.expr = b.read_expression() or { NameExpr{name: 'True'} }
	if b.read_bool() { node.msg = b.read_expression() }
	return node
}

fn (mut b ASTReadBuffer) read_ellipsis_expr() EllipsisExpr {
	mut node := EllipsisExpr{}
	b.read_loc(mut node.base)
	return node
}

fn (mut b ASTReadBuffer) read_star_expr() StarExpr {
	mut node := StarExpr{}
	b.read_loc(mut node.base)
	node.expr = b.read_expression() or { NameExpr{name: 'None'} }
	node.valid = b.read_bool()
	return node
}

fn (mut b ASTReadBuffer) read_yield_expr() YieldExpr {
	mut node := YieldExpr{}
	b.read_loc(mut node.base)
	if b.read_bool() { node.expr = b.read_expression() }
	return node
}

fn (mut b ASTReadBuffer) read_yield_from_expr() YieldFromExpr {
	mut node := YieldFromExpr{}
	b.read_loc(mut node.base)
	node.expr = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_reveal_expr() RevealExpr {
	mut node := RevealExpr{}
	b.read_loc(mut node.base)
	node.expr = b.read_expression() or { NameExpr{name: 'None'} }
	node.kind = b.read_int()
	return node
}

fn (mut b ASTReadBuffer) read_super_expr() SuperExpr {
	mut node := SuperExpr{}
	b.read_loc(mut node.base)
	node.name = b.read_str()
	return node
}

fn (mut b ASTReadBuffer) read_assignment_expr() AssignmentExpr {
	mut node := AssignmentExpr{}
	b.read_loc(mut node.base)
	node.target = b.read_expression() or { NameExpr{name: 'None'} }
	node.value = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_await_expr() AwaitExpr {
	mut node := AwaitExpr{}
	b.read_loc(mut node.base)
	node.expr = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_pattern() ?Pattern {
	tag := b.read_tag()
	match tag {
		tag_as_pattern { return Pattern(b.read_as_pattern()) }
		tag_or_pattern { return Pattern(b.read_or_pattern()) }
		tag_value_pattern { return Pattern(b.read_value_pattern()) }
		tag_singleton_pattern { return Pattern(b.read_singleton_pattern()) }
		tag_sequence_pattern { return Pattern(b.read_sequence_pattern()) }
		tag_starred_pattern { return Pattern(b.read_starred_pattern()) }
		tag_mapping_pattern { return Pattern(b.read_mapping_pattern()) }
		tag_class_pattern { return Pattern(b.read_class_pattern()) }
		else { return none }
	}
}

fn (mut b ASTReadBuffer) read_as_pattern() AsPattern {
	mut node := AsPattern{}
	b.read_loc(mut node.pbase.base)
	if b.read_bool() { node.pattern = b.read_pattern_node() }
	if b.read_bool() { node.name = b.read_name_expr() }
	return node
}

fn (mut b ASTReadBuffer) read_pattern_node() ?PatternNode {
	p := b.read_pattern() or { return none }
	match p {
		AsPattern { return PatternNode(p) }
		ClassPattern { return PatternNode(p) }
		MappingPattern { return PatternNode(p) }
		OrPattern { return PatternNode(p) }
		SequencePattern { return PatternNode(p) }
		SingletonPattern { return PatternNode(p) }
		StarredPattern { return PatternNode(p) }
		ValuePattern { return PatternNode(p) }
		else { return none }
	}
}

fn (mut b ASTReadBuffer) read_or_pattern() OrPattern {
	mut node := OrPattern{}
	b.read_loc(mut node.pbase.base)
	return node
}

fn (mut b ASTReadBuffer) read_value_pattern() ValuePattern {
	mut node := ValuePattern{}
	b.read_loc(mut node.pbase.base)
	node.expr = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_singleton_pattern() SingletonPattern {
	mut node := SingletonPattern{}
	b.read_loc(mut node.pbase.base)
	return node
}

fn (mut b ASTReadBuffer) read_sequence_pattern() SequencePattern {
	mut node := SequencePattern{}
	b.read_loc(mut node.pbase.base)
	return node
}

fn (mut b ASTReadBuffer) read_starred_pattern() StarredPattern {
	mut node := StarredPattern{}
	b.read_loc(mut node.pbase.base)
	return node
}

fn (mut b ASTReadBuffer) read_mapping_pattern() MappingPattern {
	mut node := MappingPattern{}
	b.read_loc(mut node.pbase.base)
	return node
}

fn (mut b ASTReadBuffer) read_class_pattern() ClassPattern {
	mut node := ClassPattern{}
	b.read_loc(mut node.pbase.base)
	node.class_ref = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_index_expr() IndexExpr {
	mut node := IndexExpr{}
	b.read_loc(mut node.base)
	node.base_ = b.read_expression() or { NameExpr{name: 'None'} }
	node.index = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_bytes_expr() BytesExpr {
	mut node := BytesExpr{}
	b.read_loc(mut node.base)
	node.value = b.read_str()
	return node
}

fn (mut b ASTReadBuffer) read_float_expr() FloatExpr {
	mut node := FloatExpr{}
	b.read_loc(mut node.base)
	return node
}

fn (mut b ASTReadBuffer) read_complex_expr() ComplexExpr {
	mut node := ComplexExpr{}
	b.read_loc(mut node.base)
	return node
}

fn (mut b ASTReadBuffer) read_list_comprehension() ListComprehension {
	mut node := ListComprehension{}
	b.read_loc(mut node.base)
	node.generator = b.read_generator_expr()
	return node
}

fn (mut b ASTReadBuffer) read_set_comprehension() SetComprehension {
	mut node := SetComprehension{}
	b.read_loc(mut node.base)
	node.generator = b.read_generator_expr()
	return node
}

fn (mut b ASTReadBuffer) read_dictionary_comprehension() DictionaryComprehension {
	mut node := DictionaryComprehension{}
	b.read_loc(mut node.base)
	node.key = b.read_expression() or { NameExpr{name: 'None'} }
	node.value = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_type_application() TypeApplication {
	mut node := TypeApplication{}
	b.read_loc(mut node.base)
	node.expr = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_type_var_expr() TypeVarExpr {
	mut node := TypeVarExpr{}
	b.read_loc(mut node.base)
	node.name = b.read_str()
	node.fullname = b.read_str()
	return node
}

fn (mut b ASTReadBuffer) read_paramspec_expr() ParamSpecExpr {
	mut node := ParamSpecExpr{}
	b.read_loc(mut node.base)
	node.name = b.read_str()
	node.fullname = b.read_str()
	return node
}

fn (mut b ASTReadBuffer) read_type_var_tuple_expr() TypeVarTupleExpr {
	mut node := TypeVarTupleExpr{}
	b.read_loc(mut node.base)
	node.name = b.read_str()
	node.fullname = b.read_str()
	return node
}

fn (mut b ASTReadBuffer) read_type_alias_expr() TypeAliasExpr {
	mut node := TypeAliasExpr{}
	b.read_loc(mut node.base)
	return node
}

fn (mut b ASTReadBuffer) read_namedtuple_expr() NamedTupleExpr {
	mut node := NamedTupleExpr{}
	b.read_loc(mut node.base)
	return node
}

fn (mut b ASTReadBuffer) read_enum_call_expr() EnumCallExpr {
	mut node := EnumCallExpr{}
	b.read_loc(mut node.base)
	return node
}

fn (mut b ASTReadBuffer) read_typeddict_expr() TypedDictExpr {
	mut node := TypedDictExpr{}
	b.read_loc(mut node.base)
	return node
}

fn (mut b ASTReadBuffer) read_newtype_expr() NewTypeExpr {
	mut node := NewTypeExpr{}
	b.read_loc(mut node.base)
	node.name = b.read_str()
	return node
}

fn (mut b ASTReadBuffer) read_promote_expr() PromoteExpr {
	mut node := PromoteExpr{}
	b.read_loc(mut node.base)
	return node
}

fn (mut b ASTReadBuffer) read_operator_assignment_stmt() OperatorAssignmentStmt {
	mut node := OperatorAssignmentStmt{}
	b.read_loc(mut node.base)
	node.op = b.read_str()
	node.lvalue = b.read_lvalue() or { NameExpr{name: '_'} }
	node.rvalue = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_lvalue() ?Lvalue {
	tag := b.read_tag()
	node := b.read_node_tagged(tag) or { return none }
	match node {
		ListExpr { return Lvalue(node) }
		MemberExpr { return Lvalue(node) }
		NameExpr { return Lvalue(node) }
		StarExpr { return Lvalue(node) }
		TupleExpr { return Lvalue(node) }
		else { return none }
	}
}

fn (mut b ASTReadBuffer) read_cast_expr() CastExpr {
	mut node := CastExpr{}
	b.read_loc(mut node.base)
	node.expr = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_type_alias_stmt() TypeAliasStmt {
	mut node := TypeAliasStmt{}
	b.read_loc(mut node.base)
	node.name = b.read_name_expr()
	node.type_args = b.read_list_type_param()
	node.value = b.read_expression() or { NameExpr{name: 'None'} }
	return node
}

fn (mut b ASTReadBuffer) read_type_param() TypeParam {
	mut node := TypeParam{}
	node.name = b.read_str()
	node.kind = b.read_int()
	return node
}

fn (mut b ASTReadBuffer) read_mypy_file() MypyFile {
	mut node := MypyFile{}
	b.read_loc(mut node.base)
	node.defs = b.read_list_stmt()
	node.path = b.read_str()
	node.fullpath = b.read_str()
	node.fullname = b.read_str()
	node.is_stub = b.read_bool()
	node.is_partial_stub_package = b.read_bool()
	node.names = b.read_symbol_table()
	node.imports = b.read_list_import_base()
	node.is_bom = b.read_bool()
	node.ignored_lines = b.read_list_int()
	return node
}

fn (mut b ASTReadBuffer) read_symbol_table() SymbolTable {
	len := b.read_int_bare()
	mut res := map[string]SymbolTableNode{}
	for _ in 0 .. len {
		key := b.read_str_bare()
		res[key] = b.read_symbol_table_node()
	}
	return SymbolTable{symbols: res}
}

fn (mut b ASTReadBuffer) read_symbol_table_node() SymbolTableNode {
	mut node := SymbolTableNode{}
	node.kind = b.read_int()
	node.module_public = b.read_bool()
	node.module_hidden = b.read_bool()
	node.implicit = b.read_bool()
	node.plugin_generated = b.read_bool()
	node.no_serialize = b.read_bool()
	node.cross_ref = b.read_str_opt()
	node.node = b.read_symbol_node_ref()
	return node
}

fn (mut b ASTReadBuffer) read_symbol_node_ref() ?SymbolNodeRef {
	tag := b.read_tag()
	if tag == literal_none { return none }
	match tag {
		tag_class_def { return SymbolNodeRef(b.read_class_def()) }
		tag_func_def { return SymbolNodeRef(b.read_func_def()) }
		tag_var { return SymbolNodeRef(b.read_var()) }
		else { return none }
	}
}

fn (mut b ASTReadBuffer) read_type_info() TypeInfo {
	mut node := TypeInfo{}
	b.read_loc(mut node.base)
	node.name = b.read_str()
	node.fullname = b.read_str()
	return node
}

// ---------------------------------------------------------------------------
// Native Parse API
// ---------------------------------------------------------------------------

pub fn native_parse(filename string, options Options, skip_function_bodies bool, imports_only bool) !(MypyFile, []RawParseError, map[int][]string) {
	_ = skip_function_bodies
	source := os.read_file(filename)!
	mut errors := new_errors(options)
	tree := parse(source, filename, none, mut errors, options, false, imports_only)
	return tree, []RawParseError{}, map[int][]string{}
}

fn (mut b ASTReadBuffer) read_u8_or_zero() u8 {
	if b.pos >= b.data.len { return 0 }
	v := b.data[b.pos]
	b.pos++
	return v
}
