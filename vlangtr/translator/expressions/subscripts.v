module expressions

import ast

pub fn (eg &ExprGen) get_negative_const(node ast.Expression) ?int {
	if node is ast.UnaryOp && node.op.value == '-' {
		if node.operand is ast.Constant { return node.operand.value.int() }
	}
	if node is ast.Constant {
		if node.value.starts_with('-') { return node.value[1..].int() }
	}
	return none
}

pub fn (mut eg ExprGen) visit_subscript(node ast.Subscript) string {
	value := eg.visit(node.value)
	val_type := eg.guess_type(node.value)
	pure_val_type := val_type.trim_left('&')

	// TypedDict access d["a"] -> d.a
	if (pure_val_type in eg.state.dataclasses || pure_val_type in eg.state.defined_classes) {
		if node.slice is ast.Constant && (node.slice.token.typ == .string_tok || node.slice.token.typ == .fstring_tok) {
			field := node.slice.value.trim('\'"')
			return '${value}.${field}'
		}

		// Narrowed loop variable: for k in d: d[k] -> match k { "a" { d.a } ... }
		mut idx_type := eg.guess_type(node.slice)
		if idx_type.starts_with('Literal[') {
			literals_str := idx_type[8..idx_type.len - 1]
			parts := literals_str.split(',').map(it.trim(' "\''))
			mut match_branches := []string{}
			idx_str := eg.visit(node.slice)
			for part in parts {
				match_branches << "'${part}' { Any(${value}.${part}) }"
			}
			match_branches << "else { panic('unreachable typeddict access') }"
			return 'match ${idx_str} { ${match_branches.join(' ')} }'
		}
	}

	// TupleStruct indexing
	if val_type.starts_with('TupleStruct_') && node.slice is ast.Constant {
		return '${value}.it_${node.slice.value}'
	}

	// Slicing
	if node.slice is ast.Slice {
		lower_node := node.slice.lower
		upper_node := node.slice.upper
		step_node := node.slice.step
		lower := if ln := lower_node { eg.visit(ln) } else { 'none' }
		upper := if un := upper_node { eg.visit(un) } else { 'none' }
		step := if sn := step_node { eg.visit(sn) } else { 'none' }

		// Simple reverse [::-1]
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

		is_native := eg.is_collection_type(val_type) || val_type != 'Any'
		if is_native {
			// Check if we can use V's native [..]
			mut is_simple := true
			if step != 'none' && step != '1' { is_simple = false }
			if eg.get_negative_const(lower_node or { ast.Expression(ast.NoneExpr{}) }) != none { is_simple = false }
			if eg.get_negative_const(upper_node or { ast.Expression(ast.NoneExpr{}) }) != none { is_simple = false }

			if !is_simple {
				helper := if val_type == 'string' { 'py_str_slice' } else { 'py_list_slice' }
				eg.state.used_builtins[helper] = true
				return '${helper}(${value}, ${lower}, ${upper}, ${step})'
			}

			lo := if lower == 'none' { '' } else { lower }
			up := if upper == 'none' { '' } else { upper }
			return '${value}[${lo}..${up}]'
		} else {
			eg.state.used_builtins['py_slice'] = true
			return 'py_slice(${value}, ${lower}, ${upper}, ${step})'
		}
	}

	// Simple indexing
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

fn (eg &ExprGen) is_collection_type(v_type string) bool {
	return v_type == 'string' || v_type.starts_with('[]') || v_type.starts_with('map[')
}
