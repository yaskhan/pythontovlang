module classes

import ast

pub struct ClassFieldsHandler {}

fn (h ClassFieldsHandler) should_strip_init(field_type string, default_val string) bool {
	if default_val.len == 0 {
		return false
	}
	if default_val == 'none' {
		return true
	}
	if default_val.contains('Any(NoneType{})') {
		return true
	}
	if default_val.contains('unsafe { nil }') {
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

pub fn (h ClassFieldsHandler) collect_mixin_fields(
	_ string,
	added_fields map[string]bool,
	_ bool,
	_env ClassVisitEnv,
) []string {
	_ = added_fields
	return []string{}
}

pub fn (h ClassFieldsHandler) collect_init_fields(
	node ast.ClassDef,
	added_fields map[string]bool,
	struct_name string,
	mut env ClassVisitEnv,
) ([]string, map[string]bool) {
	_ = node
	_ = added_fields
	_ = struct_name
	_ = env
	return []string{}, added_fields.clone()
}

pub fn (h ClassFieldsHandler) process_class_attributes(
	body []ast.Statement,
	struct_name string,
	added_fields map[string]bool,
	_ bool,
	_ bool,
	_ map[string]string,
	dataclass_field_order []string,
	mut env ClassVisitEnv,
) ([]string, map[string]bool, []string) {
	_ = body
	_ = struct_name
	_ = added_fields
	_ = dataclass_field_order
	_ = env
	return []string{}, added_fields.clone(), dataclass_field_order.clone()
}

pub fn (h ClassFieldsHandler) process_dataclass_fields(
	_ []ast.Statement,
	_ string,
	_ map[string]string,
	added_fields map[string]bool,
	dataclass_field_order []string,
	_ ClassVisitEnv,
) ([]string, map[string]bool, []string) {
	return []string{}, added_fields, dataclass_field_order
}

pub fn (h ClassFieldsHandler) generate_dataclass_factory(
	_ string,
	_ map[string]string,
	_ []ast.Statement,
	has_post_init bool,
	_ ClassVisitEnv,
) ?string {
	if has_post_init {
		return none
	}
	return none
}

pub fn (h ClassFieldsHandler) get_namedtuple_metadata(
	_ ast.ClassDef,
	_ string,
	_ &ClassVisitEnv,
) ?map[string]string {
	return none
}

pub fn (h ClassFieldsHandler) get_dataclass_metadata(
	_ ast.ClassDef,
	_ string,
	_ &ClassVisitEnv,
) ?map[string]string {
	return none
}

pub fn (h ClassFieldsHandler) process_namedtuple_fields(
	_ string,
	_ map[string]string,
	added_fields map[string]bool,
	_ ClassVisitEnv,
) ([]string, map[string]bool) {
	return []string{}, added_fields
}
