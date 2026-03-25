module functions

import ast
import analyzer
import base

pub struct DecoratorInfo {
pub mut:
	is_static            bool
	is_classmethod       bool
	is_setter            bool
	is_abstract          bool
	is_deprecated        bool
	cache_wrapper_needed bool
	implementation_name  string
	injected_start       []string
	injected_end         []string
	deprecated           bool
}

pub fn generate_function_for_struct(
	node &ast.FunctionDef,
	is_async bool,
	is_method bool,
	struct_name string,
	dec_info DecoratorInfo,
	is_generator bool,
	is_abstract bool,
	force_standalone bool,
	mut state base.TranslatorState,
	analyzer_ref &analyzer.Analyzer,
	visit_fn fn (ast.Statement) string,
	indent_fn fn () string,
	emit_fn fn (string),
	sanitize_fn fn (string, bool) string,
	map_type_fn fn (string, string, bool, bool, bool) string,
	get_full_self_type_fn fn (string) string,
	get_factory_name_fn fn (string) string,
	mangle_name_fn fn (string, string) string,
	is_exported_fn fn (string) bool,
	get_source_info_fn fn (ast.Statement) string,
	extract_implicit_generics_fn fn (&ast.FunctionDef, map[string]bool, map[string]bool, []string, fn (string, bool) string) []string,
	get_generic_map_fn fn ([]string, []map[string]string) map[string]string,
	get_v_default_value_fn fn (string, []string) string,
	is_empty_body_fn fn ([]ast.Statement) bool,
	get_all_active_v_generics_fn fn ([]map[string]string) []string,
	get_generics_with_variance_str_fn fn ([]string, map[string]string, map[string]string, map[string]string) string,
) {
	_ = node
	_ = is_async
	_ = is_method
	_ = struct_name
	_ = dec_info
	_ = is_generator
	_ = is_abstract
	_ = force_standalone
	_ = state
	_ = analyzer_ref
	_ = visit_fn
	_ = indent_fn
	_ = emit_fn
	_ = sanitize_fn
	_ = map_type_fn
	_ = get_full_self_type_fn
	_ = get_factory_name_fn
	_ = mangle_name_fn
	_ = is_exported_fn
	_ = get_source_info_fn
	_ = extract_implicit_generics_fn
	_ = get_generic_map_fn
	_ = get_v_default_value_fn
	_ = is_empty_body_fn
	_ = get_all_active_v_generics_fn
	_ = get_generics_with_variance_str_fn
}
