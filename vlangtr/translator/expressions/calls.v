module expressions

import analyzer
import ast
import base

pub fn (mut eg ExprGen) visit_call(node ast.Call) string {
	func_name_str, _ := eg.extract_func_info(node)
	loc_key := '${node.token.line}:${node.token.column}'
	call_sig := eg.get_call_signature(func_name_str, loc_key)
	mut args := eg.process_call_args(node, call_sig)
	_, extra_args, _ := eg.process_keywords(node, call_sig, args)
	if extra_args.len > args.len {
		args = extra_args.clone()
	}

	module_name, func_name := eg.resolve_module_and_func(node, func_name_str)
	full_func_name := eg.visit(node.func)
	if special := eg.handle_special_cases(node, module_name, func_name, full_func_name,
		args, call_sig)
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
		if attr.value is ast.Name && attr.value.id in eg.state.imported_modules {
			return attr.attr, '${eg.state.imported_modules[attr.value.id]}.${attr.attr}'
		}
		return attr.attr, ''
	}
	return eg.visit(node.func), ''
}

pub fn (mut eg ExprGen) get_call_signature(func_name_str string, loc_key string) ?analyzer.CallSignature {
	potential_keys := [loc_key, '${func_name_str}@${loc_key}', func_name_str]
	for key in potential_keys {
		if key in eg.analyzer.call_signatures {
			return eg.analyzer.call_signatures[key]
		}
	}
	for key, sig in eg.analyzer.call_signatures {
		if key == func_name_str || key.ends_with('.${func_name_str}') || key.ends_with('@${loc_key}') {
			return sig
		}
	}
	return none
}

pub fn (mut eg ExprGen) process_call_args(node ast.Call, call_sig ?analyzer.CallSignature) []string {
	mut args := []string{}
	for arg in node.args {
		args << eg.visit(arg)
	}
	if call_sig != none && call_sig or { return args }.has_vararg {
		return args
	}
	return args
}

pub fn (mut eg ExprGen) process_keywords(node ast.Call, call_sig ?analyzer.CallSignature, args []string) (map[string]string, []string, bool) {
	mut keyword_args := map[string]string{}
	mut final_args := args.clone()
	mut needs_comment := false

	mut sig := analyzer.CallSignature{}
	has_sig := call_sig != none
	if has_sig {
		sig = call_sig or { analyzer.CallSignature{} }
	}

	for kw in node.keywords {
		if kw.arg.len == 0 {
			final_args << eg.visit(kw.value)
			needs_comment = true
			continue
		}
		keyword_args[kw.arg] = eg.visit(kw.value)
	}

	if has_sig && sig.arg_names.len > 0 {
		for i := final_args.len; i < sig.arg_names.len; i++ {
			name := sig.arg_names[i]
			if name in keyword_args {
				final_args << keyword_args[name]
				keyword_args.delete(name)
			} else if name in sig.defaults {
				final_args << sig.defaults[name]
			}
		}
		if (sig.has_kwarg || !has_sig) && keyword_args.len > 0 {
			mut items := []string{}
			for key, value in keyword_args {
				items << "'${key}': ${value}"
			}
			final_args << '{${items.join(', ')}}'
			keyword_args.clear()
		}
	} else if keyword_args.len > 0 {
		mut items := []string{}
		for key, value in keyword_args {
			items << "'${key}': ${value}"
		}
		final_args << '{${items.join(', ')}}'
		keyword_args.clear()
	}
	return keyword_args, final_args, needs_comment
}

pub fn (mut eg ExprGen) resolve_module_and_func(node ast.Call, func_name_str string) (string, string) {
	qualified := eg.get_qualified_name_parts(node.func)
	if qualified.len > 0 {
		module_name, func_name := eg.lookup_module(qualified)
		if module_name.len > 0 || func_name.len > 0 {
			return module_name, func_name
		}
	}
	if node.func is ast.Attribute {
		attr := node.func
		if attr.value is ast.Name && attr.value.id in eg.state.imported_modules {
			return eg.state.imported_modules[attr.value.id], attr.attr
		}
	}
	if node.func is ast.Name {
		return eg.resolve_name_call(node.func, func_name_str)
	}
	return '', func_name_str
}

pub fn (mut eg ExprGen) get_qualified_name_parts(func_node ast.Expression) []string {
	match func_node {
		ast.Name {
			return [func_node.id]
		}
		ast.Attribute {
			mut parts := eg.get_qualified_name_parts(func_node.value)
			parts << func_node.attr
			return parts
		}
		else {
			return []string{}
		}
	}
}

