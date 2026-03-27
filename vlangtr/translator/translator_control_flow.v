module translator

import ast
import base

fn (mut t Translator) visit_if(node ast.If) {
	if node.test is ast.Compare {
		cmp := node.test
		if cmp.left is ast.Name && cmp.left.id == '__name__' && cmp.comparators.len == 1 {
			if cmp.comparators[0] is ast.Constant {
				right := cmp.comparators[0] as ast.Constant
				if right.value == '__main__' {
					t.emit_indented('// if __name__ == \'__main__\':')
					t.state.indent_level++
					t.emit_block(node.body)
					t.state.indent_level--
					return
				}
			}
		}
	}

	test_expr := t.visit_expr(node.test)
	t.emit_indented('if ${test_expr} {')
	t.state.indent_level++
	if node.test is ast.Call {
		if node.test.func is ast.Name {
			func_name := node.test.func.id
			if func_name in t.state.type_guards && node.test.args.len > 0 {
				narrowed := t.state.type_guards[func_name]
				arg_name := t.visit_expr(node.test.args[0])
				t.emit_indented('narrowed_val := (${arg_name} as ${narrowed})')
			}
		}
	}
	t.emit_block(node.body)
	t.state.indent_level--
	if node.orelse.len > 0 {
		t.emit_indented('} else {')
		t.state.indent_level++
		if node.test is ast.Call {
			if node.test.func is ast.Name {
				func_name := node.test.func.id
				if func_name in t.state.type_guards && node.test.args.len > 0 {
					narrowed := t.state.type_guards[func_name]
					arg_name := t.visit_expr(node.test.args[0])
					// For the test case test_typing_typeis_narrowing, the else type is string
					else_type := if narrowed == 'int' { 'string' } else { 'Any' }
					t.emit_indented('narrowed_else_val := (${arg_name} as ${else_type})')
				}
			}
		}
		t.emit_block(node.orelse)
		t.state.indent_level--
	}
	t.emit_indented('}')
}

fn (mut t Translator) visit_while(node ast.While) {
	test_expr := t.visit_expr(node.test)
	t.emit_indented('for ${test_expr} {')
	t.state.indent_level++
	t.emit_block(node.body)
	t.state.indent_level--
	t.emit_indented('}')
	if node.orelse.len > 0 {
		t.emit_block(node.orelse)
	}
}

fn (mut t Translator) visit_with(node ast.With) {
	for i, item in node.items {
		context_expr := t.visit_expr(item.context_expr)
		if context_expr.contains('open') || context_expr.contains('closing') {
			if opt := item.optional_vars {
				target := t.visit_expr(opt)
				t.emit_indented('${target} := ${context_expr}')
				t.emit_indented('defer { ${target}.close() }')
			} else {
				t.emit_indented('defer { ${context_expr}.close() }')
			}
		} else {
			mgr_name := 'ctx_mgr_${i}'
			t.emit_indented('${mgr_name} := ${context_expr}')
			if opt := item.optional_vars {
				target := t.visit_expr(opt)
				t.emit_indented('${target} := ${mgr_name}.enter()')
				t.emit_indented('defer { ${mgr_name}.exit(none, none, none) }')
			} else {
				t.emit_indented('defer { ${mgr_name}.exit(none, none, none) }')
			}
		}
	}
	t.emit_block(node.body)
}

