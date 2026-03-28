module translator

import ast
import control_flow

fn (mut t Translator) visit_if(node ast.If) {
	t.control_flow_module.env = t.get_control_flow_env()
	t.control_flow_module.visit_if(node)
}

fn (mut t Translator) visit_while(node ast.While) {
	t.control_flow_module.env = t.get_control_flow_env()
	t.control_flow_module.visit_while(node)
}

fn (mut t Translator) visit_with(node ast.With) {
	t.control_flow_module.env = t.get_control_flow_env()
	t.control_flow_module.visit_with(node)
}

fn (mut t Translator) visit_for(node ast.For) {
	t.control_flow_module.env = t.get_control_flow_env()
	t.control_flow_module.visit_for(node)
}

fn (mut t Translator) visit_match(node ast.Match) {
	t.control_flow_module.env = t.get_control_flow_env()
	t.control_flow_module.visit_match(node)
}

fn (mut t Translator) visit_try(node ast.Try) {
	t.control_flow_module.env = t.get_control_flow_env()
	t.control_flow_module.visit_try(node)
}

fn (mut t Translator) visit_trystar(node ast.TryStar) {
	t.control_flow_module.env = t.get_control_flow_env()
	t.control_flow_module.visit_trystar(node)
}

fn (mut t Translator) visit_break(node ast.Break) {
	t.control_flow_module.env = t.get_control_flow_env()
	t.control_flow_module.visit_break(node)
}

fn (mut t Translator) visit_continue(node ast.Continue) {
	t.control_flow_module.env = t.get_control_flow_env()
	t.control_flow_module.visit_continue(node)
}

fn (mut t Translator) visit_return(node ast.Return) {
	t.control_flow_module.env = t.get_control_flow_env()
	t.control_flow_module.visit_return(node)
}

fn (mut t Translator) visit_raise(node ast.Raise) {
	t.control_flow_module.env = t.get_control_flow_env()
	t.control_flow_module.visit_raise(node)
}

fn (mut t Translator) get_control_flow_env() control_flow.ControlFlowVisitEnv {
	return control_flow.new_control_flow_visit_env(
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
		fn [mut t] () string {
			return t.indent()
		},
		fn [mut t] (name string) {
			t.declare_local(name)
		},
		fn [mut t] (name string) bool {
			return t.is_declared_local(name)
		},
		fn [mut t] (node ast.Expression) string {
			return t.guess_type(node)
		}
	)
}
