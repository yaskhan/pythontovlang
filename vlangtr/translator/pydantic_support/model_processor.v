module pydantic_support

import ast
import base

pub struct PydanticModelProcessor {
pub:
	field_processor     PydanticFieldProcessor
	validator_processor PydanticValidatorProcessor
	config_processor    PydanticConfigProcessor
	detector            PydanticDetector
}

pub fn new_pydantic_model_processor() PydanticModelProcessor {
	return PydanticModelProcessor{
		field_processor:     new_pydantic_field_processor()
		validator_processor: new_pydantic_validator_processor()
		config_processor:    new_pydantic_config_processor()
		detector:            PydanticDetector{}
	}
}

pub fn (p PydanticModelProcessor) process_model(node ast.ClassDef, mut env PydanticVisitEnv) string {
	_ = p
	if !PydanticDetector{}.is_pydantic_model(node) {
		return ''
	}

	struct_name := sanitize_name(node.name, true)
	export := if env.state.is_exported(node.name) { 'pub ' } else { '' }

	mut fields := []PydanticFieldInfo{}
	mut methods := []ast.FunctionDef{}
	mut validators := []PydanticValidatorInfo{}
	mut config := PydanticConfigInfo{
		extra:          'ignore'
		allow_mutation: true
	}
	mut has_config := false

	for item in node.body {
		if item is ast.AnnAssign {
			fields << p.field_processor.extract(item, mut env)
		} else if item is ast.FunctionDef {
			if item.name == '__init__' {
				methods << item
				continue
			}
			if v_info := p.validator_processor.extract_info(item, mut env) {
				validator := v_info
				validators << validator
			} else {
				methods << item
			}
		} else if item is ast.ClassDef {
			if p.detector.is_config_class(item) {
				config = p.config_processor.extract(item, mut env)
				has_config = true
			}
		} else if item is ast.Assign {
			for target in item.targets {
				if target is ast.Name && target.id == 'model_config' {
					if p.detector.is_config_dict(item.value) {
						if item.value is ast.Call {
							config = p.config_processor.extract_from_config_dict(item.value, mut env)
							has_config = true
						}
					}
				}
			}
		}
	}

	mut struct_lines := []string{}
	struct_lines << '// Pydantic Model: ${struct_name}'
	if has_config {
		mut config_bits := []string{}
		if config.str_strip_whitespace {
			config_bits << 'str_strip_whitespace=true'
		}
		if config.str_to_lower {
			config_bits << 'str_to_lower=true'
		}
		if config.str_to_upper {
			config_bits << 'str_to_upper=true'
		}
		if config.min_anystr_length >= 0 {
			config_bits << 'min_anystr_length=${config.min_anystr_length}'
		}
		if config.max_anystr_length >= 0 {
			config_bits << 'max_anystr_length=${config.max_anystr_length}'
		}
		if config.validate_all {
			config_bits << 'validate_all=true'
		}
		if config.validate_assignment {
			config_bits << 'validate_assignment=true'
		}
		if config.extra.len > 0 {
			config_bits << 'extra=${config.extra}'
		}
		if !config.allow_mutation {
			config_bits << 'allow_mutation=false'
		}
		if config_bits.len > 0 {
			struct_lines << '// Config: ${config_bits.join(", ")}'
		}
	}

	struct_lines << '@[params]'
	struct_lines << '${export}struct ${struct_name} {'
	if env.state.is_exported(node.name) {
		if !config.allow_mutation {
			struct_lines << 'pub:'
		} else {
			struct_lines << 'pub mut:'
		}
	} else if config.allow_mutation {
		struct_lines << 'mut:'
	}

	for field in fields {
		tag := p.field_processor.generate_struct_tags(field)
		mut line := '    ${field.name} ${field.type_str}'
		if tag.len > 0 {
			line += ' ${tag}'
		}
		if field.default_val.len > 0 {
			line += ' = ${field.default_val}'
		}
		struct_lines << line
	}
	struct_lines << '}'
	env.emit_struct_fn(struct_lines.join('\n'))

	if struct_name !in env.state.defined_classes {
		env.state.defined_classes[struct_name] = map[string]bool{}
	}
	env.state.defined_classes[struct_name]['has_init'] = false
	env.state.defined_classes[struct_name]['has_new'] = false
	env.state.defined_classes[struct_name]['is_pydantic'] = true

	factory_code := p.generate_factory(struct_name, fields, export, mut env)
	if factory_code.len > 0 {
		env.emit_function_fn(factory_code)
		env.state.defined_classes[struct_name]['has_init'] = true
		env.state.defined_classes[struct_name]['has_new'] = true
	}

	validate_code := p.generate_validate_method(struct_name, fields, validators, config, export)
	if validate_code.len > 0 {
		env.emit_function_fn(validate_code)
	}

	for method in methods {
		env.visit_stmt_fn(method)
	}

	return ''
}

