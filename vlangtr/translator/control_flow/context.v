module control_flow

import ast

fn (mut m ControlFlowModule) is_nullcontext_call(node ast.Expression) bool {
	if node is ast.Call {
		if node.func is ast.Name {
			if node.func.id in ['nullcontext', 'suppress', 'closing'] {
				return true
			}
			if node.func.id in m.env.state.imported_symbols {
				full := m.env.state.imported_symbols[node.func.id]
				return full in ['contextlib.nullcontext', 'contextlib.suppress', 'contextlib.closing']
			}
		} else if node.func is ast.Attribute {
			if node.func.value is ast.Name {
				module_name := m.env.state.imported_modules[node.func.value.id] or { node.func.value.id }
				return module_name == 'contextlib'
					&& node.func.attr in ['nullcontext', 'suppress', 'closing']
			}
		}
	}
	return false
}

fn (mut m ControlFlowModule) visit_with_item(item ast.WithItem) {
	context_expr := m.visit_expr(item.context_expr)
	mut is_nullcontext := false
	mut is_suppress := false
	mut is_legacy_mgr := false

	if item.context_expr is ast.Call {
		call := item.context_expr
		if call.func is ast.Name {
			if call.func.id == 'nullcontext' {
				is_nullcontext = true
			}
			if call.func.id == 'suppress' {
				is_suppress = true
			}
			if call.func.id in ['closing', 'open'] {
				is_legacy_mgr = true
			}
			if call.func.id in m.env.state.imported_symbols {
				full_name := m.env.state.imported_symbols[call.func.id]
				if full_name == 'contextlib.nullcontext' {
					is_nullcontext = true
				}
				if full_name == 'contextlib.suppress' {
					is_suppress = true
				}
				if full_name == 'contextlib.closing' {
					is_legacy_mgr = true
				}
			}
		} else if call.func is ast.Attribute {
			if call.func.value is ast.Name {
				module_name := m.env.state.imported_modules[call.func.value.id] or { call.func.value.id }
				if module_name == 'contextlib' {
					if call.func.attr == 'nullcontext' {
						is_nullcontext = true
					}
					if call.func.attr == 'suppress' {
						is_suppress = true
					}
					if call.func.attr == 'closing' {
						is_legacy_mgr = true
					}
				}
			}
		}
	}

	if is_suppress {
		m.emit(context_expr)
		return
	}

	if is_nullcontext {
		if opt := item.optional_vars {
			var_name := m.visit_expr(opt)
			m.emit('${var_name} := ${context_expr}')
		} else {
			m.emit('_ = ${context_expr}')
		}
		return
	}

	if is_legacy_mgr {
		if opt := item.optional_vars {
			var_name := m.visit_expr(opt)
			m.emit('${var_name} := ${context_expr}')
			m.emit('defer { ${var_name}.close() }')
		} else {
			m.env.state.zip_counter++
			tmp_var := 'ctx_mgr_${m.env.state.zip_counter}'
			m.emit('${tmp_var} := ${context_expr}')
			m.emit('defer { ${tmp_var}.close() }')
		}
		return
	}

	m.env.state.zip_counter++
	tmp_var := 'ctx_mgr_${m.env.state.zip_counter}'
	m.emit('${tmp_var} := ${context_expr}')
	m.emit('defer { ${tmp_var}.exit(none, none, none) }')
	if opt := item.optional_vars {
		var_name := m.visit_expr(opt)
		m.emit('${var_name} := ${tmp_var}.enter()')
	} else {
		m.emit('${tmp_var}.enter()')
	}
}

pub fn (mut m ControlFlowModule) visit_with(node ast.With) {
	for item in node.items {
		m.visit_with_item(item)
	}
	for stmt in node.body {
		m.visit_stmt(stmt)
	}
}
