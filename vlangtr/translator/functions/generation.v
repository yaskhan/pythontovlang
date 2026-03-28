module functions

import ast
import base

pub struct FunctionsGenerationHandler {}

pub fn (h FunctionsGenerationHandler) generate_function(
	node &ast.FunctionDef,
	struct_name string,
	mut env FunctionVisitEnv,
	mut m FunctionsModule,
) {
	ov_key := if struct_name.len > 0 { '${struct_name}.${node.name}' } else { node.name }
	if ov_key in env.state.overloaded_signatures {
		m.overload_handler.handle_overloads(node, struct_name, h.get_decorator_info(node, struct_name, env), mut env, mut m)
		return
	}
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
	
	dec_info := h.get_decorator_info(node, struct_name, env)
	
	mut name_remap_revert := map[string]string{}
	defer {
		for k, v in name_remap_revert {
			if v == '__DELETED__' {
				env.state.name_remap.delete(k)
			} else {
				env.state.name_remap[k] = v
			}
		}
	}
	
	if dec_info.is_classmethod {
		if 'cls' in env.state.name_remap {
			name_remap_revert['cls'] = env.state.name_remap['cls']
		} else {
			name_remap_revert['cls'] = '__DELETED__'
		}
		env.state.name_remap['cls'] = struct_name
	}

	mut func_name := sanitize_name(node.name, false)
	mut is_property := dec_info.is_property
	mut is_setter := false
	
	for decorator in node.decorator_list {
		mut dec_name := ''
		if decorator is ast.Call {
			dec_name = env.visit_expr_fn(decorator.func)
		} else {
			dec_name = env.visit_expr_fn(decorator)
		}
		
		output << '// @${dec_name}'
		
		if dec_name.ends_with('.setter') {
			func_name = 'set_${func_name}'
			is_setter = true
		}
		
		if dec_name.ends_with('property') {
			is_property = true
		}
		
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
		} else if is_setter {
			// In V, setters must match the getter's return type.
			mut prop_name := node.name
			// The decorator is `@x.setter`, so we look for property `x`
			for decorator in node.decorator_list {
				dec_name := env.visit_expr_fn(decorator)
				if dec_name.ends_with('.setter') {
					prop_name = dec_name.replace('.setter', '')
					break
				}
			}
			
			lookup_name := if struct_name.len > 0 { '${struct_name}.${prop_name}' } else { prop_name }
			if inferred := env.analyzer.get_type(lookup_name) {
				if inferred != 'Any' && inferred != 'unknown' {
					can_use_union := false
					a_type = env.map_type_fn(inferred, struct_name, can_use_union, true, false)
				}
			}
		}
		args_str_list << '${name} ${a_type}'
		annotations_data[name] = a_type
	}

	if vararg := node.args.vararg {
		name := sanitize_name(vararg.arg, false)
		args_names << '...${name}'
		mut a_type := 'Any'
		if ann := vararg.annotation {
			can_use_union := env.state.current_class == ''
			a_type = env.map_type_fn(env.visit_expr_fn(ann), '', can_use_union, true, false)
		}
		// V varargs use the element type: ...T
		if a_type.starts_with('[]') {
			a_type = a_type[2..]
		}
		args_str_list << '${name} ...${a_type}'
		annotations_data[name] = a_type
	}

	mut ret_type := 'void'
	if ann := node.returns {
		ret_type = env.map_type_fn(env.visit_expr_fn(ann), struct_name, !is_property, true, true)
	}
	if func_name in ['str', 'repr'] {
		ret_type = 'string'
	}
	if ret_type != 'void' { annotations_data['return'] = ret_type }

	if ret_type == 'noreturn' {
		// Handled via attr_pfx below
	}
	
	if is_deprecated {
		if deprecated_message.len > 0 {
			output << '@[deprecated: \'${deprecated_message}\']'
		} else {
			output << '@[deprecated]'
		}
	}

	mut is_noreturn := false
	if ret_type == 'noreturn' {
		is_noreturn = true
		ret_type = 'void'
	}

	pub_pfx := if env.state.is_exported(node.name) { 'pub ' } else { '' }
	ret_suffix := if ret_type != 'void' && !is_noreturn { ' ${ret_type}' } else { '' }
	attr_pfx := if is_noreturn { '[noreturn]\n' } else { '' }
	
	real_func_name := if cache_wrapper_needed { '${func_name}__impl' } else { func_name }
	
	mut func_generics := extract_implicit_generics(node, env.analyzer.type_vars, map[string]bool{},
		env.state.current_class_generics, base.sanitize_name_helper)
	
	if is_method && (is_static || dec_info.is_classmethod) {
		for cg in env.state.current_class_generics {
			if cg !in func_generics { func_generics << cg }
		}
	}
	
	v_gen_map := base.get_generic_map(func_generics, [env.state.current_class_generic_map])
	mut combined_gen_map := env.state.current_class_generic_map.clone()
	for k, v in v_gen_map { combined_gen_map[k] = v }
	
	mut v_gens_to_declare := []string{}
	for py_name in func_generics {
		v_gens_to_declare << combined_gen_map[py_name] or { py_name }
	}
	
	gen_s := base.get_generics_with_variance_str(v_gens_to_declare, combined_gen_map, env.state.generic_variance, env.state.generic_defaults)
	
	output << '${attr_pfx}${pub_pfx}fn ${receiver_str}${real_func_name}${gen_s}(${args_str_list.join(", ")})${ret_suffix} {'
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

fn (h FunctionsGenerationHandler) get_decorator_info(node &ast.FunctionDef, struct_name string, env FunctionVisitEnv) DecoratorInfo {
	mut info := DecoratorInfo{}
	for dec in node.decorator_list {
		mut dec_name := ''
		if dec is ast.Call {
			dec_name = env.visit_expr_fn(dec.func)
		} else {
			dec_name = env.visit_expr_fn(dec)
		}
		
		if dec_name.ends_with('classmethod') {
			info.is_classmethod = true
		} else if dec_name.ends_with('staticmethod') {
			info.is_staticmethod = true
		} else if dec_name.ends_with('property') {
			info.is_property = true
		} else if dec_name.ends_with('setter') {
			info.is_setter = true
		} else if dec_name.ends_with('deleter') {
			info.is_deleter = true
		} else if dec_name.ends_with('deprecated') {
			info.is_deprecated = true
			if dec is ast.Call && dec.args.len > 0 {
				info.deprecated_msg = env.visit_expr_fn(dec.args[0]).trim("'\"")
			}
		}
	}
	return info
}
