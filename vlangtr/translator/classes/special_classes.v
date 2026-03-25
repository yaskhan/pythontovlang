module classes

import ast

pub struct SpecialClassesHandler {}

pub fn (h SpecialClassesHandler) process_enum_body(node ast.ClassDef, is_flag bool, mut env ClassVisitEnv) []string {
	_ = h
	_ = node
	_ = is_flag
	_ = env
	return []string{}
}

pub fn (h SpecialClassesHandler) generate_enum_definition(
	struct_name string,
	enum_fields []string,
	is_flag bool,
	is_int_enum bool,
	is_exported bool,
) string {
	_ = is_flag
	_ = is_int_enum
	pub_prefix := if is_exported { 'pub ' } else { '' }
	mut parts := []string{}
	parts << '${pub_prefix}enum ${struct_name} {'
	if enum_fields.len > 0 {
		parts << enum_fields.join('\n')
	}
	parts << '}'
	return parts.join('\n')
}

pub fn (h SpecialClassesHandler) generate_interface_definition(
	struct_name string,
	methods []ast.FunctionDef,
	doc_comment string,
	decorators []string,
	generics_str string,
	is_exported bool,
	source_mapping bool,
	node ast.ClassDef,
	fields []string,
	mut env ClassVisitEnv,
) string {
	_ = h
	_ = methods
	_ = doc_comment
	_ = decorators
	_ = generics_str
	_ = is_exported
	_ = source_mapping
	_ = node
	_ = fields
	_ = env
	return 'pub interface ${struct_name} {\n}'
}

pub fn (h SpecialClassesHandler) extract_docstring(body []ast.Statement) (string, []ast.Statement) {
	_ = h
	return '', body.clone()
}
