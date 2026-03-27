module expressions

import ast

fn is_none_expr(node ast.Expression) bool {
	return (node is ast.Constant && node.value == 'None')
		|| (node is ast.Name && node.id in ['None', 'none'])
		|| node is ast.NoneExpr
}

fn (eg &ExprGen) is_explicit_any(node ast.Expression, typ string) bool {
	if typ != 'Any' {
		return false
	}
	token := node.get_token()
	loc_key := '${token.line}:${token.column}'
	if loc_key in eg.analyzer.explicit_any_types {
		return true
	}
	if node is ast.Name {
		if node.id in eg.analyzer.explicit_any_types {
			return true
		}
		name_loc_key := '${node.id}@${token.line}:${token.column}'
		if name_loc_key in eg.analyzer.explicit_any_types {
			return true
		}
	}
	return false
}

fn (eg &ExprGen) should_use_is_none_type(node ast.Expression, typ string) bool {
	if typ.starts_with('?') {
		return false
	}
	if typ.starts_with('SumType_') {
		return true
	}
	if typ.starts_with('map[') && typ.ends_with(']Any') {
		return true
	}
	return eg.is_explicit_any(node, typ)
}

fn (mut eg ExprGen) format_percent_call(left string, right ast.Expression) string {
	if right is ast.Tuple {
		mut args := []string{}
		for elt in right.elements {
			args << eg.visit(elt)
		}
		return 'py_string_format(${left}, ${args.join(', ')})'
	}
	return 'py_string_format(${left}, ${eg.visit(right)})'
}

fn (mut eg ExprGen) format_percent_bytes(left string, right ast.Expression) string {
	if right is ast.Tuple {
		mut args := []string{}
		for elt in right.elements {
			args << eg.visit(elt)
		}
		return 'py_bytes_format(${left}, ${args.join(', ')})'
	}
	return 'py_bytes_format(${left}, ${eg.visit(right)})'
}

fn (eg &ExprGen) is_set_type(v_type string) bool {
	return (v_type.starts_with('map[') && v_type.ends_with(']bool'))
		|| v_type.starts_with('datatypes.Set[')
}

pub fn (mut eg ExprGen) visit_bin_op(node ast.BinaryOp) string {
	left_type := eg.guess_type(node.left)
	right_type := eg.guess_type(node.right)
	left := eg.visit(node.left)
	right := eg.visit(node.right)
	op := node.op.value

	if op in ['and', 'or'] {
		lhs := eg.wrap_bool(node.left, false)
		rhs := eg.wrap_bool(node.right, false)
		v_op := if op == 'and' { '&&' } else { '||' }
		return '${lhs} ${v_op} ${rhs}'
	}

	if op == '*' {
		if left_type == 'string' || left_type == 'LiteralString' {
			return '${left}.repeat(${right})'
		}
		if right_type == 'string' || right_type == 'LiteralString' {
			return '${right}.repeat(${left})'
		}
		if node.left is ast.List && node.left.elements.len == 1 {
			return eg.format_repeated_list_literal(node.left, right)
		}
		if node.right is ast.List && node.right.elements.len == 1 {
			return eg.format_repeated_list_literal(node.right, left)
		}
		if left_type.starts_with('[]') || right_type.starts_with('[]') {
			eg.state.used_builtins['py_repeat_list'] = true
			return if left_type.starts_with('[]') {
				'py_repeat_list(${left}, ${right})'
			} else {
				'py_repeat_list(${right}, ${left})'
			}
		}
	}

	if op == '@' {
		return '${left}.matmul(${right})'
	}

	if op == '**' {
		eg.state.used_builtins['math.pow'] = true
		if left_type == 'int' && right_type == 'int' {
			return 'int(math.powi(f64(${left}), ${right}))'
		}
		return 'math.pow(f64(${left}), f64(${right}))'
	}

	if op == '//' {
		eg.state.used_builtins['math.floor'] = true
		if left_type == 'int' && right_type == 'int' {
			return 'int(math.floor(f64(${left}) / f64(${right})))'
		}
		return 'math.floor(${left} / ${right})'
	}

	if op == '%' {
		if left_type == '[]u8' || (left.starts_with('[') && left.contains('u8(')) {
			eg.state.used_builtins['py_bytes_format'] = true
			return eg.format_percent_bytes(left, node.right)
		}
		if left_type == 'string' || left_type == 'LiteralString' {
			eg.state.used_string_format = true
			return eg.format_percent_call(left, node.right)
		}
	}

	if left_type == 'PyComplex' && right_type != 'PyComplex' {
		return '${left} ${op} py_complex(f64(${right}), 0.0)'
	}
	if right_type == 'PyComplex' && left_type != 'PyComplex' {
		return 'py_complex(f64(${left}), 0.0) ${op} ${right}'
	}

	if eg.is_set_type(left_type) && eg.is_set_type(right_type) {
		match op {
			'|' {
				eg.state.used_builtins['py_set_union'] = true
				return 'py_set_union(${left}, ${right})'
			}
			'&' {
				eg.state.used_builtins['py_set_intersection'] = true
				return 'py_set_intersection(${left}, ${right})'
			}
			'-' {
				eg.state.used_builtins['py_set_difference'] = true
				return 'py_set_difference(${left}, ${right})'
			}
			'^' {
				eg.state.used_builtins['py_set_xor'] = true
				return 'py_set_xor(${left}, ${right})'
			}
			else {}
		}
	}

	return '${left} ${op} ${right}'
}

