module translator

// VERIFY: 12345
import analyzer
import ast
import base
import expressions
import models
import classes
import functions
import stdlib_map
import control_flow

pub struct Translator {
pub mut:
	state    &base.TranslatorState
	analyzer &analyzer.Analyzer
	model    models.VType
	mutable_locals map[string]bool
	current_function_name string
	classes_module   classes.ClassesModule
	functions_module functions.FunctionsModule
	coroutine_handler analyzer.CoroutineHandler
	control_flow_module control_flow.ControlFlowModule
}

pub fn new_translator() &Translator {
	mut t := &Translator{
		state:    base.new_translator_state()
		analyzer: analyzer.new_analyzer(map[string]string{})
		model:    .unknown
		mutable_locals: map[string]bool{}
		current_function_name: ''
		classes_module:   classes.new_classes_module()
		functions_module: functions.new_functions_module()
		coroutine_handler: analyzer.new_coroutine_handler()
		control_flow_module: control_flow.new_control_flow_module()
	}
	println("TRANSLATOR_CREATED")
	t.state.mapper = stdlib_map.new_stdlib_mapper()
	t.state.coroutine_handler = &t.coroutine_handler
	t.control_flow_module.env = t.get_control_flow_env()
	return t
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
	// eprintln('EXPR VISIT')
	mut eg := expressions.new_expr_gen(&t.model, t.analyzer, t.state)
	return eg.visit(node)
}

fn (mut t Translator) guess_type(node ast.Expression) string {
	mut eg := expressions.new_expr_gen(&t.model, t.analyzer, t.state)
	return eg.guess_type(node)
}