pub fn (mut eg ExprGen) lookup_module(qualified_name_parts []string) (string, string) {
	if qualified_name_parts.len == 0 {
		return '', ''
	}
	mut full_parts := qualified_name_parts.clone()
	if qualified_name_parts[0] in eg.state.imported_symbols {
		mut imported_parts := eg.state.imported_symbols[qualified_name_parts[0]].split('.')
		for part in qualified_name_parts[1..] {
			imported_parts << part
		}
		full_parts = imported_parts.clone()
	}
	for i := full_parts.len; i > 0; i-- {
		prefix := full_parts[..i].join('.')
		if prefix in eg.state.imported_modules {
			return eg.state.imported_modules[prefix], full_parts[i..].join('.')
		}
		if prefix in eg.state.imported_modules.values() {
			return prefix, full_parts[i..].join('.')
		}
	}
	if qualified_name_parts.len > 1 && qualified_name_parts[0] == 'os'
		&& qualified_name_parts[1] == 'path' {
		return 'os', qualified_name_parts[1..].join('.')
	}
	return '', ''
}

pub fn (mut eg ExprGen) resolve_name_call(func_node ast.Name, func_name_str string) (string, string) {
	if func_name_str in eg.state.imported_symbols {
		parts := eg.state.imported_symbols[func_name_str].split('.')
		if parts.len > 1 {
			return parts[..parts.len - 1].join('.'), parts.last()
		}
	}
	if func_node.id == 'open' {
		return 'os', 'open'
	}
	if func_node.id in ['hasattr', 'getattr', 'setattr', 'delattr', 'eval', 'exec', 'compile',
		'type', 'super', 'abs', 'pow', 'divmod', 'str', 'String'] {
		return 'builtins', func_node.id
	}
	return '', func_name_str
}

