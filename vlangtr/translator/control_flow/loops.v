module control_flow

import ast

fn (m &ControlFlowModule) has_break(nodes []ast.Statement) bool {
	for node in nodes {
		if node is ast.Break {
			return true
		}
		if node is ast.If {
			if m.has_break(node.body) || m.has_break(node.orelse) {
				return true
			}
		}
		if node is ast.With {
			if m.has_break(node.body) {
				return true
			}
		}
		if node is ast.Try {
			if m.has_break(node.body) || m.has_break(node.orelse) || m.has_break(node.finalbody) {
				return true
			}
			for handler in node.handlers {
				if m.has_break(handler.body) {
					return true
				}
			}
		}
		if node is ast.TryStar {
			if m.has_break(node.body) || m.has_break(node.orelse) || m.has_break(node.finalbody) {
				return true
			}
			for handler in node.handlers {
				if m.has_break(handler.body) {
					return true
				}
			}
		}
		if node is ast.Match {
			for case in node.cases {
				if m.has_break(case.body) {
					return true
				}
			}
		}
	}
	return false
}

fn (mut m ControlFlowModule) push_loop_ctx(flag_name string) {
	m.loop_flag_stack << flag_name
	m.loop_depth_stack << m.env.state.vexc_depth
}

fn (mut m ControlFlowModule) pop_loop_ctx() {
	if m.loop_flag_stack.len > 0 {
		m.loop_flag_stack = m.loop_flag_stack[..m.loop_flag_stack.len - 1]
	}
	if m.loop_depth_stack.len > 0 {
		m.loop_depth_stack = m.loop_depth_stack[..m.loop_depth_stack.len - 1]
	}
}

pub fn (mut m ControlFlowModule) visit_while(node ast.While) {
	mut flag_name := ''
	if node.orelse.len > 0 && m.has_break(node.body) {
		m.env.state.unique_id_counter++
		flag_name = 'py_loop_completed_${m.env.state.unique_id_counter}'
		m.emit('mut ${flag_name} := true')
	}
	m.push_loop_ctx(flag_name)

	test_expr := m.wrap_bool(node.test, false)
	m.emit('for ${test_expr} {')
	m.env.state.indent_level++
	for stmt in node.body {
		m.visit_stmt(stmt)
	}
	m.env.state.indent_level--
	m.emit('}')
	m.pop_loop_ctx()

	if node.orelse.len > 0 {
		if flag_name.len > 0 {
			m.emit('if ${flag_name} {')
			m.env.state.indent_level++
			for stmt in node.orelse {
				m.visit_stmt(stmt)
			}
			m.env.state.indent_level--
			m.emit('}')
		} else {
			for stmt in node.orelse {
				m.visit_stmt(stmt)
			}
		}
	}
}

pub fn (mut m ControlFlowModule) visit_async_for(node ast.For) {
	m.emit('//##LLM@@ async for lowered as standard for loop.')
	m.visit_for(node)
}

