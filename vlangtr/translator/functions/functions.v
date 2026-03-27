module functions

import ast
import analyzer
import base

pub struct DecoratorInfo {
pub mut:
	is_classmethod  bool
	is_staticmethod bool
	is_property     bool
	is_setter       bool
	is_deleter      bool
	is_deprecated   bool
	deprecated_msg  string
}

pub struct FunctionsOverloadHandler {}

pub struct FunctionsModule {
pub mut:
	generation_handler FunctionsGenerationHandler
	overload_handler   FunctionsOverloadHandler
	visitor_handler    FunctionsVisitorHandler
}

pub fn new_functions_module() FunctionsModule {
	return FunctionsModule{
		generation_handler: FunctionsGenerationHandler{}
		overload_handler:   FunctionsOverloadHandler{}
		visitor_handler:    FunctionsVisitorHandler{}
	}
}

pub struct FunctionVisitEnv {
pub mut:
	state             &base.TranslatorState
	analyzer          analyzer.Analyzer
	visit_stmt_fn     fn (ast.Statement)
	visit_expr_fn     fn (ast.Expression) string
	emit_fn           fn (string)
	emit_constant_fn  fn (string)
	indent_fn         fn () string
	push_scope_fn     fn ()
	pop_scope_fn      fn ()
	declare_local_fn  fn (string)
	map_annotation_fn fn (ast.Expression) string
	source_mapping    bool
}

pub fn new_function_visit_env(
	state &base.TranslatorState,
	analyzer_ref analyzer.Analyzer,
	visit_stmt_fn fn (ast.Statement),
	visit_expr_fn fn (ast.Expression) string,
	emit_fn fn (string),
	emit_constant_fn fn (string),
	indent_fn fn () string,
	push_scope_fn fn (),
	pop_scope_fn fn (),
	declare_local_fn fn (string),
	map_annotation_fn fn (ast.Expression) string,
	source_mapping bool,
) FunctionVisitEnv {
	return FunctionVisitEnv{
		state:             state
		analyzer:          analyzer_ref
		visit_stmt_fn:     visit_stmt_fn
		visit_expr_fn:     visit_expr_fn
		emit_fn:           emit_fn
		emit_constant_fn:  emit_constant_fn
		indent_fn:         indent_fn
		push_scope_fn:     push_scope_fn
		pop_scope_fn:      pop_scope_fn
		declare_local_fn:  declare_local_fn
		map_annotation_fn: map_annotation_fn
		source_mapping:    source_mapping
	}
}

pub fn (mut m FunctionsModule) visit_function_def(node ast.FunctionDef, mut env FunctionVisitEnv) {
	m.visitor_handler.visit_function_def(node, mut env, mut m)
}
fn sanitize_name(name string, is_type bool) string {
	return base.sanitize_name(name, is_type, map[string]bool{}, '', map[string]bool{})
}
