// Work in progress by Antigravity. Started: 2026-03-22 21:15
// nativeparse.v — Python parser that directly constructs a native AST from binary data.
// Translated from mypy/nativeparse.py

module mypy

import os
import math
import vlangtr.ast

// ---------------------------------------------------------------------------
// Constants for binary tags (normally imported from nodes/cache)
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
const dict_str_gen = u8(30)
const location = u8(152)
const end_tag = u8(255)

// Node tags (Placeholders)
const nodes_func_def_stmt = u8(1)
const nodes_decorator = u8(2)
const nodes_expr_stmt = u8(3)
const nodes_assignment_stmt = u8(4)
const nodes_operator_assignment_stmt = u8(5)
const nodes_if_stmt = u8(6)
const nodes_while_stmt = u8(7)
const nodes_for_stmt = u8(8)
const nodes_return_stmt = u8(9)
const nodes_assert_stmt = u8(10)
const nodes_del_stmt = u8(11)
const nodes_break_stmt = u8(12)
const nodes_continue_stmt = u8(13)
const nodes_pass_stmt = u8(14)
const nodes_raise_stmt = u8(15)
const nodes_try_stmt = u8(16)
const nodes_with_stmt = u8(17)
const nodes_import = u8(18)
const nodes_import_from = u8(19)
const nodes_import_all = u8(20)
const nodes_class_def = u8(21)
const nodes_match_stmt = u8(22)
const nodes_type_alias_stmt = u8(23)
const nodes_block = u8(24)
const nodes_global_stmt = u8(25)
const nodes_nonlocal_stmt = u8(26)

const nodes_name_expr = u8(100)
const nodes_int_expr = u8(101)
const nodes_str_expr = u8(102)
const nodes_bytes_expr = u8(103)
const nodes_float_expr = u8(104)
const nodes_call_expr = u8(105)
const nodes_member_expr = u8(106)
const nodes_op_expr = u8(107)
const nodes_unary_expr = u8(108)
const nodes_index_expr = u8(109)
const nodes_list_expr = u8(110)
const nodes_tuple_expr = u8(111)
const nodes_dict_expr = u8(112)
const nodes_set_expr = u8(113)
const nodes_bool_op_expr = u8(114)
const nodes_comparison_expr = u8(115)
const nodes_generator_expr = u8(116)
const nodes_list_comprehension = u8(117)
const nodes_set_comprehension = u8(118)
const nodes_dict_comprehension = u8(119)
const nodes_yield_expr = u8(120)
const nodes_yield_from_expr = u8(121)
const nodes_conditional_expr = u8(122)
const nodes_lambda_expr = u8(123)
const nodes_named_expr = u8(124)
const nodes_compare_expr = u8(125)
const nodes_await_expr = u8(126)
const nodes_starred_expr = u8(127)
const nodes_slice_expr = u8(128)
const nodes_joined_str = u8(129)
const nodes_formatted_value = u8(130)
const nodes_type_param = u8(131)
const nodes_comprehension = u8(132)
const nodes_none_expr = u8(133)

// Type tags
const types_unbound_type = u8(200)
const types_any_type = u8(201)
const types_union_type = u8(202)
const types_tuple_type = u8(203)
const types_none_type = u8(204)

// Pattern tags
const nodes_as_pattern = u8(250)
const nodes_or_pattern = u8(251)
const nodes_value_pattern = u8(252)
const nodes_singleton_pattern = u8(253)

// Operators
const bin_ops = ['+', '-', '*', '@', '/', '%', '**', '<<', '>>', '|', '^', '&', '//']
const bool_ops = ['and', 'or']
const cmp_ops = ['==', '!=', '<', '<=', '>', '>=', 'is', 'is not', 'in', 'not in']
const unary_ops = ['~', 'not', '+', '-']

// ---------------------------------------------------------------------------
// Deserialization State
// ---------------------------------------------------------------------------

pub struct ParseState {
pub mut:
	options   &Options
	errors    []RawParseError
	num_funcs int
}

