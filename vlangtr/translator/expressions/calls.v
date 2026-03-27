module expressions

import analyzer
import ast
import base

pub fn (mut eg ExprGen) visit_call(node ast.Call) string {
	func_name_str, _ := eg.extract_func_info(node)
	loc_key := '${node.token.line}:${node.token.column}'
	call_sig := eg.get_call_signature(func_name_str, loc_key)

	mut args := eg.process_call_args(node, call_sig)
	keyword_args, needs_comment := eg.process_keywords(node, call_sig, mut args)

	if needs_comment {
		eg.state.pending_llm_call_comments << '//##LLM@@ unresolved **kwargs unpacking'
	}

	module_name, func_name := eg.resolve_module_and_func(node, func_name_str)

	if func_name_str in ['get_type_hints', 'get_annotations'] {
		return eg.handle_get_type_hints(node, args)
	}

	_ = eg.visit(node.func)
	if special := eg.handle_special_cases(node, module_name, func_name, func_name_str,
		args, call_sig, keyword_args)
	{
		return special
	}

	if mapped := eg.handle_via_mapper(node, module_name, func_name, args) {
		return mapped
	}

	if overload := eg.handle_overloads(node, call_sig, args) {
		return overload
	}

	return eg.handle_fallback_call(node, func_name_str, args, call_sig)
}

pub fn (mut eg ExprGen) extract_func_info(node ast.Call) (string, string) {
	if node.func is ast.Name {
		name := node.func.id
		if name in eg.state.imported_symbols {
			return name, eg.state.imported_symbols[name]
		}
		return name, ''
	}
	if node.func is ast.Subscript {
		sub := node.func
		if sub.value is ast.Name {
			return sub.value.id, ''
		}
	}
	if node.func is ast.Attribute {
		attr := node.func
		if attr.value is ast.Name {
			if attr.value.id in eg.state.imported_modules {
				return attr.attr, '${eg.state.imported_modules[attr.value.id]}.${attr.attr}'
			}
			if attr.value.id in eg.state.imported_symbols {
				return attr.attr, '${eg.state.imported_symbols[attr.value.id]}.${attr.attr}'
			}
		}
		return attr.attr, ''
	}
	return eg.visit(node.func), ''
}

pub fn (mut eg ExprGen) get_call_signature(func_name_str string, loc_key string) ?analyzer.CallSignature {
	potential_keys := [loc_key, '${func_name_str}@${loc_key}']
	for key in potential_keys {
		if key in eg.analyzer.call_signatures { return eg.analyzer.call_signatures[key] }
	}

	// Try mapping from current scope
	if eg.state.scope_names.len > 0 {
		for i := eg.state.scope_names.len; i >= 0; i-- {
			prefix := eg.state.scope_names[..i].join('.')
			qualified := if prefix.len > 0 { '${prefix}.${func_name_str}' } else { func_name_str }
			if qualified in eg.analyzer.call_signatures { return eg.analyzer.call_signatures[qualified] }
		}
	}

	// Fallback to suffix match
	for key, sig in eg.analyzer.call_signatures {
		if key == func_name_str || key.ends_with('.${func_name_str}') { return sig }
	}
	return eg.analyzer.call_signatures[func_name_str]
}

pub fn (mut eg ExprGen) process_call_args(node ast.Call, call_sig ?analyzer.CallSignature) []string {
	mut args := []string{}
	for i, arg in node.args {
		old_type := eg.state.current_assignment_type
		if sig := call_sig {
			if i < sig.args.len {
				eg.state.current_assignment_type = eg.map_python_type(sig.args[i], false)
			}
		}
		args << eg.visit(arg)
		eg.state.current_assignment_type = old_type
	}
	return args
}

