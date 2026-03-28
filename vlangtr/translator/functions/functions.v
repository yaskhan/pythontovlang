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

pub fn (h FunctionsOverloadHandler) handle_overloads(node &ast.FunctionDef, struct_name string, dec_info DecoratorInfo, mut env FunctionVisitEnv, mut m FunctionsModule) {
	generate_overload_variants(
		node, struct_name, struct_name.len > 0, dec_info,
		false, mut env.state, &env.analyzer, env.visit_expr_fn,
		env.indent_fn, env.emit_fn, base.sanitize_name_helper, env.map_type_fn,
		get_full_self_type_fn, get_factory_name_fn, mangle_name_fn,
		is_exported_fn, get_source_info_fn, extract_implicit_generics_fn,
		get_generic_map_fn, get_all_active_v_generics_fn, get_generics_with_variance_str_fn,
		mut m,
		mut env
	)
}

fn sanitize_name_fn(name string, is_type bool) string { return sanitize_name(name, is_type) }
fn map_type_fn(type_str string, struct_name string, allow_union bool, register bool, is_return bool) string { return type_str } // stub
fn get_full_self_type_fn(struct_name string) string { return struct_name } // stub
fn get_factory_name_fn(class_name string) string { return class_name } // stub
fn mangle_name_fn(name string, class_name string) string { return name } // stub
fn is_exported_fn(name string) bool { return true } // stub
fn get_source_info_fn(node ast.Statement) string { return '' } // stub
fn extract_implicit_generics_fn(node &ast.FunctionDef, variance map[string]bool, defaults map[string]bool, current []string, sanitize fn(string, bool) string) []string { return []string{} } // stub
fn get_generic_map_fn(generics []string, scopes []map[string]string) map[string]string { return map[string]string{} } // stub
fn get_all_active_v_generics_fn(scopes []map[string]string) []string { return []string{} } // stub
fn get_generics_with_variance_str_fn(generics []string, variance map[string]string, defaults map[string]string, variance_map map[string]string) string { return '' } // stub

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
	visit_stmt_fn     fn (ast.Statement) = unsafe { nil }
	visit_expr_fn     fn (ast.Expression) string = unsafe { nil }
	emit_fn           fn (string) = unsafe { nil }
	emit_constant_fn  fn (string) = unsafe { nil }
	indent_fn         fn () string = unsafe { nil }
	push_scope_fn     fn () = unsafe { nil }
	pop_scope_fn      fn () = unsafe { nil }
	declare_local_fn  fn (string) = unsafe { nil }
	map_annotation_fn fn (ast.Expression) string = unsafe { nil }
	map_type_fn       fn (string, string, bool, bool, bool) string = unsafe { nil }
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
	map_type_fn fn (string, string, bool, bool, bool) string,
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
		map_type_fn:       map_type_fn
		source_mapping:    source_mapping
	}
}

pub fn (mut m FunctionsModule) visit_function_def(node &ast.FunctionDef, mut env FunctionVisitEnv) {
	m.visitor_handler.visit_function_def(node, mut env, mut m)
}
fn sanitize_name(name string, is_type bool) string {
	return base.sanitize_name(name, is_type, map[string]bool{}, '', map[string]bool{})
}
