module variables

import ast

pub fn (mut m VariablesModule) visit_aug_assign(node ast.AugAssign) {
	target_expr, setup_stmts := m.capture_target_expr(node.target)
	for stmt in setup_stmts {
		m.state.output << stmt
	}

	value_expr := m.visit_expr(node.value)

	if m.state.in_main && node.target is ast.Name && node.target.id in m.state.global_vars {
		m.emitter.add_init_statement('${target_expr} += ${value_expr}')
		return
	}

	if node.op.value == '**' {
		m.emitter.add_import('math')
		target_type := m.guess_type(node.target, true)
		value_type := m.guess_type(node.value, true)
		if target_type == 'int' && value_type == 'int' {
			m.emit('${target_expr} = int(math.powi(f64(${target_expr}), ${value_expr}))')
		} else if target_type == 'int' {
			m.emit('${target_expr} = int(math.pow(f64(${target_expr}), f64(${value_expr})))')
		} else {
			m.emit('${target_expr} = math.pow(f64(${target_expr}), f64(${value_expr}))')
		}
		return
	}

	if node.op.value == '//' {
		m.emitter.add_import('math')
		target_type := m.guess_type(node.target, true)
		if target_type == 'f64' || target_type == 'float' {
			m.emit('${target_expr} = math.floor(${target_expr} / ${value_expr})')
		} else {
			m.emit('${target_expr} = int(math.floor(f64(${target_expr}) / f64(${value_expr})))')
		}
		return
	}

	op_map := {
		'+':  '+='
		'-':  '-='
		'*':  '*='
		'/':  '/='
		'%':  '%='
		'|':  '|='
		'&':  '&='
		'^':  '^='
		'<<': '<<='
		'>>': '>>='
	}
	if op := op_map[node.op.value] {
		m.emit('${target_expr} ${op} ${value_expr}')
		return
	}

	if node.op.value == '@' {
		m.emit('${target_expr} = ${target_expr}.matmul(${value_expr})')
		return
	}

	m.emit('// Unsupported AugAssign operator: ${node.op.value}')
}
