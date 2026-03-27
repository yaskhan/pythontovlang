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
	env.state.defined_classes[struct_name] = map[string]bool{}
	env.state.defined_classes[node.name] = map[string]bool{}

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

	mut fields := []FieldDefInfo{}
	mut dataclass_field_order := []string{}
	mut added_fields := map[string]bool{}

	if is_main_struct {
		mixin_fields := classes.class_fields_handler.collect_mixin_fields(struct_name, mut added_fields,
			is_main_struct, mut env)
		for f in mixin_fields { fields << f }
	}

	base_fields, current_class_bases, is_enum, is_int_enum, is_flag, is_unittest, is_protocol, _, is_typed_dict := classes.class_bases_handler.process_bases(node, struct_name, mut env)
	env.state.current_class_bases = current_class_bases
	for f in base_fields { fields << f }

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
		dc_fields := classes.class_fields_handler.process_dataclass_fields(
			body, struct_name, dataclass_metadata, mut added_fields, mut dataclass_field_order, mut env)
		for f in dc_fields { fields << f }
	}

	class_attr_fields := classes.class_fields_handler.process_class_attributes(body, struct_name,
		mut added_fields, is_dataclass, is_typed_dict, dataclass_metadata, mut dataclass_field_order, mut env)
	for f in class_attr_fields { fields << f }

	namedtuple_metadata := if !is_dataclass {
		classes.class_fields_handler.get_namedtuple_metadata(node, struct_name, &env) or { map[string]string{} }
	} else {
		map[string]string{}
	}
	if namedtuple_metadata.len > 0 {
		nt_fields := classes.class_fields_handler.process_namedtuple_fields(
			struct_name, namedtuple_metadata, mut added_fields, mut env)
		for f in nt_fields { fields << f }
	}

	// For non-enums and non-unittests, we might have __init__ fields
	if !is_enum && !is_int_enum && !is_flag && !is_unittest {
		init_fields := classes.class_fields_handler.collect_init_fields(node, mut added_fields, struct_name, mut env)
		for f in init_fields { fields << f }
	}

	// Register dataclass/typeddict field order
	if is_dataclass || is_typed_dict {
		env.state.dataclasses[struct_name] = dataclass_field_order
	}

	if is_unittest {
		env.state.current_class_is_unittest = true
	}

	if is_protocol {
		generics_str := get_generics_with_variance_str(&env)
		is_exported := env.state.is_exported(node.name)
		
		mut interface_fields_str := []string{}
		classes.class_fields_handler.build_visibility_blocks(fields, mut interface_fields_str, is_typed_dict)
		
		interface_def := classes.special_classes_handler.generate_interface_definition(struct_name,
			methods, doc_comment, decorators, generics_str, is_exported, env.source_mapping, node,
			interface_fields_str, mut env)
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
			if interface_fields_str.len > 0 {
				impl_parts << interface_fields_str.join('\n')
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
		mut struct_fields_str := []string{}
		classes.class_fields_handler.build_visibility_blocks(fields, mut struct_fields_str, is_typed_dict)

		mut is_base_for_others := false
		for _, bases in env.state.class_hierarchy {
			if node.name in bases {
				is_base_for_others = true
				break
			}
		}

		if (is_base_for_others || is_protocol || is_abc) && !node.name.ends_with('Mixin') {
			struct_name_for_body = '${struct_name}_Impl'
			env.state.current_class = struct_name_for_body
			env.state.class_to_impl[struct_name] = struct_name_for_body
			generics_str := get_generics_with_variance_str(&env)
			is_exported := env.state.is_exported(node.name)
			interface_def := classes.special_classes_handler.generate_interface_definition(struct_name,
				methods, doc_comment, decorators, generics_str, is_exported, env.source_mapping,
				node, struct_fields_str, mut env)
			env.emit_struct_fn(interface_def)
			env.state.known_interfaces[struct_name] = true
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
		if struct_fields_str.len > 0 {
			struct_parts << struct_fields_str.join('\n')
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
			env.emit_constant_fn('pub const ${meta_const_name} = &${meta_struct_name}{}')
		}

		// Generate factory function new_X for simple struct if it has __init__
		if struct_name_for_body == struct_name && !is_enum && !is_flag {
			mut init_method_opt := ?ast.FunctionDef(none)
			for m in methods {
				if m.name == '__init__' {
					init_method_opt = m
					break
				}
			}
			if init_method := init_method_opt {
				prefix := if env.state.is_exported(struct_name) { 'pub ' } else { '' }
				factory_name := get_factory_name(struct_name, &env)
				generics := get_generics_with_variance_str(&env)
				mut factory_args := []string{}
				mut struct_init := []string{}
				mut call_args := []string{}
				
				start_idx := if init_method.args.args.len > 0 && init_method.args.args[0].arg in ['self', 'cls'] { 1 } else { 0 }
				for i := start_idx; i < init_method.args.args.len; i++ {
					arg := init_method.args.args[i]
					name := sanitize_name(arg.arg, false)
					mut a_type := 'Any'
					if ann := arg.annotation {
						a_type = map_python_type(env.visit_expr_fn(ann), struct_name, false, mut env)
					}
					factory_args << '${name} ${a_type}'
					struct_init << '${name}: ${name}'
					call_args << name
				}
				
				mut f_code := []string{}
				f_code << '${prefix}fn ${factory_name}${generics}(${factory_args.join(", ")}) &${struct_name}${generics} {'
				f_code << '    mut self := &${struct_name}${generics}{}'
				f_code << '    self.init(${call_args.join(", ")})'
				f_code << '    return self'
				f_code << '}'
				env.emit_function_fn(f_code.join('\n'))
			}
		}

		if is_dataclass && has_post_init {
			if factory_code := classes.class_fields_handler.generate_dataclass_factory(
				struct_name, dataclass_metadata, body, has_post_init, mut env) {
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
