module functions

import ast
import analyzer
import base

pub fn visit_function_def(
	node &ast.FunctionDef,
	mut state base.TranslatorState,
	analyzer_ref &analyzer.Analyzer,
	visit_fn fn (ast.Statement) string,
	visit_expr_fn fn (ast.Expression) string,
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
	is_empty_body_fn fn ([]ast.Statement) bool,
	get_v_default_value_fn fn (string, []string) string,
	find_captured_vars_fn fn (ast.ASTNode, []map[string]bool, fn (string, bool) string) []string,
	generate_function_for_struct_fn fn (
		&ast.FunctionDef,
		bool,
		bool,
		string,
		DecoratorInfo,
		bool,
		bool,
		bool,
		&base.TranslatorState,
		&analyzer.Analyzer,
		fn (ast.Statement) string,
		fn () string,
		fn (string),
		fn (string, bool) string,
		fn (string, string, bool, bool, bool) string,
		fn (string) string,
		fn (string) string,
		fn (string, string) string,
		fn (string) bool,
		fn (ast.Statement) string,
		fn (&ast.FunctionDef, map[string]bool, map[string]bool, []string, fn (string, bool) string) []string,
		fn ([]string, []map[string]string) map[string]string,
		fn (string, []string) string,
		fn ([]ast.Statement) bool,
		fn ([]map[string]string) []string,
		fn ([]string, map[string]string, map[string]string, map[string]string) string,
	),
	analyze_decorator_fn fn (ast.Expression, string) DecoratorInfo,
) {
	visit_function_common(
		node,
		mut state,
		analyzer_ref,
		visit_fn,
		visit_expr_fn,
		sanitize_fn,
		map_type_fn,
		get_full_self_type_fn,
		get_factory_name_fn,
		mangle_name_fn,
		is_exported_fn,
		get_source_info_fn,
		extract_implicit_generics_fn,
		get_generic_map_fn,
		get_all_active_v_generics_fn,
		get_generics_with_variance_str_fn,
		is_empty_body_fn,
		get_v_default_value_fn,
		find_captured_vars_fn,
		generate_function_for_struct_fn,
		analyze_decorator_fn,
	)
}

