module translator

import ast
import classes
import functions

// Class translation logic has been moved to classes/ module.


fn (mut t Translator) visit_function_def(node ast.FunctionDef) {
	mut env := functions.new_function_visit_env(
		t.state,
		t.analyzer,
		fn [mut t] (stmt ast.Statement) {
			t.visit_stmt(stmt)
		},
		fn [mut t] (expr ast.Expression) string {
			return t.visit_expr(expr)
		},
		fn [mut t] (line string) {
			t.emit_indented(line)
		},
		fn [mut t] (line string) {
			t.emit_constant_code(line)
		},
		fn [mut t] () string {
			return t.indent()
		},
		fn [mut t] () {
			t.push_scope()
		},
		fn [mut t] () {
			t.pop_scope()
		},
		fn [mut t] (name string) {
			t.declare_local(name)
		},
		fn [mut t] (ann ast.Expression) string {
			return t.map_annotation(ann)
		},
		false,
	)
	t.functions_module.visit_function_def(node, mut env)
}

fn (mut t Translator) visit_class_def(node ast.ClassDef) {
	mut env := classes.new_class_visit_env(
		t.state,
		t.analyzer,
		fn [mut t] (stmt ast.Statement) {
			t.visit_stmt(stmt)
		},
		fn [mut t] (expr ast.Expression) string {
			return t.visit_expr(expr)
		},
		fn [mut t] (s string) {
			t.emit_struct_code(s)
		},
		fn [mut t] (s string) {
			t.emit_function_code(s)
		},
		fn [mut t] (s string) {
			t.emit_constant_code(s)
		},
		false,
	)
	t.classes_module.visit_class_def(node, mut env)
}

fn (mut t Translator) emit_struct_code(s string) {
	t.state.output << s
}

fn (mut t Translator) emit_function_code(s string) {
	t.state.output << s
}

fn (mut t Translator) emit_constant_code(s string) {
	t.state.output << s
}
