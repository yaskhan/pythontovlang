module base

// get_generic_map builds a stable map of Python generic names to short V generic symbols.
pub fn get_generic_map(generic_names []string, generic_scopes []map[string]string) map[string]string {
	mut mapping := map[string]string{}
	mut used_chars := map[string]bool{}
	for scope in generic_scopes {
		for _, v_name in scope {
			used_chars[v_name] = true
		}
	}

	fallback_order := ['T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
		'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S']
	for py_name in generic_names {
		clean := py_name.trim_left('_')
		if clean.len == 0 {
			continue
		}

		preferred := clean[0].ascii_str().to_upper()
		if preferred !in used_chars {
			mapping[py_name] = preferred
			used_chars[preferred] = true
			continue
		}

		for candidate in fallback_order {
			if candidate !in used_chars {
				mapping[py_name] = candidate
				used_chars[candidate] = true
				break
			}
		}
	}

	return mapping
}

// get_combined_generic_map merges all active generic scopes from outer to inner.
pub fn get_combined_generic_map(generic_scopes []map[string]string) map[string]string {
	mut combined := map[string]string{}
	for scope in generic_scopes {
		for k, v in scope {
			combined[k] = v
		}
	}
	return combined
}

// get_all_active_v_generics returns unique V generic names in declaration order.
pub fn get_all_active_v_generics(generic_scopes []map[string]string) []string {
	mut all_v := []string{}
	mut seen := map[string]bool{}
	for scope in generic_scopes {
		for _, v_name in scope {
			if v_name in seen {
				continue
			}
			all_v << v_name
			seen[v_name] = true
		}
	}
	return all_v
}

// get_generics_with_variance_str formats active generics and keeps variance/default metadata in comments.
pub fn get_generics_with_variance_str(v_generics []string, combined_generic_map map[string]string, generic_variance map[string]string, generic_defaults map[string]string) string {
	if v_generics.len == 0 {
		return ''
	}

	mut reverse_map := map[string]string{}
	for py_name, v_name in combined_generic_map {
		reverse_map[v_name] = py_name
	}

	mut parts := []string{}
	for v_name in v_generics {
		py_name := reverse_map[v_name] or { '' }
		variance := generic_variance[py_name] or { '' }
		default_type := generic_defaults[py_name] or { '' }

		mut part := v_name
		if variance.len > 0 {
			part += ' /* ${variance} */'
		}
		if default_type.len > 0 {
			part += ' /* = ${default_type} */'
		}
		parts << part
	}

	return '[${parts.join(', ')}]'
}
