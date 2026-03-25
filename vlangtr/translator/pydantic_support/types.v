module pydantic_support

import ast

pub struct PydanticFieldInfo {
pub mut:
	name           string
	type_str       string
	default_val    string
	alias          string
	gt             string
	lt             string
	ge             string
	le             string
	max_length     string
	min_length     string
	is_optional    bool
	pattern        string
	multiple_of    string
	min_items      string
	max_items      string
	unique_items   bool
	const_value    string
	description    string
	title          string
	examples       string
	repr           bool
	exclude        bool
}

pub struct PydanticValidatorInfo {
pub:
	name             string
	fields           []string
	node             ast.FunctionDef
	mode             string
	is_model_validator bool
}

pub struct PydanticConfigInfo {
pub mut:
	str_strip_whitespace bool
	str_to_lower         bool
	str_to_upper         bool
	min_anystr_length    int
	max_anystr_length    int
	validate_all         bool
	validate_assignment  bool
	extra                string
	allow_mutation       bool
}

pub struct PydanticModelResult {
pub mut:
	struct_code    string
	factory_code   string
	validate_code  string
	validator_code []string
}