pub fn (mut eg ExprGen) process_keywords(node ast.Call, call_sig ?analyzer.CallSignature, mut args []string) (map[string]string, bool) {
	mut keyword_args := map[string]string{}
	mut needs_comment := false

	for kw in node.keywords {
		if kw.arg.len == 0 {
			// **kwargs unpacking
			if sig := call_sig {
				if sig.has_kwarg {
					args << eg.visit(kw.value)
				} else if kw.value is ast.Dict {
					// Expand dict literal if possible
					dict := kw.value
					mut all_resolved := true
					for i in 0 .. dict.keys.len {
						key := dict.keys[i]
						if key is ast.Constant && (key.value.starts_with("'") || key.value.starts_with('"')) {
							k_val := key.value.trim('\'"')
							// Poor man's check: just append if it's in sig.arg_names
							if k_val in sig.arg_names {
								args << eg.visit(dict.values[i])
							} else {
								all_resolved = false
								break
							}
						} else {
							all_resolved = false
							break
						}
					}
					if !all_resolved {
						args << eg.visit(kw.value)
						needs_comment = true
					}
				} else if kw.value is ast.Name {
					if args.len < sig.arg_names.len {
						for aname in sig.arg_names[args.len..] {
							args << "${kw.value.id}['${aname}']"
						}
					}
				} else {
					args << eg.visit(kw.value)
					needs_comment = true
				}
			} else {
				args << eg.visit(kw.value)
				needs_comment = true
			}
			continue
		}
		
		old_type := eg.state.current_assignment_type
		if sig := call_sig {
			// Find arg index
			mut idx := -1
			for i, name in sig.arg_names {
				if name == kw.arg { idx = i; break }
			}
			if idx != -1 && idx < sig.args.len {
				eg.state.current_assignment_type = eg.map_python_type(sig.args[idx], false)
			}
		}
		keyword_args[kw.arg] = eg.visit(kw.value)
		eg.state.current_assignment_type = old_type
	}

	// Fill defaults if it's not a dataclass
	if sig := call_sig {
		if !sig.is_class {
			for i := args.len; i < sig.arg_names.len; i++ {
				name := sig.arg_names[i]
				if name in keyword_args {
					args << keyword_args[name]
					keyword_args.delete(name)
				} else if name in sig.defaults {
					args << sig.defaults[name]
				}
			}
			if sig.has_kwarg && keyword_args.len > 0 {
				mut items := []string{}
				for k, v in keyword_args { items << "'${k}': ${v}" }
				args << '{${items.join(', ')}}'
				keyword_args.clear()
			}
		}
	}

	return keyword_args, needs_comment
}

pub fn (mut eg ExprGen) handle_get_type_hints(node ast.Call, args []string) string {
	if args.len > 0 {
		return 'py_get_type_hints_generic(${args[0]})'
	}
	return 'map[string]Any{}'
}

