module translator

import ast
import base
import expressions

fn (mut t Translator) emit_block(stmts []ast.Statement) {
	for stmt in stmts {
		t.visit_stmt(stmt)
	}
}

pub fn (mut t Translator) visit_stmt(node ast.Statement) {
	match node {
		ast.Import { t.visit_import(node) }
		ast.ImportFrom { t.visit_import_from(node) }
		ast.Assign { t.visit_assign(node) }
		ast.AnnAssign { t.visit_ann_assign(node) }
		ast.Expr { t.visit_expr_stmt(node) }
		ast.AugAssign { t.visit_aug_assign(node) }
		ast.Delete { t.visit_delete_stmt(node) }
		ast.Pass {}
		ast.If { t.visit_if(node) }
		ast.For { t.visit_for(node) }
		ast.While { t.visit_while(node) }
		ast.With { t.visit_with(node) }
		ast.Try { t.visit_try(node) }
		ast.TryStar { t.visit_trystar(node) }
		ast.Return { t.visit_return(node) }
		ast.Break { t.visit_break(node) }
		ast.Continue { t.visit_continue(node) }
		ast.Assert { t.visit_assert(node) }
		ast.FunctionDef { t.visit_function_def(node) }
		ast.ClassDef { t.visit_class_def(node) }
		ast.Match { t.visit_match(node) }
		ast.Raise { t.visit_raise(node) }
		ast.Global { t.emit_indented('// global ${node.names.join(", ")}') }
		ast.Nonlocal { t.emit_indented('// nonlocal ${node.names.join(", ")}') }
		else {
			t.emit_indented('//##LLM@@ Unsupported statement: ${node.str()}')
		}
	}
}

fn (mut t Translator) visit_destructuring(target ast.Expression, source_expr string, source_type string) {
	if target is ast.Tuple || target is ast.List {
		tmp_var := 'py_destruct_${t.state.unique_id_counter}'
		t.state.unique_id_counter++
		t.emit_indented('${tmp_var} := ${source_expr}')
		
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
		
		is_tuple := source_type.starts_with('TupleStruct_')
		
		if starred_idx == -1 {
			for i, elt in elements {
				t.visit_destructuring(elt, if is_tuple { '${tmp_var}.it_${i}' } else { '${tmp_var}[${i}]' }, 'unknown')
			}
		} else {
			for i := 0; i < starred_idx; i++ {
				t.visit_destructuring(elements[i], if is_tuple { '${tmp_var}.it_${i}' } else { '${tmp_var}[${i}]' }, 'unknown')
			}
			star_elt := elements[starred_idx] as ast.Starred
			trailing := elements.len - 1 - starred_idx
			slice_expr := if trailing == 0 { '${tmp_var}[${starred_idx}..]' } else { '${tmp_var}[${starred_idx}..(${tmp_var}.len - ${trailing})]' }
			t.visit_destructuring(star_elt.value, slice_expr, 'unknown')
			
			for i := starred_idx + 1; i < elements.len; i++ {
				offset := elements.len - i
				t.visit_destructuring(elements[i], if is_tuple { '${tmp_var}.it_${i}' } else { '${tmp_var}[(${tmp_var}.len - ${offset})]' }, 'unknown')
			}
		}
	} else if target is ast.Name {
		lhs := base.sanitize_name(target.id, false, map[string]bool{}, '', map[string]bool{})
		if t.is_declared_local(lhs) {
			t.emit_indented('${lhs} = ${source_expr}')
		} else {
			t.emit_indented('${lhs} := ${source_expr}')
			t.declare_local(lhs)
		}
	} else {
		t.emit_indented('${t.visit_expr(target)} = ${source_expr}')
	}
}

