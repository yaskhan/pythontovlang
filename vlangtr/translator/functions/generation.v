module functions

import ast
import base

pub struct FunctionsGenerationHandler {}

pub fn (h FunctionsGenerationHandler) generate_function(node &ast.FunctionDef, struct_name string, mut env FunctionVisitEnv) {
	is_method := struct_name.len > 0
	mut annotations_data := map[string]string{}
	
	mut output := []string{}
	
	// Decorators
	mut is_deprecated := false
	mut deprecated_message := ''
	for decorator in node.decorator_list {
		mut dec_str := ''
		if decorator is ast.Call {
			func := env.visit_expr_fn(decorator.func)
			mut dec_args := []string{}
			for arg in decorator.args {
				dec_args << env.visit_expr_fn(arg)
			}
			for kw in decorator.keywords {
				dec_args << '${kw.arg}=${env.visit_expr_fn(kw.value)}'
			}
			dec_str = '${func}(${dec_args.join(", ")})'
			if (func == 'deprecated' || func == 'warnings.deprecated') && dec_args.len > 0 {
				is_deprecated = true
				deprecated_message = dec_args[0].trim("'\"")
			}
		} else {
			dec_str = env.visit_expr_fn(decorator)
			if dec_str == 'deprecated' {
				is_deprecated = true
			}
		}
		output << '// @${dec_str}'
	}

	mut args := node.args.posonlyargs.clone()
	args << node.args.args
	args << node.args.kwonlyargs

	mut receiver_str := ''
	mut func_name := sanitize_name(node.name, false)
	orig_name := node.name
	
	// Receiver handling
	if is_method && args.len > 0 && args[0].arg in ['self', 'cls'] {
		if !h.is_static_or_classmethod(node, &env) {
			mut mut_pfx := ''
			if h.is_mutating_method(node, struct_name, &env) {
				mut_pfx = 'mut '
			}
			gen_s := if env.state.current_class_generics.len > 0 {
				'[${env.state.current_class_generics.join(", ")}]'
			} else { '' }
			receiver_str = '(${mut_pfx}${args[0].arg} ${struct_name}${gen_s}) '
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
	for arg in args {
		name := sanitize_name(arg.arg, false)
		mut a_type := 'Any'
		if ann := arg.annotation {
			a_type = env.map_annotation_fn(ann)
		}
		
		is_mut := false // mutability analysis could be deeper
		args_str_list << '${if is_mut { "mut " } else { "" }}${name} ${a_type}'
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
	
	output << '${pub_pfx}fn ${receiver_str}${func_name}(${args_str_list.join(", ")})${ret_suffix} {'
	env.emit_fn(output.join('\n'))
	
	env.state.indent_level++
	env.push_scope_fn()
	
	for stmt in node.body {
		env.visit_stmt_fn(stmt)
	}

	env.pop_scope_fn()
	env.state.indent_level--
	env.emit_fn('}')

	// Metadata (__annotations__)
	if annotations_data.len > 0 {
		mut anno_parts := []string{}
		for k, v in annotations_data {
			anno_parts << "'${k}': '${v}'"
		}
		const_name := base.to_snake_case('${struct_name}_${func_name}__annotations__')
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
	// Simple heuristic or mutability map check
	return true
}

