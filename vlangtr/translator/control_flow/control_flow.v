module control_flow

import analyzer
import ast
import base

pub struct ControlFlowVisitEnv {
pub mut:
	state         base.TranslatorState
	analyzer      analyzer.Analyzer
	visit_stmt_fn fn (ast.Statement)
	visit_expr_fn fn (ast.Expression) string
	emit_fn       fn (string)
}

pub struct ControlFlowModule {
pub mut:
	env                ControlFlowVisitEnv
	loop_flag_stack    []string
	loop_depth_stack    []int
	in_finally          bool
}

fn noop_visit_stmt(_ ast.Statement) {}

fn noop_visit_expr(_ ast.Expression) string {
	return ''
}

fn noop_emit(_ string) {}

pub fn new_control_flow_visit_env(
	state base.TranslatorState,
	analyzer_ref analyzer.Analyzer,
	visit_stmt_fn fn (ast.Statement),
	visit_expr_fn fn (ast.Expression) string,
	emit_fn fn (string),
) ControlFlowVisitEnv {
	return ControlFlowVisitEnv{
		state:         state
		analyzer:      analyzer_ref
		visit_stmt_fn: visit_stmt_fn
		visit_expr_fn: visit_expr_fn
		emit_fn:       emit_fn
	}
}

pub fn new_control_flow_module() ControlFlowModule {
	return ControlFlowModule{
		env: ControlFlowVisitEnv{
			state:         base.new_translator_state()
			analyzer:      analyzer.new_analyzer(map[string]string{})
			visit_stmt_fn: noop_visit_stmt
			visit_expr_fn: noop_visit_expr
			emit_fn:       noop_emit
		}
		loop_flag_stack: []string{}
		loop_depth_stack: []int{}
		in_finally:      false
	}
}

pub fn (m &ControlFlowModule) indent() string {
	return m.env.state.indent()
}

pub fn (mut m ControlFlowModule) emit(line string) {
	m.env.state.output << '${m.indent()}${line}'
	m.env.emit_fn('${m.indent()}${line}')
}

pub fn (mut m ControlFlowModule) visit_stmt(node ast.Statement) {
	m.env.visit_stmt_fn(node)
}

pub fn (mut m ControlFlowModule) visit_expr(node ast.Expression) string {
	return m.env.visit_expr_fn(node)
}

pub fn (mut m ControlFlowModule) guess_type(node ast.Expression) string {
	ctx := base.TypeGuessingContext{
		type_map:        m.env.analyzer.type_map
		location_map:    m.env.analyzer.location_map
		known_v_types:   m.env.state.known_v_types
		name_remap:      m.env.state.name_remap
		defined_classes: m.env.state.defined_classes
	}
	return base.guess_type(node, ctx, true)
}

pub fn (mut m ControlFlowModule) wrap_bool(node ast.Expression, invert bool) string {
	expr := m.visit_expr(node)
	v_type := m.guess_type(node)
	return base.wrap_bool(node, expr, v_type, invert)
}

pub fn (m &ControlFlowModule) sanitize_name(name string, is_type bool) string {
	return base.sanitize_name(name, is_type, map[string]bool{}, '', map[string]bool{})
}

pub fn (m &ControlFlowModule) map_python_type(type_str string, is_return bool) string {
	opts := base.TypeMapOptions{
		struct_name:        m.env.state.current_class
		allow_union:        true
		register_sum_types: false
		is_return:          is_return
		generic_map:        m.env.state.current_class_generic_map
	}
	mut ctx := base.TypeUtilsContext{
		imported_symbols: m.env.state.imported_symbols
		scc_files:        m.env.state.scc_files.keys()
		used_builtins:    m.env.state.used_builtins
		warnings:         m.env.state.warnings
		config:           m.env.state.config
	}
	return base.map_type(type_str, opts, mut ctx, fn (_ string) string { return '' },
		fn (_ []string) string { return '' }, fn (_ string) string { return '' })
}