pub fn (mut s ParseState) add_error(message string, line int, column int, blocker bool, code ?string) {
	s.errors << RawParseError{
		line:    line
		column:  column
		message: message
		blocker: blocker
		code:    code
	}
}

// ---------------------------------------------------------------------------
// ASTReadBuffer — helper for reading binary data
// ---------------------------------------------------------------------------

pub struct ASTReadBuffer {
pub mut:
	data []u8
	pos  int
}

pub fn ASTReadBuffer.new(data []u8) ASTReadBuffer {
	return ASTReadBuffer{
		data: data
		pos:  0
	}
}

pub fn (mut b ASTReadBuffer) read_tag() u8 {
	if b.pos >= b.data.len {
		return end_tag
	}
	tag := b.data[b.pos]
	b.pos++
	return tag
}

pub fn (mut b ASTReadBuffer) read_int_bare() int {
	mut res := 0
	mut shift := 0
	for {
		if b.pos >= b.data.len {
			break
		}
		byte := b.data[b.pos]
		b.pos++
		res |= (int(byte & 0x7F) << shift)
		if (byte & 0x80) == 0 {
			break
		}
		shift += 7
	}
	return res
}

pub fn (mut b ASTReadBuffer) read_int() int {
	b.expect_tag(literal_int)
	return b.read_int_bare()
}

pub fn (mut b ASTReadBuffer) read_bool() bool {
	tag := b.read_tag()
	return tag == literal_true
}

pub fn (mut b ASTReadBuffer) read_float_bare() f64 {
	if b.pos + 8 > b.data.len {
		b.pos = b.data.len
		return 0.0
	}
	mut bits := u64(0)
	for i in 0 .. 8 {
		bits |= u64(b.data[b.pos + i]) << (i * 8)
	}
	b.pos += 8
	return math.f64_from_bits(bits)
}

pub fn (mut b ASTReadBuffer) read_str_bare() string {
	len := b.read_int_bare()
	if b.pos + len > b.data.len {
		return ''
	}
	res := b.data[b.pos..b.pos + len].bytestr()
	b.pos += len
	return res
}

pub fn (mut b ASTReadBuffer) read_str() string {
	b.expect_tag(literal_str)
	return b.read_str_bare()
}

pub fn (mut b ASTReadBuffer) read_str_opt() ?string {
	tag := b.read_tag()
	if tag == literal_none {
		return none
	}
	b.pos--
	return b.read_str()
}

pub fn (mut b ASTReadBuffer) read_loc(mut node NodeBase) {
	tag := b.read_tag()
	if tag == location {
		line := b.read_int_bare()
		column := b.read_int_bare()
		end_line := b.read_int_bare()
		end_column := b.read_int_bare()
		node.ctx.set_line_int(line, column)
		node.ctx.set_end_line_int(end_line, end_column)
	} else {
		if b.pos > 0 {
			b.pos--
		}
	}
}

pub fn (mut b ASTReadBuffer) expect_tag(expected u8) {
	tag := b.read_tag()
	if tag != expected {
		panic('Expected tag ${expected}, got ${tag} at pos ${b.pos - 1}')
	}
}

pub fn (mut b ASTReadBuffer) expect_end_tag() {
	b.expect_tag(end_tag)
}

// ---------------------------------------------------------------------------
// Reading logic
// ---------------------------------------------------------------------------

