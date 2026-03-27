module classes

import ast

pub struct FieldDefInfo {
pub mut:
	name       string
	orig_name  string
	def        string
	is_mutated bool
	is_readonly bool
}

pub struct ClassFieldsHandler {}

fn (h ClassFieldsHandler) should_strip_init(_ string, default_val string) bool {
	if default_val.len == 0 { return false }
	if default_val == 'none' || default_val.contains('Any(NoneType{})') || default_val.contains('unsafe { nil }') {
		return true
	}
	return false
}

fn (h ClassFieldsHandler) is_field_mutated(struct_name string, field_name string, orig_name string, env &ClassVisitEnv) bool {
	base_struct_name := struct_name.replace('_Impl', '')
	mut candidates := [field_name]
	if orig_name.len > 0 && orig_name != field_name {
		candidates << orig_name
	}
	for name in candidates {
		qualified := '${base_struct_name}.${name}'
		if m_info := env.analyzer.mutability_map[qualified] {
			if m_info.is_mutated { return true }
		}
		if m_info := env.analyzer.mutability_map[name] {
			if m_info.is_mutated { return true }
		}
	}
	return false
}

fn (h ClassFieldsHandler) get_field_def_info(name string, field_type string, struct_name string, default_val string, orig_name string, mut env ClassVisitEnv) FieldDefInfo {
	is_mutated := h.is_field_mutated(struct_name, name, orig_name, &env)
	mut def := '    ${name} ${field_type}'
	if default_val.len > 0 && !h.should_strip_init(field_type, default_val) {
		def += ' = ${default_val}'
	}
	return FieldDefInfo{
		name:       name
		orig_name:  if orig_name.len > 0 { orig_name } else { name }
		def:        def
		is_mutated: is_mutated
	}
}

fn (h ClassFieldsHandler) collect_mixin_fields(struct_name string, mut added_fields map[string]bool, is_main_struct bool, mut env ClassVisitEnv) []FieldDefInfo {
	mut fields := []FieldDefInfo{}
	if !is_main_struct { return fields }

	mixin_names := env.analyzer.main_to_mixins[struct_name] or { []string{} }
	for mixin_name in mixin_names {
		// In V, we check mixin_nodes if they are preserved as strings or nodes
		// For now, use collected class_vars if available
		vars := env.state.class_vars[mixin_name] or { []map[string]string{} }
		for v in vars {
			name := v['name']
			if name.len == 0 || name in added_fields { continue }
			added_fields[name] = true
			fields << h.get_field_def_info(name, v['type'], struct_name, v['value'], name, mut env)
		}
	}
	return fields
}

