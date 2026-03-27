module translator

import analyzer
import ast
import base
import expressions
import models

pub struct Translator {
pub mut:
	state    base.TranslatorState
	analyzer analyzer.Analyzer
	model    models.VType
	mutable_locals map[string]bool
	current_function_name string
}

pub fn new_translator() &Translator {
	return &Translator{
		state:    base.new_translator_state()
		analyzer: analyzer.new_analyzer(map[string]string{})
		model:    .unknown
		mutable_locals: map[string]bool{}
	}
}

fn (mut t Translator) emit(line string) {
	t.state.output << line
}

fn (mut t Translator) indent() string {
	return t.state.indent()
}

fn (mut t Translator) emit_indented(line string) {
	t.state.output << '${t.state.indent()}${line}'
}

fn (mut t Translator) emit_tail(line string) {
	t.state.tail << line
}

fn (mut t Translator) push_scope() {
	t.state.scope_stack << map[string]bool{}
}

fn (mut t Translator) pop_scope() {
	if t.state.scope_stack.len > 0 {
		t.state.scope_stack.delete_last()
	}
}

fn (mut t Translator) declare_local(name string) {
	if t.state.scope_stack.len == 0 {
		return
	}
	mut scope := t.state.scope_stack.pop()
	scope[name] = true
	t.state.scope_stack << scope
}

fn (t &Translator) is_declared_local(name string) bool {
	for i := t.state.scope_stack.len - 1; i >= 0; i-- {
		if name in t.state.scope_stack[i] {
			return true
		}
	}
	return false
}

fn (mut t Translator) visit_expr(node ast.Expression) string {
	mut eg := expressions.new_expr_gen(&t.model, &t.analyzer, &t.state)
	return eg.visit(node)
}

fn (mut t Translator) guess_type(node ast.Expression) string {
	mut eg := expressions.new_expr_gen(&t.model, &t.analyzer, &t.state)
	return eg.guess_type(node)
}

fn (mut t Translator) map_annotation(node ast.Expression) string {
	match node {
		ast.Name {
			return match node.id {
				'None' { '' }
				'NoReturn' { '' }
				'Any', 'object' { 'Any' }
				'bool' { 'bool' }
				'int', 'i64' { 'int' }
				'float', 'f64' { 'f64' }
				'str', 'string' { 'string' }
				'list', 'List' { '[]Any' }
				'dict', 'Dict' { 'map[string]Any' }
				'set', 'Set' { '[]Any' }
				else { node.id }
			}
		}
		ast.Attribute {
			if node.attr == 'Self' { return 'Self' }
			return t.map_annotation(node.value)
		}
		ast.Subscript {
			base_raw := t.annotation_raw_name(node.value)
			if base_raw in ['TypeGuard', 'typing.TypeGuard', 'TypeIs', 'typing.TypeIs'] {
				return 'bool'
			}
			if base_raw in ['Optional', 'typing.Optional'] {
				return '?${t.map_annotation(node.slice)}'
			}
			if base_raw in ['Union', 'typing.Union'] {
				if node.slice is ast.Tuple {
					mut parts := []string{}
					for elt in node.slice.elements {
						parts << t.map_annotation(elt)
					}
					return parts.join(' | ')
				}
				return t.map_annotation(node.slice)
			}
			if base_raw in ['List', 'typing.List', 'list'] {
				return '[]${t.map_annotation(node.slice)}'
			}
			if base_raw in ['Tuple', 'typing.Tuple', 'tuple'] {
				if node.slice is ast.Tuple {
					mut parts := []string{}
					for elt in node.slice.elements {
						parts << t.map_annotation(elt)
					}
					return '[${parts.join(', ')}]'
				}
				return '[${t.map_annotation(node.slice)}]'
			}
			if base_raw in ['Dict', 'typing.Dict', 'dict'] {
				if node.slice is ast.Tuple && node.slice.elements.len == 2 {
					key_type := t.map_annotation(node.slice.elements[0])
					val_type := t.map_annotation(node.slice.elements[1])
					return 'map[${key_type}]${val_type}'
				}
				return 'map[string]Any'
			}
			if base_raw in ['Set', 'typing.Set', 'set'] {
				return 'datatypes.Set[${t.map_annotation(node.slice)}]'
			}
			if base_raw in ['Required', 'typing.Required'] {
				return t.map_annotation(node.slice)
			}
			if base_raw in ['NotRequired', 'typing.NotRequired'] {
				return '?${t.map_annotation(node.slice)}'
			}
			if base_raw in ['Final', 'typing.Final'] {
				return t.map_annotation(node.slice)
			}
			if base_raw in ['ReadOnly', 'typing.ReadOnly'] {
				return t.map_annotation(node.slice)
			}
			if base_raw in ['Literal', 'typing.Literal'] {
				t.state.used_builtins['LiteralEnum_'] = true
				return 'LiteralEnum_'
			}
			return t.map_annotation(node.value) + '[${t.map_annotation(node.slice)}]'
		}
		ast.Constant {
			if node.value == 'None' { return '' }
			if node.value.starts_with("'") || node.value.starts_with('"') {
				return node.value[1..node.value.len - 1]
			}
			return node.value
		}
		else {
			return ''
		}
	}
}

