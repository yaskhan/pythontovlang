module classes

import ast
import base

fn noop_sum_type_registrar(_ string) string {
	return ''
}

fn noop_literal_registrar(_ []string) string {
	return ''
}

fn noop_tuple_registrar(_ string) string {
	return ''
}

fn (env &ClassVisitEnv) type_utils_context() base.TypeUtilsContext {
	return base.TypeUtilsContext{
		imported_symbols: env.state.imported_symbols
		scc_files:        env.state.scc_files.keys()
		used_builtins:    env.state.used_builtins
		warnings:         env.state.warnings
		config:           env.state.config
	}
}

fn map_python_type(type_str string, struct_name string, is_return bool, mut env ClassVisitEnv) string {
	opts := base.TypeMapOptions{
		struct_name:        struct_name
		allow_union:        true
		register_sum_types: false
		is_return:          is_return
		generic_map:        env.state.current_class_generic_map
	}
	mut ctx := env.type_utils_context()
	return base.map_type(type_str, opts, mut ctx, noop_sum_type_registrar, noop_literal_registrar,
		noop_tuple_registrar)
}

fn guess_type(node ast.Expression, env &ClassVisitEnv) string {
	ctx := base.TypeGuessingContext{
		type_map:           env.analyzer.type_map
		location_map:       env.analyzer.location_map
		known_v_types:      env.state.known_v_types
		name_remap:         env.state.name_remap
		defined_classes:    env.state.defined_classes
		explicit_any_types: env.analyzer.explicit_any_types
	}
	return base.guess_type(node, ctx, true)
}

fn sanitize_name(name string, is_type bool) string {
	return base.sanitize_name(name, is_type, map[string]bool{}, '', map[string]bool{})
}

fn get_factory_name(struct_name string, env &ClassVisitEnv) string {
	return base.get_factory_name(struct_name, env.state.class_hierarchy)
}

fn get_generics_with_variance_str(env &ClassVisitEnv) string {
	mut v_generics := []string{}
	for py_name in env.state.current_class_generics {
		v_generics << env.state.current_class_generic_map[py_name] or { py_name }
	}
	return base.get_generics_with_variance_str(v_generics,
		env.state.current_class_generic_map, env.state.generic_variance, env.state.generic_defaults)
}

fn is_v_class_type(v_type string) bool {
	return v_type.len > 0 && v_type[0].is_capital() && v_type !in ['Any', 'LiteralString', 'Self']
}
