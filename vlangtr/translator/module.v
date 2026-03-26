module translator

import ast
import base

pub struct ModuleEmitter {
pub mut:
	module_name     string
	helper_structs   []string
	helper_functions []string
	imports          map[string]bool
	init_statements  []string
	main_statements  []string
	constants        []string
}

pub fn new_module_emitter() ModuleEmitter {
	return ModuleEmitter{
		module_name:     'main'
		helper_structs:   []string{}
		helper_functions: []string{}
		imports:          map[string]bool{}
		init_statements:  []string{}
		main_statements:  []string{}
		constants:        []string{}
	}
}

pub fn (mut e ModuleEmitter) add_helper_struct(code string) {
	e.helper_structs << code
}

pub fn (mut e ModuleEmitter) add_helper_function(code string) {
	e.helper_functions << code
}

pub fn (mut e ModuleEmitter) add_import(name string) {
	e.imports[name] = true
}

pub fn (mut e ModuleEmitter) add_init_statement(code string) {
	e.init_statements << code
}

pub fn (mut e ModuleEmitter) add_main_statement(code string) {
	e.main_statements << code
}

pub fn (mut e ModuleEmitter) add_constant(code string) {
	e.constants << code
}

pub fn (e &ModuleEmitter) emit() string {
	mut parts := []string{}

	if e.imports.len > 0 {
		mut names := e.imports.keys()
		names.sort()
		for name in names {
			parts << 'import ${name}'
		}
	}

	if e.helper_structs.len > 0 {
		parts << e.helper_structs.join('\n\n')
	}

	if e.helper_functions.len > 0 {
		parts << e.helper_functions.join('\n\n')
	}

	if e.constants.len > 0 {
		parts << e.constants.join('\n')
	}

	if e.init_statements.len > 0 {
		parts << 'fn init() {\n${e.init_statements.join("\n")}\n}'
	}

	if e.main_statements.len > 0 {
		parts << 'fn main() {\n${e.main_statements.join("\n")}\n}'
	}

	return parts.join('\n\n')
}

fn noop_visit_stmt(_ ast.Statement) {}

fn clean_string_constant(value string) string {
	if value.len >= 2 {
		first := value[0]
		last := value[value.len - 1]
		if (first == `'` && last == `'`) || (first == `"` && last == `"`) {
			return value[1..value.len - 1]
		}
	}
	return value
}

pub struct ModuleTranslator {
pub mut:
	state         base.TranslatorState
	emitter       ModuleEmitter
	visit_stmt_fn fn (ast.Statement) = noop_visit_stmt
	source_mapping bool
	strict_exports bool
	has_module_all bool
}

pub fn new_module_translator(
	state base.TranslatorState,
	visit_stmt_fn fn (ast.Statement),
) ModuleTranslator {
	return ModuleTranslator{
		state:         state
		emitter:       new_module_emitter()
		visit_stmt_fn: visit_stmt_fn
		has_module_all: false
	}
}

pub fn new_module_translator_with_flags(
	state base.TranslatorState,
	visit_stmt_fn fn (ast.Statement),
	source_mapping bool,
	strict_exports bool,
) ModuleTranslator {
	mut mt := new_module_translator(state, visit_stmt_fn)
	mt.source_mapping = source_mapping
	mt.strict_exports = strict_exports
	return mt
}

pub fn (m &ModuleTranslator) indent() string {
	return m.state.indent()
}

pub fn (mut m ModuleTranslator) emit(line string) {
	m.state.output << '${m.indent()}${line}'
}

fn (m &ModuleTranslator) is_name_main(node ast.If) bool {
	if node.test is ast.Compare {
		compare := node.test
		if compare.ops.len == 1 && compare.comparators.len == 1 {
			if compare.left is ast.Name && compare.left.id == '__name__' {
				if compare.comparators[0] is ast.Constant {
					comparator := compare.comparators[0] as ast.Constant
					return comparator.value == '__main__'
				}
			}
		}
	}
	return false
}

fn (mut m ModuleTranslator) record_defined_symbol(name string) {
	if name.len == 0 {
		return
	}
	m.state.defined_top_level_symbols[name] = true
}

fn (mut m ModuleTranslator) collect_declared_names_from_block(body []ast.Statement, mut names map[string]bool) {
	for stmt in body {
		m.collect_declared_names_from_stmt(stmt, mut names)
	}
}

