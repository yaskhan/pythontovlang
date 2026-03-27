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
	_ = decorators
	_ = source_mapping
	_ = node
	_ = fields
	
	pub_prefix := if is_exported { 'pub ' } else { '' }
	mut res := []string{}
	if doc_comment.len > 0 {
		res << doc_comment.trim_right('\n')
	}
	res << '${pub_prefix}interface ${struct_name}${generics_str} {'
	for method in methods {
		mut p_args := []string{}
		start_index := if method.args.args.len > 0 && method.args.args[0].arg in ['self', 'cls'] { 1 } else { 0 }
		for i := start_index; i < method.args.args.len; i++ {
			arg := method.args.args[i]
			mut ann_str := 'Any'
			if ann := arg.annotation {
				ann_str = map_python_type(env.visit_expr_fn(ann), struct_name, false, mut env)
			}
			p_args << '${arg.arg} ${ann_str}'
		}
		ret := if ann := method.returns { 
			r_type := map_python_type(env.visit_expr_fn(ann), struct_name, true, mut env)
			if is_v_class_type(r_type) && !r_type.starts_with('&') && !r_type.starts_with('[]') {
				' &' + r_type
			} else {
				' ' + r_type
			}
		} else { '' }
		res << '    ${method.name}(${p_args.join(', ')})${ret}'
	}
	res << '}'
	return res.join('\n')
}

pub fn (h SpecialClassesHandler) extract_docstring(body []ast.Statement) (string, []ast.Statement) {
	if body.len > 0 && body[0] is ast.Expr {
		stmt := body[0] as ast.Expr
		if stmt.value is ast.Constant {
			val := stmt.value.value.trim("'\"")
			return '/* ${val} */\n', body[1..].clone()
		}
	}
	return '', body.clone()
}