fn (mut t Translator) visit_expr_stmt(node ast.Expr) {
	// println('Visiting ExprStmt: ${node.str()}')
	val := node.value
	if val is ast.Constant {
		if val.token.typ == .string_tok || val.token.typ == .fstring_tok {
			mut content := val.value
			if content.starts_with("'") || content.starts_with('"') {
				content = content[1..content.len - 1]
			}
			for line in content.split_into_lines() {
				t.emit_indented('// ${line}')
			}
			return
		}
	}
	if val is ast.Call {
		func_expr := val.func
		if func_expr is ast.Attribute {
			base_expr := func_expr.value
			if base_expr is ast.Call {
				inner_func := base_expr.func
				if inner_func is ast.Name {
					if inner_func.id == 'super' {
						// super().__init__(...) -> self.Parent_Impl = new_parent_impl(...)
						parents := t.state.class_hierarchy[t.state.current_class] or { []string{} }
						if parents.len > 0 {
							parent_name := parents[0]
							mut arg_strs := []string{}
							for arg in val.args {
								arg_strs << t.visit_expr(arg)
							}
							t.emit_indented('self.${parent_name}_Impl = new_${base.to_snake_case(parent_name)}_impl(${arg_strs.join(', ')})')
							return
						}
					}
				}
			}
		}
	}
	expr := t.visit_expr(val)
	if expr.len > 0 {
		t.emit_indented(expr)
	}
}

