// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 21:15
// nativeparse.v — Python parser that directly constructs a native AST from binary data.
// Переведён из mypy/nativeparse.py

module mypy

import os

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
const dict_str_gen = u8(30)
const location = u8(152)
const end_tag = u8(255)

// Node tags (Placeholders - adjust based on actual nodes.v constants)
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

const nodes_name_expr = u8(100)
const nodes_int_expr = u8(101)
const nodes_call_expr = u8(102)

// Type tags
const types_unbound_type = u8(200)
const types_any_type = u8(201)
const types_union_type = u8(202)
const types_tuple_type = u8(203)

// Pattern tags
const nodes_as_pattern = u8(250)
const nodes_or_pattern = u8(251)
const nodes_value_pattern = u8(252)
const nodes_singleton_pattern = u8(253)

// ---------------------------------------------------------------------------
// Deserialization State
// ---------------------------------------------------------------------------

pub struct State {
pub mut:
	options   &Options
	errors    []RawParseError
	num_funcs int
}

pub fn (mut s State) add_error(message string, line int, column int, blocker bool, code ?string) {
	s.errors << RawParseError{
		line:    line
		column:  column
		message: message
		blocker: blocker
		code:    code
	}
}

// ---------------------------------------------------------------------------
// ReadBuffer — helper for reading binary data
// ---------------------------------------------------------------------------

pub struct ReadBuffer {
pub mut:
	data []u8
	pos  int
}

pub fn ReadBuffer.new(data []u8) ReadBuffer {
	return ReadBuffer{
		data: data
		pos:  0
	}
}

pub fn (mut b ReadBuffer) read_tag() u8 {
	if b.pos >= b.data.len {
		return end_tag
	}
	tag := b.data[b.pos]
	b.pos++
	return tag
}

pub fn (mut b ReadBuffer) read_int_bare() int {
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

pub fn (mut b ReadBuffer) read_int() int {
	b.expect_tag(literal_int)
	return b.read_int_bare()
}

pub fn (mut b ReadBuffer) read_bool() bool {
	tag := b.read_tag()
	return tag == literal_true
}

pub fn (mut b ReadBuffer) read_str_bare() string {
	len := b.read_int_bare()
	if b.pos + len > b.data.len {
		return ''
	}
	res := b.data[b.pos..b.pos + len].bytestr()
	b.pos += len
	return res
}

pub fn (mut b ReadBuffer) read_str() string {
	b.expect_tag(literal_str)
	return b.read_str_bare()
}

pub fn (mut b ReadBuffer) read_str_opt() ?string {
	tag := b.read_tag()
	if tag == literal_none {
		return none
	}
	// Note: in FF some strings might not have tag if it's already known
	b.pos-- // Expect read_str to check tag
	return b.read_str()
}

pub fn (mut b ReadBuffer) read_loc(mut node NodeBase) {
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

pub fn (mut b ReadBuffer) expect_tag(expected u8) {
	tag := b.read_tag()
	if tag != expected {
		panic('Expected tag ${expected}, got ${tag} at pos ${b.pos - 1}')
	}
}

pub fn (mut b ReadBuffer) expect_end_tag() {
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

	ast_bytes, raw_errors, ignored_lines, import_bytes, is_partial_package, uses_template_strings := parse_to_binary_ast(
		filename, options, skip_function_bodies
	)!

	mut data := ReadBuffer.new(ast_bytes)
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
		base:     NodeBase{} // Placeholder
		defs:     defs
		imports:  imports
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

fn read_statements(mut state State, mut data ReadBuffer, n int) ![]Statement {
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

fn read_statement(mut state State, mut data ReadBuffer) !Statement {
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
					base: NodeBase{} // Will be set via copy
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
			// Logic for TempNode omitted for brevity
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
			else_body := read_optional_block(mut state, mut data)!
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
			else_body := read_optional_block(mut state, mut data)!
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

fn read_block(mut state State, mut data ReadBuffer) !Block {
	data.expect_tag(list_gen)
	n := data.read_int_bare()
	mut body := []Statement{}
	for _ in 0 .. n {
		body << read_statement(mut state, mut data)!
	}
	mut res := Block{
		body: body
	}
	data.read_loc(mut res.base)
	data.expect_end_tag()
	return res
}

fn read_optional_block(mut state State, mut data ReadBuffer) !?Block {
	tag := data.read_tag()
	if tag == literal_none {
		return none
	}
	data.pos--
	return read_block(mut state, mut data)!
}

fn read_try_stmt(mut state State, mut data ReadBuffer) !TryStmt {
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

fn read_expression(mut state State, mut data ReadBuffer) !Expression {
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
		nodes_call_expr {
			callee := read_expression(mut state, mut data)!
			args := read_expression_list(mut state, mut data)!
			mut res := CallExpr{
				callee: callee
				args:   args
			}
			data.read_loc(mut res.base)
			data.expect_end_tag()
			return Expression(res)
		}
		else {
			return error('Unknown expression tag: ${tag}')
		}
	}
}

fn read_expression_list(mut state State, mut data ReadBuffer) ![]Expression {
	data.expect_tag(list_gen)
	n := data.read_int_bare()
	mut res := []Expression{}
	for _ in 0 .. n {
		res << read_expression(mut state, mut data)!
	}
	return res
}

fn read_func_def(mut state State, mut data ReadBuffer) !FuncDef {
	state.num_funcs++
	name := data.read_str()
	args, _ := read_parameters(mut state, mut data)!
	body := read_block(mut state, mut data)!
	is_async := data.read_bool()

	mut fdef := FuncDef{
		name:      name
		arguments: args
		body:      body
	}
	if is_async {
		fdef.is_coroutine = true
	}
	data.read_loc(mut fdef.base)
	data.expect_end_tag()
	return fdef
}

fn read_parameters(mut state State, mut data ReadBuffer) !([]Argument, bool) {
	data.expect_tag(list_gen)
	n := data.read_int_bare()
	mut arguments := []Argument{}
	mut has_ann := false
	for _ in 0 .. n {
		arg_name := data.read_str()
		_ = data.read_int() // kind
		mut typ := ?MypyTypeNode(none)
		if data.read_bool() {
			typ = read_type(mut state, mut data)!
			has_ann = true
		}
		if data.read_bool() {
			_ = read_expression(mut state, mut data)! // default
		}
		_ = data.read_bool() // pos_only
		mut arg := Argument{
			variable: Var{
				name: arg_name
			}
			type_annotation: typ
		}
		data.read_loc(mut arg.base)
		arguments << arg
	}
	return arguments, has_ann
}

fn read_type(mut state State, mut data ReadBuffer) !MypyTypeNode {
	tag := data.read_tag()
	match tag {
		types_any_type {
			res := AnyType{}
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

fn parse_to_binary_ast(filename string, options Options, skip_function_bodies bool) !([]u8, []RawParseError, map[int][]string, []u8, bool, bool) {
	return []u8{}, []RawParseError{}, map[int][]string{}, []u8{}, false, false
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
