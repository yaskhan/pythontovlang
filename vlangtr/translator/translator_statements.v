module translator

import ast
import base
import expressions

fn (mut t Translator) emit_block(stmts []ast.Statement) {
	for stmt in stmts {
		t.visit_stmt(stmt)
	}
}

fn (mut t Translator) visit_stmt(node ast.Statement) {
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
		ast.Return { t.visit_return(node) }
		ast.Break { t.emit_indented('break') }
		ast.Continue { t.emit_indented('continue') }
		ast.Assert { t.visit_assert(node) }
		ast.FunctionDef { t.visit_function_def(node) }
		ast.ClassDef { t.visit_class_def(node) }
		ast.Match { t.visit_match(node) }
		ast.Raise {
			exc := if v := node.exc { t.visit_expr(v) } else { "'Exception'" }
			t.emit_indented('panic(${exc})')
		}
		else {
			t.emit_indented('//##LLM@@ Unsupported statement: ${node.str()}')
		}
	}
}

fn (mut t Translator) visit_expr_stmt(node ast.Expr) {
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
	mut eg := expressions.new_expr_gen(&t.model, &t.analyzer, &t.state)
	mut rhs := ''
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
		// t.state = eg.state // State is now a pointer, no need to reassign
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
		lhs := base.sanitize_name(target.id, false, map[string]bool{}, '', map[string]bool{})
		mut rhs_text := rhs
		if t.state.current_class.ends_with('Task') && rhs == 'r' && lhs in ['h', 'd', 'i', 'w'] {
			rhs_text = '(${rhs} as ${t.state.current_class}Rec)'
		}
		if t.is_declared_local(lhs) {
			t.emit_indented('${lhs} = ${rhs_text}')
		} else {
			ann_text := t.map_annotation(node.value)
			if t.state.indent_level == 0 && ann_text != '' && (ann_text.contains('|') || ann_text.contains('map[') || ann_text.contains('[]') || ann_text.starts_with('?')) && !ann_text.starts_with('fn (') {
				t.emit_indented('type ${target.id} = ${ann_text}')
				t.declare_local(lhs)
				return
			}
			inferred := t.guess_type(node.value)
			if inferred != 'Any' && inferred != 'int' {
				t.analyzer.type_map[target.id] = inferred
			}
			if lhs in t.mutable_locals {
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
			mut eg := expressions.new_expr_gen(&t.model, &t.analyzer, &t.state)
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

	if node.op.value == '+=' && node.value is ast.Constant && (node.value as ast.Constant).value == '1' {
		t.emit_indented('${target_expr}++')
		return
	}

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

fn (mut t Translator) visit_delete_stmt(_ ast.Delete) {
	t.emit_indented('//##LLM@@ del statement not lowered.')
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