pub fn (mut eg ExprGen) handle_special_cases(node ast.Call, module_name string, func_name string, func_name_str string, args []string, call_sig ?analyzer.CallSignature) ?string {
	_ = call_sig
	// Unittest assertions
	if func_name_str.starts_with('self.assert') {
		if func_name_str == 'self.assert_equal' || func_name_str == 'self.assert_count_equal' {
			return 'assert ${args[0]} == ${args[1]}'
		}
		if func_name_str == 'self.assert_true' {
			return 'assert ${args[0]}'
		}
		if func_name_str == 'self.assert_false' {
			return 'assert !(${args[0]})'
		}
		if func_name_str == 'self.assert_not_equal' {
			return 'assert ${args[0]} != ${args[1]}'
		}
		if func_name_str == 'self.assert_is_none' {
			return 'assert ${args[0]} == none'
		}
		if func_name_str == 'self.assert_is_not_none' {
			return 'assert ${args[0]} != none'
		}
		if func_name_str == 'self.assert_in' {
			return 'assert ${args[0]} in ${args[1]}'
		}
	}

	if func_name_str in eg.state.defined_classes {
		return 'new_${base.to_snake_case(func_name_str)}(${args.join(', ')})'
	}
	if func_name_str == 'cls' && eg.state.current_class.len > 0 {
		if eg.state.current_class_generics.len > 0 && args.len == 0 {
			generics_str := eg.state.current_class_generics.join(', ')
			return '&${eg.state.current_class}[${generics_str}]{}'
		}
		return 'new_${base.to_snake_case(eg.state.current_class)}(${args.join(', ')})'
	}

	if func_name_str in ['get_type_hints', 'get_annotations'] && args.len > 0 {
		return 'py_get_type_hints_generic(${args[0]})'
	}
	if module_name == 'typing' && func_name == 'cast' && args.len >= 2 {
		return '(${args[1]} as ${args[0]})'
	}
	if func_name_str == 'map' && args.len == 2 {
		return '${args[1]}.map(${args[0]})'
	}
	if func_name_str == 'filter' && args.len == 2 {
		return '${args[1]}.filter(${args[0]})'
	}
	if func_name_str == 'NewType' && args.len >= 2 {
		name := args[0].trim("'").trim('"')
		return 'type ${name} = ${args[1]}'
	}
	if module_name == 'unittest' && func_name == 'main' {
		return '// unittest.main() ignored'
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
	if module_name == 'urllib.parse' && func_name == 'urlencode' {
		eg.state.used_builtins['py_urlencode'] = true
		return 'py_urlencode(${args.join(', ')})'
	}
	if module_name == 'urllib.parse' && func_name == 'urlparse' {
		eg.state.used_builtins['py_urlparse'] = true
		return 'py_urlparse(${args.join(', ')})'
	}
	if module_name == 'urllib.parse' && func_name in ['quote', 'quote_plus'] {
		return 'urllib.query_escape(${args.join(', ')})'
	}
	if module_name == 'urllib.parse' && func_name in ['unquote', 'unquote_plus'] {
		eg.state.used_builtins['py_urllib_unquote'] = true
		return 'py_urllib_unquote(${args.join(', ')})'
	}
	if module_name == 'uuid' && func_name == 'uuid4' {
		return 'rand.uuid_v4()'
	}
	if module_name == 'builtins' && func_name in ['str', 'String'] && args.len == 1 && args[0].contains('uuid_v4') {
		return '${args[0]}.str()'
	}
	if module_name == 'os' && func_name == 'open' {
		return 'os.open(${args.join(', ')})'
	}
	if func_name_str == 'print' {
		mut new_args := []string{}
		for arg in args {
			if arg.starts_with("'") && arg.ends_with("'") {
				new_args << arg
			} else {
				new_args << "'\${${arg}}'"
			}
		}
		return 'println(${new_args.join(', ')})'
	}
	if func_name_str == 'input' {
		if args.len > 0 {
			return 'os.input(${args[0]})'
		}
		return 'os.input("")'
	}
	if func_name_str == 'len' && args.len == 1 {
		return '${args[0]}.len'
	}
	if func_name_str == 'int' {
		if args.len == 0 {
			return '0'
		}
		if args.len == 1 {
			arg_type := eg.guess_type(node.args[0])
			if arg_type in ['string', 'LiteralString'] {
				return '${args[0]}.int()'
			}
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
	if func_name_str == 'issubclass' && args.len >= 2 {
		return '${args[0]} in ${args[1]}'
	}
	if func_name_str == 'list' && args.len == 0 {
		return '[]Any{}'
	}
	if func_name_str == 'dict' && args.len == 0 {
		return 'map[string]Any{}'
	}
	if func_name_str == 'Counter' {
		if args.len == 0 {
			return 'map[string]int{}'
		}
		eg.state.used_builtins['py_counter'] = true
		return 'py_counter(${args[0]})'
	}
	if func_name_str == 'defaultdict' && args.len >= 1 {
		// defaultdict(int) -> map[string]int{}
		// defaultdict(list) -> map[string][]int{}
		mut val_type := 'Any'
		if args[0] == 'int' { val_type = 'int' }
		else if args[0] == 'list' { val_type = '[]int' }
		else if args[0] == 'str' { val_type = 'string' }
		return 'map[string]${val_type}{}'
	}
	if func_name_str == 'assert_type' && node.args.len >= 2 {
		actual_type := eg.guess_type(node.args[0])
		expected_raw := eg.visit(node.args[1])
		expected_type := map_assert_type_name(expected_raw)
		if actual_type == expected_type {
			return '// assert_type(${args[0]}, ${expected_raw}) passed statically'
		}
		return "\$compile_error('assert_type failed: expected ${expected_type} but got ${actual_type}')"
	}
	if module_name == 'argparse' && func_name_str in ['ArgumentParser', 'argument_parser'] {
		eg.state.used_builtins['py_argparse_new'] = true
		return 'py_argparse_new()'
	}
	if module_name == 'base64' {
		match func_name_str {
			'b64encode', 'standard_b64encode' {
				eg.state.imported_modules['base64'] = 'base64'
				return 'base64.encode(${args.join(', ')})'
			}
			'b64decode', 'standard_b64decode' {
				eg.state.imported_modules['base64'] = 'base64'
				return 'base64.decode(${args.join(', ')})'
			}
			'urlsafe_b64encode' {
				eg.state.imported_modules['base64'] = 'base64'
				return 'base64.url_encode(${args.join(', ')})'
			}
			'urlsafe_b64decode' {
				eg.state.imported_modules['base64'] = 'base64'
				return 'base64.url_decode(${args.join(', ')})'
			}
			else {}
		}
	}
	if func_name_str == 'bytes' {
		if args.len == 1 {
			return '${args[0]}.bytes()'
		}
		if args.len >= 2 {
			return '${args[0]}.bytes()'
		}
	}
	if module_name == 'array' && func_name_str == 'array' && args.len >= 2 {
		eg.state.used_builtins['py_array'] = true
		return "py_array(${args[0]}, ${args[1]})"
	}
	if func_name_str in ['any', 'all'] && node.args.len == 1 {
		if gen := eg.generator_exp_to_map_expr(node.args[0]) {
			if func_name_str == 'any' {
				eg.state.used_builtins['py_any'] = true
				return 'py_any(${gen})'
			}
			eg.state.used_builtins['py_all'] = true
			return 'py_all(${gen})'
		}
	}
	if func_name_str == 'any' && args.len == 1 {
		eg.state.used_builtins['py_any'] = true
		return 'py_any(${args[0]})'
	}
	if func_name_str == 'all' && args.len == 1 {
		eg.state.used_builtins['py_all'] = true
		return 'py_all(${args[0]})'
	}
	if func_name_str == 'set' && args.len == 0 {
		return 'datatypes.Set[string]{}'
	}
	if func_name_str == 'tuple' && args.len == 1 {
		return args[0]
	}
	if func_name_str == 'range' {
		return 'py_range(${args.join(', ')})'
	}
	if func_name_str == 'enumerate' {
		return 'py_enumerate(${args.join(', ')})'
	}
	if func_name_str == 'zip' {
		return 'py_zip(${args.join(', ')})'
	}
	if func_name_str == 'sorted' {
		eg.state.used_builtins['py_sorted'] = true
		return 'py_sorted(${args.join(', ')}, false)'
	}
	if func_name_str == 'reversed' {
		eg.state.used_builtins['py_reversed'] = true
		return 'py_reversed(${args.join(', ')})'
	}
	if node.func is ast.Attribute && node.func.value is ast.Call && node.func.attr == '__init__' {
		mut full_args := args.clone()
		if full_args.len > 0 {
			full_args = full_args[1..].clone()
		}
		return '${eg.visit(node.func.value)}.${node.func.attr}(${full_args.join(', ')})'
	}
	return none
}

fn (mut eg ExprGen) generator_exp_to_map_expr(expr ast.Expression) ?string {
	if expr is ast.GeneratorExp {
		gen := expr
		if gen.generators.len != 1 {
			return none
		}
		first := gen.generators[0]
		if first.ifs.len > 0 {
			return none
		}
		if first.target !is ast.Name {
			return none
		}
		target := first.target as ast.Name
		iter_expr := eg.visit(first.iter)
		body_expr := eg.visit(gen.elt).replace(target.id, 'it')
		return '${iter_expr}.map(${body_expr})'
	}
	return none
}

pub fn (mut eg ExprGen) handle_via_mapper(node ast.Call, module_name string, func_name string, args []string) ?string {
	_ = eg
	_ = node
	_ = module_name
	_ = func_name
	_ = args
	return none
}

pub fn (mut eg ExprGen) handle_overloads(node ast.Call, call_sig ?analyzer.CallSignature, args []string) ?string {
	_ = node
	if call_sig == none {
		return none
	}
	sig := call_sig or { return none }
	func_name := if node.func is ast.Name {
		node.func.id
	} else if node.func is ast.Attribute {
		node.func.attr
	} else {
		''
	}
	if func_name.len == 0 {
		return none
	}
	final_args := eg.process_mutated_args(func_name, args, call_sig)
	if sig.is_class {
		return '${func_name}(${final_args.join(', ')})'
	}
	return none
}

pub fn (mut eg ExprGen) handle_fallback_call(node ast.Call, func_name_str string, args []string, call_sig ?analyzer.CallSignature) string {
	mut func_name := eg.visit(node.func)
	if func_name in eg.state.renamed_functions {
		func_name = eg.state.renamed_functions[func_name]
	} else if func_name.len == 0 && func_name_str.len > 0 {
		func_name = func_name_str
	}

	final_args := eg.process_mutated_args(func_name, args, call_sig)
	return '${func_name}(${final_args.join(', ')})'
}

pub fn (mut eg ExprGen) process_mutated_args(func_name_str string, args []string, call_sig ?analyzer.CallSignature) []string {
	_ = call_sig
	mut final_args := []string{}
	mut mutated := map[int]bool{}
	if func_name_str in eg.analyzer.func_param_mutability {
		for idx in eg.analyzer.func_param_mutability[func_name_str] {
			mutated[idx] = true
		}
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

fn map_assert_type_name(type_name string) string {
	return match type_name {
		'float' { 'f64' }
		'int' { 'int' }
		'str' { 'string' }
		'bool' { 'bool' }
		else { type_name }
	}
}
