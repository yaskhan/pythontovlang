module analyzer

pub struct TypeInferenceUtilsMixin {
	TypeInferenceBase
}

pub fn new_type_inference_utils_mixin() TypeInferenceUtilsMixin {
	return TypeInferenceUtilsMixin{
		TypeInferenceBase: new_type_inference_base()
	}
}

pub fn (mut t TypeInferenceUtilsMixin) find_lcs(types []string) string {
	if types.len == 0 {
		return "Any"
	}
	first := types[0]
	mut all_same := true
	for typ in types {
		if typ != first {
			all_same = false
			break
		}
	}
	if all_same {
		return first
	}
	return "Any"
}

pub fn (mut t TypeInferenceUtilsMixin) mark_mutated(name string) {
	mut info := t.get_mutability(name)
	info.is_mutated = true
	t.set_mutability(name, info)
}

pub fn (mut t TypeInferenceUtilsMixin) mark_reassigned(name string) {
	mut info := t.get_mutability(name)
	info.is_reassigned = true
	t.set_mutability(name, info)
}

pub fn (mut t TypeInferenceUtilsMixin) guess_node_type(node_type string) string {
	match node_type {
		"bool" { return "bool" }
		"int" { return "int" }
		"float", "float64" { return "f64" }
		"str", "string" { return "string" }
		"bytes", "bytearray", "memoryview" { return "[]u8" }
		else {
			if t.has_type(node_type) {
				return t.get_type(node_type)
			}
			if node_type.len > 0 && node_type[0].is_capital() {
				return node_type
			}
			return "Any"
		}
	}
}

pub fn map_python_type_to_v(py_type string) string {
	match py_type {
		"int" { return "int" }
		"float" { return "f64" }
		"str" { return "string" }
		"bool" { return "bool" }
		"bytes" { return "[]u8" }
		"bytearray" { return "[]u8" }
		"None" { return "void" }
		"Any" { return "Any" }
		"object" { return "Any" }
		else {
			if py_type.starts_with("List[") || py_type.starts_with("list[") {
				inner := py_type[5..py_type.len - 1]
				return "[]" + map_python_type_to_v(inner)
			}
			if py_type.starts_with("Dict[") || py_type.starts_with("dict[") {
				return "map[string]Any"
			}
			if py_type.starts_with("Optional[") {
				inner := py_type[9..py_type.len - 1]
				return "?" + map_python_type_to_v(inner)
			}
			return py_type
		}
	}
}
