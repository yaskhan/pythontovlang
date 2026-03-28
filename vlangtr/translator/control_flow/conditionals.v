module control_flow

import ast
import translator.base

fn (m &ControlFlowModule) is_name_main(node ast.If) bool {
	if node.test is ast.Compare {
		cmp := node.test
		if cmp.left is ast.Name && cmp.left.id == '__name__' && cmp.comparators.len == 1 {
			if cmp.comparators[0] is ast.Constant && cmp.comparators[0].value == '__main__' {
				return true
			}
		}
	}
	return false
}

fn (m &ControlFlowModule) is_type_checking(node ast.If) bool {
	if node.test is ast.Name {
		return node.test.id == 'TYPE_CHECKING'
	}
	if node.test is ast.Attribute {
		return node.test.attr == 'TYPE_CHECKING'
	}
	return false
}

fn (m &ControlFlowModule) has_walrus_expr(node ast.Expression) bool {
	if node is ast.NamedExpr {
		return true
	}
	if node is ast.BinaryOp {
		return m.has_walrus_expr(node.left) || m.has_walrus_expr(node.right)
	}
	if node is ast.UnaryOp {
		return m.has_walrus_expr(node.operand)
	}
	if node is ast.Compare {
		if m.has_walrus_expr(node.left) {
			return true
		}
		for comparator in node.comparators {
			if m.has_walrus_expr(comparator) {
				return true
			}
		}
	}
	if node is ast.Call {
		if m.has_walrus_expr(node.func) {
			return true
		}
		for arg in node.args {
			if m.has_walrus_expr(arg) {
				return true
			}
		}
		for kw in node.keywords {
			if m.has_walrus_expr(kw.value) {
				return true
			}
		}
	}
	if node is ast.Attribute {
		return m.has_walrus_expr(node.value)
	}
	if node is ast.Subscript {
		return m.has_walrus_expr(node.value) || m.has_walrus_expr(node.slice)
	}
	if node is ast.IfExp {
		return m.has_walrus_expr(node.test) || m.has_walrus_expr(node.body) || m.has_walrus_expr(node.orelse)
	}
	if node is ast.JoinedStr {
		for value in node.values {
			if m.has_walrus_expr(value) {
				return true
			}
		}
	}
	if node is ast.FormattedValue {
		return m.has_walrus_expr(node.value)
	}
	return false
}

fn (mut m ControlFlowModule) collect_narrowing(node ast.Expression, positive bool) map[string]string {
	mut res := map[string]string{}
	if node is ast.Call {
		func_expr := node.func
		if func_expr is ast.Name {
			name_id := func_expr.id
			if name_id == 'isinstance' && positive && node.args.len == 2 {
				arg0 := node.args[0]
					mut var_name := ''
					if arg0 is ast.Name {
						var_name = arg0.id
					} else if arg0 is ast.Attribute {
						var_name = m.visit_expr(arg0)
					}
					if var_name.len > 0 {
						arg1 := node.args[1]
						mut v_type := if arg1 is ast.Tuple {
							mut parts := []string{}
							for elt in arg1.elements {
								parts << m.visit_expr(elt)
							}
							m.register_sum_type(parts.join(' | '))
							parts.join(' | ')
						} else {
							m.visit_expr(arg1)
						}
						if v_type == 'str' { v_type = 'string' }
						if v_type !in ['Any', 'void', 'unknown'] {
							res[var_name] = v_type
						}
					}
			} else {
				mut guard_found := false
				mut guard_info := base.TypeGuardInfo{}
				if name_id in m.env.state.type_guards {
					guard_info = m.env.state.type_guards[name_id]
					guard_found = true
				} else {
					// Try qualified name suffix match
					for k, v in m.env.state.type_guards {
						if k.ends_with('.' + name_id) {
							guard_info = v
							guard_found = true
							break
						}
					}
				}

				if guard_found && node.args.len > 0 {
					arg0_node := node.args[0]
					if arg0_node is ast.Name {
						id := arg0_node.id
						if positive {
							mut n_type := guard_info.narrowed_type
							if n_type == 'str' { n_type = 'string' }
							res[id] = n_type
						} else if guard_info.is_type_is {
							// For TypeIs, the negative branch is also narrowed.
							if orig_type := m.env.analyzer.get_type(id) {
								if orig_type.contains('|') {
									parts := orig_type.split('|').map(it.trim_space())
									mut others := []string{}
									for p in parts {
										if p != guard_info.narrowed_type {
											others << p
										}
									}
									if others.len > 0 {
										res[id] = others.join(' | ')
									}
								}
							}
						}
					}
				}
			}
		}
	} else if node is ast.Compare && node.comparators.len == 1 {
		op_tok := node.ops[0]
		op := op_tok.value
		left := node.left
		right := node.comparators[0]
		if left is ast.Name {
			var_name := left.id
			is_none := (right is ast.Constant && right.value == 'None') || (right is ast.Name && right.id in ['None', 'none']) || (right is ast.NoneExpr)
			if is_none {
				if (op == 'is not' && positive) || (op == '!=' && positive) || (op == 'is' && !positive) || (op == '==' && !positive) {
					orig_type := m.guess_type(left)
					if orig_type.starts_with('?') {
						res[var_name] = orig_type[1..]
					}
				} else if (op == 'is' && positive) || (op == '==' && positive) || (op == 'is not' && !positive) || (op == '!=' && !positive) {
					res[var_name] = 'none'
				}
			}
		}
	} else if node is ast.UnaryOp && node.op.value == 'not' {
		return m.collect_narrowing(node.operand, !positive)
	} else if node is ast.BinaryOp && node.op.value == 'and' && positive {
		for k, v in m.collect_narrowing(node.left, true) {
			res[k] = v
		}
		for k, v in m.collect_narrowing(node.right, true) {
			res[k] = v
		}
	} else if node is ast.BinaryOp && node.op.value == 'or' && !positive {
		for k, v in m.collect_narrowing(node.left, false) {
			res[k] = v
		}
		for k, v in m.collect_narrowing(node.right, false) {
			res[k] = v
		}
	}
	return res
}