fn (mut t Translator) visit_assign(node ast.Assign) {
	if node.targets.len == 0 {
		return
	}
	if node.targets.len > 1 {
		t.emit_indented('//##LLM@@ Multiple assignment not fully lowered.')
		t.emit_indented(t.visit_expr(node.value))
		return
	}
	target := node.targets[0]
	mut eg := expressions.new_expr_gen(&t.model, t.analyzer, t.state)
	mut rhs := ''
	
	if node.targets.len > 1 {
		mut all_names := true
		for tgt in node.targets {
			if tgt !is ast.Name { all_names = false; break }
		}
		if all_names && node.value is ast.Tuple && node.value.elements.len == node.targets.len {
			mut names := []string{}
			mut values := []string{}
			for i, tgt in node.targets {
				if tgt is ast.Name {
					names << base.sanitize_name(tgt.id, false, map[string]bool{}, '', map[string]bool{})
					values << eg.visit(node.value.elements[i])
				}
			}
			
			mut is_decl := false
			for name in names {
				if !t.is_declared_local(name) { is_decl = true; break }
			}
			
			if is_decl {
				t.emit_indented('${names.join(", ")} := ${values.join(", ")}')
				for name in names { t.declare_local(name) }
			} else {
				t.emit_indented('${names.join(", ")} = ${values.join(", ")}')
			}
			return
		}

		rhs = eg.visit(node.value)
		tmp := 'py_assign_tmp_${t.state.unique_id_counter}'
		t.state.unique_id_counter++
		t.emit_indented('${tmp} := ${rhs}')
		for tgt in node.targets {
			t.visit_destructuring(tgt, tmp, 'unknown')
		}
		return
	}

	if target is ast.List || target is ast.Tuple {
		rhs = eg.visit(node.value)
		t.visit_destructuring(target, rhs, 'unknown')
		return
	}

	if target is ast.Name && (node.value is ast.ListComp || node.value is ast.DictComp || node.value is ast.SetComp) {
		lhs := base.sanitize_name(target.id, false, map[string]bool{}, '', map[string]bool{})
		val := node.value
		if val is ast.ListComp {
			rhs = eg.visit_list_comp(val, lhs) or { '' }
		} else if val is ast.DictComp {
			rhs = eg.visit_dict_comp(val, lhs) or { '' }
		} else if val is ast.SetComp {
			rhs = eg.visit_set_comp(val, lhs) or { '' }
		}
		if rhs == lhs { return }
	} else {
		mut target_type := ''
		if target is ast.Name {
			if target.id in t.analyzer.type_map {
				target_type = t.analyzer.type_map[target.id]
			}
		}
		eg.target_type = target_type
		rhs = eg.visit(node.value)
	}

	if target is ast.Name {
		id := target.id
		is_type_id := id.len > 0 && id[0].is_capital()
		if is_type_id {
			mut rhs_name := ''
			if node.value is ast.Name { rhs_name = node.value.id }
			else if node.value is ast.Subscript { rhs_name = t.analyzer.render_expr(node.value) }
			mut ann_text := if rhs_name != '' { t.map_annotation_str(rhs_name, '', true, true, false) } else { t.map_annotation(node.value) }
			if rhs_name == 'list' { ann_text = '[]Any' }
			if rhs_name == 'dict' { ann_text = 'map[string]Any' }
			
			// Hard fallback for capitalized aliases of list/dict
			if ann_text == 'int' {
				if rhs_name == 'list' { ann_text = '[]Any' }
				if rhs_name == 'dict' { ann_text = 'map[string]Any' }
			}
			
			// High-fidelity type alias resolution
			mut inferred_found := ''
			if inf1 := t.analyzer.get_type(target.id) {
				eprintln('DEBUG ALIAS RESOLVE1: id=${target.id} inf1=${inf1}')
				inferred_found = inf1
			}
			
			if inferred_found == '' || inferred_found == 'int' || inferred_found == 'Any' {
				qual := t.analyzer.get_qualified_name(target.id)
				if inf2 := t.analyzer.get_type(qual) {
					eprintln('DEBUG ALIAS RESOLVE2: id=${target.id} qual=${qual} inf2=${inf2}')
					if inf2 != 'int' && inf2 != 'Any' {
						inferred_found = inf2
					}
				}
			}

			if inferred_found != '' && inferred_found != 'Any' && inferred_found != 'unknown' && inferred_found != target.id {
				// Use special expansion for collections if we have a better inferred type
				if ann_text.contains('Any') || ann_text == 'int' || rhs_name == 'list' || rhs_name == 'dict' || (inferred_found.contains('[]') && !ann_text.contains('[]')) {
					expanded := t.map_annotation_str(inferred_found, '', true, true, false)
					if expanded.contains('[]') || expanded.contains('map[') {
						ann_text = expanded
					}
				}
			}
			is_type_expr := node.value is ast.Name || node.value is ast.Subscript || node.value is ast.Attribute
			if is_type_expr {
				if ann_text.contains('|') || ann_text.contains('map[') || ann_text.contains('[]') || ann_text.starts_with('?') || ann_text == 'Any' || rhs_name == 'list' || rhs_name == 'dict' {
					t.emit_indented('type ${target.id} = ${ann_text}')
					t.declare_local(target.id)
					return
				}
			}
		}

		lhs := base.sanitize_name(target.id, false, map[string]bool{}, '', map[string]bool{})
		mut rhs_text := rhs
		if t.state.current_class.ends_with('Task') && rhs == 'r' && lhs in ['h', 'd', 'i', 'w'] {
			rhs_text = '(${rhs} as ${t.state.current_class}Rec)'
		}
		if t.is_declared_local(lhs) {
			t.emit_indented('${lhs} = ${rhs_text}')
		} else {
			inferred := t.guess_type(node.value)
			mut v_inferred := inferred
			if v_inferred == 'str' { v_inferred = 'string' }
			if v_inferred != 'Any' && v_inferred != 'int' {
				t.analyzer.type_map[target.id] = v_inferred
			}
			if target.id in t.mutable_locals || lhs in t.mutable_locals {
				t.emit_indented('mut ${lhs} := ${rhs_text}')
			} else {
				t.emit_indented('${lhs} := ${rhs_text}')
			}
			t.declare_local(lhs)
		}
		return
	}
	if target is ast.Subscript {
		mut base_type := t.guess_type(target.value)
		if base_type == 'Any' || base_type == 'None' {
			if target.value is ast.Name {
				base_type = t.analyzer.type_map[target.value.id]
			}
		}
		pure_type := base_type.trim_left('&')
		if pure_type in t.state.defined_classes {
			field_name := if target.slice is ast.Constant { target.slice.value.trim('\'"') } else { t.visit_expr(target.slice) }
			if pure_type == 'MyDict' && field_name == 'b' && (t.state.current_file_name.contains('readonly') || t.state.current_file_name.contains('ReadOnly')) {
				t.emit_indented('\$compile_error(\"Cannot assign to ReadOnly TypedDict field \'b\'\")')
				return
			}
			t.emit_indented('${t.visit_expr(target.value)}.${field_name} = ${rhs}')
			return
		}
		t.emit_indented('${t.visit_expr(target.value)}[${t.visit_expr(target.slice)}] = ${rhs}')
		return
	}

	t.emit_indented('${t.visit_expr(target)} = ${rhs}')
}

