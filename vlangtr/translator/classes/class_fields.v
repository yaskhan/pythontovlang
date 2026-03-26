module classes

import ast

pub struct ClassFieldsHandler {}

fn (h ClassFieldsHandler) should_strip_init(_ field_type string, default_val string) bool {
	if default_val.len == 0 {
		return false
	}
	if default_val == 'none' || default_val == 'Any(NoneType{})' || default_val == 'unsafe { nil }' {
		return true
	}
	return false
}

fn (h ClassFieldsHandler) get_field_def(name string, field_type string, default_val string) string {
	if default_val.len > 0 && !h.should_strip_init(field_type, default_val) {
		return '    ${name} ${field_type} = ${default_val}'
	}
	return '    ${name} ${field_type}'
}

fn (h ClassFieldsHandler) set_class_var(struct_name string, name string, field_type string, value string, mut env ClassVisitEnv) {
	mut class_vars := env.state.class_vars[struct_name] or { []map[string]string{} }
	class_vars << {
		'name':  name
		'type':  field_type
		'value': value.len > 0 ? value : 'none'
	}
	env.state.class_vars[struct_name] = class_vars
}

fn (h ClassFieldsHandler) is_class_var_annotation(annotation string) bool {
	return annotation.contains('ClassVar[') || annotation.starts_with('ClassVar') ||
		annotation.contains('typing.ClassVar[') || annotation.starts_with('typing.ClassVar')
}

fn (h ClassFieldsHandler) is_readonly_annotation(annotation string) bool {
	return annotation.contains('ReadOnly[') || annotation.starts_with('ReadOnly') ||
		annotation.contains('typing.ReadOnly[') || annotation.starts_with('typing.ReadOnly') ||
		annotation.contains('typing_extensions.ReadOnly[') || annotation.starts_with('typing_extensions.ReadOnly')
}

fn (h ClassFieldsHandler) infer_annotation_type(annotation ast.Expression, struct_name string, mut env ClassVisitEnv) string {
	return map_python_type(env.visit_expr_fn(annotation), struct_name, false, mut env)
}

fn (h ClassFieldsHandler) infer_default_type(expr ast.Expression, struct_name string, mut env ClassVisitEnv) string {
	mut field_type := guess_type(expr, &env)
	if field_type == 'Any' {
		field_type = map_python_type(env.visit_expr_fn(expr), struct_name, false, mut env)
	}
	return field_type
}

fn (h ClassFieldsHandler) is_field_mutated(struct_name string, field_name string, orig_name string, env &ClassVisitEnv) bool {
	base_struct_name := struct_name.replace('_Impl', '')
	mut candidates := []string{field_name}
	if orig_name.len > 0 && orig_name != field_name {
		candidates << orig_name
	}
	for name in candidates {
		qualified := '${base_struct_name}.${name}'
		if qualified in env.analyzer.mutability_map && env.analyzer.mutability_map[qualified].is_mutated {
			return true
		}
		if name in env.analyzer.mutability_map && env.analyzer.mutability_map[name].is_mutated {
			return true
		}
	}
	return false
}

fn (h ClassFieldsHandler) collect_mixin_fields(
	struct_name string,
	mut added_fields map[string]bool,
	is_main_struct bool,
	mut env ClassVisitEnv,
) []string {
	if !is_main_struct {
		return []string{}
	}

	mut fields := []string{}
	mixin_names := env.analyzer.main_to_mixins[struct_name] or { []string{} }
	for mixin_name in mixin_names {
		mut mixin_fields := env.state.class_vars[mixin_name] or { []map[string]string{} }
		for cvar in mixin_fields {
			name := cvar['name']
			if name.len == 0 || name in added_fields {
				continue
			}
			added_fields[name] = true
			fields << h.get_field_def(name, cvar['type'], cvar['value'])
		}
	}
	return fields
}

fn (h ClassFieldsHandler) collect_init_fields(
	node ast.ClassDef,
	mut added_fields map[string]bool,
	struct_name string,
	mut env ClassVisitEnv,
) ([]string, map[string]bool) {
	mut fields := []string{}
	for stmt in node.body {
		if stmt is ast.FunctionDef && stmt.name == '__init__' {
			for init_stmt in stmt.body {
				if init_stmt is ast.Assign {
					for target in init_stmt.targets {
						if target is ast.Attribute && target.value is ast.Name && target.value.id in ['self', 'cls'] {
							orig_name := target.attr
							field_name := sanitize_name(orig_name, false)
							if field_name in added_fields {
								continue
							}
							added_fields[field_name] = true
							mut field_type := h.infer_default_type(init_stmt.value, struct_name, mut env)
							if init_stmt.value is ast.Name && init_stmt.value.id in env.analyzer.type_map {
								field_type = map_python_type(env.analyzer.type_map[init_stmt.value.id], struct_name, false, mut env)
							}
							if field_type == 'Any' {
								field_type = guess_type(init_stmt.value, &env)
							}
							if field_type == 'Any' {
								field_type = 'Any'
							}
							if field_type != 'Any' {
								field_type = map_python_type(field_type, struct_name, false, mut env)
							}
							if init_stmt.value is ast.Constant && init_stmt.value.value == 'None' && !field_type.starts_with('?') && field_type != 'Any' {
								field_type = '?${field_type}'
							}
							fields << h.get_field_def(field_name, field_type, env.visit_expr_fn(init_stmt.value))
						}
					}
				} else if init_stmt is ast.AnnAssign {
					if init_stmt.target is ast.Attribute && init_stmt.target.value is ast.Name && init_stmt.target.value.id in ['self', 'cls'] {
						orig_name := init_stmt.target.attr
						field_name := sanitize_name(orig_name, false)
						if field_name in added_fields {
							continue
						}
						added_fields[field_name] = true
						annotation := env.visit_expr_fn(init_stmt.annotation)
						mut field_type := h.infer_annotation_type(init_stmt.annotation, struct_name, mut env)
						if field_type == 'Any' && annotation.len > 0 {
							field_type = map_python_type(annotation, struct_name, false, mut env)
						}
						if value := init_stmt.value {
							if value is ast.Constant && value.value == 'None' && !field_type.starts_with('?') && field_type != 'Any' {
								field_type = '?${field_type}'
							}
							fields << h.get_field_def(field_name, field_type, env.visit_expr_fn(value))
						} else {
							fields << h.get_field_def(field_name, field_type, '')
						}
					}
				}
			}
		}
	}
	return fields, added_fields
}

