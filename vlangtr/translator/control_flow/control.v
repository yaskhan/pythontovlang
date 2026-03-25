module control_flow

import ast

pub fn (mut m ControlFlowModule) visit_break(_ ast.Break) {
	if m.loop_flag_stack.len > 0 {
		flag := m.loop_flag_stack[m.loop_flag_stack.len - 1]
		if flag.len > 0 {
			m.emit('${flag} = false')
		}
		target_depth := m.loop_depth_stack[m.loop_depth_stack.len - 1]
		diff := m.env.state.vexc_depth - target_depth
		for _ in 0 .. diff {
			m.emit('vexc.end_try()')
		}
	} else {
		for _ in 0 .. m.env.state.vexc_depth {
			m.emit('vexc.end_try()')
		}
	}
	m.emit('break')
}

pub fn (mut m ControlFlowModule) visit_continue(_ ast.Continue) {
	if m.in_finally {
		m.emit('//##LLM@@ continue inside finally block detected. V defer cannot contain continue.')
	}
	if m.loop_depth_stack.len > 0 {
		target_depth := m.loop_depth_stack[m.loop_depth_stack.len - 1]
		diff := m.env.state.vexc_depth - target_depth
		for _ in 0 .. diff {
			m.emit('vexc.end_try()')
		}
	} else {
		for _ in 0 .. m.env.state.vexc_depth {
			m.emit('vexc.end_try()')
		}
	}
	m.emit('continue')
}
