module expressions

import ast

pub fn (mut eg ExprGen) visit_expr(node ast.Expr) string {
	val := eg.visit(node.value)
	if val.len > 0 {
		eg.emit(val)
	}
	return val
}

pub fn (mut eg ExprGen) visit_starred(node ast.Starred) string {
	return '...${eg.visit(node.value)}'
}

pub fn (mut eg ExprGen) visit_assert(node ast.Assert) string {
	test := eg.wrap_bool(node.test, false)
	if msg_expr := node.msg {
		msg := eg.visit(msg_expr)
		line := 'assert ${test}, ${msg}'
		eg.emit(line)
		return line
	}
	line := 'assert ${test}'
	eg.emit(line)
	return line
}

pub fn (mut eg ExprGen) visit_if_exp(node ast.IfExp) string {
	test := eg.wrap_bool(node.test, false)
	body := eg.visit(node.body)
	orelse := eg.visit(node.orelse)
	return 'if ${test} { ${body} } else { ${orelse} }'
}