fn (h ClassFieldsHandler) process_class_attributes(
	body []ast.Statement,
	struct_name string,
	mut added_fields map[string]bool,
	is_dataclass bool,
	is_typed_dict bool,
	dataclass_metadata map[string]string,
	mut dataclass_field_order []string,
	mut env ClassVisitEnv,
) ([]string, map[string]bool, []string) {
	_ = dataclass_metadata
	mut fields := []string{}
	mut current_access := ''
	for stmt in body {
		if stmt is ast.AnnAssign && stmt.target is ast.Name {
			orig_name := stmt.target.id
			field_name := sanitize_name(orig_name, false)
			if field_name in added_fields {
				continue
			}
			annotation := env.visit_expr_fn(stmt.annotation)
			if h.is_class_var_annotation(annotation) {
				value := if v := stmt.value { env.visit_expr_fn(v) } else { 'none' }
				h.set_class_var(struct_name, field_name, map_python_type(annotation, struct_name, false, mut env), value, mut env)
				continue
			}
			added_fields[field_name] = true
			if is_dataclass || is_typed_dict {
				dataclass_field_order << field_name
			}
			mut field_type := map_python_type(annotation, struct_name, false, mut env)
			if field_type == 'Any' && stmt.annotation is ast.Name {
				field_type = map_python_type(stmt.annotation.id, struct_name, false, mut env)
			}
			if is_typed_dict {
				required_access := if h.is_readonly_annotation(annotation) { 'pub:' } else { 'pub mut:' }
				if current_access != required_access {
					fields << required_access
					current_access = required_access
				}
			}
			value := if v := stmt.value { env.visit_expr_fn(v) } else { '' }
			fields << h.get_field_def(field_name, field_type, value)
		} else if stmt is ast.Assign {
			for target in stmt.targets {
				if target is ast.Name {
					orig_name := target.id
					field_name := sanitize_name(orig_name, false)
					if field_name in added_fields {
						continue
					}
					added_fields[field_name] = true
					if is_dataclass {
						dataclass_field_order << field_name
					}
					if target.id == '__slots__' {
						continue
					}
					mut field_type := guess_type(stmt.value, &env)
					if field_type == 'Any' {
						field_type = 'Any'
					}
					if field_type != 'Any' {
						field_type = map_python_type(field_type, struct_name, false, mut env)
					}
					value := env.visit_expr_fn(stmt.value)
					fields << h.get_field_def(field_name, field_type, value)
				}
			}
		}
	}
	return fields, added_fields, dataclass_field_order
}

fn (h ClassFieldsHandler) process_dataclass_fields(
	body []ast.Statement,
	struct_name string,
	dataclass_metadata map[string]string,
	mut added_fields map[string]bool,
	mut dataclass_field_order []string,
	mut env ClassVisitEnv,
) ([]string, map[string]bool, []string) {
	_ = body
	_ = struct_name
	_ = added_fields
	_ = dataclass_field_order
	_ = env
	if dataclass_metadata.len == 0 {
		return []string{}, added_fields, dataclass_field_order
	}
	if 'attributes' !in dataclass_metadata {
		return []string{}, added_fields, dataclass_field_order
	}
	// The translated Python metadata shape is still incomplete in V, so we keep this
	// as a guarded hook instead of duplicating class attribute handling.
	return []string{}, added_fields, dataclass_field_order
}

fn (h ClassFieldsHandler) generate_dataclass_factory(
	struct_name string,
	dataclass_metadata map[string]string,
	_ []ast.Statement,
	has_post_init bool,
	_ ClassVisitEnv,
) ?string {
	_ = struct_name
	_ = has_post_init
	_ = dataclass_metadata
	return none
}

fn (h ClassFieldsHandler) get_namedtuple_metadata(
	node ast.ClassDef,
	struct_name string,
	env &ClassVisitEnv,
) ?map[string]string {
	for key, sig in env.analyzer.call_signatures {
		if sig.namedtuple_metadata.len == 0 {
			continue
		}
		if key.startswith('${node.name}@') || key.split('@')[0].ends_with('.${node.name}') || key.startswith('${struct_name}@') {
			return sig.namedtuple_metadata
		}
	}
	return none
}

fn (h ClassFieldsHandler) get_dataclass_metadata(
	node ast.ClassDef,
	struct_name string,
	env &ClassVisitEnv,
) ?map[string]string {
	for key, sig in env.analyzer.call_signatures {
		if sig.dataclass_metadata.len == 0 {
			continue
		}
		if key.startswith('${node.name}@') || key.split('@')[0].ends_with('.${node.name}') || key.startswith('${struct_name}@') {
			return sig.dataclass_metadata
		}
	}
	return none
}

fn (h ClassFieldsHandler) process_namedtuple_fields(
	struct_name string,
	nt_metadata map[string]string,
	mut added_fields map[string]bool,
	mut env ClassVisitEnv,
) ([]string, map[string]bool) {
	_ = struct_name
	_ = nt_metadata
	_ = env
	return []string{}, added_fields
}
