module classes

import ast
import base
import pydantic_support

pub struct ClassDefinitionHandler {
pub mut:
	class_stack []string
}

pub fn (mut h ClassDefinitionHandler) visit_class_def(node ast.ClassDef, mut env ClassVisitEnv, mut classes ClassesModule) {
	struct_name := sanitize_name(node.name, true)
	if h.class_stack.len == 0 {
		env.state.defined_top_level_symbols[node.name] = true
	}

	classes.pydantic_handler.mark_pydantic_model(node, struct_name, mut env)

	h.class_stack << struct_name
	env.state.scope_names << node.name
	prev_class := env.state.current_class
	prev_generics := env.state.current_class_generics.clone()
	prev_generic_map := env.state.current_class_generic_map.clone()
	prev_bases := env.state.current_class_bases.clone()
	prev_generic_bases := env.state.current_class_generic_bases.clone()
	prev_is_unittest := env.state.current_class_is_unittest
	prev_body := env.state.current_class_body.clone()

	env.state.current_class = struct_name
	env.state.current_class_body = node.body.clone()
	env.state.current_class_generics = []string{}
	env.state.current_class_generic_map = map[string]string{}
	env.state.current_class_bases = []string{}
	env.state.current_class_generic_bases = map[string]string{}
	env.state.current_class_is_unittest = false

	if classes.pydantic_handler.is_pydantic_model(node) {
		mut p_env := pydantic_support.new_pydantic_visit_env(
			env.state,
			env.analyzer,
			env.visit_stmt_fn,
			env.visit_expr_fn,
			env.emit_struct_fn,
			env.emit_function_fn,
			env.emit_constant_fn,
			env.source_mapping,
		)
		processor := pydantic_support.new_pydantic_model_processor()
		processor.process_model(node, mut p_env)
		env.state.defined_classes[struct_name]['is_pydantic'] = true
		return
	}

	decorators_raw, is_dataclass, is_deprecated, is_disjoint_base, deprecated_message := classes.class_decorator_handler.process_decorators(node, mut env)
	mut decorators := decorators_raw.clone()
	metaclass_decorators := classes.class_decorator_handler.process_metaclass(node, mut env)
	decorators << metaclass_decorators

	dataclass_metadata := if is_dataclass {
		classes.class_fields_handler.get_dataclass_metadata(node, struct_name, &env) or { map[string]string{} }
	} else {
		map[string]string{}
	}

	is_mixin := struct_name in env.analyzer.mixin_to_main
	is_main_struct := struct_name in env.analyzer.main_to_mixins

	mut fields := []string{}
	mut dataclass_field_order := []string{}
	mut added_fields := map[string]bool{}

	if is_main_struct {
		mixin_fields := classes.class_fields_handler.collect_mixin_fields(struct_name, mut added_fields,
			is_main_struct, mut env)
		fields << mixin_fields
	}

	base_fields, current_class_bases, is_enum, is_int_enum, is_flag, is_unittest, is_protocol, _, is_typed_dict := classes.class_bases_handler.process_bases(node, struct_name, mut env)
	env.state.current_class_bases = current_class_bases
	fields << base_fields

	is_abc := classes.class_bases_handler.is_abstract_base_class(node, struct_name, &env)
	if is_abc {
		env.state.known_interfaces[struct_name] = true
	}

	if is_typed_dict {
		env.state.readonly_fields[struct_name] = map[string]bool{}
	}

	doc_comment, remaining_body := classes.special_classes_handler.extract_docstring(node.body)
	mut body := remaining_body.clone()
	mut methods := []ast.FunctionDef{}
	mut filtered_body := []ast.Statement{}
	for stmt in body {
		if stmt is ast.FunctionDef {
			methods << stmt
		} else if stmt is ast.ClassDef {
			env.visit_stmt_fn(stmt)
		} else {
			filtered_body << stmt
		}
	}
	body = filtered_body.clone()

	mut has_post_init := false
	for method in methods {
		if method.name == '__post_init__' {
			has_post_init = true
			break
		}
	}

	if is_dataclass && dataclass_metadata.len > 0 {
		dc_fields, updated_added_fields, updated_dataclass_field_order := classes.class_fields_handler.process_dataclass_fields(
			body, struct_name, dataclass_metadata, mut added_fields, mut dataclass_field_order, mut env)
		fields << dc_fields
		_ = updated_added_fields
		_ = updated_dataclass_field_order
	}

	class_fields, updated_added_fields, updated_dataclass_field_order := classes.class_fields_handler.process_class_attributes(body, struct_name,
		mut added_fields, is_dataclass, is_typed_dict, map[string]string{}, mut dataclass_field_order, mut env)
	fields << class_fields
	_ = updated_added_fields
	_ = updated_dataclass_field_order

	namedtuple_metadata := if !is_dataclass {
		classes.class_fields_handler.get_namedtuple_metadata(node, struct_name, &env) or { map[string]string{} }
	} else {
		map[string]string{}
	}
	if namedtuple_metadata.len > 0 {
		nt_fields, updated_added_fields2 := classes.class_fields_handler.process_namedtuple_fields(
			struct_name, namedtuple_metadata, mut added_fields, mut env)
		fields << nt_fields
		_ = updated_added_fields2
	}

	if is_unittest {
		env.state.current_class_is_unittest = true
		for method in methods {
			env.visit_stmt_fn(method)
		}
	} else if is_protocol {
		generics_str := get_generics_with_variance_str(&env)
		is_exported := env.state.is_exported(node.name)
		interface_def := classes.special_classes_handler.generate_interface_definition(struct_name,
			methods, doc_comment, decorators, generics_str, is_exported, env.source_mapping, node,
			fields, mut env)
		env.emit_struct_fn(interface_def)
		if !node.name.ends_with('Mixin') && node.name in env.state.class_hierarchy {
			impl_name := '${struct_name}_Impl'
			env.state.current_class = impl_name
			env.state.class_to_impl[struct_name] = impl_name
			mut impl_parts := []string{}
			if doc_comment.len > 0 {
				impl_parts << doc_comment.trim_right('\n')
			}
			impl_parts << '@[heap]'
			impl_parts << 'pub struct ${impl_name}${generics_str} {'
			if fields.len > 0 {
				impl_parts << fields.join('\n')
			}
			impl_parts << '}'
			env.emit_struct_fn(impl_parts.join('\n'))
		}
		for method in methods {
			env.visit_stmt_fn(method)
		}
	} else if is_mixin {
		for method in methods {
			env.visit_stmt_fn(method)
		}
	} else if is_enum || is_int_enum || is_flag {
		enum_fields := classes.special_classes_handler.process_enum_body(node, is_flag, mut env)
		is_exported := env.state.is_exported(node.name)
		env.emit_struct_fn(classes.special_classes_handler.generate_enum_definition(struct_name,
			enum_fields, is_flag, is_int_enum, is_exported))
	} else {
		mut struct_name_for_body := struct_name
		if node.name in env.state.class_hierarchy && !node.name.ends_with('Mixin') {
			struct_name_for_body = '${struct_name}_Impl'
			env.state.current_class = struct_name_for_body
			env.state.class_to_impl[struct_name] = struct_name_for_body
			generics_str := get_generics_with_variance_str(&env)
			is_exported := env.state.is_exported(node.name)
			interface_def := classes.special_classes_handler.generate_interface_definition(struct_name,
				methods, doc_comment, decorators, generics_str, is_exported, env.source_mapping,
				node, fields, mut env)
			env.emit_struct_fn(interface_def)
		}

		generics_str := get_generics_with_variance_str(&env)
		pub_prefix := if env.state.is_exported(node.name) { 'pub ' } else { '' }
		mut struct_parts := []string{}
		if doc_comment.len > 0 {
			struct_parts << doc_comment.trim_right('\n')
		}
		if env.source_mapping {
			_ = node
		}
		if is_deprecated {
			if deprecated_message.len > 0 {
				struct_parts << '@[deprecated: \'${deprecated_message}\']'
			} else {
				struct_parts << '@[deprecated]'
			}
		}
		if is_disjoint_base {
			struct_parts << '@[disjoint_base]'
		}
		if decorators.len > 0 {
			struct_parts << decorators.join('\n')
		}
		struct_parts << '@[heap]'
		struct_parts << '${pub_prefix}struct ${struct_name_for_body}${generics_str} {'
		if fields.len > 0 {
			struct_parts << fields.join('\n')
		}
		struct_parts << '}'
		env.emit_struct_fn(struct_parts.join('\n'))

		class_vars := env.state.class_vars[struct_name] or { []map[string]string{} }
		if class_vars.len > 0 {
			meta_struct_name := '${struct_name}Meta'
			mut meta_parts := []string{}
			meta_parts << 'pub struct ${meta_struct_name} {'
			meta_parts << 'pub mut:'
			for cvar in class_vars {
				meta_parts << '    ${cvar["name"]} ${cvar["type"]} = ${cvar["value"]}'
			}
			meta_parts << '}'
			env.emit_struct_fn(meta_parts.join('\n'))
			meta_const_name := '${base.to_snake_case(struct_name)}_meta'
			env.emit_constant_fn('pub ${meta_const_name} = &${meta_struct_name}{}')
		}
		if is_dataclass && has_post_init {
			if factory_code := classes.class_fields_handler.generate_dataclass_factory(
				struct_name, dataclass_metadata, body, has_post_init, env) {
				env.emit_function_fn(factory_code)
			}
		}
		has_str := classes.class_methods_handler.has_method(methods, '__str__')
		classes.class_methods_handler.rename_dunder_methods(mut methods, has_str)
		for method in methods {
			env.visit_stmt_fn(method)
		}
	}

	defer {
		if h.class_stack.len > 0 {
			h.class_stack = h.class_stack[..h.class_stack.len - 1]
		}
		if env.state.scope_names.len > 0 {
			env.state.scope_names = env.state.scope_names[..env.state.scope_names.len - 1]
		}
		env.state.current_class = prev_class
		env.state.current_class_generics = prev_generics
		env.state.current_class_generic_map = prev_generic_map.clone()
		env.state.current_class_bases = prev_bases
		env.state.current_class_generic_bases = prev_generic_bases.clone()
		env.state.current_class_is_unittest = prev_is_unittest
		env.state.current_class_body = prev_body
		classes.class_methods_handler.register_class_info(prev_class, false, false, []string{}, []string{}, false,
			mut env)
	}
}
