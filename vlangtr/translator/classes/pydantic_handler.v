module classes

import ast

pub struct ClassPydanticHandler {}

pub fn (h ClassPydanticHandler) is_pydantic_model(node ast.ClassDef) bool {
	_ = h
	_ = node
	return false
}

pub fn (h ClassPydanticHandler) is_pydantic_field(_ ast.Statement) bool {
	_ = h
	return false
}

pub fn (h ClassPydanticHandler) is_validator_decorator(_ ast.Expression) bool {
	_ = h
	return false
}

pub fn (h ClassPydanticHandler) is_computed_field(_ ast.Expression) bool {
	_ = h
	return false
}

pub fn (h ClassPydanticHandler) is_config_dict(_ ast.Statement) bool {
	_ = h
	return false
}

pub fn (h ClassPydanticHandler) is_config_class(_ ast.ClassDef) bool {
	_ = h
	return false
}

pub fn (h ClassPydanticHandler) mark_pydantic_model(_ ast.ClassDef, _ string, mut env ClassVisitEnv) {
	_ = h
	_ = env
}