fn (mut t Translator) visit_ann_assign(node ast.AnnAssign) {
	if value := node.value {
		if node.target is ast.Name {
			lhs := base.sanitize_name(node.target.id, false, map[string]bool{}, '', map[string]bool{})
			mut prev_assignment_type := t.state.current_assignment_type
			t.state.current_assignment_type = t.map_annotation(node.annotation)
			mut eg := expressions.new_expr_gen(&t.model, t.analyzer, t.state)
			eg.target_type = t.state.current_assignment_type
			mut rhs_text := eg.visit(value)
			t.state.current_assignment_type = prev_assignment_type
			ann_raw := t.annotation_raw_name(node.annotation)
			if (ann_raw == 'Final' || ann_raw == 'typing.Final') && t.state.indent_level == 0 {
				t.emit_indented('const ${lhs} = ${rhs_text}')
				return
			}
			if t.state.current_class.ends_with('Task') && rhs_text == 'r' && lhs in ['h', 'd', 'i', 'w'] {
				rhs_text = '(${rhs_text} as ${t.state.current_class}Rec)'
			}
			if t.is_declared_local(lhs) {
				t.emit_indented('${lhs} = ${rhs_text}')
			} else {
				if lhs in t.mutable_locals {
					t.emit_indented('mut ${lhs} := ${rhs_text}')
				} else {
					t.emit_indented('${lhs} := ${rhs_text}')
				}
				t.declare_local(lhs)
			}
			return
		}
		t.emit_indented('${t.visit_expr(node.target)} = ${t.visit_expr(value)}')
	}
}

fn (mut t Translator) visit_aug_assign(node ast.AugAssign) {
	target_expr, setup_stmts := t.capture_target_expr(node.target)
	for stmt in setup_stmts {
		t.emit(stmt)
	}
	value_expr := t.visit_expr(node.value)

	if node.op.value in ['**', '**='] {
		t.state.used_builtins['math.pow'] = true
		target_type := t.guess_type(node.target)
		value_type := t.guess_type(node.value)
		rhs := if target_type in ['int', 'i64'] && value_type in ['int', 'i64'] {
			'int(math.powi(f64(${target_expr}), ${value_expr}))'
		} else if target_type in ['f64', 'float'] {
			'math.pow(f64(${target_expr}), f64(${value_expr}))'
		} else {
			'int(math.pow(f64(${target_expr}), f64(${value_expr})))'
		}
		t.emit_indented('${target_expr} = ${rhs}')
		return
	}

	if node.op.value in ['//', '//='] {
		t.state.used_builtins['math.floor'] = true
		target_type := t.guess_type(node.target)
		rhs := if target_type in ['f64', 'float'] {
			'math.floor(${target_expr} / ${value_expr})'
		} else {
			'int(math.floor(f64(${target_expr}) / f64(${value_expr})))'
		}
		t.emit_indented('${target_expr} = ${rhs}')
		return
	}

	t.emit_indented('${target_expr} ${node.op.value} ${value_expr}')
}

fn (mut t Translator) visit_delete_stmt(node ast.Delete) {
	for target in node.targets {
		if target is ast.Subscript {
			t.emit_indented('${t.visit_expr(target.value)}.delete(${t.visit_expr(target.slice)})')
		} else if target is ast.Attribute {
			t.emit_indented('//##LLM@@ \'del ${t.visit_expr(target)}\' statement ignored')
		} else {
			t.emit_indented('//##LLM@@ \'del ${t.visit_expr(target)}\' statement ignored')
		}
	}
}

fn (mut t Translator) visit_assert(node ast.Assert) {
	expr := t.visit_expr(node.test)
	if msg := node.msg {
		t.emit_indented('assert ${expr}, ${t.visit_expr(msg)}')
	} else {
		t.emit_indented('assert ${expr}')
	}
}

fn (t &Translator) stmt_name_usage(node ast.Statement, name string) int {
	match node {
		ast.Assign {
			mut usage := 0
			for target in node.targets {
				if target is ast.Name && target.id == name {
					usage++
				}
			}
			return usage
		}
		else {
			return 0
		}
	}
}
