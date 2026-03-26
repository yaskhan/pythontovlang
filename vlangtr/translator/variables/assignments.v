module variables

import ast

pub fn (mut m VariablesModule) visit_assign(node ast.Assign) {
	if node.targets.len == 0 {
		return
	}

	if node.targets.len > 1 {
		mut rhs := m.visit_expr(node.value)
		rhs_type := m.guess_type(node.value, true)
		tmp := 'py_assign_tmp_${m.state.unique_id_counter}'
		m.state.unique_id_counter++
		m.emit('${tmp} := ${rhs}')
		for target in node.targets {
			m.visit_destructuring(target, tmp, rhs_type)
		}
		return
	}

	target := node.targets[0]
	if target is ast.Tuple {
		mut rhs := m.visit_expr(node.value)
		rhs_type := m.guess_type(node.value, true)
		m.visit_destructuring(target, rhs, rhs_type)
		return
	}
	if target is ast.List {
		mut rhs := m.visit_expr(node.value)
		rhs_type := m.guess_type(node.value, true)
		m.visit_destructuring(target, rhs, rhs_type)
		return
	}

	if target is ast.Name {
		lhs := m.sanitize_name(target.id, target.id.len > 0 && (target.id[0].is_capital() || target.id.is_upper()))
		if target.id in m.state.name_remap {
			m.state.name_remap.delete(target.id)
		}
		if m.state.in_main {
			m.state.defined_top_level_symbols[target.id] = true
		}

		if node.value is ast.Call {
			call := node.value
			if call.func is ast.Name {
				func_name := call.func.id
				if func_name == 'NewType' && call.args.len == 2 {
					base_type := m.map_python_type(m.visit_expr(call.args[1]), true, false, false)
					pub_prefix := if m.is_exported(target.id) { 'pub ' } else { '' }
					m.emitter.add_struct('${pub_prefix}type ${lhs} = ${base_type}')
					return
				}
				if func_name == 'TypeVar' || func_name == 'ParamSpec' || func_name == 'TypeVarTuple' {
					m.state.type_vars[target.id] = true
					mut constraints := []string{}
					for i in 1 .. call.args.len {
						constraints << m.map_python_type(m.visit_expr(call.args[i]), true, false, false)
					}
					for kw in call.keywords {
						if kw.arg == 'bound' {
							bound_type := m.map_python_type(m.visit_expr(kw.value), true, false, false)
							if bound_type.len > 0 {
								constraints << bound_type
								m.state.constrained_typevars[target.id] = true
							}
						} else if kw.arg == 'default' {
							m.state.generic_defaults[target.id] = m.map_python_type(m.visit_expr(kw.value), true, false, false)
						}
					}
					if constraints.len > 0 {
						pub_prefix := if m.is_exported(target.id) { 'pub ' } else { '' }
						m.emitter.add_struct('${pub_prefix}type ${lhs} = ${constraints.join(' | ')}')
					}
					return
				}
			}
		}

		if m.state.in_main && target.id.len > 0 && target.id[0].is_capital() {
			rhs_for_alias := m.visit_expr(node.value)
			mapped := m.map_python_type(rhs_for_alias, true, false, false)
			if mapped.len > 0 && mapped != rhs_for_alias {
				pub_prefix := if m.is_exported(target.id) { 'pub ' } else { '' }
				m.emitter.add_struct('${pub_prefix}type ${lhs} = ${mapped}')
				return
			}
		}

		mut rhs := m.visit_expr(node.value)
		rhs_type := m.guess_type(node.value, true)

		if node.value is ast.List {
			if rhs_type.starts_with('[]') && node.value.elements.len > 0 {
				m.emit('mut ${lhs} := ${rhs}')
				m.local_vars_in_scope[lhs] = true
				return
			}
		} else if node.value is ast.Tuple {
			if rhs_type.starts_with('[]') && node.value.elements.len > 0 {
				m.emit('mut ${lhs} := ${rhs}')
				m.local_vars_in_scope[lhs] = true
				return
			}
		}

		if node.value is ast.Call && rhs_type == 'void' {
			m.emit(rhs)
			return
		}

		if rhs == 'none' {
			if lhs in m.local_vars_in_scope {
				m.emitter.add_init_statement('${lhs} = none')
			} else if rhs_type == 'Any' || (rhs_type.starts_with('map[') && rhs_type.ends_with(']Any')) {
				m.emit('mut ${lhs} := Any(NoneType{})')
			} else {
				mut opt_type := rhs_type
				if !opt_type.starts_with('?') {
					opt_type = '?${opt_type}'
				}
				m.emit('mut ${lhs} := ${opt_type}(none)')
			}
			if !m.state.in_main {
				m.local_vars_in_scope[lhs] = true
			}
			return
		}

		if m.state.in_main && target.id in m.state.global_vars {
			m.emitter.add_init_statement('${lhs} = ${rhs}')
			return
		}

		if m.state.in_main && target.id.is_upper() && m.is_compile_time_evaluable(node.value) {
			pub_prefix := if m.is_exported(target.id) { 'pub ' } else { '' }
			m.emitter.add_constant('${pub_prefix}${m.to_snake_case(target.id)} = ${rhs}')
			return
		}

		is_mut := m.is_mutable_target(target, lhs)
		if is_mut && rhs_type.starts_with('[]') && !rhs.contains('.clone()') {
			rhs = '${rhs}.clone()'
		}
		mut_prefix := if is_mut { 'mut ' } else { '' }
		if m.state.in_main && lhs in m.local_vars_in_scope {
			m.emit('${lhs} = ${rhs}')
		} else {
			m.emit('${mut_prefix}${lhs} := ${rhs}')
		}
		if !m.state.in_main {
			m.local_vars_in_scope[lhs] = true
		}
		return
	}

	if target is ast.Attribute || target is ast.Subscript {
		lhs := m.visit_expr(target)
		rhs := m.visit_expr(node.value)
		m.emit('${lhs} = ${rhs}')
		return
	}

	rhs := m.visit_expr(node.value)
	m.emit('//##LLM@@ Unsupported assignment target.')
	m.emit(rhs)
}