fn (mut m ControlFlowModule) apply_flow_narrowing(body []ast.Statement, test ast.Expression, positive bool, branch_suffix string) map[string]string {
	if body.len == 0 {
		return map[string]string{}
	}
	mut original_remaps := map[string]string{}
	narrowing := m.collect_narrowing(test, positive)

	for var_name, narrowed_type in narrowing {
		if narrowed_type == 'none' {
			continue
		}
		sanitized := m.sanitize_name(var_name, false)
		base_type := m.guess_type(ast.Name{id: var_name})
		
		// V auto-narrowing check
		mut is_auto := false
		if test is ast.Compare {
			if base_type.starts_with('?') && narrowed_type == base_type[1..] {
				is_auto = true
			} else if (base_type.starts_with('SumType_') || base_type.contains('|')) && !narrowed_type.contains('|') {
				is_auto = true
			}
		}

		if is_auto {
			continue
		}
		
		if narrowed_type !in ['Any', 'void', 'none'] {
			// Tests expect hybrid approach:
			// 1. If it's a manual check (node is ast.Compare), use in-place cast.
			// 2. If it's a function call (TypeGuard), use explicit narrowed variable.
			is_call_narrowing := test is ast.Call || (test is ast.UnaryOp && (test as ast.UnaryOp).operand is ast.Call)
			
			if is_call_narrowing && !var_name.contains('.') {
				narrowed_name := 'narrowed${branch_suffix}_${sanitized}'.replace('.', '_').replace('__', '_')
				m.emit('${narrowed_name} := (${sanitized} as ${narrowed_type})')
				if var_name in m.env.state.name_remap {
					original_remaps[var_name] = m.env.state.name_remap[var_name]
				} else {
					original_remaps[var_name] = '__NONE__'
				}
				m.env.state.name_remap[var_name] = narrowed_name
			} else {
				// Use in-place cast remapping for others
				narrowed_expr := '(${sanitized} as ${narrowed_type})'
				if var_name in m.env.state.name_remap {
					original_remaps[var_name] = m.env.state.name_remap[var_name]
				} else {
					original_remaps[var_name] = '__NONE__'
				}
				m.env.state.name_remap[var_name] = narrowed_expr
			}
		}
	}
	return original_remaps
}

pub fn (mut m ControlFlowModule) visit_if(node ast.If) {
	m.visit_if_inner(node, false)
}

fn (mut m ControlFlowModule) visit_if_inner(node ast.If, is_elif bool) {
	if !is_elif {
		if m.is_name_main(node) {
			m.emit("// if __name__ == '__main__':")
			for stmt in node.body {
				m.visit_stmt(stmt)
			}
			return
		}
		if m.is_type_checking(node) {
			return
		}

		// Pre-declare conditionally initialized variables
		if_vars := m.collect_assigned_vars(node.body)
		else_vars := if node.orelse.len > 0 { m.collect_assigned_vars(node.orelse) } else { map[string]bool{} }
		for var, _ in if_vars {
			if !m.is_declared_local(var) {
				mut v_type := m.guess_type(ast.Name{id: var})
				if v_type == 'unknown' { v_type = 'Any' }
				if !v_type.starts_with('?') { v_type = '?${v_type}' }
				m.emit('mut ${var} := ${v_type}(none)')
				m.declare_local(var)
			}
		}
		for var, _ in else_vars {
			if !m.is_declared_local(var) {
				mut v_type := m.guess_type(ast.Name{id: var})
				if v_type == 'unknown' { v_type = 'Any' }
				if !v_type.starts_with('?') { v_type = '?${v_type}' }
				m.emit('mut ${var} := ${v_type}(none)')
				m.declare_local(var)
			}
		}
	}

	test_expr := m.wrap_bool(node.test, false)
	if is_elif {
		m.emit('} else if ${test_expr} {')
	} else {
		m.emit('if ${test_expr} {')
	}
	m.env.state.indent_level++
	
	mut remaps := m.apply_flow_narrowing(node.body, node.test, true, '')
	for stmt in node.body {
		m.visit_stmt(stmt)
	}
	for var, orig in remaps {
		if orig == '__NONE__' { m.env.state.name_remap.delete(var) } else { m.env.state.name_remap[var] = orig }
	}
	m.env.state.indent_level--

	if node.orelse.len > 0 {
		if node.orelse.len == 1 && node.orelse[0] is ast.If {
			m.visit_if_inner(node.orelse[0] as ast.If, true)
		} else {
			m.emit('} else {')
			m.env.state.indent_level++
			mut eremaps := m.apply_flow_narrowing(node.orelse, node.test, false, '_else')
			for stmt in node.orelse {
				m.visit_stmt(stmt)
			}
			for var, orig in eremaps {
				if orig == '__NONE__' { m.env.state.name_remap.delete(var) } else { m.env.state.name_remap[var] = orig }
			}
			m.env.state.indent_level--
			m.emit('}')
		}
	} else {
		m.emit('}')
	}
}
