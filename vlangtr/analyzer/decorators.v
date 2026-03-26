module analyzer

import ast

pub struct DecoratorInfo {
pub mut:
	is_static             bool
	is_property           bool
	is_setter             bool
	is_classmethod        bool
	is_abstract           bool
	decorators_to_handle  []string
	cache_wrapper_needed  bool
	cache_map_name        ?string
	cache_key_type        string
	wrapper_code          []string
	injected_start        []string
	injected_end          []string
	implementation_name   ?string
	deprecated            bool
	deprecated_message    ?string
}

pub struct DecoratorProcessor {
pub mut:
	warnings          []string
	output            []string
	renamed_functions map[string]string
}

pub fn new_decorator_processor() DecoratorProcessor {
	return DecoratorProcessor{
		warnings:          []string{}
		output:            []string{}
		renamed_functions: map[string]string{}
	}
}

pub fn (mut p DecoratorProcessor) analyze(node ast.FunctionDef, current_class ?string) DecoratorInfo {
	mut info := DecoratorInfo{
		cache_key_type: 'string'
	}

	for decorator in node.decorator_list {
		dec_name := p.get_decorator_name(decorator)
		if dec_name.len == 0 {
			continue
		}

		if dec_name == 'computed_field' {
			info.decorators_to_handle << dec_name
			continue
		}

		if dec_name in ['staticmethod', 'abstractstaticmethod'] {
			info.is_static = true
			info.decorators_to_handle << dec_name
		} else if dec_name in ['classmethod', 'abstractclassmethod'] {
			info.is_classmethod = true
			info.is_static = true
			info.decorators_to_handle << dec_name
		} else if dec_name == 'property' {
			info.is_property = true
			info.decorators_to_handle << dec_name
		} else if dec_name == 'setter' {
			info.is_setter = true
			info.decorators_to_handle << dec_name
		} else if dec_name == 'lru_cache' {
			info.cache_wrapper_needed = true
			info.decorators_to_handle << dec_name
		} else if dec_name in ['timer', 'log'] {
			info.injected_start << "println('Start ${node.name}...')"
			info.injected_end << "defer { println('End ${node.name}...') }"
			info.decorators_to_handle << dec_name
		} else if dec_name == 'deprecated' {
			info.deprecated = true
			if decorator is ast.Call && decorator.args.len > 0 {
				if decorator.args[0] is ast.Constant {
					cons := decorator.args[0] as ast.Constant
					info.deprecated_message = cons.value
				}
			}
			info.decorators_to_handle << dec_name
		} else {
			p.warnings << "Custom decorator '${dec_name}' at line ${node.token.line} is not fully supported."
		}
	}

	if info.cache_wrapper_needed {
		mut func_name := node.name
		if func_name in p.renamed_functions {
			func_name = p.renamed_functions[func_name]
		}
		info.implementation_name = '${func_name}__impl'
		if cls := current_class {
			info.cache_map_name = '${cls.to_lower()}_${func_name}_cache'
		} else {
			info.cache_map_name = '${func_name}_cache'
		}
	}

	return info
}

pub fn (p DecoratorProcessor) get_decorator_name(node ast.Expression) string {
	match node {
		ast.Name {
			return node.id
		}
		ast.Call {
			return p.get_decorator_name(node.func)
		}
		ast.Attribute {
			return node.attr
		}
		else {
			return ''
		}
	}
}

pub fn (p DecoratorProcessor) generate_cache_wrapper(info DecoratorInfo, func_name string, args_str string, ret_type string, args_names []string, receiver_str string) string {
	if info.cache_map_name == none {
		return ''
	}
	cache_map_name := info.cache_map_name or { '' }
	implementation_name := info.implementation_name or { func_name + '__impl' }

	mut receiver_name := ''
	if receiver_str.len > 0 {
		parts := receiver_str.trim_space().split(' ')
		if parts.len > 0 && parts[0].starts_with('(') {
			receiver_name = parts[0][1..]
		}
	}

	mut key_parts := []string{}
	if receiver_name.len > 0 {
		key_parts << '${receiver_name}'
	}
	for arg in args_names {
		key_parts << '${arg}'
	}

	key_gen := if key_parts.len == 0 {
		"'__no_args__'"
	} else if key_parts.len == 1 {
		"'${key_parts[0]}'"
	} else {
		"'${key_parts.join('_')}'"
	}

	mut call_prefix := ''
	if receiver_name.len > 0 {
		call_prefix = '${receiver_name}.'
	}

	call_args := args_names.join(', ')
	map_decl := 'mut ${cache_map_name} := map[string]${ret_type}{}'

	return '
${map_decl}

fn ${receiver_str}${func_name}(${args_str}) ${ret_type} {
	key := ${key_gen}
	if key in ${cache_map_name} {
		return ${cache_map_name}[key]
	}
	res := ${call_prefix}${implementation_name}(${call_args})
	${cache_map_name}[key] = res
	return res
}
'.trim_space()
}
