module base

import ast

// get_scc_prefix builds a stable per-file prefix used for SCC symbol disambiguation.
pub fn get_scc_prefix(file_path string) string {
	mut scc_base := file_path.replace('.py', '').replace('/', '__').replace('\\', '__').replace('.',
		'__')
	if scc_base.len == 0 {
		scc_base = 'py_mod'
	}
	return scc_base
}

// check_experimental_type appends a warning for experimental type usage.
pub fn check_experimental_type(mut warnings []string, type_str string, line int, experimental_enabled bool) {
	if type_str.contains('TypeForm') && !experimental_enabled {
		warnings << "Experimental feature 'TypeForm' used at line ${line} without --experimental flag."
	}
}

// is_literal_string_expr checks if expression can be treated as LiteralString.
pub fn is_literal_string_expr_state(node ast.Expression, type_map map[string]string) bool {
	if node is ast.Constant {
		return node.token.typ == .string_tok || node.token.typ == .fstring_tok
			|| node.token.typ == .tstring_tok
	}
	if node is ast.JoinedStr {
		for v in node.values {
			if !is_literal_string_expr_state(v, type_map) {
				return false
			}
		}
		return true
	}
	if node is ast.FormattedValue {
		return is_literal_string_expr_state(node.value, type_map)
	}
	if node is ast.BinaryOp && node.op.value == '+' {
		return is_literal_string_expr_state(node.left, type_map)
			&& is_literal_string_expr_state(node.right, type_map)
	}
	if node is ast.Name {
		return (type_map[node.id] or { '' }) == 'LiteralString'
	}
	return false
}

// infer_generator_types infers simple loop variable types from a comprehension generator.
pub fn infer_generator_types(gen ast.Comprehension, mut type_map map[string]string, guess_type_fn fn (ast.Expression) string) {
	if gen.iter is ast.Call {
		iter_call := gen.iter
		if iter_call.func is ast.Name {
			func_name := iter_call.func.id
			if func_name == 'range' {
				if gen.target is ast.Name {
					type_map[gen.target.id] = 'int'
				}
				return
			}
			if func_name == 'zip' {
				if gen.target is ast.Tuple {
					for i, arg in iter_call.args {
						if i >= gen.target.elements.len {
							break
						}
						if gen.target.elements[i] is ast.Name {
							target_node := gen.target.elements[i] as ast.Name
							target_name := target_node.id
							if arg is ast.List && arg.elements.len > 0 {
								type_map[target_name] = guess_type_fn(arg.elements[0])
							} else if arg is ast.Call {
								if arg.func is ast.Name && arg.func.id == 'range' {
									type_map[target_name] = 'int'
								}
							} else if arg is ast.Name {
								arg_type := type_map[arg.id] or { 'Any' }
								if arg_type.starts_with('[]') {
									type_map[target_name] = arg_type[2..]
								} else if arg_type == 'string' {
									type_map[target_name] = 'u8'
								}
							}
						}
					}
				}
			}
		}
	}

	if gen.iter is ast.List && gen.iter.elements.len > 0 {
		elt_type := guess_type_fn(gen.iter.elements[0])
		if gen.target is ast.Name {
			type_map[gen.target.id] = elt_type
		}
	}
}
