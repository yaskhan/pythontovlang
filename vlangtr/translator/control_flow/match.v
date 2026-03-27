module control_flow

import ast

fn (m &ControlFlowModule) unmangle_generic_name(name string) string {
	if !name.contains('__py2v_gen') {
		return m.map_python_type(name, false)
	}
	res := name.replace('__py2v_gen_L__', '[').replace('__py2v_gen_R__', ']').replace('__py2v_gen_C__', ', ')
		.replace('_py2v_gen_L_', '[').replace('_py2v_gen_R_', ']').replace('_py2v_gen_C_', ', ')
	return m.map_python_type(res, false)
}

fn (mut m ControlFlowModule) compile_pattern(pattern ast.Pattern, subject_expr string) (string, []string) {
	mut bindings := []string{}

	if pattern is ast.MatchValue {
		return '${subject_expr} == ${m.visit_expr(pattern.value)}', bindings
	}
	if pattern is ast.MatchSingleton {
		if pattern.value.value == 'None' {
			return '${subject_expr} is none', bindings
		}
		return '${subject_expr} == ${pattern.value.value.to_lower()}', bindings
	}
	if pattern is ast.MatchSequence {
		array_types := ['[]int', '[]f64', '[]string', '[]bool', '[]Any']
		mut star_idx := -1
		for i, p in pattern.patterns {
			if p is ast.MatchStar {
				star_idx = i
				break
			}
		}

		mut checks := []string{}
		mut or_parts := []string{}

		for t in array_types {
			l_chk := if star_idx == -1 {
				'(${subject_expr} as ${t}).len == ${pattern.patterns.len}'
			} else {
				'(${subject_expr} as ${t}).len >= ${pattern.patterns.len - 1}'
			}
			or_parts << '(${subject_expr} is ${t} && ${l_chk})'
		}

		for i, p in pattern.patterns {
			if p is ast.MatchStar {
				if name := p.name {
					mut branches := []string{}
					for t in array_types {
						num_trailing := pattern.patterns.len - 1 - i
						end_expr := '((${subject_expr} as ${t}).len - ${num_trailing})'
						slice_expr := if num_trailing == 0 { '[${i}..]' } else { '[${i}..${end_expr}]' }
						branches << '${subject_expr} is ${t} { Any((${subject_expr} as ${t})${slice_expr}) }'
					}
					branches << 'else { Any(0) }'
					extract := 'if ${branches.join(' else if ')}'
					bindings << '${name} := ${extract}'
				}
				continue
			}

			mut sub_expr_branches := []string{}
			for t in array_types {
				idx := if star_idx != -1 && i > star_idx {
					offset := pattern.patterns.len - i
					'((${subject_expr} as ${t}).len - ${offset})'
				} else {
					'${i}'
				}
				sub_expr_branches << '${subject_expr} is ${t} { Any((${subject_expr} as ${t})[${idx}]) }'
			}
			sub_expr_branches << 'else { Any(0) }'
			sub_expr := 'if ${sub_expr_branches.join(' else if ')}'

			sub_cond, sub_binds := m.compile_pattern(p, sub_expr)
			checks << '(${sub_cond})'
			bindings << sub_binds
		}

		type_len_condition := '(' + or_parts.join(' || ') + ')'
		full_condition := if checks.len > 0 { '${type_len_condition} && ${checks.join(' && ')}' } else { type_len_condition }
		return full_condition, bindings
	}
	if pattern is ast.MatchMapping {
		map_types := ['map[string]int', 'map[string]string', 'map[string]Any']
		mut or_parts := []string{}
		for t in map_types {
			mut chk := '(${subject_expr} is ${t})'
			for k in pattern.keys {
				chk += ' && (${m.visit_expr(k)} in (${subject_expr} as ${t}))'
			}
			or_parts << chk
		}
		mut cond := '(' + or_parts.join(' || ') + ')'
		for i, p in pattern.patterns {
			k_val := m.visit_expr(pattern.keys[i])
			mut branches := []string{}
			for t in map_types {
				branches << '${subject_expr} is ${t} { Any((${subject_expr} as ${t})[${k_val}]) }'
			}
			extract := 'if ${branches.join(' else if ')} else { Any(0) }'
			sub_cond, sub_binds := m.compile_pattern(p, extract)
			cond += ' && (${sub_cond})'
			bindings << sub_binds
		}
		if rest := pattern.rest {
			m.env.state.used_builtins['py_dict_residual'] = true
			exclude := '[]string{' + pattern.keys.map(m.visit_expr(it)).join(', ') + '}'
			mut branches := []string{}
			for t in map_types {
				branches << '${subject_expr} is ${t} { Any(py_dict_residual((${subject_expr} as ${t}), ${exclude})) }'
			}
			extract := 'if ${branches.join(' else if ')} else { Any(map[string]Any{}) }'
			bindings << '${rest} := ${extract}'
		}
		return cond, bindings
	}
	if pattern is ast.MatchClass {
		cls_name_expr := m.visit_expr(pattern.cls)
		mut cls_name := m.unmangle_generic_name(cls_name_expr)
		if cls_name.len > 0 && !cls_name[0].is_capital() && !cls_name.contains('[') {
			cls_name = cls_name[0].ascii_str().to_upper() + cls_name[1..]
		}
		mut cond := '(${subject_expr} is ${cls_name})'
		match_args := m.env.state.dataclasses[cls_name] or { m.env.state.dataclasses[cls_name_expr] or { []string{} } }
		for i, sub in pattern.patterns {
			attr := if i < match_args.len { match_args[i] } else { 'py_${i}' }
			val_expr := 'Any((${subject_expr} as ${cls_name}).${attr})'
			sub_cond, sub_binds := m.compile_pattern(sub, val_expr)
			cond += ' && (${sub_cond})'
			bindings << sub_binds
		}
		for i in 0 .. pattern.kwd_attrs.len {
			attr := pattern.kwd_attrs[i]
			sub := pattern.kwd_patterns[i]
			val_expr := 'Any((${subject_expr} as ${cls_name}).${attr})'
			sub_cond, sub_binds := m.compile_pattern(sub, val_expr)
			cond += ' && (${sub_cond})'
			bindings << sub_binds
		}
		return cond, bindings
	}
	if pattern is ast.MatchOr {
		mut parts := []string{}
		for sub in pattern.patterns {
			sub_cond, sub_binds := m.compile_pattern(sub, subject_expr)
			parts << '(${sub_cond})'
			// Simplified bindings for OR: only keep if all alternatives have them
			if bindings.len == 0 { bindings << sub_binds }
		}
		return parts.join(' || '), bindings
	}
	if pattern is ast.MatchAs {
		mut cond := 'true'
		mut val_expr := subject_expr
		if sub := pattern.pattern {
			sc, sb := m.compile_pattern(sub, subject_expr)
			cond = sc
			bindings << sb
			if sub is ast.MatchClass {
				cn_expr := m.visit_expr(sub.cls)
				mut cn := m.unmangle_generic_name(cn_expr)
				if cn.len > 0 && !cn[0].is_capital() { cn = cn[0].ascii_str().to_upper() + cn[1..] }
				val_expr = '(${subject_expr} as ${cn})'
			}
		}
		if name := pattern.name {
			bindings << '${name} := ${val_expr}'
		}
		return cond, bindings
	}
	if pattern is ast.MatchStar {
		if name := pattern.name {
			bindings << '${name} := ${subject_expr}'
		}
		return 'true', bindings
	}
	return 'false', bindings
}

