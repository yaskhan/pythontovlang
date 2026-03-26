module variables

import ast
import base

pub fn (mut m VariablesModule) visit_name(node ast.Name) string {
	if node.id in m.state.name_remap {
		return m.state.name_remap[node.id]
	}

	if node.id in m.state.imported_symbols {
		return m.state.imported_symbols[node.id]
	}

	mangled := base.mangle_name(node.id, m.state.current_class)
	is_potential_type := mangled.len > 0 && mangled[0].is_capital() && !mangled.is_upper()
	if mangled in m.state.defined_classes || is_potential_type {
		return m.sanitize_name(mangled, true)
	}

	if mangled.contains('__py2v_gen') {
		return mangled
	}

	res := m.sanitize_name(mangled, false)
	s_name := m.to_snake_case(mangled)
	if mangled in m.local_vars_in_scope {
		return res
	}
	if s_name in m.local_vars_in_scope {
		return m.sanitize_name(s_name, false)
	}
	if mangled in m.state.global_vars {
		return res
	}
	if s_name in m.state.global_vars {
		return m.sanitize_name(s_name, false)
	}

	if node.ctx == .load {
		narrowed_type := m.guess_type(node, true)
		base_type := m.guess_type(node, false)
		v_narrowed_type := m.map_python_type(narrowed_type, true, false, false)
		v_base_type := m.map_python_type(base_type, true, false, false)
		if v_narrowed_type.len > 0 && v_base_type.len > 0 && v_narrowed_type != v_base_type {
			if v_base_type.starts_with('fn') || v_base_type.contains('fn(') {
				return res
			}
			if v_base_type.starts_with('SumType_') || v_base_type == 'Any' {
				if v_narrowed_type != 'none' && v_narrowed_type != 'void' && v_narrowed_type != 'unknown' {
					return '(${res} as ${v_narrowed_type})'
				}
			}
		}
	}

	return res
}