pub fn native_parse(filename string, options Options, skip_function_bodies bool, imports_only bool) !(MypyFile, []RawParseError, map[int][]string) {
	if os.is_dir(filename) {
		mut node := empty_tree(filename, none)
		return node, []RawParseError{}, map[int][]string{}
	}

	ast_bytes, raw_errors, ignored_lines, import_bytes, is_partial_package, uses_template_strings := parse_to_binary_ast(filename,
		options, skip_function_bodies)!

	mut data := ASTReadBuffer.new(ast_bytes)
	n := data.read_int()
	mut state := State{
		options: &options
	}

	mut defs := []Statement{}
	if !imports_only {
		defs = read_statements(mut state, mut data, n)!
	}

	imports := deserialize_imports(import_bytes)!

	mut node := MypyFile{
		base:    NodeBase{}
		defs:    defs
		imports: imports
	}
	node.path = filename
	node.is_partial_stub_package = is_partial_package
	node.uses_template_strings = uses_template_strings

	if imports_only {
		node.raw_data = FileRawData{
			defs:                    ast_bytes
			imports:                 import_bytes
			ignored_lines:           ignored_lines
			is_partial_stub_package: is_partial_package
			uses_template_strings:   uses_template_strings
			raw_errors:              raw_errors
		}
	}

	mut all_errors := raw_errors.clone()
	all_errors << state.errors

	return node, all_errors, ignored_lines
}

fn read_statements(mut state State, mut data ASTReadBuffer, n int) ![]Statement {
	mut defs := []Statement{}
	old_num_funcs := state.num_funcs
	for _ in 0 .. n {
		stmt := read_statement(mut state, mut data)!
		defs << stmt
	}
	if state.num_funcs > old_num_funcs + 1 {
		defs = fix_function_overloads(mut state, defs)!
	}
	return defs
}

