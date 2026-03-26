module variables

import ast
import base

pub fn (mut m VariablesModule) visit_type_alias(node ast.TypeAlias) {
	name := m.sanitize_name(node.name, true)

	mut py_generics := []string{}
	mut added_variance_keys := []string{}
	mut added_default_keys := []string{}

	if node.type_params.len > 0 {
		for param in node.type_params {
			py_generics << param.name
			if param.kind == .typevar {
				if bound := param.bound {
					_ = bound
				}
			}
			if default_expr := param.default_ {
				m.state.generic_defaults[param.name] = m.map_python_type(m.visit_expr(default_expr),
					true, false, false)
				added_default_keys << param.name
			}
		}
		m.state.type_params_map[name] = py_generics.clone()
	}

	generic_map := base.get_generic_map(py_generics, m.state.generic_scopes)
	m.state.generic_scopes << generic_map
	v_generics := base.get_all_active_v_generics(m.state.generic_scopes)
	type_params_str := base.get_generics_with_variance_str(v_generics, base.get_combined_generic_map(m.state.generic_scopes),
		m.state.generic_variance, m.state.generic_defaults)

	val_str := m.visit_expr(node.value)
	v_type := m.map_python_type(val_str, true, false, false)
	pub_prefix := if m.is_exported(node.name) { 'pub ' } else { '' }
	m.emitter.add_struct('${pub_prefix}type ${name}${type_params_str} = ${v_type}')

	m.state.generic_scopes.pop()

	for key in added_variance_keys {
		if key in m.state.generic_variance {
			m.state.generic_variance.delete(key)
		}
	}
	for key in added_default_keys {
		if key in m.state.generic_defaults {
			m.state.generic_defaults.delete(key)
		}
	}
}