fn (mut m ModuleTranslator) collect_declared_names_from_stmt(stmt ast.Statement, mut names map[string]bool) {
	match stmt {
		ast.Import {
			for alias in stmt.names {
				name := alias.asname or { alias.name }
				names[name] = true
			}
		}
		ast.ImportFrom {
			for alias in stmt.names {
				name := alias.asname or { alias.name }
				names[name] = true
			}
		}
		ast.Assign {
			for target in stmt.targets {
				if target is ast.Name {
					names[target.id] = true
					if target.id == '__all__' && stmt.value is ast.List {
						m.has_module_all = true
						mut all_names := []string{}
						for elt in stmt.value.elements {
							if elt is ast.Constant {
								all_names << clean_string_constant(elt.value)
							}
						}
						m.state.module_all = all_names
					}
					if target.id == '__all__' && stmt.value is ast.Tuple {
						m.has_module_all = true
						mut all_names := []string{}
						for elt in stmt.value.elements {
							if elt is ast.Constant {
								all_names << clean_string_constant(elt.value)
							}
						}
						m.state.module_all = all_names
					}
				}
			}
		}
		ast.AnnAssign {
			if stmt.target is ast.Name {
				names[stmt.target.id] = true
				if stmt.target.id == '__all__' {
					m.has_module_all = true
				}
			}
		}
		ast.FunctionDef {
			names[stmt.name] = true
		}
		ast.ClassDef {
			names[stmt.name] = true
		}
		ast.If {
			m.collect_declared_names_from_block(stmt.body, mut names)
			m.collect_declared_names_from_block(stmt.orelse, mut names)
		}
		ast.For {
			m.collect_declared_names_from_block(stmt.body, mut names)
			m.collect_declared_names_from_block(stmt.orelse, mut names)
		}
		ast.While {
			m.collect_declared_names_from_block(stmt.body, mut names)
			m.collect_declared_names_from_block(stmt.orelse, mut names)
		}
		ast.With {
			m.collect_declared_names_from_block(stmt.body, mut names)
		}
		ast.Try {
			m.collect_declared_names_from_block(stmt.body, mut names)
			m.collect_declared_names_from_block(stmt.orelse, mut names)
			m.collect_declared_names_from_block(stmt.finalbody, mut names)
			for handler in stmt.handlers {
				m.collect_declared_names_from_block(handler.body, mut names)
			}
		}
		ast.TryStar {
			m.collect_declared_names_from_block(stmt.body, mut names)
			m.collect_declared_names_from_block(stmt.orelse, mut names)
			m.collect_declared_names_from_block(stmt.finalbody, mut names)
			for handler in stmt.handlers {
				m.collect_declared_names_from_block(handler.body, mut names)
			}
		}
		else {}
	}
}

fn (mut m ModuleTranslator) collect_global_names_from_block(body []ast.Statement, mut names map[string]bool) {
	for stmt in body {
		m.collect_global_names_from_stmt(stmt, mut names)
	}
}

fn (mut m ModuleTranslator) collect_global_names_from_stmt(stmt ast.Statement, mut names map[string]bool) {
	match stmt {
		ast.Global {
			for name in stmt.names {
				names[name] = true
			}
		}
		ast.FunctionDef {
			m.collect_global_names_from_block(stmt.body, mut names)
		}
		ast.ClassDef {
			m.collect_global_names_from_block(stmt.body, mut names)
		}
		ast.If {
			m.collect_global_names_from_block(stmt.body, mut names)
			m.collect_global_names_from_block(stmt.orelse, mut names)
		}
		ast.For {
			m.collect_global_names_from_block(stmt.body, mut names)
			m.collect_global_names_from_block(stmt.orelse, mut names)
		}
		ast.While {
			m.collect_global_names_from_block(stmt.body, mut names)
			m.collect_global_names_from_block(stmt.orelse, mut names)
		}
		ast.With {
			m.collect_global_names_from_block(stmt.body, mut names)
		}
		ast.Try {
			m.collect_global_names_from_block(stmt.body, mut names)
			m.collect_global_names_from_block(stmt.orelse, mut names)
			m.collect_global_names_from_block(stmt.finalbody, mut names)
			for handler in stmt.handlers {
				m.collect_global_names_from_block(handler.body, mut names)
			}
		}
		ast.TryStar {
			m.collect_global_names_from_block(stmt.body, mut names)
			m.collect_global_names_from_block(stmt.orelse, mut names)
			m.collect_global_names_from_block(stmt.finalbody, mut names)
			for handler in stmt.handlers {
				m.collect_global_names_from_block(handler.body, mut names)
			}
		}
		else {}
	}
}

fn (mut m ModuleTranslator) scan_module_symbols(node ast.Module) {
	m.state.module_all = []string{}
	m.has_module_all = false
	mut module_scope_names := map[string]bool{}
	mut global_names := m.state.global_vars.clone()

	for stmt in node.body {
		m.collect_declared_names_from_stmt(stmt, mut module_scope_names)
		m.collect_global_names_from_stmt(stmt, mut global_names)
	}

	for name in module_scope_names.keys() {
		m.record_defined_symbol(name)
		global_names[name] = true
	}

	for name in global_names.keys() {
		m.state.global_vars[name] = true
	}
}