fn (h ClassFieldsHandler) collect_init_fields(node ast.ClassDef, mut added_fields map[string]bool, struct_name string, mut env ClassVisitEnv) []FieldDefInfo {
	mut fields := []FieldDefInfo{}
	for stmt in node.body {
		if stmt is ast.FunctionDef && stmt.name == '__init__' {
			if stmt.args.args.len == 0 { continue }
			self_name := stmt.args.args[0].arg
			mut arg_type_map := map[string]string{}
			for arg in stmt.args.args[1..] {
				if ann := arg.annotation {
					arg_type_map[arg.arg] = map_python_type(env.visit_expr_fn(ann), struct_name, false, mut env)
				}
			}
			h.walk_init_body(stmt.body, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
		}
	}
	return fields
}

fn (h ClassFieldsHandler) walk_init_body(body []ast.Statement, self_name string, mut fields []FieldDefInfo, mut added_fields map[string]bool, struct_name string, arg_type_map map[string]string, mut env ClassVisitEnv) {
	for stmt in body {
		match stmt {
			ast.Assign {
				for target in stmt.targets {
					h.walk_init_expr(target, self_name, stmt.value, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
				}
			}
			ast.AnnAssign {
				h.walk_init_expr(stmt.target, self_name, stmt.value, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
			}
			ast.If {
				h.walk_init_body(stmt.body, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
				h.walk_init_body(stmt.orelse, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
			}
			ast.For {
				h.walk_init_body(stmt.body, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
				h.walk_init_body(stmt.orelse, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
			}
			ast.While {
				h.walk_init_body(stmt.body, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
				h.walk_init_body(stmt.orelse, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
			}
			ast.With {
				h.walk_init_body(stmt.body, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
			}
			ast.Try {
				h.walk_init_body(stmt.body, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
				for handler in stmt.handlers { h.walk_init_body(handler.body, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env) }
				h.walk_init_body(stmt.orelse, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
				h.walk_init_body(stmt.finalbody, self_name, mut fields, mut added_fields, struct_name, arg_type_map, mut env)
			}
			else {}
		}
	}
}

fn (h ClassFieldsHandler) walk_init_expr(target ast.Expression, self_name string, value_expr ?ast.Expression, mut fields []FieldDefInfo, mut added_fields map[string]bool, struct_name string, arg_type_map map[string]string, mut env ClassVisitEnv) {
	if target is ast.Attribute {
		if target.value is ast.Name && target.value.id == self_name {
			orig_name := target.attr
			field_name := sanitize_name(orig_name, false)
			if field_name in added_fields { return }
			added_fields[field_name] = true

			mut f_type := 'Any'
			if val := value_expr {
				if val is ast.Name && val.id in arg_type_map {
					f_type = arg_type_map[val.id]
				} else {
					f_type = guess_type(val, &env)
				}
				if val is ast.Constant && val.value == 'None' {
					if !f_type.starts_with('?') && f_type != 'Any' { f_type = '?${f_type}' }
				}
			}
			fields << h.get_field_def_info(field_name, map_python_type(f_type, struct_name, false, mut env), struct_name, '', orig_name, mut env)
		}
	} else if target is ast.Tuple {
		for elt in target.elements { h.walk_init_expr(elt, self_name, none, mut fields, mut added_fields, struct_name, arg_type_map, mut env) }
	} else if target is ast.List {
		for elt in target.elements { h.walk_init_expr(elt, self_name, none, mut fields, mut added_fields, struct_name, arg_type_map, mut env) }
	}
}

fn (h ClassFieldsHandler) process_class_attributes(body []ast.Statement, struct_name string, mut added_fields map[string]bool, is_dataclass bool, is_typed_dict bool, dataclass_m map[string]string, mut d_field_order []string, mut env ClassVisitEnv) []FieldDefInfo {
	mut fields := []FieldDefInfo{}
	
	for stmt in body {
		if stmt is ast.AnnAssign {
			if stmt.target is ast.Name {
				orig_name := stmt.target.id
				field_name := sanitize_name(orig_name, false)
				if field_name in added_fields { continue }
	
				// If dataclass handles it later, skip
				if is_dataclass && dataclass_m.len > 0 { continue }
				
				added_fields[field_name] = true
				raw_type := env.visit_expr_fn(stmt.annotation)
				field_type := map_python_type(raw_type, struct_name, false, mut env)
				
				if is_dataclass || is_typed_dict { d_field_order << field_name }
	
				is_class_var := raw_type.contains('ClassVar[') || raw_type.starts_with('ClassVar')
				is_readonly := raw_type.contains('ReadOnly[') || raw_type.starts_with('ReadOnly')
	
				default_val := if v := stmt.value { env.visit_expr_fn(v) } else { '' }
	
				if is_class_var {
					h.set_class_var(struct_name, field_name, field_type, if default_val.len > 0 { default_val } else { 'none' }, mut env)
				} else {
					mut info := h.get_field_def_info(field_name, field_type, struct_name, default_val, orig_name, mut env)
					info.is_readonly = is_readonly
					fields << info
				}
			}
		} else if stmt is ast.Assign {
			for target in stmt.targets {
				if target is ast.Name {
					orig_name := target.id
					field_name := sanitize_name(orig_name, false)

					if orig_name == '__slots__' {
						h.parse_slots(stmt.value, mut fields, mut added_fields, struct_name, mut env)
						continue
					}
					
					if field_name in added_fields { continue }
					added_fields[field_name] = true
					if is_dataclass { d_field_order << field_name }

					field_type := map_python_type(guess_type(stmt.value, &env), struct_name, false, mut env)
					default_val := env.visit_expr_fn(stmt.value)
					h.set_class_var(struct_name, field_name, field_type, default_val, mut env)
				}
			}
		}
	}
	return fields
}

fn (h ClassFieldsHandler) parse_slots(value ast.Expression, mut fields []FieldDefInfo, mut added_fields map[string]bool, struct_name string, mut env ClassVisitEnv) {
	mut slots := []string{}
	match value {
		ast.List { for elt in value.elements { if elt is ast.Constant { slots << elt.value.trim("'\"") } } }
		ast.Tuple { for elt in value.elements { if elt is ast.Constant { slots << elt.value.trim("'\"") } } }
		ast.Constant { slots << value.value.trim("'\"") }
		else {}
	}
	for slot in slots {
		f_name := sanitize_name(slot, false)
		if f_name in added_fields { continue }
		added_fields[f_name] = true
		fields << h.get_field_def_info(f_name, 'Any', struct_name, '', slot, mut env)
	}
}

fn (h ClassFieldsHandler) set_class_var(struct_name string, name string, field_type string, value string, mut env ClassVisitEnv) {
	mut class_vars := env.state.class_vars[struct_name] or { []map[string]string{} }
	class_vars << {
		'name':  name
		'type':  field_type
		'value': if value.len > 0 { value } else { 'none' }
	}
	env.state.class_vars[struct_name] = class_vars
}

fn (h ClassFieldsHandler) process_dataclass_fields(body []ast.Statement, struct_name string, dataclass_metadata map[string]string, mut added_fields map[string]bool, mut d_field_order []string, mut env ClassVisitEnv) []FieldDefInfo {
	if dataclass_metadata.len == 0 { return []FieldDefInfo{} }
	mut fields := []FieldDefInfo{}
	
	// dataclass_metadata in V is currently map[string]string, we need to parse it or pass structured data
	// For now, it might contain a comma-separated list of attributes or something
	// But let's assume it should follow the Python logic if possible
	return fields
}

fn (h ClassFieldsHandler) generate_dataclass_factory(struct_name string, dataclass_m map[string]string, body []ast.Statement, has_post_init bool, mut env ClassVisitEnv) ?string {
	if !has_post_init { return none }
	factory_name := get_factory_name(struct_name, &env)
	
	mut factory_args := []string{}
	mut struct_init := []string{}
	mut post_init_args := []string{}
	
	// Dataclass attributes are usually in node body
	for stmt in body {
		if stmt is ast.AnnAssign {
			if stmt.target is ast.Name {
				name := sanitize_name(stmt.target.id, false)
				raw_type := env.visit_expr_fn(stmt.annotation)
				f_type := map_python_type(raw_type, struct_name, false, mut env)
				
				mut default_expr := ''
				if val := stmt.value {
					default_expr = ' = ' + env.visit_expr_fn(val)
				}
				
				factory_args << '${name} ${f_type}${default_expr}'
				struct_init << '${name}: ${name}'
				post_init_args << name
			}
		}
	}
	
	prefix := if env.state.is_exported(struct_name) { 'pub ' } else { '' }
	generics := get_generics_with_variance_str(&env)
	
	mut code := []string{}
	code << '${prefix}fn ${factory_name}${generics}(${factory_args.join(", ")}) &${struct_name}${generics} {'
	code << '    mut self := &${struct_name}${generics}{${struct_init.join(", ")}}'
	code << '    self.post_init(${post_init_args.join(", ")})'
	code << '    return self'
	code << '}'
	
	return code.join('\n')
}

fn (h ClassFieldsHandler) get_namedtuple_metadata(node ast.ClassDef, struct_name string, env &ClassVisitEnv) ?map[string]string {
	for key, sig in env.analyzer.call_signatures {
		if sig.namedtuple_metadata.len == 0 { continue }
		if key.starts_with('${node.name}@') || key.starts_with('${struct_name}@') { return sig.namedtuple_metadata }
	}
	return none
}

fn (h ClassFieldsHandler) get_dataclass_metadata(node ast.ClassDef, struct_name string, env &ClassVisitEnv) ?map[string]string {
	for key, sig in env.analyzer.call_signatures {
		if sig.dataclass_metadata.len == 0 { continue }
		if key.starts_with('${node.name}@') || key.starts_with('${struct_name}@') { return sig.dataclass_metadata }
	}
	return none
}

fn (h ClassFieldsHandler) process_namedtuple_fields(struct_name string, nt_metadata map[string]string, mut added_fields map[string]bool, mut env ClassVisitEnv) []FieldDefInfo {
	mut fields := []FieldDefInfo{}
	// NT metadata parsing logic here
	return fields
}

fn (h ClassFieldsHandler) build_visibility_blocks(fields []FieldDefInfo, mut output []string, is_typed_dict bool) {
	mut pub_fields := []string{}
	mut pub_mut_fields := []string{}
	mut priv_fields := []string{}
	mut priv_mut_fields := []string{}

	for f in fields {
		is_private := f.orig_name.starts_with('_')
		if is_typed_dict {
			if f.is_readonly { pub_fields << f.def } else { pub_mut_fields << f.def }
		} else if is_private {
			if f.is_mutated { priv_mut_fields << f.def } else { priv_fields << f.def }
		} else {
			if f.is_readonly { pub_fields << f.def } else { pub_mut_fields << f.def }
		}
	}

	if priv_fields.len > 0 { for f in priv_fields { output << f } }
	if pub_fields.len > 0 { output << 'pub:'; for f in pub_fields { output << f } }
	if pub_mut_fields.len > 0 { output << 'pub mut:'; for f in pub_mut_fields { output << f } }
	if priv_mut_fields.len > 0 { output << 'mut:'; for f in priv_mut_fields { output << f } }
}