fn (mut t Translator) map_annotation(node ast.Expression) string {
	match node {
		ast.Name {
			res := match node.id {
				'None' { '' }
				'NoReturn' { 'noreturn' }
				'Any', 'object' { 'Any' }
				'bool' { 'bool' }
				'int', 'i64' { 'int' }
				'float', 'f64' { 'f64' }
				'str', 'string' { 'string' }
				'list', 'List' { '[]Any' }
				'Self' {
					gen_s := if t.state.current_class_generics.len > 0 {
						'[${t.state.current_class_generics.join(", ")}]'
					} else { '' }
					'&${t.state.current_class}${gen_s}'
				}
				'dict', 'Dict' { 'map[string]Any' }
				'set', 'Set' { '[]Any' }
				else { t.state.imported_symbols[node.id] or { node.id } }
			}
			if node.id == 'list' || node.id == 'OrderedCollection' {
				eprintln('MAP_ANNOTATION: id=${node.id} res=${res}')
			}
			return res
		}
		ast.Attribute {
			if node.attr == 'Self' {
				gen_s := if t.state.current_class_generics.len > 0 {
					'[${t.state.current_class_generics.join(", ")}]'
				} else { '' }
				return '&${t.state.current_class}${gen_s}'
			}
			full_name := t.annotation_raw_name(node)
			if full_name in ['NoReturn', 'typing.NoReturn'] { return 'noreturn' }
			if full_name in ['Any', 'typing.Any'] { return 'Any' }
			if full_name in ['Self', 'typing.Self'] {
				gen_s := if t.state.current_class_generics.len > 0 {
					'[${t.state.current_class_generics.join(", ")}]'
				} else { '' }
				return '&${t.state.current_class}${gen_s}'
			}
			return t.map_annotation(node.value)
		}
		ast.Subscript {
			base_raw := t.annotation_raw_name(node.value)
			if base_raw in ['TypeGuard', 'typing.TypeGuard', 'TypeIs', 'typing.TypeIs'] {
				narrowed := t.map_annotation(node.slice)
				if t.current_function_name.len > 0 {
					t.state.type_guards[t.current_function_name] = base.TypeGuardInfo{
						narrowed_type: narrowed
						is_type_is:    base_raw.contains('TypeIs')
					}
				}
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
					mut res_parts := []string{}
					mut contains_none := false
					for p in parts { 
						if p != '' { res_parts << p } 
						else { contains_none = true }
					}
					res_type := res_parts.join(' | ')
					if contains_none {
						return if res_type.len > 0 { '?${res_type}' } else { 'none' }
					}
					return res_type
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
				if node.slice is ast.Tuple {
					mut parts := []string{}
					for elt in node.slice.elements {
						parts << t.map_annotation(elt)
					}
					if parts.len >= 2 {
						return 'map[${parts[0]}]${parts[1]}'
					}
				}
				return 'map[string]Any'
			}
			if base_raw in ['Set', 'typing.Set', 'set'] {
				return 'map[${t.map_annotation(node.slice)}]bool'
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
		ast.BinaryOp {
			if node.op.value == '|' {
				l := t.map_annotation(node.left)
				r := t.map_annotation(node.right)
				if l == '' { return if r == '' { 'none' } else { '?${r}' } }
				if r == '' { return '?${l}' }
				return '${l} | ${r}'
			}
			return ''
		}
		else {
			return ''
		}
	}
}

pub fn (mut t Translator) map_annotation_str(type_str string, struct_name string, allow_union bool, register bool, is_return bool) string {
	mut actual_struct := if struct_name.len > 0 && struct_name != 'Self' { struct_name } else { t.state.current_class }
	if actual_struct == '' { actual_struct = 'Self' }
	
	opts := base.TypeMapOptions{
		struct_name:        actual_struct
		allow_union:        allow_union
		register_sum_types: register
		is_return:          is_return
		self_type:          actual_struct
		generic_map:        t.state.current_class_generic_map
	}
	mut ctx := base.TypeUtilsContext{
		imported_symbols: t.state.imported_symbols
		scc_files:        t.state.scc_files.keys()
		used_builtins:    t.state.used_builtins
		warnings:         t.state.warnings
		config:           t.state.config
	}
	mut st := t.state
	res := base.map_type(type_str, opts, mut ctx, fn [mut st, t, actual_struct] (name string) string {
		if name == 'Self' || name == 'typing.Self' {
			gen_s := if t.state.current_class_generics.len > 0 {
				"[${t.state.current_class_generics.join(', ')}]"
			} else { "" }
			return "&${actual_struct}${gen_s}"
		}
		if name == 'NoReturn' || name == 'typing.NoReturn' {
			return 'noreturn'
		}
		if name in st.generated_sum_types {
			return name
		}
		return '' // Fallthrough to basic mapping
	}, fn (_ []string) string { return '' }, fn (_ string) string { return '' })
	
	if !allow_union && res.contains(' | ') {
		// Convert "A | B" to "SumType_AB"
		parts := res.split(' | ')
		mut name_parts := []string{}
		for p in parts { 
			mut part_name := p.capitalize()
			if part_name == 'Str' { part_name = 'String' }
			name_parts << part_name 
		}
		st_name := 'SumType_${name_parts.join("")}'
		st.generated_sum_types[st_name] = ''
		return st_name
	}
	return res
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
	t.state.mapper = stdlib_map.new_stdlib_mapper()
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
	
	// Pre-analyze to fill type map for aliases
	t.analyzer.analyze(module_node)
	// Second pass to propagate inferences back to aliases
	t.analyzer.analyze(module_node)

	for k, v in t.analyzer.class_hierarchy {
		t.state.class_hierarchy[k] = v.clone()
	}
	for k, v in t.analyzer.main_to_mixins {
		t.state.main_to_mixins[k] = v.clone()
	}
	for k, v in t.analyzer.overloaded_signatures {
		t.state.overloaded_signatures[k] = v.clone()
	}
	for k, v in t.analyzer.call_signatures {
		if narrowed := v.narrowed_type {
			t.state.type_guards[k] = base.TypeGuardInfo{
				narrowed_type: narrowed
				is_type_is:    v.is_type_is
			}
		}
	}
	t.state.class_hierarchy_initialized = true

	for _, stmt in module_node.body {
		// println('Processing stmt ${i}: ${stmt.str()}')
		t.visit_stmt(stmt)
	}

	t.append_helpers()

	if t.state.used_builtins['math.pow'] || t.state.used_builtins['math.floor'] {
		t.state.output.insert(0, 'import math')
	}
	if t.state.used_builtins['encoding.base64'] {
		t.state.output.insert(0, 'import encoding.base64')
	}
	if t.state.used_builtins['compress.zlib'] {
		t.state.output.insert(0, 'import compress.zlib')
	}
	if t.state.used_builtins['datatypes'] {
		t.state.output.insert(0, 'import datatypes')
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
	t.state.output.insert(0, '// ENTRY_POINT_HIT')
	return t.state.output.join('\n')
}