fn (mut m ModuleTranslator) extract_docstring(body []ast.Statement) ([]ast.Statement, []string) {
	if body.len == 0 {
		return body, []string{}
	}
	if body[0] is ast.Expr {
		first := body[0] as ast.Expr
		if first.value is ast.Constant {
			doc := clean_string_constant(first.value.value).trim_space()
			if doc.len > 0 {
				mut comments := []string{}
				for line in doc.split_into_lines() {
					comments << '// ${line}'
				}
				return body[1..].clone(), comments
			}
		}
	}
	return body, []string{}
}

fn (mut m ModuleTranslator) append_runtime_helpers() {
	if m.state.used_builtins['math.pow'] || m.state.used_builtins['math.floor'] || m.state.used_builtins['py_round'] {
		m.emitter.add_import('math')
	}
	if m.state.used_builtins['py_set_union'] || m.state.used_builtins['py_set_intersection']
		|| m.state.used_builtins['py_set_difference'] || m.state.used_builtins['py_set_xor']
		|| m.state.used_builtins['py_set_subset'] || m.state.used_builtins['py_set_strict_subset']
		|| m.state.used_builtins['py_set_superset'] || m.state.used_builtins['py_set_strict_superset'] {
		m.emitter.add_import('datatypes')
	}

	if m.state.used_builtins['py_is_identical'] {
		m.emitter.add_helper_function('fn py_is_identical[T, U](a T, b U) bool {\n    return voidptr(&a) == voidptr(&b)\n}')
	}

	if m.state.used_builtins['py_repeat_list'] {
		m.emitter.add_helper_function('fn py_repeat_list[T](a []T, n int) []T {\n    mut res := []T{cap: a.len * n}\n    for _ in 0 .. n {\n        res << a\n    }\n    return res\n}')
	}

	if m.state.used_builtins['py_complex'] || m.state.used_complex {
		m.emitter.add_helper_struct('struct PyComplex {\n    re f64\n    im f64\n}')
		m.emitter.add_helper_function('fn py_complex(re f64, im f64) PyComplex {\n    return PyComplex{re: re, im: im}\n}')
		m.emitter.add_helper_function("fn (z PyComplex) str() string {\n    sign := if z.im >= 0 { '+' } else { '-' }\n    im_abs := if z.im >= 0 { z.im } else { -z.im }\n    return '(' + z.re.str() + sign + im_abs.str() + 'j)'\n}")
	}

	if m.state.used_list_concat {
		m.emitter.add_helper_function('fn py_list_concat[T](lists ...[]T) []T {\n    mut res := []T{}\n    for l in lists {\n        res << l\n    }\n    return res\n}')
	}

	if m.state.used_dict_merge {
		m.emitter.add_helper_function('fn py_dict_merge[K, V](dicts ...map[K]V) map[K]V {\n    mut res := map[K]V{}\n    for d in dicts {\n        for k, v in d {\n            res[k] = v\n        }\n    }\n    return res\n}')
	}

	if m.state.used_string_format {
		m.emitter.add_helper_function('fn py_string_format(fmt string, args ...string) string {\n    mut res := fmt\n    for arg in args {\n        res = res.replace_first(\'%s\', arg)\n    }\n    return res\n}')
	}

	if m.state.used_builtins['py_bytes_format'] {
		m.emitter.add_helper_function('fn py_bytes_format_arg(arg Any) string {\n    return arg.str()\n}')
		m.emitter.add_helper_function('fn py_bytes_format(fmt string, args ...string) string {\n    mut res := fmt\n    for arg in args {\n        res = res.replace_first(\'%s\', arg)\n    }\n    return res\n}')
	}

	if m.state.used_builtins['py_repr'] {
		m.emitter.add_helper_function('fn py_repr(arg Any) string {\n    return arg.str()\n}')
	}

	if m.state.used_builtins['py_ascii'] {
		m.emitter.add_helper_function('fn py_ascii(arg Any) string {\n    return arg.str()\n}')
	}

	if m.state.used_builtins['py_set_union'] {
		m.emitter.add_helper_function('fn py_set_union[K](a datatypes.Set[K], b datatypes.Set[K]) datatypes.Set[K] {\n    mut res := a.clone()\n    for k, _ in b.elements {\n        res.add(k)\n    }\n    return res\n}')
	}

	if m.state.used_builtins['py_set_intersection'] {
		m.emitter.add_helper_function('fn py_set_intersection[K](a datatypes.Set[K], b datatypes.Set[K]) datatypes.Set[K] {\n    mut res := datatypes.Set[K]{}\n    for k, _ in a.elements {\n        if k in b.elements {\n            res.add(k)\n        }\n    }\n    return res\n}')
	}

	if m.state.used_builtins['py_set_difference'] {
		m.emitter.add_helper_function('fn py_set_difference[K](a datatypes.Set[K], b datatypes.Set[K]) datatypes.Set[K] {\n    mut res := datatypes.Set[K]{}\n    for k, _ in a.elements {\n        if k !in b.elements {\n            res.add(k)\n        }\n    }\n    return res\n}')
	}

	if m.state.used_builtins['py_set_xor'] {
		m.emitter.add_helper_function('fn py_set_xor[K](a datatypes.Set[K], b datatypes.Set[K]) datatypes.Set[K] {\n    mut res := datatypes.Set[K]{}\n    for k, _ in a.elements {\n        if k !in b.elements {\n            res.add(k)\n        }\n    }\n    for k, _ in b.elements {\n        if k !in a.elements {\n            res.add(k)\n        }\n    }\n    return res\n}')
	}

	if m.state.used_builtins['py_set_subset'] {
		m.emitter.add_helper_function('fn py_set_subset[K](a datatypes.Set[K], b datatypes.Set[K]) bool {\n    for k, _ in a.elements {\n        if k !in b.elements {\n            return false\n        }\n    }\n    return true\n}')
	}

	if m.state.used_builtins['py_set_strict_subset'] {
		m.emitter.add_helper_function('fn py_set_strict_subset[K](a datatypes.Set[K], b datatypes.Set[K]) bool {\n    return a.elements.len < b.elements.len && py_set_subset(a, b)\n}')
	}

	if m.state.used_builtins['py_set_superset'] {
		m.emitter.add_helper_function('fn py_set_superset[K](a datatypes.Set[K], b datatypes.Set[K]) bool {\n    return py_set_subset(b, a)\n}')
	}

	if m.state.used_builtins['py_set_strict_superset'] {
		m.emitter.add_helper_function('fn py_set_strict_superset[K](a datatypes.Set[K], b datatypes.Set[K]) bool {\n    return a.elements.len > b.elements.len && py_set_superset(a, b)\n}')
	}

	if 'py_sorted' in m.state.used_builtins {
		m.emitter.add_helper_function('fn py_sorted[T](a []T, reverse bool) []T {\n    mut b := a.clone()\n    b.sort()\n    if reverse {\n        b.reverse()\n    }\n    return b\n}')
	}

	if 'reversed' in m.state.used_builtins {
		m.emitter.add_helper_function('fn py_reversed[T](a []T) []T {\n    mut b := a.clone()\n    b.reverse()\n    return b\n}')
	}
}

