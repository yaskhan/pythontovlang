module expressions

import ast

pub fn (mut eg ExprGen) visit_bin_op(node ast.BinaryOp) string {
	left_type := eg.guess_type(node.left)
	right_type := eg.guess_type(node.right)
	left := eg.visit(node.left)
	right := eg.visit(node.right)
	op := node.op.value

	if op == '*' {
		if left_type == 'string' {
			return '${left}.repeat(${right})'
		}
		if right_type == 'string' {
			return '${right}.repeat(${left})'
		}
		if node.left is ast.List && node.left.elements.len == 1 {
			init_val := eg.visit(node.left.elements[0])
			elem_type := eg.guess_type(node.left.elements[0])
			return '[]${elem_type}{len: ${right}, init: ${init_val}}'
		}
		if node.right is ast.List && node.right.elements.len == 1 {
			init_val := eg.visit(node.right.elements[0])
			elem_type := eg.guess_type(node.right.elements[0])
			return '[]${elem_type}{len: ${left}, init: ${init_val}}'
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
	if op == '%' && (left_type == 'string' || left_type == 'LiteralString') {
		eg.state.used_string_format = true
		if node.right is ast.Tuple {
			mut args := []string{}
			for elt in node.right.elements {
				args << eg.visit(elt)
			}
			return 'py_string_format(${left}, ${args.join(', ')})'
		}
		return 'py_string_format(${left}, ${right})'
	}

	if left_type == 'PyComplex' && right_type != 'PyComplex' {
		return '${left} ${op} py_complex(f64(${right}), 0.0)'
	}
	if right_type == 'PyComplex' && left_type != 'PyComplex' {
		return 'py_complex(f64(${left}), 0.0) ${op} ${right}'
	}

	return '${left} ${op} ${right}'
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

fn is_none_expr(node ast.Expression) bool {
	return (node is ast.Constant && node.value == 'None')
		|| (node is ast.Name && node.id in ['None', 'none']) || node is ast.NoneExpr
}

pub fn (mut eg ExprGen) visit_compare(node ast.Compare) string {
	mut comparators := []string{cap: node.comparators.len + 1}
	comparators << eg.visit(node.left)
	for comp in node.comparators {
		comparators << eg.visit(comp)
	}

	if node.ops.len == 1 && comparators.len == 2 {
		left := comparators[0]
		right := comparators[1]
		op := node.ops[0].value
		if op in ['is', '=='] && is_none_expr(node.comparators[0]) {
			return '${left} == none'
		}
		if op in ['is not', '!='] && is_none_expr(node.comparators[0]) {
			return '${left} != none'
		}
		if op == 'is' {
			eg.state.used_builtins['py_is_identical'] = true
			return 'py_is_identical(${left}, ${right})'
		}
		if op == 'is not' {
			eg.state.used_builtins['py_is_identical'] = true
			return '!py_is_identical(${left}, ${right})'
		}
		if op == 'in' {
			if is_none_expr(node.left) {
				return '${right}.any(it == none)'
			}
			return '${left} in ${right}'
		}
		if op == 'not in' {
			if is_none_expr(node.left) {
				return '!${right}.any(it == none)'
			}
			return '${left} !in ${right}'
		}
		return '${left} ${op} ${right}'
	}

	mut parts := []string{}
	for i, op in node.ops {
		if i + 1 >= comparators.len {
			break
		}
		parts << '(${comparators[i]} ${op.value} ${comparators[i + 1]})'
	}
	return parts.join(' && ')
}
