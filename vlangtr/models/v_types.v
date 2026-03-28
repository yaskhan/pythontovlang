module models

// VType - V data types
pub enum VType {
	int
	float
	string
	bool
	void_
	list
	dict
	tuple
	none
	unknown
}

// get_tuple_struct_name generates struct name for Python Tuple
pub fn get_tuple_struct_name(types_str string) string {
	field_types := types_str.split(',').map(it.trim_space())
	mut name_parts := []string{}
	for t in field_types {
		mut clean_t := t.replace('builtins.', '').replace('typing.', '').replace('.',
			'').replace('[', '').replace(']', '').capitalize()
		if clean_t.len == 0 {
			clean_t = 'Any'
		}
		name_parts << clean_t
	}
	return 'TupleStruct_${name_parts.join('')}'
}

// map_python_type_to_v maps Python type to V type
pub fn map_python_type_to_v(py_type string, self_name string, allow_union bool, generic_map map[string]string, sum_type_registrar fn (string) string, literal_registrar fn ([]string) string, tuple_registrar fn (string) string) string {
	if py_type.len == 0 {
		return 'void'
	}

	// Handle leading * for TypeVarTuple
	mut clean_type := py_type
	if clean_type.starts_with('*') && !clean_type.starts_with('**') {
		clean_type = clean_type[1..]
	}

	// Strip surrounding quotes
	for clean_type.len > 0 && ((clean_type.starts_with("'") && clean_type.ends_with("'"))
		|| (clean_type.starts_with('"') && clean_type.ends_with('"'))) {
		clean_type = clean_type[1..clean_type.len - 1]
	}

	// Handle Mypy specific: tuple[int, int, fallback=Point]
	if clean_type.contains('fallback=') {
		// Extract fallback type
		if clean_type.contains('fallback=') {
			mut fb_type := ''
			if clean_type.contains('fallback=') {
				parts := clean_type.split('fallback=')
				if parts.len > 1 {
					fb_part := parts[1]
					comma_idx := fb_part.index(',') or { -1 }
					bracket_idx := fb_part.index(']') or { -1 }
					end_idx := if comma_idx >= 0 && (bracket_idx < 0 || comma_idx < bracket_idx) {
						comma_idx
					} else {
						bracket_idx
					}
					if end_idx >= 0 {
						fb_type = fb_part[..end_idx].trim_space()
					}
				}
			}
			// If fallback is specific, use it
			if fb_type.len > 0
				&& fb_type !in ['builtins.tuple', 'tuple', 'builtins.object', 'object'] {
				clean_fb := fb_type.replace(', fallback=', '').replace('fallback=', '')
				return map_python_type_to_v(clean_fb, self_name, allow_union, generic_map,
					sum_type_registrar, literal_registrar, tuple_registrar)
			}
		}
		// Remove fallback= part
		clean_type = clean_type.replace(', fallback=', '').replace('fallback=', '')
	}

	// Pre-process basic types
	match clean_type {
		'int' { return 'int' }
		'float' { return 'f64' }
		'str' { return 'string' }
		'bool' { return 'bool' }
		'None' { return 'none' }
		'Any' { return 'Any' }
		'object' { return 'Any' }
		// 'Self', 'typing.Self' { return if self_name.len > 0 { '&' + self_name } else { 'Self' } }
		'builtins.int' { return 'int' }
		'builtins.float' { return 'f64' }
		'builtins.str' { return 'string' }
		'builtins.bool' { return 'bool' }
		else {}
	}

	if clean_type in generic_map {
		return generic_map[clean_type]
	}

	// Try to parse complex types
	if clean_type.contains('[') {
		// Simplified handling for complex types
		return map_complex_type(clean_type, self_name, allow_union, generic_map, sum_type_registrar,
			literal_registrar, tuple_registrar)
	}

	// Registrar should be called before simple fallback
	reg_res := sum_type_registrar(clean_type)
	if reg_res.len > 0 { return reg_res }

	// Fallback to basic type mapping
	return map_basic_type(clean_type)
}

