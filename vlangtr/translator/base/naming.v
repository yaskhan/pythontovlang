module base

// NamingMixin - миксин для утилит именования и санитизации идентификаторов

// to_snake_case преобразует CamelCase или UPPER_CASE в snake_case
pub fn to_snake_case(name string) string {
	if name.len == 0 || name == '_' {
		return name
	}

	// Сохраняем внутренние маркеры
	if name.contains('__py2v_gen') {
		return name
	}

	// Обрабатываем UPPER_CASE константы
	if name.is_upper() {
		return name
	}

	// Обрабатываем уже разделенные имена
	if name.contains('_') {
		mut parts := []string{}
		for p in name.split('_') {
			if p.len > 0 {
				parts << to_snake_case(p)
			}
		}
		if parts.len > 0 {
			return parts.join('_')
		}
		return '_'
	}

	mut res := []string{}
	for i, ch in name {
		if ch.is_capital() && i > 0 {
			if is_lower_ascii(name[i - 1]) {
				res << '_'
			} else if i + 1 < name.len && is_lower_ascii(name[i + 1]) {
				res << '_'
			}
		}
		res << ch.ascii_str().to_lower()
	}
	return res.join('')
}

// get_factory_name возвращает snake_case имя фабрики для заданного имени структуры
pub fn get_factory_name(struct_name string, hierarchy map[string][]string) string {
	base_name := struct_name.split('[')[0]
	sanitized := to_snake_case(base_name)

	mut is_split_base := false
	for derived, bases in hierarchy {
		if base_name in bases {
			is_split_base = true
			break
		}
	}

	if is_split_base {
		return 'new_${sanitized}_impl'
	}

	return 'new_${sanitized}'
}

// sanitize_name санитизирует идентификаторы Python для соответствия V
pub fn sanitize_name(name string, is_type bool, reserved_words map[string]bool, scc_prefix string, local_vars map[string]bool) string {
	if name.len == 0 {
		return name
	}

	// Зарезервированные типы V сохраняются как есть
	v_reserved_types := ['int', 'string', 'bool', 'f64', 'f32', 'i64', 'byte', 'rune', 'void',
		'Any', 'none', 'i8', 'i16', 'i32', 'u16', 'u32', 'u64']
	if name in v_reserved_types {
		return name
	}

	// Внутренние маркеры сохраняются как есть
	if name.contains('__py2v_gen') {
		return name
	}

	// V compliance: нет ведущих подчеркиваний
	mut clean_name := name
	mut prefix_count := 0
	for clean_name.starts_with('_') && clean_name != '_' {
		prefix_count++
		clean_name = clean_name[1..]
	}

	if clean_name.len == 0 {
		return '_'.repeat(prefix_count)
	}

	if is_type {
		// PascalCase для типов
		mut parts := []string{}
		for p in clean_name.split('_') {
			if p.len > 0 {
				parts << p[0].ascii_str().to_upper() + p[1..]
			}
		}
		mut res := if parts.len > 0 {
			parts.join('')
		} else {
			clean_name[0].ascii_str().to_upper() + clean_name[1..]
		}
		// V structs не могут иметь подчеркивания
		res = res.replace('_', '')
		res += '_'.repeat(prefix_count)

		if res in reserved_words {
			return 'Py${res}'
		}
		return res
	}

	// Остальные: snake_case
	mut sanitized := to_snake_case(clean_name)
	sanitized += '_'.repeat(prefix_count)

	if sanitized in reserved_words {
		return 'py_${sanitized}'
	}

	// SCC коллизия
	if scc_prefix.len > 0 && !sanitized.starts_with('py_') && sanitized !in local_vars {
		if !sanitized.starts_with(scc_prefix + '__') {
			return '${scc_prefix}__${sanitized}'
		}
	}

	return sanitized
}

// mangle_name реализует правила Python name mangling для приватных атрибутов
pub fn mangle_name(name string, class_name string) string {
	if class_name.len > 0 && name.starts_with('__') && !name.ends_with('__') {
		s_class := sanitize_name(class_name, true, map[string]bool{}, '', map[string]bool{}).trim_right('_')
		s_name := sanitize_name(name, false, map[string]bool{}, '', map[string]bool{})
		return '${s_class}_${s_name}'
	}
	return name
}

// local_vars_in_scope returns all local names from the current scope.
pub fn local_vars_in_scope(scope_stack []map[string]bool) map[string]bool {
	if scope_stack.len == 0 {
		return map[string]bool{}
	}
	return scope_stack[scope_stack.len - 1].clone()
}

// find_defining_class_for_static_method locates where a static/class method is defined.
pub fn find_defining_class_for_static_method(class_name string, method_name string, static_methods map[string][]string, class_methods map[string][]string, class_hierarchy map[string][]string) ?string {
	mut visited := map[string]bool{}
	mut stack := [class_name]
	for stack.len > 0 {
		curr := stack[stack.len - 1]
		stack = stack[..stack.len - 1]
		if curr in visited {
			continue
		}
		visited[curr] = true

		if curr in static_methods && method_name in static_methods[curr] {
			return curr
		}
		if curr in class_methods && method_name in class_methods[curr] {
			return curr
		}

		if curr in class_hierarchy {
			for base in class_hierarchy[curr] {
				stack << base
			}
		}
	}
	return none
}

// get_full_self_type returns a type name for Self with active generics.
pub fn get_full_self_type(struct_name string, current_class string, current_class_generics []string) string {
	name := if struct_name.len > 0 {
		struct_name
	} else if current_class.len > 0 {
		current_class
	} else {
		'Self'
	}
	if current_class_generics.len == 0 {
		return name
	}
	return '${name}[${current_class_generics.join(', ')}]'
}

// find_defining_class_for_class_var locates a class where a class variable is declared.
pub fn find_defining_class_for_class_var(class_name string, var_name string, class_vars map[string][]string, class_hierarchy map[string][]string) ?string {
	mut visited := map[string]bool{}
	mut stack := [class_name]
	for stack.len > 0 {
		curr := stack[stack.len - 1]
		stack = stack[..stack.len - 1]
		if curr in visited {
			continue
		}
		visited[curr] = true

		if curr in class_vars && var_name in class_vars[curr] {
			return curr
		}

		if curr in class_hierarchy {
			for base in class_hierarchy[curr] {
				stack << base
			}
		}
	}
	return none
}

fn is_lower_ascii(ch u8) bool {
	return ch >= `a` && ch <= `z`
}