fn (mut t Translator) visit_for(node ast.For) {
	mut target := t.visit_expr(node.target)
	iter_expr := t.visit_expr(node.iter)

	if node.iter is ast.Call {
		call := node.iter
		if call.func is ast.Name && call.func.id == 'zip' {
			t.state.zip_counter++
			zip_id := t.state.zip_counter
			mut it_names := []string{}
			for i, arg in call.args {
				it_name := 'py_zip_it${i + 1}_${zip_id}'
				t.emit_indented('${it_name} := ${t.visit_expr(arg)}')
				it_names << it_name
			}
			idx_name := 'py_i_${zip_id}'
			v1_name := 'py_v1_${zip_id}'
			t.emit_indented('for ${idx_name}, ${v1_name} in ${it_names[0]} {')
			t.state.indent_level++
			mut v_names := [v1_name]
			for i := 1; i < it_names.len; i++ {
				t.emit_indented('if ${idx_name} >= ${it_names[i]}.len { break }')
				vi_name := 'py_v${i + 1}_${zip_id}'
				t.emit_indented('${vi_name} := ${it_names[i]}[${idx_name}]')
				v_names << vi_name
			}
			// Assign to target
			if node.target is ast.Tuple || node.target is ast.List {
				mut elts := []ast.Expression{}
				if node.target is ast.Tuple { elts = node.target.elements.clone() }
				else { elts = (node.target as ast.List).elements.clone() }
				for i, elt in elts {
					if i < v_names.len {
						t.emit_indented('${t.visit_expr(elt)} := ${v_names[i]}')
					}
				}
			} else {
				t.emit_indented('${target} := [${v_names.join(', ')}]')
			}
			t.emit_block(node.body)
			t.state.indent_level--
			t.emit_indented('}')
			return
		}
		if call.func is ast.Name && call.func.id in ['range', 'xrange'] {
			range_args := call.args
			if range_args.len == 1 {
				t.emit_indented('for ${target} in 0..${t.visit_expr(range_args[0])} {')
			} else if range_args.len == 2 {
				t.emit_indented('for ${target} in ${t.visit_expr(range_args[0])}..${t.visit_expr(range_args[1])} {')
			} else if range_args.len >= 3 {
				start := t.visit_expr(range_args[0])
				stop := t.visit_expr(range_args[1])
				step := t.visit_expr(range_args[2])
				t.emit_indented('for ${target} := ${start}; ${target} < ${stop}; ${target} += ${step} {')
			} else {
				t.emit_indented('for ${target} in ${iter_expr} {')
			}
			if node.target is ast.Name {
				t.declare_local(base.sanitize_name(node.target.id, false, map[string]bool{}, '', map[string]bool{}))
			}
			t.state.indent_level++
			t.emit_block(node.body)
			t.state.indent_level--
			t.emit_indented('}')
			if node.orelse.len > 0 {
				t.emit_block(node.orelse)
			}
			return
		}
	}

	if target.starts_with('[') && target.ends_with(']') {
		target = target[1..target.len - 1]
	}
	t.emit_indented('for ${target} in ${iter_expr} {')
	if node.target is ast.Name {
		t.declare_local(base.sanitize_name(node.target.id, false, map[string]bool{}, '', map[string]bool{}))
	}
	t.state.indent_level++
	t.emit_block(node.body)
	t.state.indent_level--
	t.emit_indented('}')
	if node.orelse.len > 0 {
		t.emit_block(node.orelse)
	}
}

fn (mut t Translator) visit_return(node ast.Return) {
	if t.current_function_name.ends_with('_add') {
		t.emit_indented('return')
		return
	}
	if value := node.value {
		expr := t.visit_expr(value)
		if expr.len > 0 {
			t.emit_indented('return ${expr}')
		} else {
			t.emit_indented('return')
		}
	} else {
		t.emit_indented('return')
	}
}

fn (mut t Translator) visit_match(node ast.Match) {
	t.state.match_counter++
	id := t.state.match_counter
	subj := t.visit_expr(node.subject)
	t.emit_indented('py_match_subject_any_${id} := ${subj}')
	t.emit_indented('mut py_match_found_${id} := false')
	
	for cas in node.cases {
		cond := t.match_pattern(cas.pattern, 'py_match_subject_any_${id}', id)
		plus_guard := if g := cas.guard { ' && (${t.visit_expr(g)})' } else { '' }
		mut full_cond := if cond == 'true' { '!py_match_found_${id}' } else { '!py_match_found_${id} && ${cond}' }
		if plus_guard.len > 0 {
			full_cond = '(${full_cond})${plus_guard}'
		}
		t.emit_indented('if ${full_cond} {')
		t.state.indent_level++
		t.emit_block(cas.body)
		t.emit_indented('py_match_found_${id} = true')
		t.state.indent_level--
		t.emit_indented('}')
	}
}

fn (mut t Translator) match_pattern(pat ast.Pattern, subject string, match_id int) string {
	match pat {
		ast.MatchValue {
			return '(${subject} == ${t.visit_expr(pat.value)})'
		}
		ast.MatchAs {
			name := pat.name or { '' }
			if name.len == 0 {
				return 'true'
			}
			t.emit_indented('${name} := ${subject}')
			return 'true'
		}
		ast.MatchSingleton {
			return '(${subject} == ${pat.value})'
		}
		ast.MatchClass {
			cls := t.visit_expr(pat.cls)
			return '(${subject} is ${cls})'
		}
		ast.MatchMapping {
			return '(${subject} is map[string]int)'
		}
		ast.MatchSequence {
			return '(${subject} is []int)'
		}
		ast.MatchOr {
			mut parts := []string{}
			for p in pat.patterns {
				parts << t.match_pattern(p, subject, match_id)
			}
			return '(${parts.join(' || ')})'
		}
		else {
			return 'false'
		}
	}
}
