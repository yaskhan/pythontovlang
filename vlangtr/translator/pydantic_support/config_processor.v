module pydantic_support

import ast

pub struct PydanticConfigProcessor {}

pub fn new_pydantic_config_processor() PydanticConfigProcessor {
	return PydanticConfigProcessor{}
}

pub fn (p PydanticConfigProcessor) extract(node ast.ClassDef, mut env PydanticVisitEnv) PydanticConfigInfo {
	_ = p
	mut info := PydanticConfigInfo{
		extra:          'ignore'
		allow_mutation: true
	}
	for item in node.body {
		if item is ast.Assign {
			for target in item.targets {
				if target is ast.Name {
					p.process_option(target.id, item.value, mut info, mut env)
				}
			}
		} else if item is ast.AnnAssign {
			if item.target is ast.Name {
				if value := item.value {
					p.process_option(item.target.id, value, mut info, mut env)
				}
			}
		}
	}
	return info
}

pub fn (p PydanticConfigProcessor) extract_from_config_dict(node ast.Call, mut env PydanticVisitEnv) PydanticConfigInfo {
	_ = p
	mut info := PydanticConfigInfo{
		extra:          'ignore'
		allow_mutation: true
	}
	for kw in node.keywords {
		if kw.arg.len > 0 {
			p.process_option(kw.arg, kw.value, mut info, mut env)
		}
	}
	return info
}

fn (p PydanticConfigProcessor) process_option(name string, value_node ast.Expression, mut info PydanticConfigInfo, mut env PydanticVisitEnv) {
	_ = p
	val := env.visit_expr_fn(value_node)
	match name {
		'str_strip_whitespace' {
			info.str_strip_whitespace = val == 'true'
		}
		'str_to_lower' {
			info.str_to_lower = val == 'true'
		}
		'str_to_upper' {
			info.str_to_upper = val == 'true'
		}
		'min_anystr_length' {
			info.min_anystr_length = if val.len > 0 { val.int() } else { -1 }
		}
		'max_anystr_length' {
			info.max_anystr_length = if val.len > 0 { val.int() } else { -1 }
		}
		'validate_all' {
			info.validate_all = val == 'true'
		}
		'validate_assignment' {
			info.validate_assignment = val == 'true'
		}
		'extra' {
			info.extra = trim_quotes(val)
		}
		'allow_mutation' {
			info.allow_mutation = val == 'true'
		}
		else {}
	}
}
