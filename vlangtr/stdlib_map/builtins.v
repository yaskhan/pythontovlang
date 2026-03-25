module stdlib_map

// builtin_map - маппинг встроенных функций Python в V
pub const builtin_map = {
	'print': 'println'
	'str': 'string'
	'int': 'int'
	'float': 'f64'
	'bool': 'bool'
	'len': 'len'
	'range': 'range'
}

// get_builtin_mapping возвращает V код для встроенной функции Python
pub fn get_builtin_mapping(func_name string) ?string {
	if func_name in builtin_map {
		return builtin_map[func_name]
	}
	return none
}

// is_builtin проверяет, является ли функция встроенной
pub fn is_builtin(func_name string) bool {
	return func_name in builtin_map
}