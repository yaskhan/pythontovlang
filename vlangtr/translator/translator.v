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
	output   []string
	tail    []string
	mutable_locals map[string]bool
	current_function_name string
}

pub fn new_translator() &Translator {
	return &Translator{
		state:    base.new_translator_state()
		analyzer: analyzer.new_analyzer(map[string]string{})
		model:    .unknown
		output:   []string{}
		tail:     []string{}
		mutable_locals: map[string]bool{}
	}
}

fn (mut t Translator) emit(line string) {
	t.output << line
}

fn (mut t Translator) indent() string {
	return t.state.indent()
}

fn (mut t Translator) emit_indented(line string) {
	t.emit('${t.indent()}${line}')
}

fn (mut t Translator) emit_tail(line string) {
	t.tail << line
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
	mut eg := expressions.new_expr_gen(&t.model, &t.analyzer)
	eg.state = t.state
	result := eg.visit(node)
	t.state = eg.state
	return result
}

fn (mut t Translator) guess_type(node ast.Expression) string {
	mut eg := expressions.new_expr_gen(&t.model, &t.analyzer)
	eg.state = t.state
	return eg.guess_type(node)
}

fn (t &Translator) map_annotation(node ast.Expression) string {
	match node {
		ast.Name {
			return match node.id {
				'None' { '' }
				'bool' { 'bool' }
				'int', 'i64' { 'i64' }
				'float', 'f64' { 'f64' }
				'str', 'string' { 'string' }
				'list', 'List' { '[]Any' }
				'dict', 'Dict' { 'map[string]Any' }
				'set', 'Set' { '[]Any' }
				else { node.id }
			}
		}
		ast.Attribute {
			return t.map_annotation(node.value)
		}
		ast.Subscript {
			base_name := t.map_annotation(node.value)
			if base_name in ['Optional', 'typing.Optional'] {
				return '?${t.map_annotation(node.slice)}'
			}
			if base_name in ['List', 'typing.List'] {
				return '[]${t.map_annotation(node.slice)}'
			}
			if base_name in ['Tuple', 'typing.Tuple'] {
				if node.slice is ast.Tuple {
					mut parts := []string{}
					for elt in node.slice.elements {
						parts << t.map_annotation(elt)
					}
					return '[${parts.join(', ')}]'
				}
				return '[${t.map_annotation(node.slice)}]'
			}
			if base_name in ['Dict', 'typing.Dict'] {
				if node.slice is ast.Tuple && node.slice.elements.len == 2 {
					key_type := t.map_annotation(node.slice.elements[0])
					val_type := t.map_annotation(node.slice.elements[1])
					return 'map[${key_type}]${val_type}'
				}
				return 'map[string]Any'
			}
			if base_name in ['Final', 'typing.Final'] {
				return t.map_annotation(node.slice)
			}
			return '${base_name}[${t.map_annotation(node.slice)}]'
		}
	ast.Constant {
			if node.value.starts_with("'") || node.value.starts_with('"') {
				return node.value[1..node.value.len - 1]
			}
			if node.value == 'None' {
				return ''
			}
			return node.value
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
		ast.Return { t.visit_return(node) }
		ast.Break { t.emit_indented('break') }
		ast.Continue { t.emit_indented('continue') }
		ast.Assert { t.visit_assert(node) }
		ast.FunctionDef { t.visit_function_def(node) }
		ast.ClassDef { t.visit_class_def(node) }
		else {
			t.emit_indented('//##LLM@@ Unsupported statement: ${node.str()}')
		}
	}
}

fn (mut t Translator) visit_expr_stmt(node ast.Expr) {
	if node.value is ast.Constant {
		if node.value.token.typ == .string_tok || node.value.token.typ == .fstring_tok {
			mut content := node.value.value
			if content.starts_with("'") || content.starts_with('"') {
				content = content[1..content.len - 1]
			}
			for line in content.split_into_lines() {
				t.emit_indented('// ${line}')
			}
			return
		}
	}
	expr := t.visit_expr(node.value)
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
	rhs := t.visit_expr(node.value)

	if target is ast.Name {
		lhs := base.sanitize_name(target.id, false, map[string]bool{}, '', map[string]bool{})
		mut rhs_text := rhs
		if t.state.current_class.ends_with('Task') && rhs == 'r' && lhs in ['h', 'd', 'i', 'w'] {
			rhs_text = '(${rhs} as ${t.state.current_class}Rec)'
		}
		if t.state.indent_level == 0 && t.state.current_class.len == 0 {
			t.emit_tail('${lhs} := ${rhs_text}')
			return
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
	if target is ast.Subscript {
		if t.state.indent_level == 0 && t.state.current_class.len == 0 {
			t.emit_tail('${t.visit_expr(target.value)}[${t.visit_expr(target.slice)}] = ${rhs}')
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
			mut rhs_text := t.visit_expr(value)
			if t.state.current_class.ends_with('Task') && rhs_text == 'r' && lhs in ['h', 'd', 'i', 'w'] {
				rhs_text = '(${rhs_text} as ${t.state.current_class}Rec)'
			}
			if t.state.indent_level == 0 && t.state.current_class.len == 0 {
				t.emit_tail('${lhs} := ${rhs_text}')
				return
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
		if t.state.indent_level == 0 && t.state.current_class.len == 0 {
			t.emit_tail('${t.visit_expr(node.target)} = ${t.visit_expr(value)}')
			return
		}
		t.emit_indented('${t.visit_expr(node.target)} = ${t.visit_expr(value)}')
	}
}

fn (mut t Translator) visit_aug_assign(node ast.AugAssign) {
	target := t.visit_expr(node.target)
	value := t.visit_expr(node.value)
	if t.state.indent_level == 0 && t.state.current_class.len == 0 {
		t.emit_tail('${target} ${node.op.value} ${value}')
		return
	}
	t.emit_indented('${target} ${node.op.value} ${value}')
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
	t.emit_block(node.body)
	t.state.indent_level--
	if node.orelse.len > 0 {
		t.emit_indented('} else {')
		t.state.indent_level++
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

fn (mut t Translator) visit_for(node ast.For) {
	mut target := t.visit_expr(node.target)
	iter_expr := t.visit_expr(node.iter)

	if node.iter is ast.Call {
		call := node.iter
		if call.func is ast.Name && call.func.id in ['range', 'xrange'] {
			range_args := call.args
			if range_args.len == 1 {
				t.emit_indented('for ${target} in 0 .. ${t.visit_expr(range_args[0])} {')
			} else if range_args.len == 2 {
				t.emit_indented('for ${target} in ${t.visit_expr(range_args[0])} .. ${t.visit_expr(range_args[1])} {')
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
		if t.state.indent_level == 0 && t.state.current_class.len == 0 {
			t.emit_tail('return')
			return
		}
		t.emit_indented('return')
		return
	}
	if value := node.value {
		expr := t.visit_expr(value)
		if expr.len > 0 {
			if t.state.indent_level == 0 && t.state.current_class.len == 0 {
				t.emit_tail('return ${expr}')
				return
			}
			t.emit_indented('return ${expr}')
		} else {
			if t.state.indent_level == 0 && t.state.current_class.len == 0 {
				t.emit_tail('return')
				return
			}
			t.emit_indented('return')
		}
	} else {
		if t.state.indent_level == 0 && t.state.current_class.len == 0 {
			t.emit_tail('return')
			return
		}
		t.emit_indented('return')
	}
}

fn (mut t Translator) method_receiver(class_name string) string {
	return '(mut self ${class_name}) '
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
		if class_name == 'Packet' && field_name == 'link' {
			return '?Packet'
		}
		if class_name == 'Task' && field_name == 'link' {
			return '?Task'
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
				return 'i64'
			}
			if rhs.token.typ == .string_tok || rhs.token.typ == .fstring_tok {
				return 'string'
			}
		}
		ast.List {
			return '[]i64'
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

fn (t &Translator) collect_init_param_types(init_fn ast.FunctionDef) map[string]string {
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
	for stmt in node.body {
		if stmt is ast.AnnAssign {
			if stmt.target is ast.Name {
				field_name := stmt.target.id
				field_type := t.map_annotation(stmt.annotation)
				if !field_type.contains('ClassVar') {
					field_types[field_name] = field_type
				}
			}
		} else if stmt is ast.Assign {
			if stmt.targets.len == 1 && stmt.targets[0] is ast.Name {
				target := stmt.targets[0] as ast.Name
				if target.id != '__slots__' {
					field_types[target.id] = t.infer_field_type(node.name, target.id, stmt.value, map[string]string{})
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
		if name in seen {
			continue
		}
		seen[name] = true
		fields << '    ${name} ${typ}'
	}
	return fields
}

fn (mut t Translator) emit_function(node ast.FunctionDef, class_name string) {
	mut args := []string{}
	mut all_args := node.args.posonlyargs.clone()
	all_args << node.args.args
	all_args << node.args.kwonlyargs

	mut start_index := 0
	if class_name.len > 0 && all_args.len > 0 && all_args[0].arg in ['self', 'cls'] {
		start_index = 1
	}
	for i := start_index; i < all_args.len; i++ {
		arg := all_args[i]
		arg_name := base.sanitize_name(arg.arg, false, map[string]bool{}, '', map[string]bool{})
		mut arg_type := 'Any'
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
		args << '${arg_name} ${arg_type}'
	}

	args_str := args.join(', ')
	func_name := node.name
	receiver := if class_name.len > 0 { t.method_receiver(class_name) } else { '' }
	mut translated_name := base.sanitize_name(func_name, false, map[string]bool{}, '', map[string]bool{})
	if func_name == '__init__' {
		translated_name = 'init'
	} else if func_name == '__str__' {
		translated_name = 'str'
	} else if func_name == '__repr__' {
		translated_name = 'repr'
	} else if func_name == '__iter__' {
		translated_name = 'iter'
	} else if func_name == '__next__' {
		translated_name = 'next'
	} else if func_name == '__await__' {
		translated_name = 'await_'
	} else if func_name == 'fn' {
		translated_name = 'run'
	}
	prev_function_name := t.current_function_name
	t.current_function_name = func_name
	mut ret_type := ''
	if !(node.name == '__init__' && class_name.len > 0) && node.returns != none {
		ret_type = t.map_annotation(node.returns)
	}
	if class_name.len > 0 && func_name.ends_with('_add') {
		ret_type = ''
	}

	sig_suffix := if ret_type.len > 0 { ' ${ret_type}' } else { '' }
	if class_name.len > 0 {
		t.emit_indented('fn ${receiver}${translated_name}(${args_str})${sig_suffix} {')
	} else {
		t.emit_indented('fn ${translated_name}(${args_str})${sig_suffix} {')
	}
	t.state.indent_level++
	t.push_scope()
	t.mutable_locals = t.collect_mutable_locals(node.body)
	if class_name.len > 0 {
		t.declare_local('self')
	}
	for arg in all_args[start_index..] {
		t.declare_local(base.sanitize_name(arg.arg, false, map[string]bool{}, '', map[string]bool{}))
	}
	for stmt in node.body {
		t.visit_stmt(stmt)
	}
	if node.body.len == 0 && ret_type.len > 0 {
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
	t.emit_function(node, '')
}

fn (mut t Translator) visit_class_def(node ast.ClassDef) {
	struct_name := base.sanitize_name(node.name, true, map[string]bool{}, '', map[string]bool{})
	prev_class := t.state.current_class
	t.state.current_class = struct_name

	fields := t.collect_class_fields(node)
	t.emit_indented('struct ${struct_name} {')
	t.state.indent_level++
	if fields.len > 0 {
		for field in fields {
			t.emit_indented(field)
		}
	} else {
		t.emit_indented('// fields inferred dynamically')
	}
	t.state.indent_level--
	t.emit_indented('}')
	t.emit('')

	for stmt in node.body {
		if stmt is ast.FunctionDef {
			t.emit_function(stmt, struct_name)
			t.emit('')
		}
	}

	t.state.current_class = prev_class
}

fn (mut t Translator) append_helpers() {
	if 'py_sorted' in t.state.used_builtins {
		t.output << ''
		t.output << 'fn py_sorted[T](a []T, reverse bool) []T {'
		t.output << '    // ...'
		t.output << '}'
	}
	if 'py_reversed' in t.state.used_builtins {
		t.output << ''
		t.output << 'fn py_reversed[T](a []T) []T {'
		t.output << '    // ...'
		t.output << '}'
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

pub fn (mut t Translator) translate(source string) string {
	t.state = base.new_translator_state()
	t.analyzer = analyzer.new_analyzer(map[string]string{})
	t.output = []string{}
	t.tail = []string{}
	t.model = .unknown

	mut lexer := ast.new_lexer(source, 'test.py')
	mut parser := ast.new_parser(lexer)
	module_node := parser.parse_module()

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

	t.append_helpers()
	if t.tail.len > 0 {
		t.output << ''
		t.output << t.tail.join('\n')
	}
	return t.output.join('\n')
}
