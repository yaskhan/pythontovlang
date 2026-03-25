module control_flow

import ast

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
	}

	test_expr := m.wrap_bool(node.test, false)
	if is_elif {
		m.emit('} else if ${test_expr} {')
	} else {
		m.emit('if ${test_expr} {')
	}
	m.env.state.indent_level++
	for stmt in node.body {
		m.visit_stmt(stmt)
	}
	m.env.state.indent_level--

	if node.orelse.len > 0 {
		m.emit('} else {')
		m.env.state.indent_level++
		for stmt in node.orelse {
			m.visit_stmt(stmt)
		}
		m.env.state.indent_level--
		m.emit('}')
	} else {
		m.emit('}')
	}
}
