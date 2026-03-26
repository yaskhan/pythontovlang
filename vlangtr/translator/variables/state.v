module variables

import analyzer
import ast
import base

pub struct VariablesEmitter {
pub mut:
	helper_structs []string
	globals        []string
	init_statements []string
	constants      []string
	imports        map[string]bool
}

pub fn new_variables_emitter() VariablesEmitter {
	return VariablesEmitter{
		helper_structs: []string{}
		globals:        []string{}
		init_statements: []string{}
		constants:      []string{}
		imports:        map[string]bool{}
	}
}

pub fn (mut e VariablesEmitter) add_helper_struct(code string) {
	e.helper_structs << code
}

pub fn (mut e VariablesEmitter) add_struct(code string) {
	e.helper_structs << code
}

pub fn (mut e VariablesEmitter) add_global(code string) {
	e.globals << code
}

pub fn (mut e VariablesEmitter) add_init_statement(code string) {
	e.init_statements << code
}

pub fn (mut e VariablesEmitter) add_constant(code string) {
	e.constants << code
}

pub fn (mut e VariablesEmitter) add_import(name string) {
	e.imports[name] = true
}

fn noop_visit_expr(_ ast.Expression) string {
	return ''
}

fn noop_sum_type_registrar(_ string) string {
	return ''
}

fn noop_literal_registrar(_ []string) string {
	return ''
}

fn noop_tuple_registrar(_ string) string {
	return ''
}

pub struct VariablesModule {
pub mut:
	state                   base.TranslatorState
	analyzer                analyzer.Analyzer
	emitter                 VariablesEmitter
	visit_expr_fn           fn (ast.Expression) string = noop_visit_expr
	local_vars_in_scope     map[string]bool
	current_assignment_type string
}

pub fn new_variables_module(state base.TranslatorState, analyzer_ref analyzer.Analyzer, visit_expr_fn fn (ast.Expression) string) VariablesModule {
	return VariablesModule{
		state:                   state
		analyzer:                analyzer_ref
		emitter:                 new_variables_emitter()
		visit_expr_fn:           visit_expr_fn
		local_vars_in_scope:     map[string]bool{}
		current_assignment_type: ''
	}
}

pub fn new_empty_variables_module() VariablesModule {
	return new_variables_module(base.new_translator_state(), analyzer.new_analyzer(map[string]string{}),
		noop_visit_expr)
}

pub fn (m &VariablesModule) indent() string {
	return m.state.indent()
}

pub fn (mut m VariablesModule) emit(line string) {
	m.state.output << '${m.indent()}${line}'
}

pub fn (mut m VariablesModule) visit_expr(node ast.Expression) string {
	return m.visit_expr_fn(node)
}

fn (m &VariablesModule) type_utils_context() base.TypeUtilsContext {
	return base.TypeUtilsContext{
		imported_symbols: m.state.imported_symbols
		scc_files:        m.state.scc_files.keys()
		used_builtins:    m.state.used_builtins
		warnings:         m.state.warnings
		config:           m.state.config
	}
}

pub fn (mut m VariablesModule) guess_type(node ast.Expression, use_location bool) string {
	ctx := base.TypeGuessingContext{
		type_map:           m.analyzer.type_map
		location_map:       m.analyzer.location_map
		known_v_types:      m.state.known_v_types
		name_remap:         m.state.name_remap
		defined_classes:    m.state.defined_classes
		explicit_any_types: m.analyzer.explicit_any_types
	}
	return base.guess_type(node, ctx, use_location)
}

pub fn (mut m VariablesModule) map_python_type(type_str string, allow_union bool, register_sum_types bool, is_return bool) string {
	opts := base.TypeMapOptions{
		struct_name:        m.state.current_class
		allow_union:        allow_union
		register_sum_types: register_sum_types
		is_return:          is_return
		generic_map:        m.state.current_class_generic_map
	}
	mut ctx := m.type_utils_context()
	return base.map_type(type_str, opts, mut ctx, noop_sum_type_registrar, noop_literal_registrar,
		noop_tuple_registrar)
}

pub fn (m &VariablesModule) sanitize_name(name string, is_type bool) string {
	return base.sanitize_name(name, is_type, map[string]bool{}, '', m.local_vars_in_scope)
}

pub fn (m &VariablesModule) to_snake_case(name string) string {
	return base.to_snake_case(name)
}

pub fn (m &VariablesModule) is_exported(name string) bool {
	return m.state.is_exported(name)
}

pub fn (m &VariablesModule) is_literal_string_expr(node ast.Expression) bool {
	return base.is_literal_string_expr_state(node, m.analyzer.type_map)
}

