module classes

import ast
import pydantic_support

pub struct ClassPydanticHandler {}

pub fn (h ClassPydanticHandler) is_pydantic_model(node ast.ClassDef) bool {
	_ = h
	return pydantic_support.PydanticDetector{}.is_pydantic_model(node)
}

pub fn (h ClassPydanticHandler) is_pydantic_field(node ast.Statement) bool {
	_ = h
	if node is ast.AnnAssign {
		if value := node.value {
			return pydantic_support.PydanticDetector{}.is_pydantic_field(value)
		}
	}
	return false
}

pub fn (h ClassPydanticHandler) is_validator_decorator(node ast.Expression) bool {
	_ = h
	return pydantic_support.PydanticDetector{}.is_validator_decorator(node)
}

pub fn (h ClassPydanticHandler) is_computed_field(node ast.Expression) bool {
	_ = h
	return pydantic_support.PydanticDetector{}.is_computed_field(node)
}

pub fn (h ClassPydanticHandler) is_config_dict(node ast.Statement) bool {
	_ = h
	if node is ast.Assign {
		return pydantic_support.PydanticDetector{}.is_config_dict(node.value)
	}
	return false
}

pub fn (h ClassPydanticHandler) is_config_class(node ast.ClassDef) bool {
	_ = h
	return pydantic_support.PydanticDetector{}.is_config_class(node)
}

pub fn (h ClassPydanticHandler) mark_pydantic_model(node ast.ClassDef, struct_name string, mut env ClassVisitEnv) {
	_ = h
	if !pydantic_support.PydanticDetector{}.is_pydantic_model(node) {
		return
	}
	if struct_name.len == 0 {
		return
	}
	if struct_name !in env.state.defined_classes {
		env.state.defined_classes[struct_name] = map[string]bool{}
	}
	env.state.defined_classes[struct_name]['is_pydantic'] = true
}
