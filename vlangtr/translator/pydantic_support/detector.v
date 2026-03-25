module pydantic_support

import ast

pub struct PydanticDetector {}

pub fn (d PydanticDetector) is_pydantic_model(node ast.ClassDef) bool {
	_ = d
	for base in node.bases {
		if base is ast.Name {
			if base.id == 'BaseModel' {
				return true
			}
		} else if base is ast.Attribute {
			if base.attr == 'BaseModel' {
				if base.value is ast.Name && base.value.id == 'pydantic' {
					return true
				}
			}
		} else if base is ast.Subscript {
			if base.value is ast.Name && base.value.id == 'BaseModel' {
				return true
			}
			if base.value is ast.Attribute && base.value.attr == 'BaseModel' {
				if base.value.value is ast.Name && base.value.value.id == 'pydantic' {
					return true
				}
			}
		}
	}
	return false
}

pub fn (d PydanticDetector) is_pydantic_field(node ast.Expression) bool {
	_ = d
	if node is ast.Call {
		if node.func is ast.Name {
			return node.func.id == 'Field'
		}
		if node.func is ast.Attribute {
			if node.func.attr == 'Field' {
				if node.func.value is ast.Name && node.func.value.id == 'pydantic' {
					return true
				}
			}
		}
	}
	return false
}

pub fn (d PydanticDetector) is_validator_decorator(node ast.Expression) bool {
	_ = d
	if node is ast.Name {
		return node.id in ['validator', 'field_validator', 'model_validator']
	}
	if node is ast.Call {
		if node.func is ast.Name {
			return node.func.id in ['validator', 'field_validator', 'model_validator']
		}
		if node.func is ast.Attribute {
			return node.func.attr in ['validator', 'field_validator', 'model_validator']
		}
	}
	if node is ast.Attribute {
		return node.attr in ['validator', 'field_validator', 'model_validator']
	}
	return false
}

pub fn (d PydanticDetector) is_computed_field(node ast.Expression) bool {
	_ = d
	if node is ast.Name {
		return node.id == 'computed_field'
	}
	if node is ast.Attribute {
		return node.attr == 'computed_field'
	}
	if node is ast.Call {
		if node.func is ast.Name {
			return node.func.id == 'computed_field'
		}
		if node.func is ast.Attribute {
			return node.func.attr == 'computed_field'
		}
	}
	return false
}

pub fn (d PydanticDetector) is_config_dict(node ast.Expression) bool {
	_ = d
	if node is ast.Call {
		if node.func is ast.Name {
			return node.func.id == 'ConfigDict'
		}
		if node.func is ast.Attribute {
			return node.func.attr == 'ConfigDict'
		}
	}
	return false
}

pub fn (d PydanticDetector) is_config_class(node ast.ClassDef) bool {
	_ = d
	return node.name == 'Config'
}
