module expressions

import ast

pub fn (eg &ExprGen) get_negative_const(node ast.Expression) ?int {
	if node is ast.UnaryOp && node.op.value == '-' {
		if node.operand is ast.Constant {
			return node.operand.value.int()
		}
	}
	if node is ast.Constant {
		if node.value.starts_with('-') {
			return node.value[1..].int()
		}
	}
	return none
}

pub fn (mut eg ExprGen) visit_subscript(node ast.Subscript) string {
	value := eg.visit(node.value)
	val_type := eg.guess_type(node.value)

	if val_type in eg.state.dataclasses && node.slice is ast.Constant
		&& (node.slice.token.typ == .string_tok || node.slice.token.typ == .fstring_tok) {
		return '${value}.${node.slice.value.trim('\'"')}'
	}

	if val_type.starts_with('TupleStruct_') && node.slice is ast.Constant {
		return '${value}.it_${node.slice.value}'
	}

	if node.slice is ast.Slice {
		lower := if lower_expr := node.slice.lower { eg.visit(lower_expr) } else { 'none' }
		upper := if upper_expr := node.slice.upper { eg.visit(upper_expr) } else { 'none' }
		step := if step_expr := node.slice.step { eg.visit(step_expr) } else { 'none' }

		if step == '-1' && lower == 'none' && upper == 'none' {
			if val_type == 'string' {
				eg.state.used_builtins['py_str_reverse'] = true
				return 'py_str_reverse(${value})'
			}
			if val_type.starts_with('[]') {
				eg.state.used_builtins['py_list_reverse'] = true
				return 'py_list_reverse(${value})'
			}
		}

		if val_type == 'Any' || step != 'none' {
			helper := if val_type == 'string' { 'py_str_slice' } else { 'py_list_slice' }
			eg.state.used_builtins[helper] = true
			return '${helper}(${value}, ${lower}, ${upper}, ${step})'
		}

		lo := if lower == 'none' { '' } else { lower }
		hi := if upper == 'none' { '' } else { upper }
		return '${value}[${lo}..${hi}]'
	}

	index := eg.visit(node.slice)
	if neg := eg.get_negative_const(node.slice) {
		return '${value}[${value}.len - ${neg}]'
	}

	if val_type == 'Any' {
		eg.state.used_builtins['py_subscript'] = true
		return 'py_subscript(${value}, ${index})'
	}
	return '${value}[${index}]'
}
