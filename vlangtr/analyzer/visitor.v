module analyzer

pub struct TypeInferenceVisitorMixin {
	TypeInferenceBase
}

pub fn new_type_inference_visitor_mixin() TypeInferenceVisitorMixin {
	return TypeInferenceVisitorMixin{
		TypeInferenceBase: new_type_inference_base()
	}
}

const mutating_methods = ['append', 'extend', 'insert', 'pop', 'remove', 'clear', 'update',
	'setdefault', 'delete', 'add', 'discard']

pub fn (mut t TypeInferenceVisitorMixin) visit_call(func_name string, obj_name string, method_name string, args []string) {
	if method_name in mutating_methods {
		mut info := t.get_mutability(obj_name)
		info.is_mutated = true
		t.set_mutability(obj_name, info)
	}
	if method_name == 'append' && args.len == 1 {
		elt_type := t.guess_node_type(args[0])
		if elt_type != 'Any' {
			new_type := '[]' + elt_type
			current := t.get_type(obj_name)
			if !t.has_type(obj_name) || current == '[]Any' {
				t.set_type(obj_name, new_type)
			}
		}
	}
	if obj_name == 'hashlib' {
		if method_name == 'sha256' {
			t.set_type(func_name, 'PyHashSha256')
		} else if method_name == 'md5' {
			t.set_type(func_name, 'PyHashMd5')
		}
	}
	if !t.has_type(func_name) {
		t.set_type(func_name, 'fn (...Any) Any')
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_class_def(class_name string, bases []string, field_names []string, field_types []string) {
	t.push_scope(class_name)
	t.add_class_to_hierarchy(class_name, bases)
	for i := 0; i < field_names.len && i < field_types.len; i++ {
		t.set_type(field_names[i], field_types[i])
	}
	t.pop_scope()
}

pub fn (mut t TypeInferenceVisitorMixin) visit_assign(target_name string, value_type string, is_self_attr bool) {
	if is_self_attr {
		t.set_type(target_name, value_type)
		return
	}
	if t.has_type(target_name) {
		mut info := t.get_mutability(target_name)
		info.is_reassigned = true
		t.set_mutability(target_name, info)
	}
	if !t.has_type(target_name) || t.get_type(target_name) == 'Any' {
		if value_type != 'Any' {
			t.set_type(target_name, value_type)
		}
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_aug_assign(target_name string) {
	mut info := t.get_mutability(target_name)
	info.is_reassigned = true
	t.set_mutability(target_name, info)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_delete(target_name string) {
	mut info := t.get_mutability(target_name)
	info.is_mutated = true
	t.set_mutability(target_name, info)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_ann_assign(target_name string, annotation string) {
	v_type := map_python_type_to_v(annotation)
	if v_type == 'LiteralString' {
		t.set_type(target_name, 'string')
	} else {
		t.set_type(target_name, v_type)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_function_def(func_name string, args []string, arg_types []string, return_type string) {
	t.push_scope(func_name)
	t.set_type(func_name, 'fn (...Any) Any')
	for i := 0; i < args.len && i < arg_types.len; i++ {
		v_type := map_python_type_to_v(arg_types[i])
		if v_type == 'LiteralString' {
			t.set_type(args[i], 'string')
		} else {
			t.set_type(args[i], v_type)
		}
	}
	if return_type != 'void' && return_type != '' {
		v_ret := map_python_type_to_v(return_type)
		t.set_type(func_name + '@return', v_ret)
	}
	t.pop_scope()
}

pub fn (mut t TypeInferenceVisitorMixin) visit_subscript(container_name string, is_store bool) {
	if is_store {
		mut info := t.get_mutability(container_name)
		info.is_mutated = true
		t.set_mutability(container_name, info)
	}
}

fn (mut t TypeInferenceVisitorMixin) guess_node_type(node_type string) string {
	match node_type {
		'bool' {
			return 'bool'
		}
		'int' {
			return 'int'
		}
		'float', 'float64' {
			return 'f64'
		}
		'str', 'string' {
			return 'string'
		}
		'bytes', 'bytearray', 'memoryview' {
			return '[]u8'
		}
		else {
			if t.has_type(node_type) {
				return t.get_type(node_type)
			}
			if node_type.len > 0 && node_type[0].is_capital() {
				return node_type
			}
			return 'Any'
		}
	}
}

// visit_node обходит AST узел
pub fn (mut t TypeInferenceVisitorMixin) visit_node(node string) {
	// Placeholder for AST node visiting logic
	// This will be expanded based on the AST structure
	match node {
		'Module' { t.visit_module() }
		'FunctionDef' { t.visit_function_def('', []string{}, []string{}, '') }
		'ClassDef' { t.visit_class_def('', []string{}, []string{}, []string{}) }
		'Assign' { t.visit_assign('', '', false) }
		'AugAssign' { t.visit_aug_assign('') }
		'Delete' { t.visit_delete('') }
		'AnnAssign' { t.visit_ann_assign('', '') }
		'Call' { t.visit_call('', '', '', []string{}) }
		'Subscript' { t.visit_subscript('', false) }
		else {}
	}
}

// visit_module обходит модуль
fn (mut t TypeInferenceVisitorMixin) visit_module() {
	// Placeholder for module visiting logic
}
