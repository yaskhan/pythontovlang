module ast

import math

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
const bin_ops = ['+', '-', '*', '@', '/', '%', '**', '<<', '>>', '|', '^', '&', '//']
const bool_ops = ['and', 'or']
const cmp_ops = ['==', '!=', '<', '<=', '>', '>=', 'is', 'is not', 'in', 'not in']
const unary_ops = ['~', 'not', '+', '-']


// Type tags
const types_unbound_type = u8(200)
const types_any_type = u8(201)
const types_union_type = u8(202)
const types_tuple_type = u8(203)
const types_none_type = u8(204)
const types_typevar = u8(205)
const types_paramspec = u8(206)
const types_typevartuple = u8(207)

// TypeParamKind tags
const typeparam_typevar = u8(0)
const typeparam_typevartuple = u8(1)
const typeparam_paramspec = u8(2)

const arg_kind_pos = 0
const arg_kind_opt = 1
const arg_kind_star = 2
const arg_kind_named = 3
const arg_kind_named_opt = 4
const arg_kind_star2 = 5

// Pattern tags
const nodes_as_pattern = u8(250)
const nodes_or_pattern = u8(251)
const nodes_value_pattern = u8(252)
const nodes_singleton_pattern = u8(253)
const nodes_sequence_pattern = u8(240)
const nodes_mapping_pattern = u8(241)
const nodes_class_pattern = u8(242)
const nodes_star_pattern = u8(243)

// ---------------------------------------------------------------------------
// Serializer
// ---------------------------------------------------------------------------

pub struct Serializer {
pub mut:
	buf []u8
}

struct SerializedParameter {
	param     Parameter
	kind      int
	pos_only  bool
}