pub fn (m &VariablesModule) is_compile_time_evaluable(node ast.Expression) bool {
	if node is ast.Constant {
		return true
	}
	if node is ast.Name {
		return node.id.is_upper()
	}
	if node is ast.UnaryOp {
		return m.is_compile_time_evaluable(node.operand)
	}
	if node is ast.BinaryOp {
		return m.is_compile_time_evaluable(node.left) && m.is_compile_time_evaluable(node.right)
	}
	if node is ast.List || node is ast.Tuple || node is ast.Set {
		mut elements := []ast.Expression{}
		if node is ast.List {
			elements = node.elements.clone()
		} else if node is ast.Tuple {
			elements = node.elements.clone()
		} else if node is ast.Set {
			elements = node.elements.clone()
		}
		for elt in elements {
			if !m.is_compile_time_evaluable(elt) {
				return false
			}
		}
		return true
	}
	if node is ast.Dict {
		for key in node.keys {
			if key !is ast.NoneExpr && !m.is_compile_time_evaluable(key) {
				return false
			}
		}
		for value in node.values {
			if !m.is_compile_time_evaluable(value) {
				return false
			}
		}
		return true
	}
	return false
}

pub fn (mut m VariablesModule) capture_value(node ast.Expression) (string, []string) {
	if node is ast.Name || node is ast.Constant {
		return m.visit_expr(node), []string{}
	}
	tmp := m.state.create_temp()
	return tmp, ['${m.indent()}${tmp} := ${m.visit_expr(node)}']
}

pub fn (mut m VariablesModule) capture_target_expr(node ast.Expression) (string, []string) {
	if node is ast.Name {
		return m.visit_expr(node), []string{}
	}
	if node is ast.Attribute {
		attr := node
		mut base_expr := ''
		mut setup := []string{}
		if attr.value is ast.Name || attr.value is ast.Attribute || attr.value is ast.Subscript {
			base_expr, setup = m.capture_target_expr(attr.value)
		} else {
			base_expr, setup = m.capture_value(attr.value)
		}
		return '${base_expr}.${m.sanitize_name(attr.attr, false)}', setup
	}
	if node is ast.Subscript {
		sub := node
		mut base_expr := ''
		mut setup := []string{}
		if sub.value is ast.Name || sub.value is ast.Attribute || sub.value is ast.Subscript {
			base_expr, setup = m.capture_target_expr(sub.value)
		} else {
			base_expr, setup = m.capture_value(sub.value)
		}
		idx_expr, idx_setup := m.capture_value(sub.slice)
		mut all_setup := []string{}
		all_setup << setup
		all_setup << idx_setup
		return '${base_expr}[${idx_expr}]', all_setup
	}
	return m.visit_expr(node), []string{}
}

pub fn (mut m VariablesModule) register_lambda_signature(name string, lambda_node ast.Lambda) {
	if name !in m.analyzer.call_signatures {
		m.analyzer.call_signatures[name] = analyzer.CallSignature{
			args:        []string{}
			arg_names:   []string{}
			defaults:    map[string]string{}
			return_type: 'Any'
			is_class:    false
			has_init:    false
			has_vararg:  lambda_node.args.vararg != none
			has_kwarg:   lambda_node.args.kwarg != none
		}
	}

	mut arg_names := []string{}
	mut defaults_map := map[string]string{}
	mut positional := []ast.Parameter{}
	for param in lambda_node.args.posonlyargs {
		positional << param
	}
	for param in lambda_node.args.args {
		positional << param
	}
	for param in positional {
		arg_names << param.arg
		if default_expr := param.default_ {
			if default_expr is ast.Name {
				if default_expr.id != param.arg {
					defaults_map[param.arg] = m.visit_expr(default_expr)
				}
			} else {
				defaults_map[param.arg] = m.visit_expr(default_expr)
			}
		}
	}
	for param in lambda_node.args.kwonlyargs {
		arg_names << param.arg
		if default_expr := param.default_ {
			if default_expr is ast.Name {
				if default_expr.id != param.arg {
					defaults_map[param.arg] = m.visit_expr(default_expr)
				}
			} else {
				defaults_map[param.arg] = m.visit_expr(default_expr)
			}
		}
	}

	mut args := []string{}
	for _ in arg_names {
		args << 'Any'
	}
	m.analyzer.call_signatures[name] = analyzer.CallSignature{
		args:        args
		arg_names:   arg_names
		defaults:    defaults_map
		return_type: 'Any'
		is_class:    false
		has_init:    false
		has_vararg:  lambda_node.args.vararg != none
		has_kwarg:   lambda_node.args.kwarg != none
	}
}
