module classes

import ast

pub struct ClassBasesHandler {}

pub fn (h ClassBasesHandler) is_enum_type(name string, env &ClassVisitEnv) (bool, bool, bool) {
	if name in ['Enum', 'IntEnum', 'Flag', 'IntFlag', 'enum.Enum', 'enum.IntEnum', 'enum.Flag', 'enum.IntFlag'] {
		is_flag := name.contains('Flag')
		is_int := name.contains('Int')
		return true, is_int, is_flag
	}
	// Check hierarchy
	if name in env.state.class_hierarchy {
		for parent in env.state.class_hierarchy[name] {
			is_enum, is_int, is_flag := h.is_enum_type(parent, env)
			if is_enum {
				return true, is_int, is_flag
			}
		}
	}
	return false, false, false
}

pub fn (h ClassBasesHandler) process_bases(node ast.ClassDef, struct_name string, mut env ClassVisitEnv) ([]FieldDefInfo, []string, bool, bool, bool, bool, bool, bool, bool) {
	mut fields := []FieldDefInfo{}
	mut current_class_bases := []string{}
	mut is_enum := false
	mut is_int_enum := false
	mut is_flag := false
	mut is_unittest := false
	mut is_protocol := false
	mut is_named_tuple := false
	mut is_typed_dict := false
	
	mut direct_bases := []string{}

	for base_expr in node.bases {
		mut b_name := ''
		if base_expr is ast.Name {
			b_name = base_expr.id
		} else if base_expr is ast.Attribute {
			b_name = base_expr.attr
		} else if base_expr is ast.Subscript {
			b_name = env.visit_expr_fn(base_expr.value)
		}
		
		is_e, is_i, is_f := h.is_enum_type(b_name, &env)
		if is_e {
			is_enum = true
			is_int_enum = is_i
			is_flag = is_f
		} else if b_name in ['TestCase', 'unittest.TestCase'] {
			is_unittest = true
		} else if b_name in ['Protocol', 'typing.Protocol'] {
			is_protocol = true
		} else if b_name in ['NamedTuple', 'typing.NamedTuple'] {
			is_named_tuple = true
		} else if b_name in ['TypedDict', 'typing.TypedDict'] {
			is_typed_dict = true
		}

		if base_expr is ast.Subscript {
			if b_name in ['Generic', 'Protocol'] {
				if b_name == 'Protocol' { is_protocol = true }
				continue
			}
			
			if b_name !in env.analyzer.mixin_to_main {
				type_str := env.visit_expr_fn(base_expr)
				v_type := map_python_type(type_str, struct_name, false, mut env)
				if !v_type.starts_with('[]') && !v_type.starts_with('map[') {
					if !b_name.ends_with('Mixin') {
						is_split := b_name in env.state.known_interfaces
						sanitized_base := sanitize_name(b_name, true)
						if is_split {
							fields << FieldDefInfo{
								name: ''
								def:  '    ${v_type.replace(sanitized_base, sanitized_base + "_Impl")}'
								is_mutated: false
							}
						} else {
							fields << FieldDefInfo{
								name: ''
								def:  '    ${v_type}'
								is_mutated: false
							}
						}
					}
				}
			}
			current_class_bases << b_name
		} else if b_name.len > 0 && b_name != 'object' && b_name != 'ABC' {
			if b_name.ends_with('Mixin') {
				// skip
			} else {
				is_split := b_name in env.state.known_interfaces
				sanitized_base := sanitize_name(b_name, true)
				if is_split {
					fields << FieldDefInfo{
						name: ''
						def:  '    ${sanitized_base}_Impl'
						is_mutated: false
					}
				} else if b_name !in env.analyzer.mixin_to_main {
					fields << FieldDefInfo{
						name: ''
						def:  '    ${sanitized_base}'
						is_mutated: false
					}
				}
			}
			current_class_bases << b_name
			direct_bases << b_name
		}
	}
	
	env.state.class_hierarchy[struct_name] = current_class_bases
	
	return fields, current_class_bases, is_enum, is_int_enum, is_flag, is_unittest, is_protocol, is_named_tuple, is_typed_dict
}


pub fn (h ClassBasesHandler) is_descendant_of(cls_name string, target string, env &ClassVisitEnv) bool {
	if cls_name == target { return true }
	if cls_name in env.state.class_hierarchy {
		for parent in env.state.class_hierarchy[cls_name] {
			if h.is_descendant_of(parent, target, env) { return true }
		}
	}
	return false
}

pub fn (h ClassBasesHandler) is_abstract_base_class(node ast.ClassDef, struct_name string, env &ClassVisitEnv) bool {
	for b in node.bases {
		name := env.visit_expr_fn(b)
		if name in ['ABC', 'abc.ABC'] { return true }
	}
	for stmt in node.body {
		if stmt is ast.FunctionDef {
			for dec in stmt.decorator_list {
				d_name := env.visit_expr_fn(dec)
				if d_name in ['abstractmethod', 'abc.abstractmethod'] { return true }
			}
		}
	}
	return false
}