struct SerializedCallArg {
	expr Expression
	kind int
	name ?string
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
	// Decorators wrapping FuncDef or ClassDef
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
		}
	} else if node is ClassDef {
		if node.decorator_list.len > 0 {
			s.write_tag(nodes_decorator)
			s.write_tag(list_gen)
			s.write_int_bare(node.decorator_list.len)
			for d in node.decorator_list {
				s.write_expression(d)
			}
			s.write_int(node.get_token().line)
			s.write_int(node.get_token().column)
		}
	}

	match node {
		FunctionDef {
			s.write_tag(nodes_func_def_stmt)
			s.write_str(node.name)
			// Type params (Python 3.12+)
			s.write_type_params(node.type_params)
			// Parameters
			s.write_parameters(node.args)
			s.write_block(node.body)
			s.write_tag(if node.is_async { literal_true } else { literal_false })
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		If {
			s.write_tag(nodes_if_stmt)
			s.write_expression(node.test)
			s.write_block(node.body)
			s.write_int(0) // num_elif (nested in mypy)
			if node.orelse.len > 0 {
				s.write_tag(literal_true)
				s.write_block(node.orelse)
			} else {
				s.write_tag(literal_false)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		While {
			s.write_tag(nodes_while_stmt)
			s.write_expression(node.test)
			s.write_block(node.body)
			if node.orelse.len > 0 {
				s.write_block(node.orelse)
			} else {
				s.write_tag(literal_none)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		For {
			s.write_tag(nodes_for_stmt)
			s.write_expression(node.target)
			s.write_expression(node.iter)
			s.write_block(node.body)
			if node.orelse.len > 0 {
				s.write_block(node.orelse)
			} else {
				s.write_tag(literal_none)
			}
			s.write_tag(if node.is_async { literal_true } else { literal_false })
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		TryStar {
			s.write_tag(nodes_try_stmt)
			s.write_block(node.body)
			s.write_int(node.handlers.len)
			for h in node.handlers {
				if typ := h.typ {
					s.write_tag(literal_true)
					s.write_expression(typ)
				} else {
					s.write_tag(literal_false)
				}
			}
			for h in node.handlers {
				if name := h.name {
					s.write_tag(literal_true)
					s.write_str(name)
				} else {
					s.write_tag(literal_false)
				}
			}
			for h in node.handlers {
				s.write_block(h.body)
			}
			if node.orelse.len > 0 {
				s.write_tag(literal_true)
				s.write_block(node.orelse)
			} else {
				s.write_tag(literal_false)
			}
			if node.finalbody.len > 0 {
				s.write_tag(literal_true)
				s.write_block(node.finalbody)
			} else {
				s.write_tag(literal_false)
			}
			s.write_tag(literal_true) // is_star = true for TryStar
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		With {
			s.write_tag(nodes_with_stmt)
			s.write_tag(list_gen)
			s.write_int_bare(node.items.len)
			for item in node.items {
				s.write_expression(item.context_expr)
				if val := item.optional_vars {
					s.write_tag(literal_true)
					s.write_expression(val)
				} else {
					s.write_tag(literal_false)
				}
			}
			s.write_block(node.body)
			s.write_tag(if node.is_async { literal_true } else { literal_false })
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Delete {
			s.write_tag(nodes_del_stmt)
			s.write_tag(list_gen)
			s.write_int_bare(node.targets.len)
			for t in node.targets {
				s.write_expression(t)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Match {
			s.write_tag(nodes_match_stmt)
			s.write_expression(node.subject)
			s.write_tag(list_gen)
			s.write_int_bare(node.cases.len)
			for c in node.cases {
				s.write_pattern(c.pattern)
				if guard := c.guard {
					s.write_tag(literal_true)
					s.write_expression(guard)
				} else {
					s.write_tag(literal_false)
				}
				s.write_block(c.body)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		TypeAlias {
			s.write_tag(nodes_type_alias_stmt)
			s.write_str(node.name)
			s.write_type_params(node.type_params)
			s.write_type(node.value)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Global {
			s.write_tag(nodes_global_stmt)
			s.write_tag(list_str)
			s.write_int_bare(node.names.len)
			for name in node.names {
				s.write_str_bare(name)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Nonlocal {
			s.write_tag(nodes_nonlocal_stmt)
			s.write_tag(list_str)
			s.write_int_bare(node.names.len)
			for name in node.names {
				s.write_str_bare(name)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Assign {
			s.write_tag(nodes_assignment_stmt)
			s.write_tag(list_gen)
			s.write_int_bare(node.targets.len)
			for t in node.targets {
				s.write_expression(t)
			}
			s.write_expression(node.value)
			s.write_tag(literal_false) // no type info in ast.Assign
			s.write_tag(literal_false) // new_syntax
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		AugAssign {
			s.write_tag(nodes_operator_assignment_stmt)
			s.write_expression(node.target)
			idx := bin_ops.index(node.op.value)
			s.write_int(if idx >= 0 { idx } else { 0 })
			s.write_expression(node.value)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		AnnAssign {
			s.write_tag(nodes_assignment_stmt)
			s.write_tag(list_gen)
			s.write_int_bare(1)
			s.write_expression(node.target)
			if val := node.value {
				s.write_expression(val)
			} else {
				// Assignment must have a value in binary format usually, use none?
				// Nativeparse expects an expression, so use a placeholder name.
				s.write_tag(nodes_name_expr)
				s.write_str('...')
				s.write_loc(node.token)
				s.write_tag(end_tag)
			}
			s.write_tag(literal_true) // has_type
			s.write_type(node.annotation)
			s.write_tag(literal_true) // new_syntax
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
		Break {
			s.write_tag(nodes_break_stmt)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Continue {
			s.write_tag(nodes_continue_stmt)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Assert {
			s.write_tag(nodes_assert_stmt)
			s.write_expression(node.test)
			if msg := node.msg {
				s.write_tag(literal_true)
				s.write_expression(msg)
			} else {
				s.write_tag(literal_false)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Raise {
			s.write_tag(nodes_raise_stmt)
			if exc := node.exc {
				s.write_tag(literal_true)
				s.write_expression(exc)
			} else {
				s.write_tag(literal_false)
			}
			if cause := node.cause {
				s.write_tag(literal_true)
				s.write_expression(cause)
			} else {
				s.write_tag(literal_false)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Try {
			s.write_tag(nodes_try_stmt)
			s.write_block(node.body)
			s.write_int(node.handlers.len)
			for h in node.handlers {
				if typ := h.typ {
					s.write_tag(literal_true)
					s.write_expression(typ)
				} else {
					s.write_tag(literal_false)
				}
			}
			for h in node.handlers {
				if name := h.name {
					s.write_tag(literal_true)
					s.write_str(name)
				} else {
					s.write_tag(literal_false)
				}
			}
			for h in node.handlers {
				s.write_block(h.body)
			}
			if node.orelse.len > 0 {
				s.write_tag(literal_true)
				s.write_block(node.orelse)
			} else {
				s.write_tag(literal_false)
			}
			if node.finalbody.len > 0 {
				s.write_tag(literal_true)
				s.write_block(node.finalbody)
			} else {
				s.write_tag(literal_false)
			}
			s.write_tag(literal_false) // is_star
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		ClassDef {
			s.write_tag(nodes_class_def)
			s.write_str(node.name)
			// Type params (Python 3.12+)
			s.write_type_params(node.type_params)
			s.write_tag(list_gen)
			s.write_int_bare(node.bases.len)
			for base in node.bases {
				s.write_expression(base)
			}
			s.write_tag(list_gen)
			s.write_int_bare(node.keywords.len)
			for kw in node.keywords {
				s.write_str(kw.arg)
				s.write_expression(kw.value)
			}
			s.write_block(node.body)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Import {
			s.write_tag(nodes_import)
			s.write_tag(list_gen)
			s.write_int_bare(node.names.len)
			for alias in node.names {
				s.write_str(alias.name)
				if val := alias.asname {
					s.write_tag(literal_true)
					s.write_str(val)
				} else {
					s.write_tag(literal_false)
				}
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		ImportFrom {
			s.write_tag(nodes_import_from)
			s.write_str(node.module)
			s.write_tag(list_gen)
			s.write_int_bare(node.names.len)
			for alias in node.names {
				s.write_str(alias.name)
				if val := alias.asname {
					s.write_tag(literal_true)
					s.write_str(val)
				} else {
					s.write_tag(literal_false)
				}
			}
			s.write_int(node.level)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		else {
			// Skip other statements
		}
	}
}
pub fn (mut s Serializer) write_comprehension(gen Comprehension) {
	s.write_tag(nodes_comprehension)
	s.write_expression(gen.target)
	s.write_expression(gen.iter)
	s.write_tag(list_gen)
	s.write_int_bare(gen.ifs.len)
	for if_clause in gen.ifs {
		s.write_expression(if_clause)
	}
	s.write_tag(if gen.is_async { literal_true } else { literal_false })
	s.write_tag(end_tag)
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
				if node.value.contains('.') {
					s.write_tag(nodes_float_expr)
					s.write_tag(literal_float)
					s.write_float_bare(node.value.f64())
				} else {
					s.write_tag(nodes_int_expr)
					s.write_int_bare(node.value.int())
				}
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
			call_args := s.collect_call_args(node)
			s.write_tag(list_gen)
			s.write_int_bare(call_args.len)
			for arg in call_args {
				s.write_expression(arg.expr)
			}
			s.write_tag(list_int)
			s.write_int_bare(call_args.len)
			for arg in call_args {
				s.write_int_bare(arg.kind)
			}
			s.write_tag(list_gen)
			s.write_int_bare(call_args.len)
			for arg in call_args {
				s.write_optional_str(arg.name)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		BinaryOp {
			s.write_tag(nodes_op_expr)
			idx := bin_ops.index(node.op.value)
			s.write_int(if idx >= 0 { idx } else { 0 })
			s.write_expression(node.left)
			s.write_expression(node.right)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		UnaryOp {
			s.write_tag(nodes_unary_expr)
			idx := unary_ops.index(node.op.value)
			s.write_int(if idx >= 0 { idx } else { 0 })
			s.write_expression(node.operand)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Attribute {
			s.write_tag(nodes_member_expr)
			s.write_expression(node.value)
			s.write_str(node.attr)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Subscript {
			s.write_tag(nodes_index_expr)
			s.write_expression(node.value)
			s.write_expression(node.slice)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		List {
			s.write_tag(nodes_list_expr)
			s.write_tag(list_gen)
			s.write_int_bare(node.elements.len)
			for el in node.elements {
				s.write_expression(el)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Tuple {
			s.write_tag(nodes_tuple_expr)
			s.write_tag(list_gen)
			s.write_int_bare(node.elements.len)
			for el in node.elements {
				s.write_expression(el)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Dict {
			s.write_tag(nodes_dict_expr)
			s.write_tag(list_gen)
			s.write_int_bare(node.keys.len)
			for i in 0 .. node.keys.len {
				s.write_expression(node.keys[i])
				s.write_expression(node.values[i])
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Set {
			s.write_tag(nodes_set_expr)
			s.write_tag(list_gen)
			s.write_int_bare(node.elements.len)
			for el in node.elements {
				s.write_expression(el)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Yield {
			s.write_tag(nodes_yield_expr)
			if val := node.value {
				s.write_tag(literal_true)
				s.write_expression(val)
			} else {
				s.write_tag(literal_false)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		IfExp {
			s.write_tag(nodes_conditional_expr)
			s.write_expression(node.test)
			s.write_expression(node.body)
			s.write_expression(node.orelse)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Lambda {
			s.write_tag(nodes_lambda_expr)
			s.write_parameters(node.args)
			// Write body expression
			s.write_expression(node.body)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		NamedExpr {
			s.write_tag(nodes_named_expr)
			s.write_expression(node.target)
			s.write_expression(node.value)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Compare {
			s.write_tag(nodes_compare_expr)
			s.write_expression(node.left)
			s.write_tag(list_gen)
			s.write_int_bare(node.ops.len)
			for op in node.ops {
				idx := cmp_ops.index(op.value)
				s.write_int(if idx >= 0 { idx } else { 0 })
			}
			s.write_tag(list_gen)
			s.write_int_bare(node.comparators.len)
			for comp in node.comparators {
				s.write_expression(comp)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		YieldFrom {
			s.write_tag(nodes_yield_from_expr)
			s.write_expression(node.value)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Await {
			s.write_tag(nodes_await_expr)
			s.write_expression(node.value)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Starred {
			s.write_tag(nodes_starred_expr)
			s.write_expression(node.value)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		Slice {
			s.write_tag(nodes_slice_expr)
			if lower := node.lower {
				s.write_tag(literal_true)
				s.write_expression(lower)
			} else {
				s.write_tag(literal_false)
			}
			if upper := node.upper {
				s.write_tag(literal_true)
				s.write_expression(upper)
			} else {
				s.write_tag(literal_false)
			}
			if step := node.step {
				s.write_tag(literal_true)
				s.write_expression(step)
			} else {
				s.write_tag(literal_false)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		NoneExpr {
			s.write_tag(nodes_none_expr)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		JoinedStr {
			s.write_tag(nodes_joined_str)
			s.write_tag(list_gen)
			s.write_int_bare(node.values.len)
			for val in node.values {
				s.write_expression(val)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		FormattedValue {
			s.write_tag(nodes_formatted_value)
			s.write_expression(node.value)
			s.write_int(node.conversion)
			if spec := node.format_spec {
				s.write_tag(literal_true)
				s.write_expression(spec)
			} else {
				s.write_tag(literal_false)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		ListComp {
			s.write_tag(nodes_list_comprehension)
			s.write_expression(node.elt)
			s.write_tag(list_gen)
			s.write_int_bare(node.generators.len)
			for gen in node.generators {
				s.write_comprehension(gen)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		DictComp {
			s.write_tag(nodes_dict_comprehension)
			s.write_expression(node.key)
			s.write_expression(node.value)
			s.write_tag(list_gen)
			s.write_int_bare(node.generators.len)
			for gen in node.generators {
				s.write_comprehension(gen)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		SetComp {
			s.write_tag(nodes_set_comprehension)
			s.write_expression(node.elt)
			s.write_tag(list_gen)
			s.write_int_bare(node.generators.len)
			for gen in node.generators {
				s.write_comprehension(gen)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		GeneratorExp {
			s.write_tag(nodes_generator_expr)
			s.write_expression(node.elt)
			s.write_tag(list_gen)
			s.write_int_bare(node.generators.len)
			for gen in node.generators {
				s.write_comprehension(gen)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		else {
			// Placeholder for unhandled expression types
		}
	}
}

pub fn (mut s Serializer) write_type(node Expression) {
	if node is BinaryOp {
		if node.op.value == '|' {
			s.write_tag(types_union_type)
			s.write_tag(list_gen)
			s.write_int_bare(2)
			s.write_type(node.left)
			s.write_type(node.right)
			s.write_loc(node.token)
			s.write_tag(end_tag)
			return
		}
	}
	if node is Name {
		if node.id == 'Any' {
			s.write_tag(types_any_type)
			s.write_loc(node.token)
			s.write_tag(end_tag)
			return
		} else if node.id == 'None' {
			s.write_tag(types_none_type)
			s.write_loc(node.token)
			s.write_tag(end_tag)
			return
		}
		// Unbound type
		s.write_tag(types_unbound_type)
		s.write_str(node.id)
		s.write_tag(list_gen)
		s.write_int_bare(0) // no args
		s.write_tag(literal_false) // not experimental
		s.write_tag(end_tag)
		return
	}
	// Fallback to unbound with str representation
	s.write_tag(types_unbound_type)
	s.write_str(node.str())
	s.write_tag(list_gen)
	s.write_int_bare(0)
	s.write_tag(literal_false)
	s.write_tag(end_tag)
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

pub fn (mut s Serializer) write_pattern(node Pattern) {
	match node {
		MatchValue {
			s.write_tag(nodes_value_pattern)
			s.write_expression(node.value)
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		MatchSingleton {
			s.write_tag(nodes_singleton_pattern)
			if node.value.value == 'True' {
				s.write_tag(literal_true)
			} else if node.value.value == 'False' {
				s.write_tag(literal_false)
			} else {
				s.write_tag(literal_none)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		MatchSequence {
			s.write_tag(nodes_sequence_pattern)
			s.write_tag(list_gen)
			s.write_int_bare(node.patterns.len)
			for p in node.patterns {
				s.write_pattern(p)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		MatchMapping {
			s.write_tag(nodes_mapping_pattern)
			s.write_tag(list_gen)
			s.write_int_bare(node.keys.len)
			for i in 0 .. node.keys.len {
				s.write_expression(node.keys[i])
				s.write_pattern(node.patterns[i])
			}
			if rest := node.rest {
				s.write_tag(literal_true)
				s.write_str(rest)
			} else {
				s.write_tag(literal_false)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		MatchClass {
			s.write_tag(nodes_class_pattern)
			s.write_expression(node.cls)
			s.write_tag(list_gen)
			s.write_int_bare(node.patterns.len)
			for p in node.patterns {
				s.write_pattern(p)
			}
			s.write_tag(list_str)
			s.write_int_bare(node.kwd_attrs.len)
			for attr in node.kwd_attrs {
				s.write_str_bare(attr)
			}
			s.write_tag(list_gen)
			s.write_int_bare(node.kwd_patterns.len)
			for p in node.kwd_patterns {
				s.write_pattern(p)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		MatchStar {
			s.write_tag(nodes_star_pattern)
			if name := node.name {
				s.write_tag(literal_true)
				s.write_str(name)
			} else {
				s.write_tag(literal_false)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		MatchAs {
			s.write_tag(nodes_as_pattern)
			if p := node.pattern {
				s.write_tag(literal_true)
				s.write_pattern(p)
			} else {
				s.write_tag(literal_false)
			}
			if name := node.name {
				s.write_tag(literal_true)
				s.write_str(name)
			} else {
				s.write_tag(literal_false)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		MatchOr {
			s.write_tag(nodes_or_pattern)
			s.write_tag(list_gen)
			s.write_int_bare(node.patterns.len)
			for p in node.patterns {
				s.write_pattern(p)
			}
			s.write_loc(node.token)
			s.write_tag(end_tag)
		}
		else {
			// Unknown pattern
		}
	}
}

// ---------------------------------------------------------------------------
// Low-level helpers
// ---------------------------------------------------------------------------

pub fn (mut s Serializer) write_tag(tag u8) {
	s.buf << tag
}

pub fn (mut s Serializer) write_int_bare(v int) {
	mut val := u32(v)
	for {
		mut b := u8(val & 0x7f)
		val >>= 7
		if val != 0 {
			b |= 0x80
			s.buf << b
		} else {
			s.buf << b
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

pub fn (mut s Serializer) write_optional_str(v ?string) {
	if value := v {
		s.write_str(value)
	} else {
		s.write_tag(literal_none)
	}
}

pub fn (mut s Serializer) write_float_bare(v f64) {
	bits := math.f64_bits(v)
	for i in 0 .. 8 {
		s.buf << u8((bits >> (i * 8)) & u64(0xff))
	}
}

pub fn (mut s Serializer) write_loc(t Token) {
	s.write_tag(location)
	s.write_int_bare(t.line)
	s.write_int_bare(t.column)
	s.write_int_bare(t.line) // end_line placeholder
	s.write_int_bare(t.column + t.value.len) // end_column placeholder
}

pub fn (mut s Serializer) write_type_params(params []TypeParam) {
	s.write_tag(list_gen)
	s.write_int_bare(params.len)
	for p in params {
		s.write_type_param(p)
	}
}

pub fn (mut s Serializer) write_type_param(node TypeParam) {
	s.write_tag(nodes_type_param)
	s.write_str(node.name)
	s.write_int_bare(int(node.kind))
	if bound := node.bound {
		s.write_tag(literal_true)
		s.write_type(bound)
	} else {
		s.write_tag(literal_false)
	}
	if def := node.default_ {
		s.write_tag(literal_true)
		s.write_type(def)
	} else {
		s.write_tag(literal_false)
	}
	s.write_loc(node.token)
	s.write_tag(end_tag)
}

fn (s &Serializer) collect_parameters(args Arguments) []SerializedParameter {
	mut result := []SerializedParameter{}
	for arg in args.posonlyargs {
		result << SerializedParameter{
			param:    arg
			kind:     s.positional_arg_kind(arg)
			pos_only: true
		}
	}
	for arg in args.args {
		result << SerializedParameter{
			param:    arg
			kind:     s.positional_arg_kind(arg)
			pos_only: false
		}
	}
	if vararg := args.vararg {
		result << SerializedParameter{
			param:    vararg
			kind:     arg_kind_star
			pos_only: false
		}
	}
	for arg in args.kwonlyargs {
		result << SerializedParameter{
			param:    arg
			kind:     if arg.default_ != none { arg_kind_named_opt } else { arg_kind_named }
			pos_only: false
		}
	}
	if kwarg := args.kwarg {
		result << SerializedParameter{
			param:    kwarg
			kind:     arg_kind_star2
			pos_only: false
		}
	}
	return result
}

fn (s &Serializer) positional_arg_kind(arg Parameter) int {
	return if arg.default_ != none { arg_kind_opt } else { arg_kind_pos }
}

fn (mut s Serializer) write_parameters(args Arguments) {
	params := s.collect_parameters(args)
	s.write_tag(list_gen)
	s.write_int_bare(params.len)
	for entry in params {
		s.write_str(entry.param.arg)
		s.write_int(entry.kind)
		if ann := entry.param.annotation {
			s.write_tag(literal_true)
			s.write_type(ann)
		} else {
			s.write_tag(literal_false)
		}
		if def := entry.param.default_ {
			s.write_tag(literal_true)
			s.write_expression(def)
		} else {
			s.write_tag(literal_false)
		}
		s.write_tag(if entry.pos_only { literal_true } else { literal_false })
		s.write_loc(entry.param.token)
	}
}

fn (s &Serializer) collect_call_args(node Call) []SerializedCallArg {
	mut result := []SerializedCallArg{}
	for arg in node.args {
		if arg is Starred {
			result << SerializedCallArg{
				expr: arg
				kind: arg_kind_star
				name: none
			}
		} else {
			result << SerializedCallArg{
				expr: arg
				kind: arg_kind_pos
				name: none
			}
		}
	}
	for kw in node.keywords {
		result << SerializedCallArg{
			expr: kw.value
			kind: if kw.arg == '' { arg_kind_star2 } else { arg_kind_named }
			name: if kw.arg == '' { none } else { kw.arg }
		}
	}
	return result
}