pub fn (mut m ControlFlowModule) visit_match(node ast.Match) {
	m.env.state.unique_id_counter++
	match_id := m.env.state.unique_id_counter
	subject := m.visit_expr(node.subject)
	subject_var := 'py_match_subject_${match_id}'
	subject_any := 'py_match_subject_any_${match_id}'
	found_var := 'py_match_found_${match_id}'

	m.emit('// Match statement lowered to if blocks')
	m.emit('${subject_var} := ${subject}')
	m.emit('${subject_any} := Any(${subject_var})')
	m.emit('mut ${found_var} := false')

	mut expanded_cases := []ast.MatchCase{}
	for case in node.cases {
		if case.pattern is ast.MatchOr {
			for sub in case.pattern.patterns {
				expanded_cases << ast.MatchCase{
					pattern: sub
					guard:   case.guard
					body:    case.body
				}
			}
		} else {
			expanded_cases << case
		}
	}

	for case in expanded_cases {
		cond, bindings := m.compile_pattern(case.pattern, subject_any)
		if cond == 'true' {
			m.emit('if !${found_var} {')
		} else {
			m.emit('if !${found_var} && (${cond}) {')
		}
		m.env.state.indent_level++
		for binding in bindings { m.emit(binding) }
		if guard := case.guard {
			guard_expr := m.visit_expr(guard)
			m.emit('if (${guard_expr}) {')
			m.env.state.indent_level++
			for stmt in case.body { m.visit_stmt(stmt) }
			m.emit('${found_var} = true')
			m.env.state.indent_level--
			m.emit('}')
		} else {
			for stmt in case.body { m.visit_stmt(stmt) }
			m.emit('${found_var} = true')
		}
		m.env.state.indent_level--
		m.emit('}')
		if cond == 'true' && case.guard == none {
			break
		}
	}
}
