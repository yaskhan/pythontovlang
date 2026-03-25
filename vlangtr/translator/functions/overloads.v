module functions

import ast
import analyzer
import base

pub fn generate_overload_variants(
	node &ast.FunctionDef,
	struct_name string,
	is_method bool,
	dec_info DecoratorInfo,
	is_generator bool,
	mut state base.TranslatorState,
	analyzer_ref &analyzer.Analyzer,
	visit_fn fn (ast.Expression) string,
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
	get_all_active_v_generics_fn fn ([]map[string]string) []string,
	get_generics_with_variance_str_fn fn ([]string, map[string]string, map[string]string, map[string]string) string,
) {
	_ = node
	_ = struct_name
	_ = is_method
	_ = dec_info
	_ = is_generator
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
	_ = get_all_active_v_generics_fn
	_ = get_generics_with_variance_str_fn
}
