module base

import ast

// capture_value stores a complex expression into a temporary variable.
pub fn capture_value(node ast.Expression, visit_fn fn (ast.Expression) string, create_temp_fn fn () string, indent_fn fn () string) (string, []string) {
	if node is ast.Name || node is ast.Constant {
		return visit_fn(node), []string{}
	}
	tmp := create_temp_fn()
	val_code := visit_fn(node)
	return tmp, ['${indent_fn()}${tmp} := ${val_code}']
}

// capture_target prepares an assignment target and setup statements for AugAssign lowering.
pub fn capture_target(node ast.Expression, visit_fn fn (ast.Expression) string, create_temp_fn fn () string, indent_fn fn () string, sanitize_name_fn fn (string) string) (string, []string) {
	if node is ast.Name {
		return visit_fn(node), []string{}
	}

	if node is ast.Attribute {
		mut base_expr := ''
		mut base_setup := []string{}
		if node.value is ast.Name || node.value is ast.Attribute || node.value is ast.Subscript {
			base_expr, base_setup = capture_target(node.value, visit_fn, create_temp_fn,
				indent_fn, sanitize_name_fn)
		} else {
			base_expr, base_setup = capture_value(node.value, visit_fn, create_temp_fn,
				indent_fn)
		}
		attr_name := sanitize_name_fn(node.attr)
		return '${base_expr}.${attr_name}', base_setup
	}

	if node is ast.Subscript {
		mut base_expr := ''
		mut base_setup := []string{}
		if node.value is ast.Name || node.value is ast.Attribute || node.value is ast.Subscript {
			base_expr, base_setup = capture_target(node.value, visit_fn, create_temp_fn,
				indent_fn, sanitize_name_fn)
		} else {
			base_expr, base_setup = capture_value(node.value, visit_fn, create_temp_fn,
				indent_fn)
		}

		idx_expr, idx_setup := capture_value(node.slice, visit_fn, create_temp_fn, indent_fn)
		mut setup := []string{}
		setup << base_setup
		setup << idx_setup
		return '${base_expr}[${idx_expr}]', setup
	}

	return visit_fn(node), []string{}
}