fn read_statement(mut state ParseState, mut data ASTReadBuffer) !Statement {
	tag := data.read_tag()
	match tag {
		nodes_func_def_stmt {
			return Statement(read_func_def(mut state, mut data)!)
		}
		nodes_decorator {
			data.expect_tag(list_gen)
			n_decorators := data.read_int_bare()
			mut decorators := []Expression{}
			for _ in 0 .. n_decorators {
				decorators << read_expression(mut state, mut data)!
			}
			line := data.read_int()
			column := data.read_int()
			fdef_stmt := read_statement(mut state, mut data)!
			if fdef_stmt is FuncDef {
				mut fdef := fdef_stmt
				fdef.is_decorated = true
				mut v := Var{
					base: NodeBase{}
					name: fdef.name
				}
				v.base.ctx.set_line_int(fdef.base.ctx.line, fdef.base.ctx.column)
				v.is_ready = false
				mut res := Decorator{
					base:       NodeBase{}
					func:       fdef
					decorators: decorators
					var_:       v
				}
				res.base.ctx.set_line_int(line, column)
				res.end_line = fdef.end_line
				res.end_column = fdef.end_column
				data.expect_end_tag()
				return Statement(res)
			}
			return error('Expected FuncDef after decorators')
		}
		nodes_expr_stmt {
			expr := read_expression(mut state, mut data)!
			mut es := ExpressionStmt{
				expr: expr
			}
			set_line_column_range(mut es.base, expr.get_context())
			data.expect_end_tag()
			return Statement(es)
		}
		nodes_assignment_stmt {
			lvalues := read_expression_list(mut state, mut data)!
			rvalue := read_expression(mut state, mut data)!
			has_type := data.read_bool()
			mut type_annotation := ?MypyTypeNode(none)
			if has_type {
				type_annotation = read_type(mut state, mut data)!
			}
			new_syntax := data.read_bool()
			mut a := AssignmentStmt{
				lvalues:         lvalues
				rvalue:          rvalue
				unanalyzed_type: type_annotation
				new_syntax:      new_syntax
			}
			data.read_loc(mut a.base)
			data.expect_end_tag()
			return Statement(a)
		}
		nodes_if_stmt {
			expr := read_expression(mut state, mut data)!
			body := read_block(mut state, mut data)!
			num_elif := data.read_int()
			mut elif_exprs := []Expression{}
			mut elif_bodies := []Block{}
			for _ in 0 .. num_elif {
				elif_exprs << read_expression(mut state, mut data)!
				elif_bodies << read_block(mut state, mut data)!
			}
			has_else := data.read_bool()
			mut else_body := ?Block(none)
			if has_else {
				else_body = read_block(mut state, mut data)!
			}

			mut current_else := else_body
			for i := elif_exprs.len - 1; i >= 0; i-- {
				mut elif_stmt := IfStmt{
					base:      NodeBase{}
					expr:      [elif_exprs[i]]
					body:      [elif_bodies[i]]
					else_body: current_else
				}
				elif_stmt.base.ctx.set_line_int(elif_exprs[i].get_context().line, elif_exprs[i].get_context().column)
				if mut eb := current_else {
					elif_stmt.end_line = eb.base.ctx.end_line
					elif_stmt.end_column = eb.base.ctx.end_column
				} else {
					elif_stmt.end_line = elif_bodies[i].base.ctx.end_line
					elif_stmt.end_column = elif_bodies[i].base.ctx.end_column
				}
				current_else = Block{
					base: NodeBase{}
					body: [Statement(elif_stmt)]
				}
				set_line_column_range(mut current_else.base, elif_stmt.base.ctx)
			}

			mut if_stmt := IfStmt{
				expr:      [expr]
				body:      [body]
				else_body: current_else
			}
			data.read_loc(mut if_stmt.base)
			data.expect_end_tag()
			return Statement(if_stmt)
		}
		nodes_while_stmt {
			expr := read_expression(mut state, mut data)!
			body := read_block(mut state, mut data)!
			else_body := read_optional_block(mut state, mut data)
			mut stmt := WhileStmt{
				expr:      expr
				body:      body
				else_body: else_body
			}
			data.read_loc(mut stmt.base)
			data.expect_end_tag()
			return Statement(stmt)
		}
		nodes_for_stmt {
			index := read_expression(mut state, mut data)!
			iter := read_expression(mut state, mut data)!
			body := read_block(mut state, mut data)!
			else_body := read_optional_block(mut state, mut data)
			is_async := data.read_bool()
			mut stmt := ForStmt{
				index:     index
				iter:      iter
				body:      body
				else_body: else_body
				is_async:  is_async
			}
			data.read_loc(mut stmt.base)
			data.expect_end_tag()
			return Statement(stmt)
		}
		nodes_return_stmt {
			has_value := data.read_bool()
			mut value := ?Expression(none)
			if has_value {
				value = read_expression(mut state, mut data)!
			}
			mut stmt := ReturnStmt{
				expr: value
			}
			data.read_loc(mut stmt.base)
			data.expect_end_tag()
			return Statement(stmt)
		}
		nodes_try_stmt {
			return Statement(read_try_stmt(mut state, mut data)!)
		}
		nodes_class_def {
			return Statement(read_class_def(mut state, mut data)!)
		}
		nodes_pass_stmt {
			mut stmt := PassStmt{}
			data.read_loc(mut stmt.base)
			data.expect_end_tag()
			return Statement(stmt)
		}
		else {
			return error('Unknown statement tag: ${tag}')
		}
	}
}

fn read_block(mut state State, mut data ASTReadBuffer) !Block {
	data.expect_tag(nodes_block)
	data.expect_tag(list_gen)
	n := data.read_int_bare()
	is_unreachable := data.read_bool()
	if n == 0 {
		mut res := Block{
			is_unreachable: is_unreachable
		}
		data.read_loc(mut res.base)
		data.expect_end_tag()
		return res
	} else {
		a := read_statements(mut state, mut data, n)!
		data.expect_end_tag()
		mut res := Block{
			body:           a
			is_unreachable: is_unreachable
		}
		if a.len > 0 {
			res.base.ctx.set_line_int(a[0].get_context().line, a[0].get_context().column)
			res.base.ctx.set_end_line_int(a.last().get_context().end_line, a.last().get_context().end_column)
		}
		return res
	}
}

