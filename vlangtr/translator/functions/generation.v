module functions

import ast
import base

pub struct FunctionsGenerationHandler {}

pub fn (h FunctionsGenerationHandler) generate_function(node &ast.FunctionDef, struct_name string, mut env FunctionVisitEnv) {
	is_method := struct_name.len > 0
	mut annotations_data := map[string]string{}
	
	mut output := []string{}
	
	// Decorators
	// Decorators Analysis
	mut is_static := false
	mut is_deprecated := false
	mut deprecated_message := ''
	mut cache_wrapper_needed := false
	mut injected_start := []string{}
	mut injected_end := []string{}
	
	for decorator in node.decorator_list {
		mut dec_name := ''
		if decorator is ast.Call {
			dec_name = env.visit_expr_fn(decorator.func)
		} else {
			dec_name = env.visit_expr_fn(decorator)
		}
		
		output << '// @${dec_name}'
		
		if dec_name.ends_with('staticmethod') {
			is_static = true
		} else if dec_name.ends_with('classmethod') {
			is_static = true
		} else if dec_name.ends_with('lru_cache') {
			cache_wrapper_needed = true
		} else if dec_name in ['timer', 'log'] {
			injected_start << "println('Start ${node.name}...')"
			injected_end << "defer { println('End ${node.name}...') }"
		} else if dec_name.ends_with('deprecated') {
			is_deprecated = true
			if decorator is ast.Call && decorator.args.len > 0 {
				deprecated_message = env.visit_expr_fn(decorator.args[0]).trim("'\"")
			}
		}
	}

	mut args := node.args.posonlyargs.clone()
	args << node.args.args
	args << node.args.kwonlyargs

	mut receiver_str := ''
	mut func_name := sanitize_name(node.name, false)
	orig_name := node.name
	
	// Name mangling for static/class methods
	if is_method && is_static {
		func_name = '${struct_name}_${func_name}'
	}

	// Receiver handling
	mut receiver_name := ''
	if is_method && args.len > 0 && args[0].arg in ['self', 'cls'] {
		if !is_static {
			mut mut_pfx := ''
			if h.is_mutating_method(node, struct_name, &env) {
				mut_pfx = 'mut '
			}
			gen_s := if env.state.current_class_generics.len > 0 {
				'[${env.state.current_class_generics.join(", ")}]'
			} else { '' }
			receiver_name = args[0].arg
			receiver_str = '(${mut_pfx}${receiver_name} ${struct_name}${gen_s}) '
		}
		args = args[1..].clone()
	}

	// Unittest special handling
	if env.state.current_class_is_unittest {
		if node.name.starts_with('test_') {
			func_name = '${node.name}_${struct_name}'
			receiver_str = ''
		} else if node.name in ['setUp', 'tearDown'] {
			output << '// ${node.name} method in unittest ignored'
			env.emit_fn(output.join('\n'))
			return
		}
	}

	// Dunder renames
	if orig_name == '__init__' {
		func_name = 'init'
	} else if orig_name == '__post_init__' {
		func_name = 'post_init'
	} else if orig_name == '__str__' {
		func_name = 'str'
	} else if orig_name == '__repr__' {
		func_name = 'str' // fallback
	}

	// Args processing
	mut args_str_list := []string{}
	mut args_names := []string{}
	for arg in args {
		name := sanitize_name(arg.arg, false)
		args_names << name
		mut a_type := 'Any'
		if ann := arg.annotation {
			a_type = env.map_annotation_fn(ann)
		}
		args_str_list << '${name} ${a_type}'
		annotations_data[name] = a_type
	}

	if vararg := node.args.vararg {
		name := sanitize_name(vararg.arg, false)
		args_names << '...${name}'
		mut a_type := 'Any'
		if ann := vararg.annotation {
			a_type = env.map_annotation_fn(ann)
		}
		args_str_list << '${name} ...${a_type}'
		annotations_data[name] = a_type
	}

	mut ret_type := 'void'
	if ann := node.returns {
		ret_type = env.map_annotation_fn(ann)
	}
	if ret_type != 'void' { annotations_data['return'] = ret_type }

	if is_deprecated {
		if deprecated_message.len > 0 {
			output << '@[deprecated: \'${deprecated_message}\']'
		} else {
			output << '@[deprecated]'
		}
	}

	pub_pfx := if env.state.is_exported(node.name) { 'pub ' } else { '' }
	ret_suffix := if ret_type != 'void' { ' ${ret_type}' } else { '' }
	
	real_func_name := if cache_wrapper_needed { '${func_name}__impl' } else { func_name }
	
	output << '${pub_pfx}fn ${receiver_str}${real_func_name}(${args_str_list.join(", ")})${ret_suffix} {'
	for start_stmt in injected_start {
		output << '    ${start_stmt}'
	}
	for end_stmt in injected_end {
		output << '    ${end_stmt}'
	}
	
	env.emit_fn(output.join('\n'))
	
	env.state.indent_level++
	env.push_scope_fn()
	
	for stmt in node.body {
		env.visit_stmt_fn(stmt)
	}

	env.pop_scope_fn()
	env.state.indent_level--
	env.emit_fn('}')

	if cache_wrapper_needed {
		cache_name := if is_method { '${struct_name.to_lower()}_${func_name}_cache' } else { '${func_name}_cache' }
		env.emit_constant_fn('mut ${cache_name} := map[string]${if ret_type == "void" { "int" } else { ret_type }}{ }')
		
		mut key_parts := []string{}
		if receiver_name.len > 0 { key_parts << '\${${receiver_name}}' }
		for name in args_names { key_parts << '\${${name}}' }
		key_expr := if key_parts.len == 0 { "'__no_args__'" } else { "'${key_parts.join("_")}'" }
		
		call_prefix := if receiver_name.len > 0 { '${receiver_name}.' } else { '' }
		
		mut wrapper := []string{}
		wrapper << 'fn ${receiver_str}${func_name}(${args_str_list.join(", ")})${ret_suffix} {'
		wrapper << '    key := ${key_expr}'
		wrapper << '    if key in ${cache_name} {'
		wrapper << '        return ${cache_name}[key]'
		wrapper << '    }'
		wrapper << '    res := ${call_prefix}${real_func_name}(${args_names.join(", ")})'
		wrapper << '    ${cache_name}[key] = res'
		wrapper << '    return res'
		wrapper << '}'
		env.emit_fn(wrapper.join('\n'))
	}

	// Metadata (__annotations__)
	if annotations_data.len > 0 {
		mut anno_parts := []string{}
		for k, v in annotations_data {
			anno_parts << "'${k}': '${v}'"
		}
		const_name := base.to_snake_case('${struct_name}_${func_name}_annotations')
		env.emit_constant_fn('pub const ${const_name} = { ${anno_parts.join(", ")} }')
	}
}

fn (h FunctionsGenerationHandler) is_static_or_classmethod(node &ast.FunctionDef, env &FunctionVisitEnv) bool {
	for dec in node.decorator_list {
		name := env.visit_expr_fn(dec)
		if name in ['staticmethod', 'classmethod'] { return true }
	}
	return false
}

fn (h FunctionsGenerationHandler) is_mutating_method(node &ast.FunctionDef, class_name string, env &FunctionVisitEnv) bool {
	if node.decorator_list.len > 0 {
		for dec in node.decorator_list {
			name := env.visit_expr_fn(dec)
			if name.ends_with('staticmethod') || name.ends_with('classmethod') { return false }
		}
	}
	
	// Scan body for assignments to self
	for stmt in node.body {
		if stmt is ast.Assign {
			for tgt in stmt.targets {
				if tgt is ast.Attribute {
					val := tgt.value
					if val is ast.Name && val.id == 'self' {
						return true
					}
				}
			}
		} else if stmt is ast.AugAssign {
			tgt := stmt.target
			if tgt is ast.Attribute {
				val := tgt.value
				if val is ast.Name && val.id == 'self' {
					return true
				}
			}
		}
	}
	
	return node.name == '__init__'
}

