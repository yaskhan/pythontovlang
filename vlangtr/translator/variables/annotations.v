module variables

import ast

pub fn (mut m VariablesModule) visit_ann_assign(node ast.AnnAssign) {
	target_expr := m.visit_expr(node.target)
	annotation_str := m.visit_expr(node.annotation)
	mut v_type := m.map_python_type(annotation_str, true, false, false)
	if v_type.len == 0 {
		v_type = m.guess_type(node.target, true)
	}

	if value_expr := node.value {
		if value_expr is ast.Call {
			call := value_expr
			if call.func is ast.Name {
				if call.func.id == 'input' && m.is_literal_string_expr(value_expr) {
					m.emit('//##LLM@@ LiteralString variable may lose its guarantee after input().')
				}
			}
		}

		if m.state.in_main && node.target is ast.Name {
			if annotation_str == 'TypeAlias' || annotation_str == 'typing.TypeAlias'
				|| annotation_str == 'typing_extensions.TypeAlias' {
				rhs_v_type := m.map_python_type(m.visit_expr(value_expr), true, true, false)
				pub_prefix := if m.is_exported(node.target.id) { 'pub ' } else { '' }
				m.emitter.add_struct('${pub_prefix}type ${target_expr} = ${rhs_v_type}')
				return
			}
		}

		if annotation_str == 'LiteralString' || annotation_str == 'typing.LiteralString'
			|| annotation_str == 'typing_extensions.LiteralString' {
			if !m.is_literal_string_expr(value_expr) {
				m.emit("//##LLM@@ LiteralString variable '${target_expr}' receives non-literal value.")
			}
		}

		if value_expr is ast.List {
			if (v_type.starts_with('[]') || v_type.starts_with('?[]')) && value_expr.elements.len > 0 {
				prev_type := m.current_assignment_type
				m.current_assignment_type = v_type
				rhs := m.visit_expr(value_expr)
				m.current_assignment_type = prev_type
				m.emit('mut ${target_expr} := ${rhs}')
				return
			}
		} else if value_expr is ast.Tuple {
			if (v_type.starts_with('[]') || v_type.starts_with('?[]')) && value_expr.elements.len > 0 {
				prev_type := m.current_assignment_type
				m.current_assignment_type = v_type
				rhs := m.visit_expr(value_expr)
				m.current_assignment_type = prev_type
				m.emit('mut ${target_expr} := ${rhs}')
				return
			}
		}

		if value_expr is ast.Dict {
			if value_expr.keys.len == 0 && v_type.starts_with('map[') {
				m.emit('${target_expr} := ${v_type}{}')
				return
			}
		}

		if value_expr is ast.List && value_expr.elements.len == 0 && v_type.starts_with('[]') {
			m.emit('${target_expr} := ${v_type}{}')
			return
		}

		is_interface_array := if v_type.starts_with('[]') {
			v_type[2..] in m.state.known_interfaces
		} else if v_type.starts_with('?[]') {
			v_type[3..] in m.state.known_interfaces
		} else {
			false
		}

		if is_interface_array {
			if value_expr is ast.List {
				if value_expr.elements.len > 0 {
					m.emit('mut ${target_expr} := ${v_type}{}')
					for elt in value_expr.elements {
						m.emit('${target_expr} << ${m.visit_expr(elt)}')
					}
					return
				}
			} else if value_expr is ast.Tuple {
				if value_expr.elements.len > 0 {
					m.emit('mut ${target_expr} := ${v_type}{}')
					for elt in value_expr.elements {
						m.emit('${target_expr} << ${m.visit_expr(elt)}')
					}
					return
				}
			}
		}

		if v_type in m.state.dataclasses {
			if value_expr is ast.Dict {
				mut pairs := []string{}
				for i, key in value_expr.keys {
					if i >= value_expr.values.len {
						break
					}
					if key is ast.Constant {
						key_str := m.sanitize_name(key.value, false)
						val_str := m.visit_expr(value_expr.values[i])
						pairs << '${key_str}: ${val_str}'
					}
				}
				m.emit('${target_expr} := ${v_type}{${pairs.join(', ')}}')
				return
			}
		}

		if value_expr is ast.Constant && value_expr.value == 'None' {
			if v_type == 'Any' || (v_type.starts_with('map[') && v_type.ends_with(']Any')) {
				m.emit('${target_expr} := Any(NoneType{})')
			} else {
				mut opt_type := v_type
				if !opt_type.starts_with('?') {
					opt_type = '?${opt_type}'
				}
				m.emit('mut ${target_expr} := ${opt_type}(none)')
			}
			return
		}

		if m.state.in_main && node.target is ast.Name && node.target.id.is_upper()
			&& m.is_compile_time_evaluable(value_expr) {
			pub_prefix := if m.is_exported(node.target.id) { 'pub ' } else { '' }
			m.emitter.add_constant('${pub_prefix}${m.to_snake_case(node.target.id)} = ${m.visit_expr(value_expr)}')
			return
		}

		if node.target is ast.Attribute || node.target is ast.Subscript {
			m.emit('${target_expr} = ${m.visit_expr(value_expr)}')
			return
		}

		rhs := m.visit_expr(value_expr)
		if rhs == 'none' {
			if v_type == 'Any' || (v_type.starts_with('map[') && v_type.ends_with(']Any')) {
				m.emit('mut ${target_expr} := Any(NoneType{})')
			} else {
				mut opt_type := v_type
				if !opt_type.starts_with('?') {
					opt_type = '?${opt_type}'
				}
				m.emit('mut ${target_expr} := ${opt_type}(none)')
			}
			return
		}

		if m.state.in_main && node.target is ast.Name && node.target.id in m.state.global_vars {
			m.emitter.add_init_statement('${target_expr} = ${rhs}')
			return
		}

		is_mut := m.is_mutable_target(node.target, target_expr)
		mut_prefix := if is_mut { 'mut ' } else { '' }
		m.emit('${mut_prefix}${target_expr} := ${rhs}')
		if !m.state.in_main {
			m.local_vars_in_scope[target_expr] = true
		}
		return
	}

	default_val := m.default_value_for_annotation(v_type)
	m.emit('${target_expr} := ${default_val}')
}

fn (m &VariablesModule) default_value_for_annotation(v_type string) string {
	if v_type == 'int' {
		return '0'
	}
	if v_type == 'f64' {
		return '0.0'
	}
	if v_type == 'bool' {
		return 'false'
	}
	if v_type == 'string' {
		return "''"
	}
	if v_type.starts_with('[]') || v_type.starts_with('map[') {
		return '${v_type}{}'
	}
	if v_type.starts_with('?') {
		return 'none'
	}
	return '0'
}

fn (m &VariablesModule) is_mutable_target(target ast.Expression, lhs string) bool {
	if target is ast.Name {
		if target.id.is_upper() {
			return false
		}
		if target.id in m.analyzer.mutability_map {
			info := m.analyzer.mutability_map[target.id]
			return (info.is_reassigned || info.is_mutated) && !info.is_final
		}
		if lhs in m.analyzer.mutability_map {
			info := m.analyzer.mutability_map[lhs]
			return (info.is_reassigned || info.is_mutated) && !info.is_final
		}
	}
	return false
}