pub fn (mut eg ExprGen) handle_special_cases(node ast.Call, module_name string, func_name string, func_name_str string, args []string, call_sig ?analyzer.CallSignature, keyword_args map[string]string) ?string {
	if module_name == 'six' {
		return match func_name {
			'PY2' { 'false' }
			'PY3' { 'true' }
			'string_types' { '[]string' }
			'text_type' { 'string' }
			else { none }
		}
	}

	if func_name_str.starts_with('self.assert') {
		return match func_name_str {
			'self.assert_equal', 'self.assert_count_equal' { 'assert ${args[0]} == ${args[1]}' }
			'self.assert_true' { 'assert ${args[0]}' }
			'self.assert_false' { 'assert !(${args[0]})' }
			'self.assert_not_equal' { 'assert ${args[0]} != ${args[1]}' }
			'self.assert_is_none' { 'assert ${args[0]} is none' }
			'self.assert_is_not_none' { 'assert ${args[0]} !is none' }
			'self.assert_in' { 'assert ${args[0]} in ${args[1]}' }
			'self.assert_not_in' { 'assert ${args[0]} !in ${args[1]}' }
			'self.assert_is' { 'assert ${args[0]} == ${args[1]}' }
			'self.assert_is_not' { 'assert ${args[0]} != ${args[1]}' }
			'self.assert_raises' { '/* assert_raises ignored */' }
			else { none }
		}
	}

	if func_name_str in ['assert_type', 'typing.assert_type'] && args.len == 2 {
		val_type := eg.guess_type(node.args[0])
		expected_p_type := eg.visit(node.args[1])
		expected_v_type := eg.map_assert_type_name(expected_p_type)
		if val_type == expected_v_type {
			return '// assert_type(${args[0]}, ${expected_p_type}) passed statically'
		} else {
			return "\$compile_error('assert_type failed: expected ${expected_v_type} but got ${val_type}')"
		}
	}
	if func_name_str == 'bool' {
		if args.len == 0 { return 'false' }
		if args[0] == 'none' { return 'false' }
	}
	if func_name_str == 'str' {
		if args.len > 0 {
			return '${args[0]}.str()'
		}
		return "''"
	}
	
	if func_name_str in ['any', 'all', 'sum'] {
		eg.state.used_builtins['py_${func_name_str}'] = true
		return 'py_${func_name_str}(${args.join(', ')})'
	}
	if func_name_str in ['bytes', 'bytearray'] {
		if args.len > 0 {
			if args[0].starts_with("'") || args[0].starts_with('"') {
				return '${args[0]}.bytes()'
			}
			if eg.guess_type(node.args[0]) == 'int' {
				return '[]u8{len: ${args[0]}}'
			}
		}
		eg.state.used_builtins['py_${func_name_str}'] = true
		return 'py_${func_name_str}(${args.join(', ')})'
	}
	if func_name_str == 'sorted' {
		eg.state.used_builtins['py_sorted'] = true
		mut sorted_args := args.clone()
		if 'reverse' !in keyword_args && args.len < 2 {
			sorted_args << 'false'
		}
		return 'py_sorted(${sorted_args.join(', ')})'
	}
	if func_name_str == 'reversed' {
		eg.state.used_builtins['py_reversed'] = true
		return 'py_reversed(${args.join(', ')})'
	}

	if func_name_str in eg.state.defined_classes {
		return 'new_${base.to_snake_case(func_name_str)}(${args.join(', ')})'
	}

	if func_name == 'acquire' && node.func is ast.Attribute {
		return '${eg.visit(node.func.value)}.lock()'
	}
	if func_name == 'release' && node.func is ast.Attribute {
		return '${eg.visit(node.func.value)}.unlock()'
	}

	if module_name == 'argparse' {
		if func_name == 'ArgumentParser' {
			eg.state.used_builtins['py_argparse_new'] = true
			return 'py_argparse_new()'
		}
	}

	if module_name == 'array' {
		if func_name == 'array' {
			eg.state.used_builtins['py_array'] = true
			return 'py_array(${args.join(', ')})'
		}
	}

	if module_name == 'base64' {
		eg.state.used_builtins['encoding.base64'] = true
		match func_name {
			'b64encode', 'standard_b64encode' { return 'base64.encode(${args[0]})' }
			'b64decode', 'standard_b64decode' { return 'base64.decode(${args[0]})' }
			'urlsafe_b64encode' { return 'base64.url_encode(${args[0]})' }
			'urlsafe_b64decode' { return 'base64.url_decode(${args[0]})' }
			else { none }
		}
	}

	if module_name == 'struct' {
		if func_name == 'pack' && args.len >= 2 {
			if node.args[0] is ast.Constant {
				fmt := (node.args[0] as ast.Constant).value.trim("'").trim('"')
				if fmt == '<I' {
					eg.state.used_builtins['py_struct_pack_I_le'] = true
					return 'py_struct_pack_I_le(u32(${args[1]}))'
				}
			}
		}
		if func_name == 'unpack' && args.len >= 2 {
			if node.args[0] is ast.Constant {
				fmt := (node.args[0] as ast.Constant).value.trim("'").trim('"')
				if fmt == '<I' {
					eg.state.used_builtins['py_struct_unpack_I_le'] = true
					return 'py_struct_unpack_I_le(${args[1]})'
				}
			}
		}
	}

	if module_name == 'subprocess' && func_name in ['run', 'call', 'check_call', 'check_output'] {
		eg.state.used_builtins['py_subprocess_${func_name}'] = true
		return 'py_subprocess_${func_name}(${args.join(', ')})'
	}

	if module_name == 'tempfile' {
		return match func_name {
			'mkdtemp' { "os.mkdir_temp('')" }
			'gettempdir' { "os.temp_dir()" }
			'NamedTemporaryFile', 'TemporaryFile' { "os.create_temp('')" }
			'TemporaryDirectory' { "os.mkdir_temp('')" }
			else { none }
		}
	}

	if module_name == 'threading' {
		if func_name == 'Thread' { return 'PyThread{${args.join(', ')}}' }
		if func_name == 'Lock' { return 'sync.new_mutex()' }
	}

	if func_name_str == 'print' {
		mut print_args := []string{}
		for arg in args {
			if arg.starts_with("'") || arg.starts_with('"') {
				print_args << arg
			} else {
				print_args << "'\${${arg}}'"
			}
		}
		return 'println(${print_args.join(', ')})'
	}

	if func_name_str == 'len' && args.len == 1 {
		return '${args[0]}.len'
	}

	if func_name_str == 'int' {
		if args.len == 0 { return '0' }
		if args.len == 1 {
			typ := eg.guess_type(node.args[0])
			if typ in ['string', 'LiteralString'] { return '${args[0]}.int()' }
			return 'int(${args[0]})'
		}
		if args.len >= 2 {
			eg.state.used_builtins['strconv.parse_int'] = true
			return 'int(strconv.parse_int(${args[0]}, ${args[1]}, 32) or { 0 })'
		}
	}

	if func_name_str == 'round' && args.len == 1 {
		return 'int(math.round(${args[0]}))'
	}

	if func_name_str == 'isinstance' && args.len >= 2 {
		return '${args[0]} is ${args[1]}'
	}

	if func_name_str == 'list' && args.len == 0 { return '[]Any{}' }
	if func_name_str == 'dict' && args.len == 0 { return 'map[string]Any{}' }

	if func_name_str == 'Counter' || (module_name == 'collections' && func_name == 'Counter') {
		if args.len == 0 { return 'map[string]int{}' }
		eg.state.used_builtins['py_counter'] = true
		return 'py_counter(${args[0]})'
	}

	if (func_name_str == 'defaultdict' || (module_name == 'collections' && func_name == 'defaultdict')) && args.len >= 1 {
		mut d_type := 'Any'
		if node.args.len > 0 {
			if node.args[0] is ast.Name {
				id := (node.args[0] as ast.Name).id
				if id == 'int' { d_type = 'int' }
				else if id == 'list' { d_type = '[]Any' }
				else if id == 'dict' { d_type = 'map[string]Any' }
			}
		}
		return 'map[string]${d_type}{}'
	}

	if module_name == 'gzip' && func_name in ['compress', 'decompress'] {
		eg.state.used_builtins['py_gzip_${func_name}'] = true
		return 'py_gzip_${func_name}(${args.join(', ')})'
	}

	if module_name == 'zlib' && func_name in ['compress', 'decompress'] {
		eg.state.used_builtins['py_zlib_${func_name}'] = true
		return 'py_zlib_${func_name}(${args.join(', ')})'
	}

	if module_name == 'copy' && func_name in ['copy', 'deepcopy'] {
		return 'py_${func_name}(${args.join(', ')})'
	}

	if module_name == 'uuid' && func_name == 'uuid4' {
		return 'rand.uuid_v4()'
	}

	if func_name_str == 'range' {
		return 'py_range(${args.join(', ')})'
	}

	if func_name_str == 'sorted' {
		eg.state.used_builtins['py_sorted'] = true
		return 'py_sorted(${args.join(', ')}, false)'
	}

	return none
}

