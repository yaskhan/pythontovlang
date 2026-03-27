module variables

import ast

pub fn (mut m VariablesModule) visit_assign(node ast.Assign) {
	if node.targets.len == 0 {
		return
	}

	target := node.targets[0]
	mut lhs := ''

	if target is ast.Name {
		maybe_type := target.id.len > 0 && (target.id[0].is_capital() || (target.id.starts_with('_') && target.id.len > 1 && target.id[1].is_capital()))
		lhs = m.sanitize_name(target.id, maybe_type)
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
					for arg in call.args[1..] {
						constraints << m.map_python_type(m.visit_expr(arg), true, false, false)
					}
					for kw in call.keywords {
						if kw.arg == 'bound' {
							bound_type := m.map_python_type(m.visit_expr(kw.value), true, false, false)
							if bound_type.len > 0 {
								if bound_type.contains('|') {
									constraints << bound_type.split('|').map(it.trim_space())
								} else {
									constraints << bound_type
								}
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

		if m.state.in_main {
			mut is_type_alias := false
			mut type_alias_val := ''
			if maybe_type {
				if target.id in m.analyzer.type_map && node.value is ast.Name {
					is_type_alias = true
					type_alias_val = m.analyzer.type_map[target.id]
				} else {
					rhs_source := m.visit_expr(node.value)
					mapped := m.map_python_type(rhs_source, true, false, false)
					if mapped.len > 0 && mapped != rhs_source {
						is_type_alias = true
						type_alias_val = mapped
					} else if node.value is ast.Name && node.value.id.len > 0 && node.value.id[0].is_capital() {
						is_type_alias = true
						type_alias_val = node.value.id
					}
				}
			}
			if is_type_alias {
				pub_prefix := if m.is_exported(target.id) { 'pub ' } else { '' }
				m.emitter.add_struct('${pub_prefix}type ${lhs} = ${type_alias_val}')
				return
			}
			if maybe_type || target.id.is_upper() {
				lhs = m.sanitize_name(target.id, false)
			}
		}
	} else if target is ast.Attribute {
		lhs = m.visit_expr(target)
		if !lhs.contains('_meta.') {
			obj_type := m.guess_type(target.value, true)
			if obj_type in m.state.readonly_fields {
				field_name := m.sanitize_name(target.attr, false)
				if field_name in m.state.readonly_fields[obj_type] {
					m.emit('\$compile_error("Cannot assign to ReadOnly TypedDict field \'${field_name}\'")')
					return
				}
			}
			if obj_type in m.state.property_setters && target.attr in m.state.property_setters[obj_type] {
				obj_expr := m.visit_expr(target.value)
				rhs_expr := m.visit_expr(node.value)
				m.emit('${obj_expr}.set_${target.attr}(${rhs_expr})')
				return
			}
		}
	} else if target is ast.Subscript {
		obj_type := m.guess_type(target.value, true)
		if obj_type in m.state.dataclasses {
			list_obj := m.visit_expr(target.value)
			if target.slice is ast.Constant {
				if target.slice.value.starts_with("'") || target.slice.value.starts_with('"') {
					field_name := m.sanitize_name(target.slice.value.trim('\'"'), false)
					if obj_type in m.state.readonly_fields && field_name in m.state.readonly_fields[obj_type] {
						m.emit('\$compile_error("Cannot assign to ReadOnly TypedDict field \'${field_name}\'")')
						return
					}
					lhs = '${list_obj}.${field_name}'
					rhs := m.visit_expr(node.value)
					m.emit('${lhs} = ${rhs}')
					return
				}
			}
		}
		// Slice assignment logic
		if target.slice is ast.Slice {
			sl := target.slice
			list_obj := m.visit_expr(target.value)
			lower := if val := sl.lower { m.visit_expr(val) } else { '0' }
			upper := if val := sl.upper { m.visit_expr(val) } else { '${list_obj}.len' }
			rhs := m.visit_expr(node.value)
			mut step_val := 0
			if val := sl.step {
				if val is ast.Constant && val.value.is_int() {
					step_val = val.value.int()
				}
			}
			if step_val >= 2 {
				uid := m.state.unique_id_counter
				m.state.unique_id_counter++
				rhs_tmp := 'py_step_rhs_${uid}'
				i_tmp := 'py_step_i_${uid}'
				idx_tmp := 'py_step_idx_${uid}'
				m.emit('${rhs_tmp} := ${rhs}')
				m.emit('mut ${i_tmp} := 0')
				m.emit('for ${idx_tmp} := ${lower}; ${idx_tmp} < ${upper}; ${idx_tmp} += ${step_val} {')
				m.state.indent_level++
				m.emit('if ${i_tmp} >= ${rhs_tmp}.len { break }')
				m.emit('${list_obj}[${idx_tmp}] = ${rhs_tmp}[${i_tmp}]')
				m.emit('${i_tmp}++')
				m.state.indent_level--
				m.emit('}')
				return
			}
			m.state.used_delete_many = true
			m.state.used_insert_many = true
			m.emit('${list_obj}.delete_many(${lower}, (${upper}) - (${lower}))')
			m.emit('${list_obj}.insert_many(${lower}, ${rhs})')
			return
		}
		lhs = m.visit_expr(target)
	} else if target is ast.Tuple || target is ast.List {
		rhs := m.visit_expr(node.value)
		if m.state.in_main {
			m.track_targets(target)
		}
		rhs_type := m.guess_type(node.value, true)
		m.visit_destructuring(target, rhs, rhs_type)
		return
	}

	if node.targets.len > 1 {
		rhs := m.visit_expr(node.value)
		rhs_type := m.guess_type(node.value, true)
		tmp := 'py_assign_tmp_${m.state.unique_id_counter}'
		m.state.unique_id_counter++
		m.emit('${tmp} := ${rhs}')
		for t in node.targets {
			m.visit_destructuring(t, tmp, rhs_type)
		}
		return
	}

	if lhs.len == 0 {
		return
	}

	if node.value is ast.Lambda && target is ast.Name {
		m.register_lambda_signature(target.id, node.value)
	}

	v_type := m.guess_type(target, true)
	is_literal_string := v_type == 'LiteralString'
	is_implicit_literal := m.is_literal_string_expr(node.value)

	// interface array logic
	mut is_interface_array := false
	mut base_v_type := ''
	if v_type.starts_with('[]') {
		base_v_type = v_type[2..]
	} else if v_type.starts_with('?[]') {
		base_v_type = v_type[3..]
	}
	if base_v_type.len > 0 && base_v_type in m.state.known_interfaces {
		is_interface_array = true
	}

	if is_interface_array && node.value is ast.List && node.value.elements.len > 0 {
		if !m.state.in_main && lhs in m.local_vars_in_scope {
			m.emit('${lhs} = ${v_type}{}')
		} else {
			m.emit('mut ${lhs} := ${v_type}{}')
			if !m.state.in_main { m.local_vars_in_scope[lhs] = true }
		}
		for elt in node.value.elements {
			m.emit('${lhs} << ${m.visit_expr(elt)}')
		}
		return
	}

	mut rhs := ''
	is_void_call := if node.value is ast.Call { m.map_python_type(m.guess_type(node.value, true), false, false, true) == 'void' } else { false }

	if is_void_call {
		m.emit(m.visit_expr(node.value))
		rhs = 'Any(NoneType{})'
	} else {
		prev_type := m.state.current_assignment_type
		m.state.current_assignment_type = v_type
		rhs = m.visit_expr(node.value)
		m.state.current_assignment_type = prev_type
	}

	if m.state.in_main {
		if lhs in m.state.global_vars {
			m.emitter.add_init_statement('${lhs} = ${rhs}')
			return
		}
		if target is ast.Name && target.id.is_upper() && m.is_compile_time_evaluable(node.value) {
			pub_prefix := if m.is_exported(target.id) { 'pub ' } else { '' }
			m.emitter.add_constant('${pub_prefix}${m.to_snake_case(target.id)} = ${rhs}')
			return
		}
	}

	is_mut := m.is_mutable_target(target, lhs)
	if is_mut && m.is_clonable_collection(v_type) && !rhs.contains('.clone()') && !rhs.starts_with('[') && !rhs.starts_with('map[') {
		rhs = '${rhs}.clone()'
	}

	if !m.state.in_main && lhs in m.local_vars_in_scope {
		if lhs in m.state.cond_optional_var_type && rhs != 'none' && !rhs.starts_with('?') {
			opt_type := m.state.cond_optional_var_type[lhs]
			rhs = if opt_type == '?Any' { 'Any(${rhs})' } else { '${opt_type}(${rhs})' }
		}
		m.emit('${lhs} = ${rhs}')
	} else {
		mut_prefix := if is_mut { 'mut ' } else { '' }
		m.emit('${mut_prefix}${lhs} := ${rhs}')
		if !m.state.in_main { m.local_vars_in_scope[lhs] = true }
	}
}

fn (mut m VariablesModule) track_targets(target ast.Expression) {
	match target {
		ast.Tuple {
			for elt in target.elements {
				m.track_targets(elt)
			}
		}
		ast.List {
			for elt in target.elements {
				m.track_targets(elt)
			}
		}
		ast.Starred {
			m.track_targets(target.value)
		}
		ast.Name {
			m.state.defined_top_level_symbols[target.id] = true
		}
		else {}
	}
}

fn (mut m VariablesModule) visit_destructuring(target ast.Expression, source_expr string, source_type string) {
	if target is ast.Tuple || target is ast.List {
		tmp_var := 'py_destruct_${m.state.zip_counter}'
		m.state.zip_counter++
		m.emit('${tmp_var} := ${source_expr}')

		mut elements := []ast.Expression{}
		if target is ast.Tuple { elements = target.elements.clone() }
		else if target is ast.List { elements = target.elements.clone() }

		mut starred_idx := -1
		for i, elt in elements {
			if elt is ast.Starred {
				starred_idx = i
				break
			}
		}

		is_tuple := source_type.starts_with('TupleStruct_') || source_type.contains('Tuple')
		if starred_idx == -1 {
			for i, elt in elements {
				m.visit_destructuring(elt, if is_tuple { '${tmp_var}.it_${i}' } else { '${tmp_var}[${i}]' }, source_type)
			}
		} else {
			for i in 0 .. starred_idx {
				m.visit_destructuring(elements[i], if is_tuple { '${tmp_var}.it_${i}' } else { '${tmp_var}[${i}]' }, source_type)
			}
			star_elt := elements[starred_idx]
			if star_elt is ast.Starred {
				trailing := elements.len - 1 - starred_idx
				slice_expr := if trailing == 0 {
					'${tmp_var}[${starred_idx}..]'
				} else {
					'${tmp_var}[${starred_idx}..(${tmp_var}.len - ${trailing})]'
				}
				m.visit_destructuring(star_elt.value, slice_expr, source_type)
			}
			for i in starred_idx + 1 .. elements.len {
				offset := elements.len - i
				m.visit_destructuring(elements[i], if is_tuple { '${tmp_var}.it_${i}' } else { '${tmp_var}[(${tmp_var}.len - ${offset})]' }, source_type)
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
		mut rhs := source_expr
		if is_mut && m.is_clonable_collection(m.guess_type(target, false)) && !rhs.contains('.clone()') && !rhs.starts_with('[') {
			rhs = '${rhs}.clone()'
		}
		m.emit('${mut_prefix}${lhs} := ${rhs}')
		if !m.state.in_main { m.local_vars_in_scope[lhs] = true }
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

fn (m &VariablesModule) is_mutable_target(node ast.Expression, name string) bool {
	// Simple heuristic for now, should ideally come from analyzer
	if node is ast.Attribute || node is ast.Subscript { return true }
	if name in m.local_vars_in_scope { return true }
	return true // Default to true to be safe in V
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