// map_complex_type handles complex types
fn map_complex_type(py_type string, self_name string, allow_union bool, generic_map map[string]string, sum_type_registrar fn (string) string, literal_registrar fn ([]string) string, tuple_registrar fn (string) string) string {
	// Extract base type and arguments
	mut base_type := ''
	mut args_str := ''

	if py_type.contains('[') {
		bracket_idx := py_type.index('[') or { -1 }
		if bracket_idx >= 0 {
			base_type = py_type[..bracket_idx].trim_space()
			args_str = py_type[bracket_idx + 1..py_type.len - 1].trim_space()
		}
	} else {
		base_type = py_type
	}

	// Normalize base_type by removing 'typing.' or 'typing_extensions.' prefix
	if base_type.contains('.') {
		base_type = base_type.all_after('.')
	}
	// eprintln('DEBUG map_complex_type: base_type=${base_type} py_type=${py_type}')

	// Parse arguments
	mut args := []string{}
	if args_str.len > 0 {
		args = split_args(args_str)
	}

	// Map arguments
	mut mapped_args := []string{}
	for arg in args {
		mapped_args << map_python_type_to_v(arg.trim_space(), self_name, allow_union,
			generic_map, sum_type_registrar, literal_registrar, tuple_registrar)
	}

	// Handle specific base types
	match base_type {
		'List', 'list', 'Sequence', 'MutableSequence', 'Iterable', 'Iterator' {
			if mapped_args.len > 0 {
				return '[]${mapped_args[0]}'
			}
			return '[]int'
		}
		'Set', 'set', 'FrozenSet', 'MutableSet', 'AbstractSet' {
			if mapped_args.len > 0 {
				return 'map[${mapped_args[0]}]bool'
			}
			return 'map[int]bool'
		}
		'Dict', 'dict', 'Mapping', 'MutableMapping' {
			if mapped_args.len >= 2 {
				return 'map[${mapped_args[0]}]${mapped_args[1]}'
			} else if mapped_args.len == 1 {
				return 'map[${mapped_args[0]}]Any'
			}
			return 'map[string]Any'
		}
		'IO', 'TextIO' {
			if mapped_args.len >= 1 && mapped_args[0] == 'string' {
				return '&strings.Builder'
			}
			return 'os.File'
		}
		'Tuple', 'tuple' {
			if mapped_args.len == 2 && mapped_args[1] == '...' {
				return '[]${mapped_args[0]}'
			}
			if tuple_registrar != unsafe { nil } {
				return tuple_registrar(mapped_args.join(', '))
			}
			return get_tuple_struct_name(mapped_args.join(', '))
		}
		'Optional' {
			if mapped_args.len > 0 {
				return '?${mapped_args[0]}'
			}
			return '?int'
		}
		'Union' {
			// Deduplicate
			mut unique_args := []string{}
			for arg in mapped_args {
				if arg !in unique_args {
					unique_args << arg
				}
			}

			// If Any is present, return Any
			if 'Any' in unique_args {
				return 'Any'
			}

			// Check for None to map to Optional
			mut non_none := []string{}
			for t in unique_args {
				if t != 'none' {
					non_none << t
				}
			}
			if non_none.len == 1 && unique_args.len > 1 {
				return '?${non_none[0]}'
			}

			union_str := unique_args.join(' | ')
			if sum_type_registrar != unsafe { nil } {
				mut reg_res := ''
				if non_none.len < unique_args.len {
					reg_res = sum_type_registrar(non_none.join(' | '))
					if reg_res != '' { return '?${reg_res}' }
				} else {
					reg_res = sum_type_registrar(union_str)
					if reg_res != '' { return reg_res }
				}
			}

			if allow_union {
				return union_str
			}
			return 'Any'
		}
		'Callable', 'typing.Callable', 'callable', 'collections.abc.Callable' {
			if args.len == 2 {
				arg_types := if args[0].len > 0 {
					split_args(args[0].trim_space())
				} else {
					[]string{}
				}
				ret_type := map_python_type_to_v(args[1].trim_space(), self_name, allow_union,
					generic_map, sum_type_registrar, literal_registrar, tuple_registrar)
				if ret_type in ['none', 'void'] {
					return 'fn (${arg_types.join(', ')})'
				}
				return 'fn (${arg_types.join(', ')}) ${ret_type}'
			}
			return 'fn (...Any) Any'
		}
		'Literal' {
			if literal_registrar != unsafe { nil } {
				return literal_registrar(args)
			}
			if args.len > 0 {
				// Simplified: return type based on first literal
				return 'string' // default
			}
			return 'string'
		}
		'Type', 'type', 'builtins.type' {
			if mapped_args.len > 0 {
				return mapped_args[0]
			}
			return 'Any'
		}
		'Final', 'ClassVar', 'Annotated', 'ReadOnly', 'ForwardRef' {
			if mapped_args.len > 0 {
				return mapped_args[0]
			}
			return 'Any'
		}
		'Required' {
			if mapped_args.len > 0 {
				return mapped_args[0]
			}
			return 'Any'
		}
		'NotRequired' {
			if mapped_args.len > 0 {
				return '?${mapped_args[0]}'
			}
			return '?Any'
		}
		'TypeGuard', 'TypeIs' {
			return 'bool'
		}
		else {}
	}

	// Default generic mapping
	return '${base_type}[${mapped_args.join(', ')}]'
}

