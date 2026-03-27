module stdlib_map

// builtin_map - mapping of Python built-in functions to V
pub const builtin_map = {
	'print': 'println'
	'str': 'string'
	'int': 'int'
	'float': 'f64'
	'bool': 'bool'
	'len': 'len'
	'range': 'range'
}

// get_builtin_mapping returns V code for Python built-in function
pub fn get_builtin_mapping(func_name string) ?string {
	if func_name in builtin_map {
		return builtin_map[func_name]
	}
	return none
}

// is_builtin checks if function is a built-in
pub fn is_builtin(func_name string) bool {
	return func_name in builtin_map
}