fn (mut eg ExprGen) format_repeated_list_literal(list_node ast.List, len_expr string) string {
	if list_node.elements.len == 0 {
		return '[]Any{len: ${len_expr}, init: none}'
	}
	elt := list_node.elements[0]
	if is_none_expr(elt) {
		elem_type := eg.repeated_list_none_type()
		return '[]${elem_type}{len: ${len_expr}, init: none}'
	}
	init_val := eg.visit(elt)
	elem_type := eg.guess_type(elt)
	return '[]${elem_type}{len: ${len_expr}, init: ${init_val}}'
}

fn (eg &ExprGen) repeated_list_none_type() string {
	if eg.state.current_assignment_type.starts_with('[]?') {
		return eg.state.current_assignment_type[2..]
	}
	if eg.state.current_assignment_type.starts_with('[]') {
		return '?${eg.state.current_assignment_type[2..]}'
	}
	return '?Any'
}

pub fn (mut eg ExprGen) visit_unary_op(node ast.UnaryOp) string {
	if node.op.value == 'not' {
		return eg.wrap_bool(node.operand, true)
	}
	operand := eg.visit(node.operand)
	return '${node.op.value}${operand}'
}

pub fn (mut eg ExprGen) visit_bool_op(node ast.Expression) string {
	if node is ast.BinaryOp && node.op.value in ['and', 'or'] {
		left := eg.wrap_bool(node.left, false)
		right := eg.wrap_bool(node.right, false)
		op := if node.op.value == 'and' { '&&' } else { '||' }
		return '${left} ${op} ${right}'
	}
	return eg.visit(node)
}

pub fn (mut eg ExprGen) visit_compare(node ast.Compare) string {
	mut comparators := []string{cap: node.comparators.len + 1}
	comparators << eg.visit(node.left)
	for comp in node.comparators {
		comparators << eg.visit(comp)
	}

	if node.ops.len == 1 && comparators.len == 2 {
		return eg.translate_single_comparison(comparators[0], node.ops[0].value, comparators[1], node.left, node.comparators[0])
	}

	mut parts := []string{}
	for i, op in node.ops {
		if i + 1 >= comparators.len {
			break
		}
		left_node := if i == 0 { node.left } else { node.comparators[i-1] }
		right_node := node.comparators[i]
		res := eg.translate_single_comparison(comparators[i], op.value, comparators[i + 1], left_node, right_node)
		parts << '(${res})'
	}
	return parts.join(' && ')
}

fn (mut eg ExprGen) translate_single_comparison(left string, op string, right string, left_expr ast.Expression, right_expr ast.Expression) string {
	left_type := eg.guess_type(left_expr)
	if op in ['is', '=='] && is_none_expr(right_expr) {
		if eg.should_use_is_none_type(left_expr, left_type) {
			return '${left} is NoneType'
		}
		return '${left} == none'
	}
	if op in ['is not', '!='] && is_none_expr(right_expr) {
		if eg.should_use_is_none_type(left_expr, left_type) {
			return '${left} !is NoneType'
		}
		return '${left} != none'
	}
	if op == 'is' {
		if is_none_expr(left_expr) {
			return '${left} == ${right}'
		}
		eg.state.used_builtins['py_is_identical'] = true
		return 'py_is_identical(${left}, ${right})'
	}
	if op == 'is not' {
		if is_none_expr(left_expr) {
			return '${left} != ${right}'
		}
		eg.state.used_builtins['py_is_identical'] = true
		return '!py_is_identical(${left}, ${right})'
	}
	if op == 'in' {
		if is_none_expr(left_expr) {
			return '${right}.any(it == ${left})'
		}
		return '${left} in ${right}'
	}
	if op == 'not in' {
		if is_none_expr(left_expr) {
			return '!${right}.any(it == ${left})'
		}
		return '${left} !in ${right}'
	}
	if eg.is_set_type(left_type) {
		match op {
			'<=' {
				eg.state.used_builtins['py_set_subset'] = true
				return 'py_set_subset(${left}, ${right})'
			}
			'<' {
				eg.state.used_builtins['py_set_strict_subset'] = true
				return 'py_set_strict_subset(${left}, ${right})'
			}
			'>=' {
				eg.state.used_builtins['py_set_superset'] = true
				return 'py_set_superset(${left}, ${right})'
			}
			'>' {
				eg.state.used_builtins['py_set_strict_superset'] = true
				return 'py_set_strict_superset(${left}, ${right})'
			}
			else {}
		}
	}
	v_op := match op {
		'is' { '==' }
		'is not' { '!=' }
		else { op }
	}
	return '${left} ${v_op} ${right}'
}
