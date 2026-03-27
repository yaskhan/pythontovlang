module control_flow

import ast

pub fn (mut m ControlFlowModule) visit_raise(node ast.Raise) {
	if exc := node.exc {
		if exc is ast.Name && exc.id == 'StopIteration' {
			if m.env.state.scope_names.len > 0 {
				last_scope := m.env.state.scope_names[m.env.state.scope_names.len - 1]
				if last_scope == '__next__' || last_scope == 'next' {
					m.emit('return none')
					return
				}
			}
		}
	}

	if m.env.state.in_pydantic_validator {
		if exc := node.exc {
			if exc is ast.Call {
				msg := if exc.args.len > 0 { m.visit_expr(exc.args[0]) } else { "''" }
				m.emit('return error(${msg})')
			} else if exc is ast.Name {
				m.emit("return error('${exc.id}')")
			} else {
				val := m.visit_expr(exc)
				m.emit("return error('${val}')")
			}
		} else {
			m.emit("return error('Validation Error')")
		}
		return
	}

	m.env.state.used_builtins['vexc'] = true
	if exc := node.exc {
		if exc is ast.Call {
			exc_name := m.visit_expr(exc.func)
			if exc.args.len > 0 {
				arg0 := exc.args[0]
				mut msg := m.visit_expr(arg0)
				if arg0 is ast.Constant && (arg0.value.starts_with("'") || arg0.value.starts_with('"') || arg0.value.starts_with('b')) {
					if msg.starts_with("'") && msg.ends_with("'") { msg = msg[1..msg.len - 1] }
					else if msg.starts_with('"') && msg.ends_with('"') { msg = msg[1..msg.len - 1] }
					m.emit("vexc.raise('${exc_name}', '${msg}')")
				} else {
					m.emit("vexc.raise('${exc_name}', ${msg})")
				}
			} else {
				m.emit("vexc.raise('${exc_name}', '')")
			}
		} else if exc is ast.Name {
			m.emit("vexc.raise('${exc.id}', '')")
		} else {
			val := m.visit_expr(exc)
			m.emit("vexc.raise('Exception', '${val}')")
		}
	} else {
		m.emit('if vexc.get_curr_exc().name != "" {')
		m.env.state.indent_level++
		m.emit('vexc.raise(vexc.get_curr_exc().name, vexc.get_curr_exc().msg)')
		m.env.state.indent_level--
		m.emit('} else {')
		m.env.state.indent_level++
		m.emit("//##LLM@@ Bare 'raise' detected outside an active exception block. V cannot re-raise here.")
		m.emit("panic('reraise not supported outside except block')")
		m.env.state.indent_level--
		m.emit('}')
	}
}

pub fn (mut m ControlFlowModule) visit_try(node ast.Try) {
	m.emit('//##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling.')
	m.env.state.used_builtins['vexc'] = true

	mut has_continue_in_finally := false
	if node.finalbody.len > 0 {
		// Check for continue in finally
		// (Simplified check for now)
		if !has_continue_in_finally {
			m.emit('{')
			m.emit('    defer {')
			m.env.state.indent_level += 2
			for stmt in node.finalbody { m.visit_stmt(stmt) }
			m.env.state.indent_level -= 2
			m.emit('    }')
		}
	}

	m.env.state.vexc_depth++
	success_var := 'py_success_${m.env.state.unique_id_counter}'
	m.env.state.unique_id_counter++
	if node.orelse.len > 0 {
		m.emit('mut ${success_var} := false')
	}

	m.emit('if C.try() {')
	m.env.state.indent_level++
	for stmt in node.body { m.visit_stmt(stmt) }
	if node.orelse.len > 0 { m.emit('${success_var} = true') }
	m.emit('vexc.end_try()')
	m.env.state.indent_level--
	m.env.state.vexc_depth--
	m.emit('} else {')
	m.env.state.indent_level++

	if node.handlers.len > 0 {
		exc_var := 'py_exc_${m.env.state.unique_id_counter}'
		m.env.state.unique_id_counter++
		m.emit('${exc_var} := vexc.get_curr_exc()')
		mut first := true
		mut has_default := false
		for handler in node.handlers {
			mut cond := ''
			if typ := handler.typ {
				if typ is ast.Tuple {
					mut parts := []string{}
					for item in typ.elements {
						parts << "${exc_var}.name == '${m.visit_expr(item)}'"
					}
					cond = parts.join(' || ')
				} else {
					cond = "${exc_var}.name == '${m.visit_expr(typ)}'"
				}
			} else {
				has_default = true
			}

			prefix := if first { 'if' } else { 'else if' }
			if has_default {
				m.emit('//##LLM@@ Bare except block.')
				if !first { m.emit('else {') }
			} else {
				m.emit('${prefix} ${cond} {')
			}
			m.env.state.indent_level++
			if name := handler.name {
				if name.len > 0 {
					// Try to narrow type if possible (stubbed)
					m.emit('${name} := ${exc_var}')
				}
			}
			for stmt in handler.body { m.visit_stmt(stmt) }
			m.env.state.indent_level--
			if !has_default || !first { m.emit('}') }
			first = false
			if has_default { break }
		}
		if !has_default {
			m.emit('else {')
			m.emit('    vexc.raise(${exc_var}.name, ${exc_var}.msg)')
			m.emit('}')
		}
	} else {
		m.emit('py_exc := vexc.get_curr_exc()')
		m.emit('vexc.raise(py_exc.name, py_exc.msg)')
	}

	m.env.state.indent_level--
	m.emit('}')

	if node.orelse.len > 0 {
		m.emit('if ${success_var} {')
		m.env.state.indent_level++
		for stmt in node.orelse { m.visit_stmt(stmt) }
		m.env.state.indent_level--
		m.emit('}')
	}

	if node.finalbody.len > 0 && !has_continue_in_finally {
		m.emit('}')
	}
}

pub fn (mut m ControlFlowModule) visit_trystar(node ast.TryStar) {
	m.emit('//##LLM@@ Python except* detected; lowering as standard try/except.')
	m.visit_try(ast.Try{
		token:     node.token
		body:      node.body
		handlers:  node.handlers
		orelse:    node.orelse
		finalbody: node.finalbody
	})
}
