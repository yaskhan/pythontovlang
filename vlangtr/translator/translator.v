module translator

import analyzer
import ast
import base
import expressions
import models
import classes

pub struct Translator {
pub mut:
	state    base.TranslatorState
	analyzer analyzer.Analyzer
	model    models.VType
	mutable_locals map[string]bool
	current_function_name string
	classes_module classes.ClassesModule
}

pub fn new_translator() &Translator {
	return &Translator{
		state:    base.new_translator_state()
		analyzer: analyzer.new_analyzer(map[string]string{})
		model:    .unknown
		mutable_locals: map[string]bool{}
		current_function_name: ''
		classes_module: classes.new_classes_module()
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

pub fn (mut t Translator) translate(source string, filename string) string {
	t.state = base.new_translator_state()
	t.state.current_file_name = filename
	t.analyzer = analyzer.new_analyzer(map[string]string{})
	t.state.output = []string{}
	t.state.tail = []string{}
	t.model = .unknown
	t.mutable_locals = map[string]bool{}
	t.current_function_name = ''

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

	t.append_helpers()

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
		t.state.output.insert(0, 'import binary')
	}

	return t.state.output.join('\n')
}
