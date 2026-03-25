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

	if exc := node.exc {
		if exc is ast.Call {
			exc_name := m.visit_expr(exc.func)
			msg := if exc.args.len > 0 { m.visit_expr(exc.args[0]) } else { "''" }
			m.emit("vexc.raise('${exc_name}', ${msg})")
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
		m.emit("//##LLM@@ Bare raise outside active exception block.")
		m.emit("panic('reraise not supported outside except block')")
		m.env.state.indent_level--
		m.emit('}')
	}
}

fn (mut m ControlFlowModule) emit_handler_body(handler ast.ExceptHandler) {
	if name := handler.name {
		if name.len > 0 {
			m.emit('${name} := py_exc')
		}
	}
	for stmt in handler.body {
		m.visit_stmt(stmt)
	}
}

pub fn (mut m ControlFlowModule) visit_try(node ast.Try) {
	m.emit('//##LLM@@ Python try/except/finally block detected.')

	if node.finalbody.len > 0 {
		m.in_finally = true
		m.emit('defer {')
		m.env.state.indent_level++
		for stmt in node.finalbody {
			m.visit_stmt(stmt)
		}
		m.env.state.indent_level--
		m.emit('}')
	}

	m.env.state.vexc_depth++
	success_var := 'py_success_${m.env.state.unique_id_counter}'
	m.env.state.unique_id_counter++
	if node.orelse.len > 0 {
		m.emit('mut ${success_var} := false')
	}

	m.emit('if C.try() {')
	m.env.state.indent_level++
	for stmt in node.body {
		m.visit_stmt(stmt)
	}
	if node.orelse.len > 0 {
		m.emit('${success_var} = true')
	}
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
		for handler in node.handlers {
			mut cond := 'true'
			if typ := handler.typ {
				if typ is ast.Tuple {
					mut parts := []string{}
					for item in typ.elements {
						parts << '${exc_var}.name == "${m.visit_expr(item)}"'
					}
					cond = parts.join(' || ')
				} else {
					cond = '${exc_var}.name == "${m.visit_expr(typ)}"'
				}
			}
			if first {
				m.emit('if ${cond} {')
				first = false
			} else if handler.typ != none {
				m.emit('} else if ${cond} {')
			} else {
				m.emit('} else {')
			}
			m.env.state.indent_level++
			if name := handler.name {
				if name.len > 0 {
					m.emit('${name} := ${exc_var}')
				}
			}
			for stmt in handler.body {
				m.visit_stmt(stmt)
			}
			m.env.state.indent_level--
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
		for stmt in node.orelse {
			m.visit_stmt(stmt)
		}
		m.env.state.indent_level--
		m.emit('}')
	}

	if node.finalbody.len > 0 {
		m.in_finally = false
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