pub fn (mut m ModuleTranslator) visit_module(node ast.Module) string {
	m.scan_module_symbols(node)
	m.emitter.module_name = m.state.current_module_name

	mut body := node.body.clone()
	mut doc_comments := []string{}
	body, doc_comments = m.extract_docstring(body)
	for comment in doc_comments {
		m.emitter.add_init_statement(comment)
	}

	for stmt in body {
		if stmt is ast.Assign {
			mut is_all := false
			for target in stmt.targets {
				if target is ast.Name && target.id == '__all__' {
					is_all = true
					break
				}
			}
			if is_all {
				continue
			}
		}

		m.state.output = []string{}
		if m.source_mapping {
			m.state.output << '// @line: ${m.state.get_source_info(stmt)}'
		}
		if stmt is ast.FunctionDef || stmt is ast.ClassDef || stmt is ast.Import || stmt is ast.ImportFrom {
			m.visit_stmt_fn(stmt)
		} else {
			if stmt is ast.If && m.is_name_main(stmt) {
				m.visit_stmt_fn(stmt)
			} else {
				m.visit_stmt_fn(stmt)
			}
		}

		for line in m.state.output {
			if stmt is ast.If && m.is_name_main(stmt) {
				m.emitter.add_main_statement(line)
			} else {
				m.emitter.add_init_statement(line)
			}
		}
	}

	if m.has_module_all {
		for name in m.state.module_all {
			if name !in m.state.defined_top_level_symbols {
				m.state.warnings << "Symbol '${name}' listed in __all__ but not defined in module"
			}
		}

		if m.strict_exports {
			for name in m.state.defined_top_level_symbols.keys() {
				if name == '__all__' || name.starts_with('_') {
					continue
				}
				if name !in m.state.module_all {
					m.state.warnings << "Public symbol '${name}' not listed in __all__"
				}
			}
		}
	}

	m.append_runtime_helpers()
	return m.emitter.emit()
}
