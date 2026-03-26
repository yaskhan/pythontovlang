module pydantic_support

import ast

pub struct PydanticFieldProcessor {}

pub fn new_pydantic_field_processor() PydanticFieldProcessor {
	return PydanticFieldProcessor{}
}

pub fn (p PydanticFieldProcessor) extract(node ast.AnnAssign, mut env PydanticVisitEnv) PydanticFieldInfo {
	mut info := PydanticFieldInfo{
		name:        'unknown'
		type_str:    'Any'
		default_val: ''
		repr:        true
	}

	if node.target is ast.Name {
		info.name = sanitize_name(node.target.id, false)
	} else if node.target is ast.Attribute {
		info.name = sanitize_name(node.target.attr, false)
	}

	annotation := node.annotation
	mut type_expr := annotation

	if annotation is ast.Subscript {
		if annotation.value is ast.Name && annotation.value.id == 'Annotated' {
			slice_expr := annotation.slice
			if slice_expr is ast.Tuple {
				if slice_expr.elements.len > 0 {
					type_expr = slice_expr.elements[0]
					for meta in slice_expr.elements[1..] {
						if meta is ast.Call && PydanticDetector{}.is_pydantic_field(meta) {
							p.parse_field_call(meta, mut info, mut env)
							break
						}
					}
				}
			}
		}
	}

	info.type_str = env.visit_expr_fn(type_expr)
	info.is_optional = info.type_str.starts_with('?')

	if value := node.value {
		if value is ast.Call && PydanticDetector{}.is_pydantic_field(value) {
			p.parse_field_call(value, mut info, mut env)
		} else if info.default_val.len == 0 {
			info.default_val = env.visit_expr_fn(value)
		}
	}

	return info
}

fn (p PydanticFieldProcessor) parse_field_call(node ast.Call, mut info PydanticFieldInfo, mut env PydanticVisitEnv) {
	_ = p
	for keyword in node.keywords {
		if keyword.arg.len == 0 {
			continue
		}
		val := env.visit_expr_fn(keyword.value)
		match keyword.arg {
			'alias' {
				info.alias = trim_quotes(val)
			}
			'default' {
				if val != 'none' && val.len > 0 {
					info.default_val = val
				}
			}
			'default_factory' {
				env.state.pending_llm_call_comments << "//##LLM@@ Pydantic 'Field(default_factory=...)' detected on field '${info.name}'. This is not fully supported by the transpiler. Please manually initialize the default value in the V struct or factory."
				if info.default_val.len == 0 {
					info.default_val = 'none'
				}
			}
			'gt' {
				info.gt = val
			}
			'lt' {
				info.lt = val
			}
			'ge' {
				info.ge = val
			}
			'le' {
				info.le = val
			}
			'max_length' {
				info.max_length = val
			}
			'min_length' {
				info.min_length = val
			}
			'pattern', 'regex' {
				info.pattern = val
			}
			'multiple_of' {
				info.multiple_of = val
			}
			'min_items' {
				info.min_items = val
			}
			'max_items' {
				info.max_items = val
			}
			'unique_items' {
				info.unique_items = val == 'true'
			}
			'const' {
				info.const_value = val
			}
			'description' {
				info.description = trim_quotes(val)
			}
			'title' {
				info.title = trim_quotes(val)
			}
			'examples' {
				info.examples = val
			}
			'repr' {
				info.repr = val == 'true'
			}
			'exclude' {
				info.exclude = val == 'true'
			}
			else {}
		}
	}
}

pub fn (p PydanticFieldProcessor) generate_struct_tags(info PydanticFieldInfo) string {
	_ = p
	mut tags := []string{}
	if info.exclude {
		tags << "json: '-'"
	} else if info.alias.len > 0 {
		tags << "json: '${info.alias}'"
	}
	if info.description.len > 0 {
		tags << "description: '${info.description}'"
	}
	if info.title.len > 0 {
		tags << "title: '${info.title}'"
	}
	if tags.len > 0 {
		return '[${tags.join('; ')}]'
	}
	return ''
}

pub fn (p PydanticFieldProcessor) generate_validation_code(info PydanticFieldInfo, struct_var string) []string {
	_ = p
	mut code := []string{}
	field_access := '${struct_var}.${info.name}'
	mut indent := '    '
	mut prefix := field_access

	if info.is_optional {
		code << '${indent}if ${field_access} != none {'
		indent += '    '
		prefix = '${field_access}?'
	}
	if info.gt.len > 0 {
		code << '${indent}if ${prefix} <= ${info.gt} { return error("Validation Error: ${info.name} must be greater than ${info.gt}") }'
	}
	if info.lt.len > 0 {
		code << '${indent}if ${prefix} >= ${info.lt} { return error("Validation Error: ${info.name} must be less than ${info.lt}") }'
	}
	if info.ge.len > 0 {
		code << '${indent}if ${prefix} < ${info.ge} { return error("Validation Error: ${info.name} must be greater than or equal to ${info.ge}") }'
	}
	if info.le.len > 0 {
		code << '${indent}if ${prefix} > ${info.le} { return error("Validation Error: ${info.name} must be less than or equal to ${info.le}") }'
	}
	if info.max_length.len > 0 {
		code << '${indent}if ${prefix}.len > ${info.max_length} { return error("Validation Error: ${info.name} length must be <= ${info.max_length}") }'
	}
	if info.min_length.len > 0 {
		code << '${indent}if ${prefix}.len < ${info.min_length} { return error("Validation Error: ${info.name} length must be >= ${info.min_length}") }'
	}
	if info.pattern.len > 0 {
		code << '${indent}// pattern validation for ${info.name}: ${info.pattern}'
	}
	if info.multiple_of.len > 0 {
		code << '${indent}if ${prefix} % ${info.multiple_of} != 0 { return error("Validation Error: ${info.name} must be multiple of ${info.multiple_of}") }'
	}
	if info.min_items.len > 0 {
		code << '${indent}if ${prefix}.len < ${info.min_items} { return error("Validation Error: ${info.name} length must be >= ${info.min_items}") }'
	}
	if info.max_items.len > 0 {
		code << '${indent}if ${prefix}.len > ${info.max_items} { return error("Validation Error: ${info.name} length must be <= ${info.max_items}") }'
	}
	if info.unique_items {
		code << '${indent}// unique_items validation for ${info.name}'
	}
	if info.const_value.len > 0 {
		code << '${indent}if ${prefix} != ${info.const_value} { return error("Validation Error: ${info.name} must be ${trim_quotes(info.const_value)}") }'
	}
	if info.is_optional {
		code << '    }'
	}
	return code
}
