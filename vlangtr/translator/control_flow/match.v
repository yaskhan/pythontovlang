module control_flow

import ast

fn (m &ControlFlowModule) normalize_match_class_name(expr string) string {
	mut name := expr
	if name.contains('.') {
		name = name.all_after('.')
	}
	if name.starts_with('[') && name.ends_with(']') {
		name = name[1..name.len - 1]
	}
	if name.len > 0 {
		first := name[0]
		if first >= `a` && first <= `z` {
			name = first.ascii_str().to_upper() + name[1..]
		}
	}
	return name
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
	if pattern is ast.MatchStar {
		if name := pattern.name {
			if name.len > 0 {
				bindings << '${name} := ${subject_expr}'
			}
		}
		return 'true', bindings
	}
	if pattern is ast.MatchAs {
		if subpat := pattern.pattern {
			cond, sub_bindings := m.compile_pattern(subpat, subject_expr)
			bindings << sub_bindings
			if name := pattern.name {
				if name.len > 0 {
					bindings << '${name} := ${subject_expr}'
				}
			}
			return cond, bindings
		}
		if name := pattern.name {
			if name.len > 0 {
				bindings << '${name} := ${subject_expr}'
			}
		}
		return 'true', bindings
	}
	if pattern is ast.MatchOr {
		mut parts := []string{}
		for sub in pattern.patterns {
			cond, sub_bindings := m.compile_pattern(sub, subject_expr)
			parts << '(${cond})'
			if bindings.len == 0 {
				bindings << sub_bindings
			}
		}
		return parts.join(' || '), bindings
	}
	if pattern is ast.MatchSequence {
		mut parts := []string{}
		for i, sub in pattern.patterns {
			if sub is ast.MatchStar {
				if name := sub.name {
					if name.len > 0 {
						bindings << '${name} := ${subject_expr}'
					}
				}
				continue
			}
			cond, sub_bindings := m.compile_pattern(sub, '${subject_expr}[${i}]')
			parts << '(${cond})'
			bindings << sub_bindings
		}
		len_check := if pattern.patterns.len == 0 { 'true' } else { '${subject_expr}.len >= ${pattern.patterns.len}' }
		if parts.len > 0 {
			return '${len_check} && ${parts.join(' && ')}', bindings
		}
		return len_check, bindings
	}
	if pattern is ast.MatchMapping {
		mut parts := []string{}
		for i, sub in pattern.patterns {
			if i >= pattern.keys.len {
				continue
			}
			key_expr := m.visit_expr(pattern.keys[i])
			parts << '${key_expr} in ${subject_expr}'
			cond, sub_bindings := m.compile_pattern(sub, '${subject_expr}[${key_expr}]')
			parts << '(${cond})'
			bindings << sub_bindings
		}
		if rest := pattern.rest {
			if rest.len > 0 {
				bindings << '${rest} := ${subject_expr}'
			}
		}
		if parts.len > 0 {
			return parts.join(' && '), bindings
		}
		return 'true', bindings
	}
	if pattern is ast.MatchClass {
		cls_name := m.normalize_match_class_name(m.visit_expr(pattern.cls))
		mut parts := ['${subject_expr} is ${cls_name}']
		for i, sub in pattern.patterns {
			cond, sub_bindings := m.compile_pattern(sub, '${subject_expr}[${i}]')
			parts << '(${cond})'
			bindings << sub_bindings
		}
		for i, sub in pattern.kwd_patterns {
			if i < pattern.kwd_attrs.len {
				attr := pattern.kwd_attrs[i]
				cond, sub_bindings := m.compile_pattern(sub, '${subject_expr}.${attr}')
				parts << '(${cond})'
				bindings << sub_bindings
			}
		}
		return parts.join(' && '), bindings
	}

	return 'false', bindings
}

pub fn (mut m ControlFlowModule) visit_match(node ast.Match) {
	m.env.state.unique_id_counter++
	match_id := m.env.state.unique_id_counter
	subject := m.visit_expr(node.subject)
	subject_var := 'py_match_subject_${match_id}'
	found_var := 'py_match_found_${match_id}'

	m.emit('// Match statement lowered to if blocks')
	m.emit('${subject_var} := ${subject}')
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
		cond, bindings := m.compile_pattern(case.pattern, subject_var)
		if cond == 'true' {
			m.emit('if !${found_var} {')
		} else {
			m.emit('if !${found_var} && (${cond}) {')
		}
		m.env.state.indent_level++
		for binding in bindings {
			m.emit(binding)
		}
		if guard := case.guard {
			guard_expr := m.visit_expr(guard)
			m.emit('if (${guard_expr}) {')
			m.env.state.indent_level++
			for stmt in case.body {
				m.visit_stmt(stmt)
			}
			m.emit('${found_var} = true')
			m.env.state.indent_level--
			m.emit('}')
		} else {
			for stmt in case.body {
				m.visit_stmt(stmt)
			}
			m.emit('${found_var} = true')
		}
		m.env.state.indent_level--
		m.emit('}')
		if cond == 'true' && case.guard == none {
			break
		}
	}
}