fn (p PydanticModelProcessor) generate_validate_method(
	struct_name string,
	fields []PydanticFieldInfo,
	validators []PydanticValidatorInfo,
	config PydanticConfigInfo,
	export string,
) string {
	mut code := []string{}
	mut has_validation := false

	code << '${export}fn (mut m ${struct_name}) validate() ! {'

	if config.str_strip_whitespace || config.str_to_lower || config.str_to_upper
		|| config.min_anystr_length >= 0 || config.max_anystr_length >= 0 {
		for field in fields {
			if !field.type_str.contains('string') {
				continue
			}
			if config.str_strip_whitespace {
				code << '    m.${field.name} = m.${field.name}.trim_space()'
				has_validation = true
			}
			if config.str_to_lower {
				code << '    m.${field.name} = m.${field.name}.to_lower()'
				has_validation = true
			}
			if config.str_to_upper {
				code << '    m.${field.name} = m.${field.name}.to_upper()'
				has_validation = true
			}
			if config.min_anystr_length >= 0 {
				code << '    if m.${field.name}.len < ${config.min_anystr_length} { return error("Validation Error: ${field.name} length must be >= ${config.min_anystr_length}") }'
				has_validation = true
			}
			if config.max_anystr_length >= 0 {
				code << '    if m.${field.name}.len > ${config.max_anystr_length} { return error("Validation Error: ${field.name} length must be <= ${config.max_anystr_length}") }'
				has_validation = true
			}
		}
	}

	for field in fields {
		for line in p.field_processor.generate_validation_code(field, 'm') {
			code << line
			has_validation = true
		}
	}

	for validator in validators {
		if validator.is_model_validator {
			code << '    // validator: ${validator.name}'
		} else {
			code << '    // field validator: ${validator.name} (${validator.fields.join(", ")})'
		}
		has_validation = true
	}

	if !has_validation && !config.validate_all {
		return ''
	}

	code << '}'
	return code.join('\n')
}

fn (p PydanticModelProcessor) generate_factory(
	struct_name string,
	fields []PydanticFieldInfo,
	export string,
	mut env PydanticVisitEnv,
) string {
	_ = p
	_ = env
	factory_name := base.get_factory_name(struct_name, map[string][]string{})
	mut required := []PydanticFieldInfo{}
	for field in fields {
		if field.default_val.len == 0 && !field.is_optional {
			required << field
		}
	}

	mut args := []string{}
	for field in required {
		args << '${field.name} ${field.type_str}'
	}

	mut code := []string{}
	code << '// ${factory_name} creates a new ${struct_name} and validates it.'
	code << '${export}fn ${factory_name}(${args.join(", ")}) !${struct_name} {'
	code << '    mut self := ${struct_name}{'
	for field in fields {
		if field.default_val.len == 0 && !field.is_optional {
			code << '        ${field.name}: ${field.name}'
		} else if field.default_val.len > 0 {
			code << '        ${field.name}: ${field.default_val}'
		} else {
			code << '        ${field.name}: none'
		}
	}
	code << '    }'
	code << '    self.validate() or { return err }'
	code << '    return self'
	code << '}'
	return code.join('\n')
}
