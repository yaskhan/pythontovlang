module tests

import analyzer
import ast
import models
import translator.expressions as exprs

fn translate_expr(source string, type_map map[string]string) string {
	mut lexer := ast.new_lexer(source, 'test.py')
	mut parser := ast.new_parser(lexer)
	module_node := parser.parse_module()
	if module_node.body.len == 0 {
		return ''
	}

	mut an := analyzer.new_analyzer(type_map)
	mut model := models.VType.unknown
	mut eg := exprs.new_expr_gen(&model, &an)
	first_stmt := module_node.body[0]
	return match first_stmt {
		ast.Expr { eg.visit(first_stmt.value) }
		ast.Assert { eg.visit_assert(first_stmt) }
		else { panic('expected expression statement') }
	}
}

fn test_assert_translation() {
	assert translate_expr('assert x > 0', map[string]string{}) == 'assert x > 0'
	assert translate_expr('assert False', map[string]string{}) == 'assert false'
}

fn test_floor_div_translation() {
	assert translate_expr('-7 // 2', map[string]string{}) == 'int(math.floor(f64(-7) / f64(2)))'
	assert translate_expr('7 // -2', map[string]string{}) == 'int(math.floor(f64(7) / f64(-2)))'
	assert translate_expr('7.0 // 2', map[string]string{}) == 'math.floor(7.0 / 2)'
	assert translate_expr('7 // 2.0', map[string]string{}) == 'math.floor(7 / 2.0)'
}

fn test_pow_translation() {
	assert translate_expr('2 ** -1', map[string]string{}) == 'int(math.powi(f64(2), -1))'
	assert translate_expr('2 ** -2', map[string]string{}) == 'int(math.powi(f64(2), -2))'
	assert translate_expr('2.0 ** -1', map[string]string{}) == 'math.pow(f64(2.0), f64(-1))'
	assert translate_expr('2 ** 2', map[string]string{}) == 'int(math.powi(f64(2), 2))'
}

fn test_round_translation() {
	assert translate_expr('round(3.5)', map[string]string{}) == 'int(math.round(3.5))'
	mut type_map := map[string]string{}
	type_map['x'] = 'f64'
	assert translate_expr('round(x)', type_map) == 'int(math.round(x))'
}

fn test_builtin_type_checks_translation() {
	assert translate_expr('isinstance(x, int)', map[string]string{}) == 'x is int'
	assert translate_expr('issubclass(A, B)', map[string]string{}) == 'A in B'
}

fn test_percent_format_translation() {
	mut type_map := map[string]string{}
	type_map['s'] = 'string'

	assert translate_expr("'Hello %s' % 'World'", type_map) == "py_string_format('Hello %s', 'World')"
	assert translate_expr("'Num %d' % 123", type_map) == "py_string_format('Num %d', 123)"
	assert translate_expr("'%.2f' % 3.14", type_map).contains("py_string_format('%.2f', 3.14)")
	assert translate_expr("'%s %d' % ('Age', 30)", type_map) == "py_string_format('%s %d', 'Age', 30)"
}