pub fn (mut m ControlFlowModule) visit_for(node ast.For) {
	mut flag_name := ''
	if node.orelse.len > 0 && m.has_break(node.body) {
		m.env.state.unique_id_counter++
		flag_name = 'py_loop_completed_${m.env.state.unique_id_counter}'
		m.emit('mut ${flag_name} := true')
	}
	m.push_loop_ctx(flag_name)

	mut target := m.visit_expr(node.target)
	mut iter_expr := m.visit_expr(node.iter)

	mut is_zip := false
	mut is_range := false
	mut is_enumerate := false
	mut is_dict_items := false
	if node.iter is ast.Call {
		call := node.iter
		if call.func is ast.Name {
			if call.func.id == 'zip' || call.func.id == 'izip' {
				is_zip = true
			}
			if call.func.id == 'range' || call.func.id == 'xrange' {
				is_range = true
			}
			if call.func.id == 'enumerate' {
				is_enumerate = true
			}
		} else if call.func is ast.Attribute {
			if call.func.attr == 'izip' {
				is_zip = true
			}
			if call.func.attr == 'xrange' {
				is_range = true
			}
			if call.func.attr == 'items' {
				is_dict_items = true
			}
		}
	}

	if is_zip && node.iter is ast.Call {
		call := node.iter
		if call.args.len == 2 {
			m.env.state.zip_counter++
			zip_id := m.env.state.zip_counter
			it1 := m.visit_expr(call.args[0])
			it2 := m.visit_expr(call.args[1])
			var_it1 := 'py_zip_it1_${zip_id}'
			var_it2 := 'py_zip_it2_${zip_id}'
			var_i := 'py_i_${zip_id}'
			var_v1 := 'py_v1_${zip_id}'
			var_v2 := 'py_v2_${zip_id}'
			m.emit('${var_it1} := ${it1}')
			m.emit('${var_it2} := ${it2}')
			m.emit('for ${var_i}, ${var_v1} in ${var_it1} {')
			m.env.state.indent_level++
			m.emit('if ${var_i} >= ${var_it2}.len { break }')
			m.emit('${var_v2} := ${var_it2}[${var_i}]')
			if node.target is ast.Tuple && node.target.elements.len == 2 {
				left := m.visit_expr(node.target.elements[0])
				right := m.visit_expr(node.target.elements[1])
				m.emit('${left} := ${var_v1}')
				m.emit('${right} := ${var_v2}')
			} else {
				if target.starts_with('[') && target.ends_with(']') {
					target = target[1..target.len - 1]
				}
				m.emit('${target} := [${var_v1}, ${var_v2}]')
			}
			for stmt in node.body {
				m.visit_stmt(stmt)
			}
			m.env.state.indent_level--
			m.emit('}')
			m.pop_loop_ctx()
			return
		}
	}

	if is_range && node.iter is ast.Call {
		call := node.iter
		range_args := call.args
		if range_args.len == 3 {
			start := m.visit_expr(range_args[0])
			stop := m.visit_expr(range_args[1])
			step := m.visit_expr(range_args[2])
			m.emit('for ${target} := ${start}; ${target} < ${stop}; ${target} += ${step} {')
			m.env.state.indent_level++
			for stmt in node.body {
				m.visit_stmt(stmt)
			}
			m.env.state.indent_level--
			m.emit('}')
			m.pop_loop_ctx()
			return
		}
		start := if range_args.len == 2 { m.visit_expr(range_args[0]) } else { '0' }
		stop := if range_args.len >= 2 { m.visit_expr(range_args[range_args.len - 1]) } else { m.visit_expr(range_args[0]) }
		iter_expr = '${start}..${stop}'
	}

	if is_enumerate && node.iter is ast.Call && node.iter.args.len > 0 {
		iter_expr = m.visit_expr(node.iter.args[0])
	}

	if node.target is ast.Tuple {
		if target.starts_with('[') && target.ends_with(']') && !is_enumerate && !is_dict_items {
			val_name := 'py_val_${m.env.state.unique_id_counter}'
			m.env.state.unique_id_counter++
			m.emit('for ${val_name} in ${iter_expr} {')
			m.env.state.indent_level++
			for i, elt in node.target.elements {
				elt_name := m.visit_expr(elt)
				m.emit('${elt_name} := ${val_name}[${i}]')
			}
			for stmt in node.body {
				m.visit_stmt(stmt)
			}
			m.env.state.indent_level--
			m.emit('}')
			m.pop_loop_ctx()
			return
		}
	}

	if target.starts_with('[') && target.ends_with(']') {
		target = target[1..target.len - 1]
	}

	mut iter_to_check := node.iter
	if is_enumerate {
		if node.iter is ast.Call {
			if node.iter.args.len > 0 {
				iter_to_check = node.iter.args[0]
			}
		}
	}
	mut is_string_iter := false
	if m.guess_type(iter_to_check) == 'string' {
		is_string_iter = true
	}

	if is_string_iter {
		if is_enumerate && target.contains(',') {
			parts := target.split(',').map(it.trim_space())
			if parts.len >= 2 {
				idx_var := parts[0]
				val_var := parts[1]
				m.emit('for ${idx_var}, ${val_var}_u8 in ${iter_expr} {')
				m.env.state.indent_level++
				m.emit('${val_var} := ${val_var}_u8.ascii_str()')
			}
		} else {
			m.emit('for ${target}_u8 in ${iter_expr} {')
			m.env.state.indent_level++
			m.emit('${target} := ${target}_u8.ascii_str()')
		}
	} else {
		m.emit('for ${target} in ${iter_expr} {')
		m.env.state.indent_level++
	}

	for stmt in node.body {
		m.visit_stmt(stmt)
	}
	m.env.state.indent_level--
	m.emit('}')
	m.pop_loop_ctx()

	if node.orelse.len > 0 {
		if flag_name.len > 0 {
			m.emit('if ${flag_name} {')
			m.env.state.indent_level++
			for stmt in node.orelse {
				m.visit_stmt(stmt)
			}
			m.env.state.indent_level--
			m.emit('}')
		} else {
			for stmt in node.orelse {
				m.visit_stmt(stmt)
			}
		}
	}
}