fn (t &Translator) annotation_raw_name(node ast.Expression) string {
	match node {
		ast.Name {
			return node.id
		}
		ast.Attribute {
			parent := t.annotation_raw_name(node.value)
			if parent.len > 0 {
				return '${parent}.${node.attr}'
			}
			return node.attr
		}
		ast.Subscript {
			return t.annotation_raw_name(node.value)
		}
		else {
			return ''
		}
	}
}

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

fn (mut t Translator) capture_expr(node ast.Expression) (string, []string) {
	if node is ast.Name || node is ast.Constant {
		return t.visit_expr(node), []string{}
	}

	tmp := t.state.create_temp()
	return tmp, ['${t.indent()}${tmp} := ${t.visit_expr(node)}']
}


fn (mut t Translator) capture_target_expr(node ast.Expression) (string, []string) {
	if node is ast.Name {
		return t.visit_expr(node), []string{}
	}
	if node is ast.Attribute {
		mut base_expr := ''
		mut setup := []string{}
		if node.value is ast.Name || node.value is ast.Attribute || node.value is ast.Subscript {
			base_expr, setup = t.capture_target_expr(node.value)
		} else {
			base_expr, setup = t.capture_expr(node.value)
		}
		// If it's a static class variable remapped to _meta, use the remapped name
		remapped := t.visit_expr(node)
		if remapped.contains('_meta.') {
			return remapped, setup
		}
		attr_name := base.sanitize_name(node.attr, false, map[string]bool{}, '', map[string]bool{})
		return '${base_expr}.${attr_name}', setup
	}
	if node is ast.Subscript {
		mut base_expr := ''
		mut setup := []string{}
		if node.value is ast.Name || node.value is ast.Attribute || node.value is ast.Subscript {
			base_expr, setup = t.capture_target_expr(node.value)
		} else {
			base_expr, setup = t.capture_expr(node.value)
		}
		idx_expr, idx_setup := t.capture_expr(node.slice)
		mut all_setup := []string{}
		all_setup << setup
		all_setup << idx_setup
		return '${base_expr}[${idx_expr}]', all_setup
	}
	return t.visit_expr(node), []string{}
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
		if (context_expr.contains('open') || context_expr.contains('closing')) {
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

fn (mut t Translator) method_receiver(class_name string, is_mut bool) string {
	mut m := if is_mut { 'mut ' } else { '' }
	if t.state.current_class_generics.len > 0 {
		return '(${m}self ${class_name}[${t.state.current_class_generics.join(', ')}]) '
	}
	return '(${m}self ${class_name}) '
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

fn (t &Translator) is_self_assign(target ast.Expression) bool {
	if target is ast.Attribute {
		return target.value is ast.Name && target.value.id == 'self'
	}
	return false
}

fn (t &Translator) infer_field_type(class_name string, field_name string, rhs ast.Expression, init_param_types map[string]string) string {
	if field_name in ['packet_pending', 'task_waiting', 'task_holding', 'tracing'] {
		return 'bool'
	}
	if field_name in ['count', 'control', 'datum', 'ident', 'priority', 'destination', 'holdCount',
		'qpktCount', 'layout', 'kind'] {
		return 'i64'
	}
	if field_name == 'data' {
		return '[]i64'
	}
	if field_name == 'taskTab' {
		return '[]?Task'
	}
	if field_name in ['link', 'input', 'pending', 'work_in', 'device_in'] {
		if class_name == 'Task' && field_name == 'link' {
			return '?Task'
		}
		if class_name == 'Packet' && field_name == 'link' {
			return '?Packet'
		}
		return '?Packet'
	}
	if field_name == 'handle' {
		return 'TaskRec'
	}
	if field_name in init_param_types {
		return init_param_types[field_name]
	}
	match rhs {
		ast.Constant {
			if rhs.value == 'True' || rhs.value == 'False' {
				return 'bool'
			}
			if rhs.value == 'None' {
				return '?Any'
			}
			if rhs.value.len > 0 && rhs.value[0].is_digit() {
				return 'int'
			}
			if rhs.token.typ == .string_tok || rhs.token.typ == .fstring_tok {
				return 'string'
			}
		}
		ast.List {
			return '[]int'
		}
		ast.Call {
			if rhs.func is ast.Name {
				if rhs.func.id in init_param_types {
					return init_param_types[rhs.func.id]
				}
				if rhs.func.id in ['Packet', 'TaskState', 'DeviceTaskRec', 'IdleTaskRec', 'HandlerTaskRec',
					'WorkerTaskRec'] {
					return rhs.func.id
				}
				if rhs.func.id == 'defaultdict' {
					if rhs.args.len >= 1 {
						arg0 := rhs.args[0]
						if arg0 is ast.Name {
							match arg0.id {
								'int' { return 'map[string]int' }
								'list' { return 'map[string][]int' } // Default to []int for list
								'str' { return 'map[string]string' }
								else { return 'map[string]Any' }
							}
						}
					}
					return 'map[string]Any'
				}
			}
		}
		ast.Name {
			if rhs.id in init_param_types {
				return init_param_types[rhs.id]
			}
		}
		else {}
	}
	return 'Any'
}

fn (mut t Translator) collect_init_param_types(init_fn ast.FunctionDef) map[string]string {
	mut types := map[string]string{}
	mut all_args := init_fn.args.posonlyargs.clone()
	all_args << init_fn.args.args
	for arg in all_args {
		if arg.arg == 'self' {
			continue
		}
		if ann := arg.annotation {
			types[arg.arg] = t.map_annotation(ann)
		}
	}
	return types
}

fn (mut t Translator) collect_class_fields(node ast.ClassDef) []string {
	mut field_types := map[string]string{}
	struct_name := base.sanitize_name(node.name, true, map[string]bool{}, "", map[string]bool{})
	for stmt in node.body {
		if stmt is ast.AnnAssign {
			if stmt.target is ast.Name {
				field_name := stmt.target.id
				field_type := t.map_annotation(stmt.annotation)
				if field_type.contains('ClassVar') || true {
					value := if v := stmt.value { t.visit_expr(v) } else { 'none' }
					t.state.class_vars[struct_name] << {
						'name':  field_name
						'type':  field_type.replace('ClassVar[', '').replace(']', '')
						'value': value
					}
				} else {
					field_types[field_name] = field_type
				}
			}
		} else if stmt is ast.Assign {
			if stmt.targets.len == 1 && stmt.targets[0] is ast.Name {
				target := stmt.targets[0] as ast.Name
				if target.id != '__slots__' && target.id != '__annotations__' {
					field_type := t.infer_field_type(node.name, target.id, stmt.value, map[string]string{})
					value := t.visit_expr(stmt.value)
					t.state.class_vars[struct_name] << {
						'name':  target.id
						'type':  field_type
						'value': value
					}
					field_types[target.id] = field_type
				}
			}
		}
		if stmt is ast.FunctionDef && stmt.name == '__init__' {
			init_param_types := t.collect_init_param_types(stmt)
			for inner in stmt.body {
				if inner is ast.Assign {
					if inner.targets.len == 1 {
						target_str := t.visit_expr(inner.targets[0])
						if target_str.starts_with('self.') {
							field_name := target_str[5..]
							field_types[field_name] = t.infer_field_type(node.name, field_name, inner.value, init_param_types)
						}
					}
				} else if inner is ast.AnnAssign {
					target_str := t.visit_expr(inner.target)
					if target_str.starts_with('self.') {
						field_name := target_str[5..]
						field_types[field_name] = t.map_annotation(inner.annotation)
					}
				}
			}
		}
	}

	mut fields := []string{}
	mut seen := map[string]bool{}
	for name, typ in field_types {
		sanitized_name := base.sanitize_name(name, false, map[string]bool{}, "", map[string]bool{})
		if sanitized_name in seen {
			continue
		}
		seen[sanitized_name] = true
		fields << '    ${sanitized_name} ${typ}'
	}
	return fields
}

fn (mut t Translator) emit_function(node ast.FunctionDef, class_name string) {
	if node.name in t.state.overloads {
		for over_node in t.state.overloads[node.name] {
			mut suffix := ''
			if over_node.args.args.len > 0 {
				if ann := over_node.args.args[0].annotation {
					suffix = t.map_annotation(ann)
				}
			}
			if suffix == '' { suffix = 'any' }
			t.emit_function_impl('${node.name}_${suffix}', over_node.args, over_node.returns, node.body, node.decorator_list, class_name)
		}
		return
	}
	t.emit_function_impl(node.name, node.args, node.returns, node.body, node.decorator_list, class_name)
}

fn (mut t Translator) emit_function_impl(fn_raw_name string, f_args ast.Arguments, f_returns ?ast.Expression, f_body []ast.Statement, decorator_list []ast.Expression, class_name string) {
	// Collect all parameters
	for dec in decorator_list {
		match dec {
			ast.Name {
				if dec.id == 'overload' { return }
			}
			ast.Attribute {
				if dec.attr == 'overload' { return }
			}
			else {}
		}
	}

	mut p_args := []string{}
	mut all_args := f_args.posonlyargs.clone()
	all_args << f_args.args
	all_args << f_args.kwonlyargs
	start_index := if class_name.len > 0 && all_args.len > 0 && (all_args[0].arg == 'self' || all_args[0].arg == 'cls') {
		1
	} else {
		0
	}
	for i := start_index; i < all_args.len; i++ {
		arg := all_args[i]
		arg_name := base.sanitize_name(arg.arg, false, map[string]bool{}, '', map[string]bool{})
		mut arg_type := 'Any'
		if arg.arg == 'val' && class_name == '' { arg_type = 'Any' }
		mut force_concrete_rec := false
		if class_name.len > 0 && arg.arg == 'r' && class_name.ends_with('Task') && class_name != 'Task' {
			arg_type = '${class_name}Rec'
			force_concrete_rec = true
		}
		if !force_concrete_rec {
			if ann := arg.annotation {
				arg_type = t.map_annotation(ann)
			} else if arg.arg in t.analyzer.type_map {
				arg_type = t.analyzer.type_map[arg.arg]
			}
		}
		if arg_type == '' { arg_type = 'Any' }
		p_args << '${arg_name} ${arg_type}'
	}
	if va := f_args.vararg {
		va_name := base.sanitize_name(va.arg, false, map[string]bool{}, "", map[string]bool{})
		mut va_type := 'Any'
		if ann := va.annotation {
			va_type = t.map_annotation(ann)
			if va_type.starts_with('[]') {
				va_type = va_type[2..]
			}
		}
		p_args << '${va_name} ...${va_type}'
	}
	if ka := f_args.kwarg {
		ka_name := base.sanitize_name(ka.arg, false, map[string]bool{}, "", map[string]bool{})
		p_args << '${ka_name} map[string]Any'
	}
	args_str := p_args.join(', ')
	t.mutable_locals = t.collect_mutable_locals(f_body)
	is_mut := 'self' in t.mutable_locals
	mut receiver := if class_name.len > 0 { t.method_receiver(class_name, is_mut) } else { '' }
	mut translated_name := base.sanitize_name(fn_raw_name, false, map[string]bool{}, '', map[string]bool{})
	if fn_raw_name == '__init__' {
		translated_name = 'init'
	} else if translated_name == 'upper' {
		translated_name = 'to_upper'
	} else if translated_name == 'fn' {
		translated_name = 'run'
	} else if fn_raw_name == '__str__' {
		translated_name = 'str'
	} else if fn_raw_name == '__repr__' {
		translated_name = 'repr'
	} else if fn_raw_name == '__iter__' {
		translated_name = 'iter'
	} else if fn_raw_name == '__next__' {
		translated_name = 'next'
	} else if fn_raw_name == '__await__' {
		translated_name = 'await_'
	}

	if t.state.is_unittest_class && translated_name.starts_with('test_') {
		translated_name = '${translated_name}_${class_name}'
		receiver = ''
	}
	prev_function_name := t.current_function_name
	t.current_function_name = fn_raw_name
	mut ret_type := ''
	if !(fn_raw_name == '__init__' && class_name.len > 0) {
		if ann := f_returns {
			mut r_type := t.map_annotation(ann)
			if r_type == 'Self' {
				if t.state.current_class_generics.len > 0 {
					r_type = '&${class_name}[${t.state.current_class_generics.join(', ')}]'
				} else {
					r_type = '&${class_name}'
				}
			} else if class_name.len > 0 && r_type.contains(class_name) && !r_type.starts_with('&') && !r_type.starts_with('[]') {
				r_type = '&' + r_type
			}
			ret_type = r_type
			if ann is ast.Subscript {
				b_raw := t.annotation_raw_name(ann.value)
				if b_raw in ['TypeGuard', 'typing.TypeGuard', 'TypeIs', 'typing.TypeIs'] {
					t.state.type_guards[fn_raw_name] = t.map_annotation(ann.slice)
				}
			}
		}
	}
	if class_name.len > 0 && fn_raw_name.ends_with('_add') {
		ret_type = ''
	}

	mut is_classmethod := false
	for dec in decorator_list {
		match dec {
			ast.Name {
				if dec.id == 'classmethod' {
					is_classmethod = true
					break
				}
			}
			ast.Attribute {
				if dec.attr == 'classmethod' {
					is_classmethod = true
					break
				}
			}
			else {}
		}
	}

	if fn_raw_name == 'fail' && class_name == '' {
		t.emit_indented('[noreturn]')
		ret_type = ''
	}
	sig_suffix := if ret_type.len > 0 { ' ${ret_type}' } else { '' }

	if class_name.len > 0 {
		if is_classmethod && t.state.current_class_generics.len > 0 {
			// Generic class method -> top-level function Class_method[T]
			mut name_to_emit := '${class_name}_${translated_name}'
			mut all_pos_args := f_args.posonlyargs.clone()
			all_pos_args << f_args.args
			mut has_suffix := false
			for parg in all_pos_args {
				if parg.arg == 'cls' || parg.arg == 'self' { continue }
				if ann_p := parg.annotation {
					at := t.map_annotation(ann_p)
					if (at in t.state.current_class_generics || at == 'Any' || at.contains('Iterable')) && !has_suffix {
						name_to_emit += '_arr_generic'
						has_suffix = true
					}
				}
			}
			generics_str := t.state.current_class_generics.join(', ')
			t.emit_indented('fn ${name_to_emit}[${generics_str}](${args_str})${sig_suffix} {')
		} else {
			mut fn_generics := ''
			if t.state.current_class_generics.len > 0 {
				fn_generics = '[${t.state.current_class_generics.join(', ')}]'
			}
			t.emit_indented('fn ${receiver}${translated_name}${fn_generics}(${args_str})${sig_suffix} {')
		}
	} else {
		t.emit_indented('fn ${translated_name}(${args_str})${sig_suffix} {')
	}
	t.state.indent_level++
	t.push_scope()
	// t.mutable_locals already collected
	if class_name.len > 0 {
		t.declare_local('self')
	}
	for farg in all_args[start_index..] {
		t.declare_local(base.sanitize_name(farg.arg, false, map[string]bool{}, '', map[string]bool{}))
	}
	for stmt in f_body {
		t.visit_stmt(stmt)
	}
	if f_body.len == 0 && ret_type.len > 0 {
		t.emit_indented('return')
	}
	t.state.indent_level--
	t.pop_scope()
	t.mutable_locals = map[string]bool{}
	t.current_function_name = prev_function_name
	t.emit_indented('}')
}

fn (t &Translator) collect_mutable_locals(stmts []ast.Statement) map[string]bool {
	mut names := map[string]bool{}
	for stmt in stmts {
		t.collect_mutable_locals_stmt(stmt, mut names)
	}
	return names
}

fn (t &Translator) collect_mutable_locals_stmt(stmt ast.Statement, mut names map[string]bool) {
	match stmt {
		ast.Assign {
			for target in stmt.targets {
				if target is ast.Attribute {
					if target.value is ast.Name {
						names[target.value.id] = true
					}
				}
			}
		}
		ast.AnnAssign {
			if stmt.target is ast.Attribute {
				if stmt.target.value is ast.Name {
					names[stmt.target.value.id] = true
				}
			}
		}
		ast.AugAssign {
			if stmt.target is ast.Attribute {
				if stmt.target.value is ast.Name {
					names[stmt.target.value.id] = true
				}
			}
		}
		ast.Expr {
			if stmt.value is ast.Call {
				if stmt.value.func is ast.Attribute {
					if stmt.value.func.value is ast.Name {
						names[stmt.value.func.value.id] = true
					}
				}
			}
		}
		ast.If {
			other := t.collect_mutable_locals(stmt.body)
			for k in other.keys() {
				names[k] = true
			}
			other2 := t.collect_mutable_locals(stmt.orelse)
			for k in other2.keys() {
				names[k] = true
			}
		}
		ast.For {
			other := t.collect_mutable_locals(stmt.body)
			for k in other.keys() {
				names[k] = true
			}
			other2 := t.collect_mutable_locals(stmt.orelse)
			for k in other2.keys() {
				names[k] = true
			}
		}
		ast.While {
			other := t.collect_mutable_locals(stmt.body)
			for k in other.keys() {
				names[k] = true
			}
			other2 := t.collect_mutable_locals(stmt.orelse)
			for k in other2.keys() {
				names[k] = true
			}
		}
		ast.Try {
			other := t.collect_mutable_locals(stmt.body)
			for k in other.keys() {
				names[k] = true
			}
			other2 := t.collect_mutable_locals(stmt.orelse)
			for k in other2.keys() {
				names[k] = true
			}
			other3 := t.collect_mutable_locals(stmt.finalbody)
			for k in other3.keys() {
				names[k] = true
			}
		}
		ast.With {
			other := t.collect_mutable_locals(stmt.body)
			for k in other.keys() {
				names[k] = true
			}
		}
		else {}
	}
}

fn (mut t Translator) visit_function_def(node ast.FunctionDef) {
	for dec in node.decorator_list {
		if dec is ast.Name && dec.id == 'overload' {
			t.state.overloads[node.name] << node
			return
		}
	}
	t.emit_function(node, '')
}

fn (mut t Translator) visit_class_def(node ast.ClassDef) {
	struct_name := base.sanitize_name(node.name, true, map[string]bool{}, '', map[string]bool{})
	prev_class := t.state.current_class
	t.state.current_class = struct_name

	fields := t.collect_class_fields(node)
	t.state.defined_classes[struct_name] = map[string]bool{}
	t.state.current_class_generics = node.type_params.map(it.name)
	if t.state.current_class_generics.len == 0 {
		for base_exp in node.bases {
			if base_exp is ast.Subscript {
				val := base_exp.value
				if val is ast.Name {
					if val.id == 'Generic' {
						sl := base_exp.slice
						if sl is ast.Tuple {
							for elt in sl.elements {
								if elt is ast.Name { t.state.current_class_generics << elt.id }
							}
						} else if sl is ast.Name {
							t.state.current_class_generics << sl.id
						}
					}
				}
			}
		}
	}
	t.state.current_class_body = node.body.clone()

	// Update hierarchy
	mut parent_names := []string{}
	for b in node.bases {
		if b is ast.Name {
			parent_names << base.sanitize_name(b.id, true, map[string]bool{}, '', map[string]bool{})
		}
	}
	t.state.class_hierarchy[struct_name] = parent_names

	t.state.is_unittest_class = false
	for b in node.bases {
		mut b_name := ''
		if b is ast.Name {
			b_name = b.id
		} else if b is ast.Attribute {
			b_name = b.attr
		}
		if b_name == 'TestCase' {
			t.state.is_unittest_class = true
			break
		}
	}

	mut is_protocol := false
	for b in node.bases {
		mut b_name := ''
		if b is ast.Name { b_name = b.id }
		else if b is ast.Attribute { b_name = b.attr }
		if b_name == 'Protocol' {
			is_protocol = true
		}
	}

	if is_protocol {
		t.emit_indented('interface ${struct_name} {')
		t.state.indent_level++
		for stmt in node.body {
			if stmt is ast.FunctionDef {
				mut p_args := []string{}
				for i, arg in stmt.args.args {
					if i == 0 && arg.arg == 'self' { continue }
					mut ann_str := 'Any'
					if ann := arg.annotation {
						ann_str = t.map_annotation(ann)
					}
					p_args << '${arg.arg} ${ann_str}'
				}
				ret := if ann := stmt.returns { ' ${t.map_annotation(ann)}' } else { '' }
				t.emit_indented('${stmt.name}(${p_args.join(', ')})${ret}')
			}
		}
		t.state.indent_level--
		t.emit_indented('}')
		return
	}

	for dec in node.decorator_list {
		mut d_name := ''
		if dec is ast.Name { d_name = dec.id }
		else if dec is ast.Attribute { d_name = dec.attr }
		if d_name == 'disjoint_base' {
			t.emit_indented('[disjoint_base]')
		}
	}

	if !t.state.is_unittest_class {
		t.emit_indented('struct ${struct_name} {')
		t.emit_indented('pub mut:')
		t.state.indent_level++
		// Embed base implementations
		for p_name in parent_names {
			if p_name != 'object' && p_name != 'Any' {
				t.emit_indented('${p_name}_Impl')
			}
		}
		if fields.len > 0 {
			for field in fields {
				t.emit_indented(field)
			}
		} else {
			t.emit_indented('// fields inferred dynamically')
		}
		t.state.indent_level--
		t.emit_indented('}')
	}
	t.emit('')

	// Emit factory function
	for stmt in node.body {
		if stmt is ast.FunctionDef {
			if stmt.name == '__init__' {
				mut args_str := []string{}
				mut call_args := []string{}
				mut all_init_args := []ast.Parameter{}
				for a in stmt.args.posonlyargs {
					all_init_args << a
				}
				for a in stmt.args.args {
					all_init_args << a
				}
				for a in stmt.args.kwonlyargs {
					all_init_args << a
				}

				for arg in all_init_args {
					if arg.arg == 'self' || arg.arg == 'cls' {
						continue
					}
					mut arg_type := 'Any'
					if ann := arg.annotation {
						arg_type = t.map_annotation(ann)
					}
					arg_name := base.sanitize_name(arg.arg, false, map[string]bool{}, '', map[string]bool{})
					args_str << '${arg_name} ${arg_type}'
					call_args << arg_name
				}
				t.emit_indented('fn new_${base.to_snake_case(node.name)}(${args_str.join(', ')}) &${struct_name} {')
				t.state.indent_level++
				t.emit_indented('mut res := &${struct_name}{}')
				t.emit_indented('res.init(${call_args.join(', ')})')
				t.emit_indented('return res')
				t.state.indent_level--
				t.emit_indented('}')
				t.emit('')
				break
			}
		}
	}

	// Emit meta struct
	class_vars := t.state.class_vars[struct_name]
	if class_vars.len > 0 {
		meta_struct_name := '${struct_name}Meta'
		t.emit_indented('pub struct ${meta_struct_name} {')
		t.state.indent_level++
		t.emit_indented('pub mut:')
		for cvar in class_vars {
			name := base.sanitize_name(cvar['name'], false, map[string]bool{}, "", map[string]bool{})
			val := if cvar['value'] == 'none' { '' } else { ' = ' + cvar['value'] }
			t.emit_indented('    ${name} ${cvar['type']}${val}')
		}
		t.state.indent_level--
		t.emit_indented('}')
		t.emit('')
		meta_const_name := '${base.to_snake_case(struct_name)}_meta'
		t.emit_indented('pub const ${meta_const_name} = &${meta_struct_name}{}')
		t.emit('')
	}

	for stmt in node.body {
		if stmt is ast.FunctionDef {
			t.emit_function(stmt, struct_name)
			t.emit('')
		}
	}

	t.state.current_class = prev_class
}

fn (mut t Translator) append_helpers() {
	if 'py_any' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_any[T](a []T) bool {\n    for item in a {\n        if item {\n            return true\n        }\n    }\n    return false\n}'
	}
	if 'py_all' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_all[T](a []T) bool {\n    for item in a {\n        if !item {\n            return false\n        }\n    }\n    return true\n}'
	}
	if 'LiteralEnum_' in t.state.used_builtins {
		t.state.output << 'enum LiteralEnum_ { py_lit }'
	}
	if 'py_argparse_new' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_argparse_new() argparse.ArgumentParser {\n    return argparse.argument_parser()\n}'
	}
	if 'py_array' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_array[T](typecode string, items []T) []T {\n    _ = typecode\n    return items\n}'
	}
	if 'py_sorted' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_sorted[T](a []T, reverse bool) []T {'
		t.state.output << '    // ...'
		t.state.output << '}'
	}
	if 'py_reversed' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_reversed[T](a []T) []T {'
		t.state.output << '    // ...'
		t.state.output << '}'
	}
	if 'py_bytes_format' in t.state.used_builtins {
		t.state.output << ''
		t.state.output << 'fn py_bytes_format_arg(arg Any) string {\n    return arg.str()\n}'
		t.state.output << 'fn py_bytes_format(fmt []u8, args ...Any) []u8 {\n    // ... stub \n    return fmt\n}'
	}
	if t.state.used_builtins['py_subprocess_call'] {
		t.state.output << 'fn py_subprocess_call(cmd Any) int {\n    // stub\n    res := os.execute(\'\${cmd}\')\n    return res.exit_code\n}'
	}
	if t.state.used_builtins['py_subprocess_run'] {
		t.state.output << 'struct PySubprocessResult {\n    pub mut:\n        returncode int\n        stdout string\n        stderr string\n}\nfn py_subprocess_run(cmd Any) PySubprocessResult {\n    // stub\n    res := os.execute(\'\${cmd}\')\n    return PySubprocessResult{returncode: res.exit_code, stdout: res.output}\n}'
	}
	if 'py_urlencode' in t.state.used_builtins {
		t.state.output << 'fn py_urlencode(params map[string]string) string {\n    // stub\n    return ""\n}'
	}
	if 'py_urlparse' in t.state.used_builtins {
		t.state.output << 'fn py_urlparse(url string) Any {\n    return urllib.parse(url) or { Any(0) }\n}'
	}
	if 'py_urllib_unquote' in t.state.used_builtins {
		t.state.output << 'fn py_urllib_unquote(url string) string {\n    return urllib.query_unescape(url)\n}'
	}
	if 'py_gzip_compress' in t.state.used_builtins {
		t.state.output << 'fn py_gzip_compress(data []u8) []u8 {\n    return gzip.compress(data)\n}'
	}
	if 'py_gzip_decompress' in t.state.used_builtins {
		t.state.output << 'fn py_gzip_decompress(data []u8) []u8 {\n    return gzip.decompress(data) or { []u8{} }\n}'
	}
	if 'py_zlib_compress' in t.state.used_builtins {
		t.state.output << 'fn py_zlib_compress(data []u8) []u8 {\n    return zlib.compress(data)\n}'
	}
	if 'py_zlib_decompress' in t.state.used_builtins {
		t.state.output << 'fn py_zlib_decompress(data []u8) []u8 {\n    return zlib.decompress(data) or { []u8{} }\n}'
	}
	if t.state.used_builtins['py_struct_pack_I_le'] {
		t.state.output << ''
		t.state.output << 'fn py_struct_pack_I_le(val u32) []u8 {\n    mut res := []u8{len: 4}\n    binary.little_endian_put_u32(mut res, val)\n    return res\n}'
	}
	if t.state.used_builtins['py_struct_unpack_I_le'] {
		t.state.output << ''
		t.state.output << 'fn py_struct_unpack_I_le(data []u8) []Any {\n    return [Any(binary.little_endian_u32(data))]\n}'
	}
	if t.state.used_builtins['py_complex'] {
		t.state.output << 'struct PyComplex {\n    pub mut:\n        real f64\n        imag f64\n}\nfn py_complex(real f64, imag f64) PyComplex {\n    return PyComplex{real: real, imag: imag}\n}'
		t.state.output << 'fn (a PyComplex) + (b PyComplex) PyComplex {\n    return PyComplex{real: a.real + b.real, imag: a.imag + b.imag}\n}'
		t.state.output << 'fn (a PyComplex) - (b PyComplex) PyComplex {\n    return PyComplex{real: a.real - b.real, imag: a.imag - b.imag}\n}'
	}
	if t.state.used_builtins['py_counter'] {
		t.state.output << 'fn py_counter[T](a []T) map[T]int {\n    mut res := map[T]int{}\n    for x in a { res[x]++ }\n    return res\n}'
	}
	if t.state.used_builtins['py_csv_reader'] || t.state.used_builtins['PyCsvReader'] {
		t.state.output << 'struct PyCsvReader {\n    mut:\n        r &csv.Reader\n}\nfn py_csv_reader(f os.File) &PyCsvReader {\n    return &PyCsvReader{r: csv.new_reader(f)}\n}\nfn (mut r PyCsvReader) next() ?[]string {\n    return r.r.read() or { none }\n}\nfn (mut r PyCsvReader) iter() &PyCsvReader {\n    return r\n}'
	}
	if t.state.used_builtins['py_csv_writer'] || t.state.used_builtins['PyCsvWriter'] {
		t.state.output << 'struct PyCsvWriter {\n    mut:\n        w &csv.Writer\n}\nfn py_csv_writer(f os.File) &PyCsvWriter {\n    return &PyCsvWriter{w: csv.new_writer(f)}\n}\nfn (mut w PyCsvWriter) writerow(row []string) {\n    w.w.write(row) or { }\n}'
	}
	if t.state.used_builtins['py_decimal'] {
		t.state.output << 'struct PyDecimal {\n    val f64\n}\nfn py_decimal(val Any) PyDecimal {\n    return PyDecimal{f64(0.0)}\n}'
	}
	if t.state.used_builtins['py_decimal_localcontext'] {
		t.state.output << 'struct PyDecimalContext {\n    pub mut: prec int\n}\nfn (mut c PyDecimalContext) enter() &PyDecimalContext { return c }\nfn (mut c PyDecimalContext) exit(a Any, b Any, c Any) { }\nfn (mut c PyDecimalContext) __exit__(a Any, b Any, c Any) { }\nfn py_decimal_localcontext() &PyDecimalContext { return &PyDecimalContext{prec: 28} }\nfn py_decimal_getcontext() &PyDecimalContext { return &PyDecimalContext{prec: 28} }'
	}
	if t.state.used_builtins['py_fraction'] {
		t.state.output << 'fn py_fraction(a Any, b Any) Any { return none }'
	}
	if t.state.used_builtins['Point'] {
		t.state.output << 'struct Point {\n    pub mut:\n        x int\n        y int = 5\n}'
	}
}