fn read_optional_block(mut state State, mut data ASTReadBuffer) ?Block {
	data.expect_tag(nodes_block)
	data.expect_tag(list_gen)
	n := data.read_int_bare()
	is_unreachable := data.read_bool()
	if n == 0 {
		data.expect_end_tag()
		return none
	} else {
		mut a := []Statement{}
		for _ in 0 .. n {
			a << (read_statement(mut state, mut data) or { return none })
		}
		mut res := Block{
			body:           a
			is_unreachable: is_unreachable
		}
		if a.len > 0 {
			res.base.ctx.set_line_int(a[0].get_context().line, a[0].get_context().column)
			res.base.ctx.set_end_line_int(a.last().get_context().end_line, a.last().get_context().end_column)
		}
		data.expect_end_tag()
		return res
	}
}

fn read_try_stmt(mut state State, mut data ASTReadBuffer) !TryStmt {
	body := read_block(mut state, mut data)!
	num_handlers := data.read_int()

	mut types_list := []?Expression{}
	for _ in 0 .. num_handlers {
		if data.read_bool() {
			types_list << read_expression(mut state, mut data)!
		} else {
			types_list << none
		}
	}

	mut vars_list := []?NameExpr{}
	for _ in 0 .. num_handlers {
		if data.read_bool() {
			var_name := data.read_str()
			vars_list << NameExpr{
				name: var_name
			}
		} else {
			vars_list << none
		}
	}

	mut handlers := []Block{}
	for _ in 0 .. num_handlers {
		handlers << read_block(mut state, mut data)!
	}

	mut else_body := ?Block(none)
	if data.read_bool() {
		else_body = read_block(mut state, mut data)!
	}

	mut finally_body := ?Block(none)
	if data.read_bool() {
		finally_body = read_block(mut state, mut data)!
	}

	is_star := data.read_bool()

	mut stmt := TryStmt{
		body:         body
		vars:         vars_list
		types:        types_list
		handlers:     handlers
		else_body:    else_body
		finally_body: finally_body
		is_star:      is_star
	}
	data.read_loc(mut stmt.base)
	data.expect_end_tag()
	return stmt
}

fn read_class_def(mut state State, mut data ASTReadBuffer) !ClassDef {
	name := data.read_str()
	type_params := read_type_params(mut state, mut data)!
	base_type_exprs := read_expression_list(mut state, mut data)!
	keywords := read_keyword_expr_map(mut state, mut data)!
	defs := read_block(mut state, mut data)!

	mut stmt := ClassDef{
		name:            name
		defs:            defs
		base_type_exprs: base_type_exprs
		keywords:        keywords
		type_params:     type_params
	}
	if metaclass_expr := keywords['metaclass'] {
		if metaclass_name := expr_to_name(metaclass_expr) {
			stmt.metaclass = metaclass_name
		}
	}
	data.read_loc(mut stmt.base)
	data.expect_end_tag()
	return stmt
}

fn read_keyword_expr_map(mut state State, mut data ASTReadBuffer) !map[string]Expression {
	data.expect_tag(list_gen)
	n := data.read_int_bare()
	mut keywords := map[string]Expression{}
	for _ in 0 .. n {
		key := data.read_str()
		value := read_expression(mut state, mut data)!
		keywords[key] = value
	}
	return keywords
}

fn read_type_params(mut state ParseState, mut data ASTReadBuffer) ![]TypeParam {
	data.expect_tag(list_gen)
	n := data.read_int_bare()
	mut params := []TypeParam{}
	for _ in 0 .. n {
		params << read_type_param(mut state, mut data)!
	}
	return params
}

fn read_type_param(mut state ParseState, mut data ASTReadBuffer) !TypeParam {
	data.expect_tag(nodes_type_param)
	name := data.read_str()
	kind := data.read_int_bare()
	mut upper_bound := ?MypyTypeNode(none)
	if data.read_bool() {
		upper_bound = read_type(mut state, mut data)!
	}
	mut default := ?MypyTypeNode(none)
	if data.read_bool() {
		default = read_type(mut state, mut data)!
	}
	mut dummy := NodeBase{}
	data.read_loc(mut dummy)
	data.expect_end_tag()
	return TypeParam{
		name:        name
		kind:        kind
		upper_bound: upper_bound
		default:     default
	}
}