pub fn (mut eg ExprGen) handle_via_mapper(node ast.Call, module_name string, func_name string, args []string) ?string {
	if module_name == 'typing' && func_name == 'cast' && args.len >= 2 {
		return '(${args[1]} as ${args[0]})'
	}
	if module_name == 'typing' && func_name == 'NewType' && args.len >= 2 {
		name := args[0].trim("'").trim('"')
		return 'type ${name} = ${args[1]}'
	}
	// Add more mapper logic if needed
	return none
}

pub fn (mut eg ExprGen) handle_overloads(node ast.Call, call_sig ?analyzer.CallSignature, args []string) ?string {
	if sig := call_sig {
		func_name := if node.func is ast.Name { node.func.id } else if node.func is ast.Attribute { node.func.attr } else { '' }
		if func_name.len > 0 {
			final_args := eg.process_mutated_args(func_name, args, call_sig)
			if sig.is_class {
				return '${func_name}(${final_args.join(', ')})'
			}
		}
	}
	return none
}

pub fn (mut eg ExprGen) handle_fallback_call(node ast.Call, func_name_str string, args []string, call_sig ?analyzer.CallSignature) string {
	mut func_name := eg.visit(node.func)
	if func_name.len == 0 { func_name = func_name_str }
	if func_name in eg.state.renamed_functions { func_name = eg.state.renamed_functions[func_name] }

	final_args := eg.process_mutated_args(func_name, args, call_sig)
	return '${func_name}(${final_args.join(', ')})'
}

pub fn (mut eg ExprGen) process_mutated_args(func_name_str string, args []string, call_sig ?analyzer.CallSignature) []string {
	mut final_args := []string{}
	mut mutated := map[int]bool{}
	if func_name_str in eg.analyzer.func_param_mutability {
		for idx in eg.analyzer.func_param_mutability[func_name_str] { mutated[idx] = true }
	}
	for i, arg in args {
		if i in mutated && !arg.starts_with('mut ') && arg !in ['none', 'true', 'false'] {
			final_args << 'mut ${arg}'
		} else {
			final_args << arg
		}
	}
	return final_args
}

fn (eg &ExprGen) map_assert_type_name(type_name string) string {
	return match type_name {
		'float' { 'f64' }
		'int' { 'int' }
		'str' { 'string' }
		'bool' { 'bool' }
		else { type_name }
	}
}
pub fn (mut eg ExprGen) resolve_module_and_func(node ast.Call, func_name_str string) (string, string) {
	if node.func is ast.Attribute {
		attr := node.func
		if attr.value is ast.Name {
			name := attr.value.id
			if name in eg.state.imported_modules {
				return name, attr.attr
			}
			if name in eg.state.imported_symbols {
				return name, attr.attr
			}
		}
	}
	if func_name_str in eg.state.imported_symbols {
		sym := eg.state.imported_symbols[func_name_str]
		if sym.contains('.') {
			parts := sym.split('.')
			return parts[0], parts[1]
		}
	}
	return '', func_name_str
}
