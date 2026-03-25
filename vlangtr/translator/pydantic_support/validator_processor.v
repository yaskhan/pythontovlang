module pydantic_support

import ast

pub struct PydanticValidatorProcessor {}

pub fn new_pydantic_validator_processor() PydanticValidatorProcessor {
	return PydanticValidatorProcessor{}
}

pub fn (p PydanticValidatorProcessor) extract_info(node ast.FunctionDef, mut env PydanticVisitEnv) ?PydanticValidatorInfo {
	_ = p
	mut is_field_validator := false
	mut is_model_validator := false
	mut fields := []string{}
	mut mode := 'after'

	for decorator in node.decorator_list {
		mut dec_name := ''
		mut dec_args := []string{}
		mut dec_keywords := map[string]string{}

		if decorator is ast.Name {
			dec_name = decorator.id
		} else if decorator is ast.Attribute {
			dec_name = decorator.attr
		} else if decorator is ast.Call {
			if decorator.func is ast.Name {
				dec_name = decorator.func.id
			} else if decorator.func is ast.Attribute {
				dec_name = decorator.func.attr
			}
			for arg in decorator.args {
				dec_args << env.visit_expr_fn(arg)
			}
			for kw in decorator.keywords {
				if kw.arg.len > 0 {
					dec_keywords[kw.arg] = env.visit_expr_fn(kw.value)
				}
			}
		}

		if dec_name in ['validator', 'field_validator'] {
			is_field_validator = true
			fields << dec_args
			if 'mode' in dec_keywords {
				mode = dec_keywords['mode']
			} else if 'pre' in dec_keywords && dec_keywords['pre'] == 'true' {
				mode = 'before'
			}
		} else if dec_name in ['model_validator', 'root_validator'] {
			is_model_validator = true
			if 'mode' in dec_keywords {
				mode = dec_keywords['mode']
			} else if 'pre' in dec_keywords && dec_keywords['pre'] == 'true' {
				mode = 'before'
			}
		}
	}

	if !is_field_validator && !is_model_validator {
		return none
	}
	return PydanticValidatorInfo{
		name:               node.name
		fields:             fields
		node:               node
		mode:               mode
		is_model_validator: is_model_validator
	}
}

pub fn (p PydanticValidatorProcessor) process(node ast.FunctionDef, mut env PydanticVisitEnv) string {
	_ = p
	_ = env
	return node.name
}