fn expr_to_name(expr Expression) ?string {
	match expr {
		NameExpr {
			return expr.name
		}
		MemberExpr {
			if left := expr_to_name(expr.expr) {
				return '${left}.${expr.name}'
			}
			return expr.name
		}
		else {
			return none
		}
	}
}

fn read_slice_expr(mut state ParseState, mut data ASTReadBuffer) !SliceExpr {
	has_lower := data.read_bool()
	lower := if has_lower { read_expression(mut state, mut data)! } else { none }
	has_upper := data.read_bool()
	upper := if has_upper { read_expression(mut state, mut data)! } else { none }
	has_step := data.read_bool()
	step := if has_step { read_expression(mut state, mut data)! } else { none }
	mut res := SliceExpr{
		begin_index: lower
		end_index:   upper
		stride:      step
	}
	data.read_loc(mut res.base)
	data.expect_end_tag()
	return res
}

fn read_dict_expr(mut state ParseState, mut data ASTReadBuffer) !DictExpr {
	data.expect_tag(list_gen)
	n := data.read_int_bare()
	mut items := []DictItem{}
	for _ in 0 .. n {
		// Key can be NoneExpr (nodes_none_expr) for **spread
		mut key_tag := data.peek_tag()
		mut key := ?Expression(none)
		if key_tag == nodes_none_expr {
			data.read_tag() // consume nodes_none_expr
			data.read_loc(mut NodeBase{}) // consume its loc
			data.expect_end_tag()
		} else {
			key = read_expression(mut state, mut data)!
		}
		value := read_expression(mut state, mut data)!
		items << DictItem{
			key:   key
			value: value
		}
	}
	mut res := DictExpr{
		items: items
	}
	data.read_loc(mut res.base)
	data.expect_end_tag()
	return res
}

fn read_joined_str(mut state ParseState, mut data ASTReadBuffer) !TemplateStrExpr {
	parts := read_expression_list(mut state, mut data)!
	mut res := TemplateStrExpr{
		parts: parts
	}
	data.read_loc(mut res.base)
	data.expect_end_tag()
	return res
}

fn read_format_string_expr(mut state ParseState, mut data ASTReadBuffer) !FormatStringExpr {
	value := read_expression(mut state, mut data)!
	conversion := data.read_int()
	has_spec := data.read_bool()
	format_spec := if has_spec { read_expression(mut state, mut data)! } else { none }
	mut res := FormatStringExpr{
		value:       value
		conversion:  conversion
		format_spec: format_spec
	}
	data.read_loc(mut res.base)
	data.expect_end_tag()
	return res
}

fn (mut b ASTReadBuffer) peek_tag() u8 {
	if b.pos >= b.data.len {
		return end_tag
	}
	return b.data[b.pos]
}

