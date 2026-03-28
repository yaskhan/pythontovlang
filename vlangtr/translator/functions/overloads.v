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
	is_exported_c fn (string) bool,
	get_source_info_fn fn (ast.Statement) string,
	extract_implicit_generics_fn fn (&ast.FunctionDef, map[string]bool, map[string]bool, []string, fn (string, bool) string) []string,
	get_generic_map_fn fn ([]string, []map[string]string) map[string]string,
	get_all_active_v_generics_fn fn ([]map[string]string) []string,
	get_generics_with_variance_str_fn fn ([]string, map[string]string, map[string]string, map[string]string) string,
	mut m FunctionsModule,
	mut env FunctionVisitEnv,
) {
	ov_key := if is_method { '${struct_name}.${node.name}' } else { node.name }
	if ov_key !in state.overloaded_signatures { return }
	
	sigs := state.overloaded_signatures[ov_key]
	for sig in sigs {
		mut type_suffix_parts := []string{}
		mut args_str_list := []string{}
		
		// Collect arg types and build suffix
		for arg_name, arg_type in sig {
			if arg_name == 'return' { continue }
			if arg_name in ['self', 'cls'] { continue }
			
			mut clean_type := if arg_type in state.type_vars { 'generic' } else { arg_type }
			clean_type = clean_type.replace('?', 'opt_').replace('[]', 'arr_').replace('[', '_').replace(']', '').replace('.', '_')
			type_suffix_parts << clean_type
			args_str_list << '${sanitize_fn(arg_name, false)} ${arg_type}'
		}
		
		mut func_name := sanitize_fn(node.name, false)
		if is_method && (dec_info.is_staticmethod || dec_info.is_classmethod) {
			func_name = '${struct_name}_${func_name}'
		}
		
		if type_suffix_parts.len > 0 {
			func_name = '${func_name}_${type_suffix_parts.join("_")}'
		} else {
			func_name = '${func_name}_noargs'
		}
		
		ret_type := sig['return'] or { 'void' }
		ret_suffix := if ret_type != 'void' { ' ${ret_type}' } else { '' }
		
		gen_s := if state.current_class_generics.len > 0 {
			'[${state.current_class_generics.join(", ")}]'
		} else { '' }

		pub_pfx := if is_exported_c(node.name) { 'pub ' } else { '' }
		
		mut deprecated_attr := ''
		if dec_info.is_deprecated {
			if dec_info.deprecated_msg.len > 0 {
				deprecated_attr = '@[deprecated: \'${dec_info.deprecated_msg}\']\n'
			} else {
				deprecated_attr = '@[deprecated]\n'
			}
		}

		mut receiver_str := ''
		if is_method && !dec_info.is_staticmethod && !dec_info.is_classmethod {
			gen_s_class := if state.current_class_generics.len > 0 {
				'[${state.current_class_generics.join(", ")}]'
			} else { '' }
			receiver_str = '(cls ${struct_name}${gen_s_class}) ' // simplified, usually takes node.args.args[0]
		}

		mut out_parts := []string{}
		out_parts << '${indent_fn()}${deprecated_attr}${pub_pfx}${receiver_str}fn ${func_name}${gen_s}(${args_str_list.join(", ")})${ret_suffix} {'
		
		// Visit implementation body
		state.indent_level++
		for stmt in node.body {
			env.visit_stmt_fn(stmt)
		}
		state.indent_level--
		
		out_parts << '${indent_fn()}}'
		emit_fn(out_parts.join('\n'))
	}
}