fn visit_function_common(
	node &ast.FunctionDef,
	mut state base.TranslatorState,
	analyzer_ref &analyzer.Analyzer,
	visit_fn fn (ast.Statement) string,
	visit_expr_fn fn (ast.Expression) string,
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
	is_empty_body_fn fn ([]ast.Statement) bool,
	get_v_default_value_fn fn (string, []string) string,
	find_captured_vars_fn fn (ast.ASTNode, []map[string]bool, fn (string, bool) string) []string,
	generate_function_for_struct_fn fn (
		&ast.FunctionDef,
		bool,
		bool,
		string,
		DecoratorInfo,
		bool,
		bool,
		bool,
		&base.TranslatorState,
		&analyzer.Analyzer,
		fn (ast.Statement) string,
		fn () string,
		fn (string),
		fn (string, bool) string,
		fn (string, string, bool, bool, bool) string,
		fn (string) string,
		fn (string) string,
		fn (string, string) string,
		fn (string) bool,
		fn (ast.Statement) string,
		fn (&ast.FunctionDef, map[string]bool, map[string]bool, []string, fn (string, bool) string) []string,
		fn ([]string, []map[string]string) map[string]string,
		fn (string, []string) string,
		fn ([]ast.Statement) bool,
		fn ([]map[string]string) []string,
		fn ([]string, map[string]string, map[string]string, map[string]string) string,
	),
	analyze_decorator_fn fn (ast.Expression, string) DecoratorInfo,
) {
	_ = extract_implicit_generics_fn
	_ = get_generic_map_fn
	_ = get_all_active_v_generics_fn
	_ = get_generics_with_variance_str_fn
	_ = is_empty_body_fn
	_ = get_v_default_value_fn
	_ = find_captured_vars_fn
	_ = generate_function_for_struct_fn

	state.name_remap = map[string]string{}

	mut is_overload := false
	mut is_singledispatch := false
	mut is_abstract := false
	mut is_static := false
	mut is_classmethod := false
	mut is_setter := false
	mut is_deprecated := false
	mut deprecated_message := ''

	for decorator in node.decorator_list {
		if decorator is ast.Name {
			if decorator.id == 'overload' {
				is_overload = true
			} else if decorator.id == 'singledispatch' {
				is_singledispatch = true
			} else if decorator.id == 'abstractmethod' {
				is_abstract = true
			} else if decorator.id == 'staticmethod' {
				is_static = true
			} else if decorator.id == 'classmethod' || decorator.id == 'abstractclassmethod' {
				is_classmethod = true
			} else if decorator.id == 'setter' {
				is_setter = true
			}
		} else if decorator is ast.Attribute {
			if decorator.attr == 'overload' {
				is_overload = true
			} else if decorator.attr == 'singledispatch' {
				is_singledispatch = true
			} else if decorator.attr == 'abstractmethod' {
				is_abstract = true
			} else if decorator.attr == 'staticmethod' {
				is_static = true
			} else if decorator.attr == 'classmethod' || decorator.attr == 'abstractclassmethod' {
				is_classmethod = true
			} else if decorator.attr == 'setter' {
				is_setter = true
			}
		} else if decorator is ast.Call {
			dec_call := decorator
			if dec_call.func is ast.Attribute && dec_call.func.attr == 'deprecated' {
				is_deprecated = true
				if dec_call.args.len > 0 {
					deprecated_message = dec_call.args[0].str().trim_left("'\"").trim_right("'\"")
				}
			}
		}
	}

	if is_overload {
		ov_key := if state.current_class.len > 0 {
			'${state.current_class}.${node.name}'
		} else {
			node.name
		}
		mut sig := map[string]string{}
		mut sig_args := []string{}
		mut all_args := node.args.posonlyargs.clone()
		all_args << node.args.args
		all_args << node.args.kwonlyargs
		if state.current_class.len > 0 && all_args.len > 0 && (all_args[0].arg == 'self' || all_args[0].arg == 'cls') {
			all_args = all_args[1..].clone()
		}
		for arg in all_args {
			arg_name := sanitize_fn(arg.arg, false)
			arg_type := if arg.annotation != none { 'Any' } else { analyzer_ref.type_map[arg_name] or { 'int' } }
			sig_args << '${arg_name}:${arg_type}'
		}
		sig['args'] = sig_args.join(',')
		sig['return'] = if node.returns != none { 'Any' } else { 'void' }
		if ov_key !in state.overloaded_signatures {
			state.overloaded_signatures[ov_key] = []map[string]string{}
		}
		state.overloaded_signatures[ov_key] << sig
		return
	}

	if is_singledispatch {
		base_impl_name := '${node.name}_base'
		state.renamed_functions[node.name] = base_impl_name
		if node.name !in state.single_dispatch_functions {
			state.single_dispatch_functions[node.name] = map[string]string{}
		}
		state.single_dispatch_functions[node.name]['default'] = base_impl_name
	}

	mut func_name := sanitize_fn(node.name, false)
	mut receiver_str := ''
	mut args := node.args.posonlyargs.clone()
	args << node.args.args
	args << node.args.kwonlyargs

	if state.current_class.len > 0 && args.len > 0 && (args[0].arg == 'self' || args[0].arg == 'cls')
		&& !is_static && !is_classmethod {
		if args[0].arg == 'self' {
			mut_prefix := if is_setter { 'mut ' } else { '' }
			generics := if state.current_class_generics.len > 0 {
				'[${state.current_class_generics.join(', ')}]'
			} else {
				''
			}
			receiver_str = '(${mut_prefix}${args[0].arg} ${state.current_class}${generics}) '
		} else {
			receiver_str = '(${args[0].arg} ${state.current_class}) '
		}
		args = args[1..].clone()
	}

	mut args_parts := []string{}
	for arg in args {
		arg_name := sanitize_fn(arg.arg, false)
		mut arg_type := analyzer_ref.type_map[arg_name] or { 'Any' }
		if arg.annotation != none {
			arg_type = 'Any'
		}
		args_parts << '${arg_name} ${map_type_fn(arg_type, state.current_class, true, true, false)}'
	}
	args_str := args_parts.join(', ')

	mut ret_type := 'void'
	if node.returns != none {
		ret_type = 'Any'
	}
	if node.name == '__init__' {
		ret_type = get_full_self_type_fn(state.current_class)
	}
	if node.name == '__new__' {
		func_name = get_factory_name_fn(state.current_class)
		ret_type = get_full_self_type_fn(state.current_class)
	}
	if is_deprecated {
		_ = deprecated_message
	}

	emit_fn := fn (line string) {}
	_ = emit_fn
	_ = get_source_info_fn
	_ = mangle_name_fn
	_ = is_exported_fn
	_ = analyze_decorator_fn

	state.output << 'fn ${receiver_str}${func_name}(${args_str}) ${ret_type} {'
	state.indent_level++
	for stmt in node.body {
		if stmt is ast.Expr {
			expr_stmt := stmt
			if expr_stmt.value is ast.Constant {
				if expr_stmt.value.value.len > 0 {
					state.output << '${state.indent()}// ${expr_stmt.value.value}'
					continue
				}
			}
		}
		state.output << '${state.indent()}${visit_fn(stmt)}'
	}
	if node.body.len == 0 && ret_type != 'void' {
		state.output << '${state.indent()}return ${get_v_default_value_fn(ret_type, []string{})}'
	}
	state.indent_level--
	state.output << '}'
}
