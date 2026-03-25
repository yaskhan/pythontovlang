module classes

import ast

pub struct ClassMethodsHandler {}

pub fn (h ClassMethodsHandler) extract_method_info(node ast.ClassDef) (bool, bool, []string, []string) {
	mut has_init := false
	mut has_new := false
	mut static_methods := []string{}
	mut class_methods := []string{}

	for child in node.body {
		if child is ast.FunctionDef {
			if child.name == '__init__' {
				has_init = true
			} else if child.name == '__new__' {
				has_new = true
			}
			for decorator in child.decorator_list {
				mut dec_name := ''
				if decorator is ast.Name {
					dec_name = decorator.id
				} else if decorator is ast.Call {
					if decorator.func is ast.Name {
						dec_name = decorator.func.id
					}
				} else if decorator is ast.Attribute {
					dec_name = decorator.attr
				}
				if dec_name in ['staticmethod', 'abstractstaticmethod'] && child.name !in static_methods {
					static_methods << child.name
				} else if dec_name in ['classmethod', 'abstractclassmethod'] && child.name !in class_methods {
					class_methods << child.name
				}
			}
		}
	}

	return has_init, has_new, static_methods, class_methods
}

pub fn (h ClassMethodsHandler) separate_methods(body []ast.Statement) ([]ast.FunctionDef, []ast.Statement) {
	mut methods := []ast.FunctionDef{}
	mut remaining_body := []ast.Statement{}
	for stmt in body {
		if stmt is ast.FunctionDef {
			methods << stmt
		} else {
			remaining_body << stmt
		}
	}
	return methods, remaining_body
}

pub fn (h ClassMethodsHandler) rename_dunder_methods(mut methods []ast.FunctionDef, has_str bool) {
	_ = methods
	_ = has_str
}

pub fn (h ClassMethodsHandler) has_method(methods []ast.FunctionDef, method_name string) bool {
	for method in methods {
		if method.name == method_name {
			return true
		}
	}
	return false
}

pub fn (h ClassMethodsHandler) process_interface_methods(methods []ast.FunctionDef, mut env ClassVisitEnv) []string {
	mut interface_methods := []string{}
	has_str := h.has_method(methods, '__str__')
	struct_name := env.state.current_class

	for method in methods {
		if method.name == '__init__' {
			continue
		}

		mut m_name := sanitize_name(method.name, false)
		if m_name == '__next__' {
			m_name = 'next'
		} else if m_name == '__post_init__' {
			m_name = 'post_init'
		} else if m_name == '__await__' {
			m_name = 'await_'
		} else if m_name == '__iter__' {
			m_name = 'iter'
		} else if m_name == '__str__' {
			m_name = 'str'
		} else if m_name == '__repr__' {
			m_name = if has_str { 'repr' } else { 'str' }
		}

		mut is_m_classmethod := false
		for dec in method.decorator_list {
			if dec is ast.Name && dec.id in ['classmethod', 'abstractclassmethod'] {
				is_m_classmethod = true
			} else if dec is ast.Call {
				if dec.func is ast.Name && dec.func.id in ['classmethod', 'abstractclassmethod'] {
					is_m_classmethod = true
				}
			} else if dec is ast.Attribute && dec.attr in ['classmethod', 'abstractclassmethod'] {
				is_m_classmethod = true
			}
		}

		mut args := []string{}
		mut all_args := method.args.posonlyargs.clone()
		all_args << method.args.args
			for arg in all_args {
			if arg.arg == 'self' || (is_m_classmethod && arg.arg == 'cls') {
				continue
			}
			arg_name := sanitize_name(arg.arg, false)
			mut a_type := 'int'
			if ann := arg.annotation {
				a_type = map_python_type(env.visit_expr_fn(ann), struct_name, false, mut env)
				} else if arg_name in env.analyzer.type_map {
					a_type = map_python_type(env.analyzer.type_map[arg_name], struct_name, false, mut env)
				}
			if is_v_class_type(a_type) {
				a_type = '&${a_type}'
			}
			args << '${arg_name} ${a_type}'
		}

		mut ret_type := 'void'
		if ret := method.returns {
			ret_type = map_python_type(env.visit_expr_fn(ret), struct_name, true, mut env)
		} else if '${method.name}@return' in env.analyzer.type_map {
			ret_type = map_python_type(env.analyzer.type_map['${method.name}@return'], struct_name,
				true, mut env)
		}
		if is_v_class_type(ret_type) {
			ret_type = '&${ret_type}'
		}
		if m_name == 'next' && ret_type != 'void' && !ret_type.starts_with('?') {
			ret_type = '?${ret_type}'
		}

		if ret_type == 'void' {
			interface_methods << '    ${m_name}(${args.join(", ")})'
		} else {
			interface_methods << '    ${m_name}(${args.join(", ")}) ${ret_type}'
		}
	}

	return interface_methods
}

pub fn (h ClassMethodsHandler) register_class_info(
	struct_name string,
	has_init bool,
	has_new bool,
	static_methods []string,
	class_methods []string,
	has_factory bool,
	mut env ClassVisitEnv,
) {
	if struct_name.len == 0 {
		return
	}
	if struct_name !in env.state.defined_classes {
		env.state.defined_classes[struct_name] = map[string]bool{}
	}
	env.state.defined_classes[struct_name]['has_init'] = has_init || has_factory
	env.state.defined_classes[struct_name]['has_new'] = has_new || has_factory
	env.state.defined_classes[struct_name]['has_static_methods'] = static_methods.len > 0
	env.state.defined_classes[struct_name]['has_class_methods'] = class_methods.len > 0
}
