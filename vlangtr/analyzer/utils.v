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
		return 'Any'
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
	return 'Any'
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

pub fn map_python_type_to_v(py_type string) string {
	mut clean_type := py_type.trim_space()
	if clean_type.starts_with('typing_extensions.') {
		clean_type = clean_type[18..]
	}
	if clean_type.starts_with('typing.') {
		clean_type = clean_type[7..]
	}
	if clean_type.starts_with('builtins.') {
		clean_type = clean_type[9..]
	}
	if clean_type in ['LiteralString', 'typing.LiteralString', 'typing_extensions.LiteralString'] {
		return 'string'
	}
	match clean_type {
		'int' {
			return 'int'
		}
		'float' {
			return 'f64'
		}
		'str' {
			return 'string'
		}
		'bool' {
			return 'bool'
		}
		'bytes' {
			return '[]u8'
		}
		'bytearray' {
			return '[]u8'
		}
		'None' {
			return 'void'
		}
		'Any' {
			return 'Any'
		}
		'object' {
			return 'Any'
		}
		else {
			if clean_type.starts_with('List[') || clean_type.starts_with('list[') {
				inner := clean_type[5..clean_type.len - 1]
				return '[]' + map_python_type_to_v(inner)
			}
			if clean_type.starts_with('Dict[') || clean_type.starts_with('dict[') {
				mut inner := clean_type[5..clean_type.len - 1]
				if inner.len > 0 {
					parts := inner.split(',')
					if parts.len >= 2 {
						key_type := map_python_type_to_v(parts[0].trim_space())
						val_type := map_python_type_to_v(parts[1].trim_space())
						return 'map[${key_type}]${val_type}'
					}
				}
				return 'map[string]Any'
			}
			if clean_type.starts_with('Optional[') {
				inner := clean_type[9..clean_type.len - 1]
				return '?' + map_python_type_to_v(inner)
			}
			if clean_type.starts_with('Union[') {
				inner := clean_type[6..clean_type.len - 1]
				parts := inner.split(',').map(it.trim_space())
				mut non_none := []string{}
				for part in parts {
					if part != 'None' {
						non_none << map_python_type_to_v(part)
					}
				}
				if non_none.len == 1 && parts.len > 1 {
					return '?' + non_none[0]
				}
				return if non_none.len > 0 { non_none.join(' | ') } else { 'Any' }
			}
			return clean_type
		}
	}
}