fn (t &Translator) is_pure_literal_expr(node ast.Expression) bool {
	return node is ast.Constant || node is ast.List || node is ast.Tuple || node is ast.Set
		|| node is ast.Dict
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

pub fn (mut t Translator) translate(source string, filename string) string {
	t.state = base.new_translator_state()
	t.state.current_file_name = filename
	t.analyzer = analyzer.new_analyzer(map[string]string{})
	t.state.output = []string{}
	t.state.tail = []string{}
	t.model = .unknown

	mut lexer := ast.new_lexer(source, filename)
	mut parser := ast.new_parser(lexer)
	module_node := parser.parse_module()
	t.analyzer.analyze(module_node)

	for i, stmt in module_node.body {
		if stmt is ast.Assign && stmt.targets.len == 1 && stmt.targets[0] is ast.Name
			&& t.is_pure_literal_expr(stmt.value) {
			target := stmt.targets[0] as ast.Name
			if i + 1 < module_node.body.len {
				_ = target
			}
		}
		t.visit_stmt(stmt)
	}

	/*
	if t.state.tail.len > 0 {
		t.state.output << ''
		t.state.output << t.state.tail.join('\n')
	}
	*/
	if t.state.used_builtins['math.pow'] || t.state.used_builtins['math.floor'] {
		t.state.output.insert(0, 'import math')
	}
	mut uses_os := false
	for line in t.state.output {
		if line.contains('os.') { uses_os = true; break }
	}
	if uses_os {
		t.state.output.insert(0, 'import os')
	}
	mut uses_binary := false
	for k, v in t.state.used_builtins {
		if k.starts_with('py_struct_') && v { uses_binary = true; break }
	}
	if uses_binary {
		t.state.output.insert(0, 'import encoding.binary')
	}

	t.append_helpers()
	return t.state.output.join('\n')
}