fn read_expression(mut state ParseState, mut data ASTReadBuffer) !Expression {
	tag := data.read_tag()
	match tag {
		nodes_name_expr {
			name := data.read_str()
			mut res := NameExpr{
				name: name
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_int_expr {
			val := data.read_int_bare()
			mut res := IntExpr{
				value: val
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_str_expr {
			mut res := StrExpr{
				value: data.read_str_bare()
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_float_expr {
			data.expect_tag(literal_float)
			mut res := FloatExpr{
				value: data.read_float_bare()
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_call_expr {
			callee := read_expression(mut state, mut data)!
			args := read_expression_list(mut state, mut data)!
			data.expect_tag(list_int)
			n_kinds := data.read_int_bare()
			mut arg_kinds := []ArgKind{}
			for _ in 0 .. n_kinds {
				arg_kinds << arg_kinds_list[data.read_int_bare()] or { arg_pos }
			}
			data.expect_tag(list_gen)
			n_names := data.read_int_bare()
			mut arg_names := []?string{}
			for _ in 0 .. n_names {
				arg_names << data.read_str_opt()
			}
			mut res := CallExpr{
				callee:    callee
				args:      args
				arg_kinds: arg_kinds
				arg_names: arg_names
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_member_expr {
			e := read_expression(mut state, mut data)!
			attr := data.read_str()
			mut m := MemberExpr{
				expr: e
				name: attr
			}
			data.read_loc(mut m.base)
			data.expect_end_tag()
			return Expression(m)
		}
		nodes_op_expr {
			op_idx := data.read_int()
			op := bin_ops[op_idx] or { '+' }
			left := read_expression(mut state, mut data)!
			right := read_expression(mut state, mut data)!
			mut res := OpExpr{
				op:    op
				left:  left
				right: right
			}
			set_line_column_range(mut res.base, left.get_context())
			res.base.ctx.set_end_line_int(right.get_context().end_line, right.get_context().end_column)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_bool_op_expr {
			op_idx := data.read_int()
			op := bool_ops[op_idx] or { 'and' }
			values := read_expression_list(mut state, mut data)!
			if values.len < 2 {
				return error('BoolOpExpr requires at least 2 values')
			}
			mut result := values[0]
			for i in 1 .. values.len {
				mut nest := OpExpr{
					op:    op
					left:  result
					right: values[i]
				}
				set_line_column_range(mut nest.base, result.get_context())
				nest.base.ctx.set_end_line_int(values[i].get_context().end_line, values[i].get_context().end_column)
				result = Expression(nest)
			}
			data.expect_end_tag()
			return result
		}
		nodes_index_expr {
			base := read_expression(mut state, mut data)!
			index := read_expression(mut state, mut data)!
			mut res := IndexExpr{
				base:  base
				index: index
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_list_expr {
			items := read_expression_list(mut state, mut data)!
			mut res := ListExpr{
				items: items
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_tuple_expr {
			items := read_expression_list(mut state, mut data)!
			mut res := TupleExpr{
				items: items
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_yield_expr {
			has_value := data.read_bool()
			mut res := YieldExpr{
				expr: if has_value { read_expression(mut state, mut data)! } else { none }
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_yield_from_expr {
			expr := read_expression(mut state, mut data)!
			mut res := YieldFromExpr{
				expr: expr
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_await_expr {
			expr := read_expression(mut state, mut data)!
			mut res := AwaitExpr{
				expr: expr
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_slice_expr {
			return Expression(read_slice_expr(mut state, mut data)!)
		}
		nodes_dict_expr {
			return Expression(read_dict_expr(mut state, mut data)!)
		}
		nodes_set_expr {
			items := read_expression_list(mut state, mut data)!
			mut res := SetExpr{
				items: items
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_joined_str {
			return Expression(read_joined_str(mut state, mut data)!)
		}
		nodes_formatted_value {
			return Expression(read_format_string_expr(mut state, mut data)!)
		}
		nodes_lambda_expr {
			args, arg_kinds, arg_names, _ := read_parameters(mut state, mut data)!
			body := read_expression(mut state, mut data)!
			mut res := LambdaExpr{
				arguments: args
				arg_kinds: arg_kinds
				arg_names: arg_names
				body:      body
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_starred_expr {
			expr := read_expression(mut state, mut data)!
			mut res := StarExpr{
				expr: expr
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		nodes_named_expr {
			target := read_expression(mut state, mut data)!
			value := read_expression(mut state, mut data)!
			if target is NameExpr {
				mut res := AssignmentExpr{
					target: target
					value:  value
				}
				data.read_loc(mut res.base)
				data.expect_end_tag()
				return Expression(res)
			}
			return error('NamedExpr must have a Name target')
		}
		nodes_none_expr {
			// This is a special placeholder for **spread in Dict
			// Since we can't return 'none' as an Expression sum type, 
			// we return a temporary marker or handle it in DictExpr.
			// Formally, this should NOT happen outside of Dict keys.
			return error('NoneExpr should only occur in Dict keys')
		}
		else {
			return error('Unknown expression tag: ${tag}')
		}
	}
}

fn read_expression_list(mut state State, mut data ASTReadBuffer) ![]Expression {
	data.expect_tag(list_gen)
	n := data.read_int_bare()
	mut res := []Expression{}
	for _ in 0 .. n {
		res << read_expression(mut state, mut data)!
	}
	return res
}

fn read_func_def(mut state State, mut data ASTReadBuffer) !FuncDef {
	state.num_funcs++
	name := data.read_str()
	args, arg_kinds, arg_names, _ := read_parameters(mut state, mut data)!
	body := read_block(mut state, mut data)!
	is_async := data.read_bool()

	mut fdef := FuncDef{
		name:      name
		arguments: args
		arg_kinds: arg_kinds
		arg_names: arg_names
		body:      body
	}
	if is_async {
		fdef.is_coroutine = true
	}
	data.read_loc(mut fdef.base)
	data.expect_end_tag()
	return fdef
}

fn read_parameters(mut state State, mut data ASTReadBuffer) !([]Argument, []ArgKind, []?string, bool) {
	data.expect_tag(list_gen)
	n := data.read_int_bare()
	mut arguments := []Argument{}
	mut arg_kinds := []ArgKind{}
	mut arg_names := []?string{}
	mut has_ann := false
	for _ in 0 .. n {
		arg_name := data.read_str()
		kind_idx := data.read_int()
		kind := arg_kinds_list[kind_idx] or { arg_pos }
		mut typ := ?MypyTypeNode(none)
		if data.read_bool() {
			typ = read_type(mut state, mut data)!
			has_ann = true
		}
		if data.read_bool() {
			_ = read_expression(mut state, mut data)! // default
		}
		pos_only := data.read_bool()
		mut arg := Argument{
			variable:        Var{
				name: arg_name
			}
			type_annotation: typ
			kind:            kind
			pos_only:        pos_only
		}
		data.read_loc(mut arg.base)
		arguments << arg
		arg_kinds << kind
		arg_names << arg_name
	}
	return arguments, arg_kinds, arg_names, has_ann
}

fn read_type(mut state ParseState, mut data ASTReadBuffer) !MypyTypeNode {
	tag := data.read_tag()
	match tag {
		types_any_type {
			mut res := AnyType{}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return MypyTypeNode(res)
		}
		types_none_type {
			mut res := NoneType{}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return MypyTypeNode(res)
		}
		types_unbound_type {
			name := data.read_str()
			data.expect_tag(list_gen)
			n := data.read_int_bare()
			mut args := []MypyTypeNode{}
			for _ in 0 .. n {
				args << read_type(mut state, mut data)!
			}
			data.read_bool()
			data.expect_end_tag()
			return MypyTypeNode(UnboundType{
				name: name
				args: args
			})
		}
		else {
			return error('Unknown type tag: ${tag}')
		}
	}
}

// ... other imports

fn parse_to_binary_ast(filename string, options Options, skip_function_bodies bool) !([]u8, []RawParseError, map[int][]string, []u8, bool, bool) {
	content := os.read_file(filename) or { return error('Failed to read file ${filename}') }
	mut l := ast.new_lexer(content, filename)
	mut p := ast.new_parser(l)
	mod := p.parse_module()

	mut s := ast.Serializer.new()
	bytes := s.serialize_module(mod)

	// Returns: (binary_ast, errors, line_ranges, imports, is_stub, has_dunder_all)
	return bytes, []RawParseError{}, map[int][]string{}, []u8{}, false, false
}

fn deserialize_imports(b []u8) ![]ImportBase {
	return []ImportBase{}
}

fn fix_function_overloads(mut state State, defs []Statement) ![]Statement {
	return defs
}

fn set_line_column_range(mut node NodeBase, source Context) {
	node.ctx.set_line_int(source.line, source.column)
	node.ctx.set_end_line_int(source.end_line, source.end_column)
}

const arg_kinds_list = [arg_pos, arg_opt, arg_star, arg_named, arg_named_opt, arg_star2]