pub fn (mut m VariablesModule) visit_named_expr(node ast.NamedExpr) string {
	if node.target is ast.Name {
		target := m.sanitize_name(node.target.id, false)
		value := m.visit_expr(node.value)
		m.state.walrus_assignments << '${target} := ${value}'
		return target
	}
	return ''
}

fn (mut m VariablesModule) visit_destructuring(target ast.Expression, source_expr string, source_type string) {
	if target is ast.Tuple {
		tmp_var := 'py_destruct_${m.state.zip_counter}'
		m.state.zip_counter++
		m.emit('${tmp_var} := ${source_expr}')
		mut starred_idx := -1
		for i, elt in target.elements {
			if elt is ast.Starred {
				starred_idx = i
				break
			}
		}
		if starred_idx == -1 {
			for i, elt in target.elements {
				m.visit_destructuring(elt, '${tmp_var}[${i}]', source_type)
			}
		} else {
			for i in 0 .. starred_idx {
				m.visit_destructuring(target.elements[i], '${tmp_var}[${i}]', source_type)
			}
			star_elt := target.elements[starred_idx]
			if star_elt is ast.Starred {
				trailing := target.elements.len - 1 - starred_idx
				slice_expr := if trailing == 0 {
					'${tmp_var}[${starred_idx}..]'
				} else {
					'${tmp_var}[${starred_idx}..(${tmp_var}.len - ${trailing})]'
				}
				m.visit_destructuring(star_elt.value, slice_expr, source_type)
			}
			for i in starred_idx + 1 .. target.elements.len {
				offset := target.elements.len - i
				m.visit_destructuring(target.elements[i], '${tmp_var}[(${tmp_var}.len - ${offset})]', source_type)
			}
		}
		return
	}

	if target is ast.List {
		tmp_var := 'py_destruct_${m.state.zip_counter}'
		m.state.zip_counter++
		m.emit('${tmp_var} := ${source_expr}')
		mut starred_idx := -1
		for i, elt in target.elements {
			if elt is ast.Starred {
				starred_idx = i
				break
			}
		}
		if starred_idx == -1 {
			for i, elt in target.elements {
				m.visit_destructuring(elt, '${tmp_var}[${i}]', source_type)
			}
		} else {
			for i in 0 .. starred_idx {
				m.visit_destructuring(target.elements[i], '${tmp_var}[${i}]', source_type)
			}
			star_elt := target.elements[starred_idx]
			if star_elt is ast.Starred {
				trailing := target.elements.len - 1 - starred_idx
				slice_expr := if trailing == 0 {
					'${tmp_var}[${starred_idx}..]'
				} else {
					'${tmp_var}[${starred_idx}..(${tmp_var}.len - ${trailing})]'
				}
				m.visit_destructuring(star_elt.value, slice_expr, source_type)
			}
			for i in starred_idx + 1 .. target.elements.len {
				offset := target.elements.len - i
				m.visit_destructuring(target.elements[i], '${tmp_var}[(${tmp_var}.len - ${offset})]', source_type)
			}
		}
		return
	}

	if target is ast.Name {
		lhs := m.sanitize_name(target.id, false)
		if !m.state.in_main && lhs in m.local_vars_in_scope {
			m.emit('${lhs} = ${source_expr}')
			return
		}
		is_mut := m.is_mutable_target(target, lhs)
		mut_prefix := if is_mut { 'mut ' } else { '' }
		if is_mut && m.is_clonable_collection(source_type) && !source_expr.contains('.clone()') {
			m.emit('${mut_prefix}${lhs} := ${source_expr}.clone()')
		} else {
			m.emit('${mut_prefix}${lhs} := ${source_expr}')
		}
		if !m.state.in_main {
			m.local_vars_in_scope[lhs] = true
		}
		return
	}

	if target is ast.Attribute || target is ast.Subscript {
		m.emit('${m.visit_expr(target)} = ${source_expr}')
		return
	}

	m.emit('//##LLM@@ Unsupported destructuring target')
}

fn (m &VariablesModule) is_clonable_collection(v_type string) bool {
	return v_type.starts_with('[]') || v_type.starts_with('map[')
}
