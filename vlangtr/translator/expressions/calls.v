module expressions

import analyzer
import ast
import base
import stdlib_map

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

	if mapped_val := eg.handle_via_mapper(node, module_name, func_name, args) {
		if mapped_val.contains('(') {
			eg.state.used_builtins[mapped_val.all_before('(')] = true
		} else {
			eg.state.used_builtins[mapped_val] = true
		}
		return mapped_val
	}

	if overload := eg.handle_overloads(node, call_sig, args) {
		return overload
	}

	if result := eg.handle_object_method_call(node, node.func, func_name_str, args) {
		return result
	}

	return eg.handle_fallback_call(node, func_name_str, args, keyword_args, call_sig)
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
		full_name := eg.visit(node.func)
		return full_name, ''
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
		name := func_name_str.replace('self.', '')
		return match name {
			'assertEqual', 'assert_equal', 'assertCountEqual', 'assert_count_equal' { 'assert ${args[0]} == ${args[1]}' }
			'assertTrue', 'assert_true' { 'assert ${args[0]}' }
			'assertFalse', 'assert_false' { 'assert !(${args[0]})' }
			'assertNotEqual', 'assert_not_equal' { 'assert ${args[0]} != ${args[1]}' }
			'assertIsNone', 'assert_is_none' { 'assert ${args[0]} == none' }
			'assertIsNotNone', 'assert_is_not_none' { 'assert ${args[0]} != none' }
			'assertIn', 'assert_in' { 'assert ${args[0]} in ${args[1]}' }
			'assertNotIn', 'assert_not_in' { 'assert ${args[0]} !in ${args[1]}' }
			'assertIs', 'assert_is' { 'assert ${args[0]} == ${args[1]}' }
			'assertIsNot', 'assert_is_not' { 'assert ${args[0]} != ${args[1]}' }
			'assertRaises', 'assert_raises' { '/* assert_raises ignored */' }
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
	if func_name_str in ['assert_never', 'typing.assert_never'] {
		return 'panic(\'assert_never reached\')'
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
	
	if func_name_str in ['any', 'all', 'sum'] || (module_name == 'builtins' && func_name in ['any', 'all', 'sum']) {
		b_name := if func_name_str in ['any', 'all', 'sum'] { func_name_str } else { func_name }
		eg.state.used_builtins['py_${b_name}'] = true
		return 'py_${b_name}(${args.join(', ')})'
	}
	
	if (module_name == 'urllib.parse' || module_name == 'urllib') && func_name == 'urlparse' {
		eg.state.used_builtins['py_urlparse'] = true
		return 'py_urlparse(${args.join(', ')})'
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

	if (func_name == 'acquire' || func_name_str.ends_with('.acquire')) && node.func is ast.Attribute {
		return '${eg.visit(node.func.value)}.lock()'
	}
	if (func_name == 'release' || func_name_str.ends_with('.release')) && node.func is ast.Attribute {
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
				if fmt == '>I' {
					eg.state.used_builtins['py_struct_pack_I_be'] = true
					return 'py_struct_pack_I_be(u32(${args[1]}))'
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
			'TemporaryDirectory' { 
				eg.state.used_builtins['py_tempfile_tempdir'] = true
				"py_tempfile_tempdir()" 
			}
			else { none }
		}
	}

	if module_name == 'threading' {
		if func_name == 'Thread' { return 'PyThread{${args.join(', ')}}' }
		if func_name == 'Lock' { return 'sync.new_mutex()' }
	}

	if func_name_str == 'print' {
		mut items := []string{}
		for arg in args {
			if arg.starts_with("'") || arg.starts_with('"') {
				items << arg.trim("'\"")
			} else {
				items << "\${${arg}}"
			}
		}
		sep := if s := keyword_args['sep'] { s.trim("'\"") } else { ' ' }
		end := if e := keyword_args['end'] { e.trim("'\"") } else { '\\n' }
		file := if f := keyword_args['file'] { f } else { 'stdout' }
		
		fmt_str := items.join(sep)
		is_stderr := file == 'sys.stderr'
		if end == '\\n' {
			if is_stderr {
				return "eprintln('${fmt_str}')"
			} else {
				return "println('${fmt_str}')"
			}
		} else {
			if is_stderr {
				return "eprint('${fmt_str}${end}')"
			} else {
				return "print('${fmt_str}${end}')"
			}
		}
	}

	if func_name_str == 'any' && args.len == 1 {
		eg.state.used_builtins['py_any'] = true
		return 'py_any(${args[0]})'
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

	if func_name_str == 'sorted' && args.len >= 1 {
		eg.state.used_builtins['py_sorted'] = true
		return 'py_sorted(${args.join(', ')})'
	}

	if func_name_str == 'isinstance' && args.len >= 2 {
		v_type := eg.map_python_type(args[1], false)
		return '${args[0]} is ${v_type}'
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
		eg.state.used_builtins['py_${func_name}'] = true
		return 'py_${func_name}(${args.join(', ')})'
	}

	if module_name == 'uuid' && func_name == 'uuid4' {
		eg.state.used_builtins['rand.uuid_v4'] = true
		return 'rand.uuid_v4()'
	}

	if func_name_str == 'range' {
		eg.state.used_builtins['py_range'] = true
		return 'py_range(${args.join(', ')})'
	}

	if func_name_str == 'sorted' {
		eg.state.used_builtins['py_sorted'] = true
		return 'py_sorted(${args.join(', ')}, false)'
	}

	if module_name == 'time' && func_name == 'sleep' && args.len >= 1 {
		return 'time.sleep(${args[0]} * time.second)'
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
	
	if (module_name == 'argparse' || func_name.contains('argparse') || func_name.ends_with('add_argument')) && func_name.contains('add_argument') {
		mut pos_args := []string{}
		for a in args {
			if !a.contains('=') {
				pos_args << a
			}
		}
		// Try to keep the receiver if it was visit_attribute
		if func_name.contains('.') {
			parts := func_name.split('.')
			recv := parts[..parts.len-1].join('.')
			return '${recv}.add_argument(${pos_args.join(', ')})'
		}
		return 'parser.add_argument(${pos_args.join(', ')})'
	}
	
	if eg.state.mapper == unsafe { nil } { return none }
	mapper := unsafe { &stdlib_map.StdLibMapper(eg.state.mapper) }

	if module_name.len > 0 {
		if res := mapper.get_mapping(module_name, func_name, args) {
			return res
		}
	}
	
	// Try submodule matching if module_name is empty but func_name has dots
	if func_name.contains('.') {
		parts := func_name.split('.')
		for i := 1; i < parts.len; i++ {
			m_name := parts[..i].join('.')
			f_name := parts[i..].join('.')
			if res := mapper.get_mapping(m_name, f_name, args) {
				return res
			}
		}
	}

	// Try with extract_func_info if it returned dots
	func_str, _ := eg.extract_func_info(node)
	if func_str.contains('.') && func_str != func_name {
		parts := func_str.split('.')
		for i := 1; i < parts.len; i++ {
			m_name := parts[..i].join('.')
			f_name := parts[i..].join('.')
			if res := mapper.get_mapping(m_name, f_name, args) {
				return res
			}
		}
	}

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

pub fn (mut eg ExprGen) handle_fallback_call(node ast.Call, func_name_str string, args []string, keyword_args map[string]string, call_sig ?analyzer.CallSignature) string {
	mut func_name := eg.visit(node.func)
	if func_name.len == 0 { func_name = func_name_str }
	if func_name in eg.state.renamed_functions { func_name = eg.state.renamed_functions[func_name] }

	mut final_raw_args := args.clone()
	for k, v in keyword_args {
		final_raw_args << '${k}=${v}'
	}

	final_args := eg.process_mutated_args(func_name, final_raw_args, call_sig)
	return '${func_name}(${final_args.join(', ')})'
}

pub fn (mut eg ExprGen) handle_object_method_call(node ast.Call, func_node ast.Expression, func_name_str string, args []string) ?string {
	if func_node !is ast.Attribute { return none }
	attr := (func_node as ast.Attribute).attr
	receiver_expr := (func_node as ast.Attribute).value
	mut obj_type_raw := eg.guess_type(receiver_expr)
	mut obj := eg.visit(receiver_expr)
	
	// Check for receiver narrowing
	receiver_token := receiver_expr.get_token()
	loc_key := '${receiver_token.line}:${receiver_token.column}'
	if narrowed := eg.analyzer.location_map[loc_key] {
		v_narrowed := eg.map_python_type(narrowed, false)
		v_obj_base := eg.map_python_type(obj_type_raw, false)
		if v_narrowed != v_obj_base && v_narrowed != 'Any' {
			obj = "(${obj} as ${v_narrowed})"
			obj_type_raw = narrowed
		}
	}
	obj_type := eg.map_python_type(obj_type_raw, false)
	mut recv := "${obj}"

	// List methods
	if obj_type.starts_with('[]') || obj_type == 'Any' {
		if attr == 'append' && args.len == 1 { return '${obj} << ${args[0]}' }
		if attr == 'extend' && args.len == 1 { return '${obj} << ${args[0]}' }
		if attr == 'pop' {
			if args.len == 0 { return '${obj}.pop()' }
			eg.state.used_builtins['py_list_pop_at'] = true
			return 'py_list_pop_at(mut ${obj}, ${args[0]})'
		}
		if attr == 'remove' && args.len == 1 {
			eg.state.used_builtins['py_list_remove'] = true
			return 'py_list_remove(mut ${obj}, ${args[0]})'
		}
		if attr == 'sort' {
			// simplified: always maps to .sort() or use py_sorted
			return '${obj}.sort()'
		}
	}

	// String methods
	mut current_type := obj_type
	receiver_token_str := receiver_expr.get_token()
	loc_key_str := '${receiver_token_str.line}:${receiver_token_str.column}'
	if narrowed := eg.analyzer.location_map[loc_key_str] {
		current_type = eg.map_python_type(narrowed, false)
	} else if inferred := eg.analyzer.get_type(eg.analyzer.render_expr(receiver_expr)) {
		if inferred != 'Any' && inferred != 'unknown' {
			current_type = eg.map_python_type(inferred, false)
		}
	}
		if current_type == 'string' || current_type == 'Any' {
		if attr == 'lower' { return '${recv}.to_lower()' }
		if attr == 'upper' { return '${recv}.to_upper()' }
		if attr == 'capitalize' { return '${recv}.capitalize()' }
		if attr == 'title' { return '${recv}.title()' }
		if attr == 'strip' { return if args.len == 0 { '${recv}.trim_space()' } else { '${recv}.trim(${args[0]})' } }
		if attr == 'split' { return if args.len == 0 { '${recv}.fields()' } else { '${recv}.split(${args[0]})' } }
		if attr == 'join' && args.len == 1 { return '${args[0]}.join(${recv})' }
		if attr == 'startswith' && args.len >= 1 { return '${recv}.starts_with(${args[0]})' }
		if attr == 'endswith' && args.len >= 1 { return '${recv}.ends_with(${args[0]})' }
		if attr == 'isdigit' { return '${recv}.runes().all(it.is_digit())' }
		if attr == 'isalpha' { return '${recv}.runes().all(it.is_letter())' }
		if attr == 'isalnum' { return '${recv}.runes().all(it.is_letter() || it.is_digit())' }
		if attr == 'replace' { return if args.len == 2 { '${recv}.replace(${args[0]}, ${args[1]})' } else { '${recv}.replace_n(${args[0]}, ${args[1]}, ${args[2]})' } }
	}

	return none
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
			last_dot := sym.last_index('.') or { -1 }
			if last_dot != -1 {
				return sym[..last_dot], sym[last_dot+1..]
			}
		}
	}
	return '', func_name_str
}