// split_args splits type arguments considering nesting
fn split_args(args_str string) []string {
	mut result := []string{}
	mut depth := 0
	mut current := ''

	for ch in args_str {
		match ch {
			`[` {
				depth++
			}
			`]` {
				depth--
			}
			`,` {
				if depth == 0 {
					result << current.trim_space()
					current = ''
					continue
				}
			}
			else {}
		}
		current += ch.ascii_str()
	}

	if current.trim_space().len > 0 {
		result << current.trim_space()
	}

	return result
}

// _map_basic_type maps basic types
fn map_basic_type(name string) string {
	mut clean_name := name

	// Strip typing. prefix
	if clean_name.starts_with('typing.') {
		clean_name = clean_name[7..]
	}
	if clean_name.starts_with('typing_extensions.') {
		clean_name = clean_name[18..]
	}

	mapping := {
		'int':                             'int'
		'float':                           'f64'
		'str':                             'string'
		'bytes':                           '[]u8'
		'bool':                            'bool'
		'None':                            'none'
		'Any':                             'Any'
		'object':                          'Any'
		'list':                            '[]Any'
		'dict':                            'map[string]int'
		'tuple':                           '[]int'
		'set':                             'map[int]bool'
		'memoryview':                      '[]u8'
		'bytearray':                       '[]u8'
		'IO':                              'os.File'
		'TextIO':                          'os.File'
		'BinaryIO':                        'os.File'
		'StringIO':                        'strings.Builder'
		'io.StringIO':                     'strings.Builder'
		'NoReturn':                        'noreturn'
		'List':                            '[]Any'
		'Dict':                            'map[string]Any'
		'Tuple':                           '[]Any'
		'Set':                             'map[string]bool'
		'Optional':                        '?Any'
		'Union':                           'Any'
		'Callable':                        'fn (...Any) Any'
		'callable':                        'fn (...Any) Any'
		'collections.abc.Callable':        'fn (...Any) Any'
		'Sequence':                        '[]Any'
		'Iterable':                        '[]Any'
		'Mapping':                         'map[string]Any'
		'typing.Any':                      'Any'
		'typing.List':                     '[]Any'
		'typing.Dict':                     'map[string]Any'
		'typing.Tuple':                    '[]Any'
		'typing.Set':                      'map[string]bool'
		'typing.Optional':                 '?Any'
		'typing.Union':                    'Any'
		'typing.Callable':                 'fn (...Any) Any'
		'typing_extensions.Callable':      'fn (...Any) Any'
		'typing_extensions.Union':         'Any'
		'typing.NoReturn':                 'noreturn'
		'typing.Sequence':                 '[]Any'
		'typing.Iterable':                 '[]Any'
		'typing.Mapping':                  'map[string]Any'
		'builtins.int':                    'int'
		'builtins.float':                  'f64'
		'builtins.str':                    'string'
		'builtins.bool':                   'bool'
		'builtins.bytes':                  '[]u8'
		'builtins.object':                 'Any'
		'LiteralString':                   'string'
		'typing.LiteralString':            'string'
		'typing_extensions.LiteralString': 'string'
		'TypeForm':                        'Any'
		'typing.TypeForm':                 'Any'
		'typing_extensions.TypeForm':      'Any'
		'type':                            'Any'
		'builtins.type':                   'Any'
		'Final':                           'Any'
		'typing.Final':                    'Any'
		'ClassVar':                        'Any'
		'typing.ClassVar':                 'Any'
		'ForwardRef':                      'Any'
		'typing.ForwardRef':               'Any'
		'annotationlib.ForwardRef':        'Any'
	}

	if clean_name in mapping {
		return mapping[clean_name]
	}

	return clean_name
}
