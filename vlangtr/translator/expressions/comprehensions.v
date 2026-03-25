module expressions

import ast

fn (mut eg ExprGen) infer_generator_target_types(gen ast.Comprehension) {
	if gen.iter is ast.Call {
		iter_call := gen.iter
		if iter_call.func is ast.Name && gen.target is ast.Name {
			if iter_call.func.id in ['range', 'xrange', 'enumerate'] {
				eg.analyzer.type_map[gen.target.id] = 'int'
				return
			}
		}
	}
	if gen.iter is ast.List && gen.iter.elements.len > 0 && gen.target is ast.Name {
		eg.analyzer.type_map[gen.target.id] = eg.guess_type(gen.iter.elements[0])
	}
}

pub fn (mut eg ExprGen) emit_generators(generators []ast.Comprehension, body_callback fn (mut ExprGen)) {
	if generators.len == 0 {
		body_callback(mut eg)
		return
	}

	gen := generators[0]
	rest := generators[1..]
	eg.infer_generator_target_types(gen)

	if gen.is_async {
		eg.emit('// async comprehension requires manual review')
	}

	mut iter_expr := eg.visit(gen.iter)
	mut target := eg.visit(gen.target)
	mut is_enumerate := false

	if gen.iter is ast.Call {
		iter_call := gen.iter
		if iter_call.func is ast.Name {
			if iter_call.func.id == 'enumerate' {
				is_enumerate = true
				if iter_call.args.len > 0 {
					iter_expr = eg.visit(iter_call.args[0])
				}
				if gen.target is ast.Tuple && target.starts_with('[') && target.ends_with(']') {
					target = target[1..target.len - 1]
				}
			}

			if iter_call.func.id in ['range', 'xrange'] {
				mut start := '0'
				mut stop := '0'
				mut step := '1'
				if iter_call.args.len == 1 {
					stop = eg.visit(iter_call.args[0])
				} else if iter_call.args.len >= 2 {
					start = eg.visit(iter_call.args[0])
					stop = eg.visit(iter_call.args[1])
					if iter_call.args.len > 2 {
						step = eg.visit(iter_call.args[2])
					}
				}
				op := if step.starts_with('-') { '>' } else { '<' }
				eg.emit('for ${target} := ${start}; ${target} ${op} ${stop}; ${target} += ${step} {')
				eg.state.indent_level++
				for if_expr in gen.ifs {
					eg.emit('if ${eg.wrap_bool(if_expr, false)} {')
					eg.state.indent_level++
				}
				eg.emit_generators(rest, body_callback)
				for _ in gen.ifs {
					eg.state.indent_level--
					eg.emit('}')
				}
				eg.state.indent_level--
				eg.emit('}')
				return
			}
		}
	}

	if gen.target is ast.Tuple && !is_enumerate {
		val_name := 'py_comp_val_${eg.state.unique_id_counter + 1}'
		eg.emit('for ${val_name} in ${iter_expr} {')
		eg.state.indent_level++
		for i, elt in gen.target.elements {
			eg.emit('${eg.visit(elt)} := ${val_name}[${i}]')
		}
	} else {
		eg.emit('for ${target} in ${iter_expr} {')
		eg.state.indent_level++
	}

	for if_expr in gen.ifs {
		eg.emit('if ${eg.wrap_bool(if_expr, false)} {')
		eg.state.indent_level++
	}

	eg.emit_generators(rest, body_callback)

	for _ in gen.ifs {
		eg.state.indent_level--
		eg.emit('}')
	}
	eg.state.indent_level--
	eg.emit('}')
}

pub fn (mut eg ExprGen) visit_list_comp(node ast.ListComp, target_var string) ?string {
	mut target := target_var
	if target.len == 0 {
		eg.state.unique_id_counter++
		target = 'py_comp_${eg.state.unique_id_counter}'
	}

	mut elt_type := eg.guess_type(node.elt)
	if elt_type == 'unknown' {
		elt_type = 'int'
	}
	eg.emit('mut ${target} := []${elt_type}{}')
	eg.emit_generators(node.generators, fn [node, target] (mut eg ExprGen) {
		eg.emit('${target} << ${eg.visit(node.elt)}')
	})
	return target
}

pub fn (mut eg ExprGen) visit_generator_exp(node ast.GeneratorExp, target_var string) ?string {
	list_like := ast.ListComp{
		token:      node.token
		elt:        node.elt
		generators: node.generators
	}
	return eg.visit_list_comp(list_like, target_var)
}

pub fn (mut eg ExprGen) visit_dict_comp(node ast.DictComp, target_var string) ?string {
	mut target := target_var
	if target.len == 0 {
		eg.state.unique_id_counter++
		target = 'py_comp_${eg.state.unique_id_counter}'
	}
	key_type := eg.guess_type(node.key)
	val_type := eg.guess_type(node.value)
	eg.emit('mut ${target} := map[${key_type}]${val_type}{}')
	eg.emit_generators(node.generators, fn [node, target] (mut eg ExprGen) {
		eg.emit('${target}[${eg.visit(node.key)}] = ${eg.visit(node.value)}')
	})
	return target
}

pub fn (mut eg ExprGen) visit_set_comp(node ast.SetComp, target_var string) ?string {
	mut target := target_var
	if target.len == 0 {
		eg.state.unique_id_counter++
		target = 'py_comp_${eg.state.unique_id_counter}'
	}
	key_type := eg.guess_type(node.elt)
	eg.emit('mut ${target} := datatypes.Set[${key_type}]{}')
	eg.emit_generators(node.generators, fn [node, target] (mut eg ExprGen) {
		eg.emit('${target}.add(${eg.visit(node.elt)})')
	})
	return target
}
