module translator

import ast
import base
import analyzer

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
	if code !in e.helper_structs {
		e.helper_structs << code
	}
}

pub fn (mut e ModuleEmitter) add_helper_function(code string) {
	if code !in e.helper_functions {
		e.helper_functions << code
	}
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
pub fn (mut e ModuleEmitter) add_helper_import(name string) {
	e.imports[name] = true
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

	if e.constants.len > 0 {
		parts << e.constants.join('\n')
	}

	if e.helper_structs.len > 0 {
		parts << e.helper_structs.join('\n\n')
	}

	if e.init_statements.len > 0 {
		parts << 'fn init() {\n' + e.init_statements.join('\n') + '\n}'
	}

	if e.main_statements.len > 0 {
		parts << 'fn main() {\n' + e.main_statements.join('\n') + '\n}'
	}

	if e.helper_functions.len > 0 {
		parts << e.helper_functions.join('\n\n')
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
	state         &base.TranslatorState
	emitter       ModuleEmitter
	coroutine_handler analyzer.CoroutineHandler
	visit_stmt_fn fn (ast.Statement) = noop_visit_stmt
	source_mapping bool
	strict_exports bool
	has_module_all bool
}

pub fn new_module_translator(
	mut state &base.TranslatorState,
	visit_stmt_fn fn (ast.Statement),
) ModuleTranslator {
	mut m := ModuleTranslator{
		state:             state
		emitter:           new_module_emitter()
		coroutine_handler: analyzer.new_coroutine_handler()
		visit_stmt_fn:     visit_stmt_fn
		has_module_all:    false
	}
	m.state.coroutine_handler = &m.coroutine_handler
	return m
}

pub fn new_module_translator_with_flags(
	mut state &base.TranslatorState,
	visit_stmt_fn fn (ast.Statement),
	source_mapping bool,
	strict_exports bool,
) ModuleTranslator {
	mut mt := new_module_translator(mut state, visit_stmt_fn)
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
		ast.FunctionDef { names[stmt.name] = true }
		ast.ClassDef { names[stmt.name] = true }
		ast.Import { for n in stmt.names { names[if val := n.asname { val } else { n.name }] = true } }
		ast.ImportFrom { for n in stmt.names { names[if val := n.asname { val } else { n.name }] = true } }
		ast.Assign {
			for target in stmt.targets {
				m.collect_names_from_expr(target, mut names)
			}
		}
		ast.AnnAssign {
			m.collect_names_from_expr(stmt.target, mut names)
		}
		else {}
	}
}


fn (mut m ModuleTranslator) collect_assigned_names(n []ast.Statement, mut names map[string]bool) {
	for stmt in n {
		match stmt {
			ast.Assign {
				for t in stmt.targets {
					m.collect_names_from_expr(t, mut names)
				}
				// Special check for __all__
				for t in stmt.targets {
					if t is ast.Name && t.id == '__all__' {
						if stmt.value is ast.List {
							m.has_module_all = true
							for elt in stmt.value.elements {
								if elt is ast.Constant {
									m.state.module_all << clean_string_constant(elt.value)
								}
							}
						} else if stmt.value is ast.Tuple {
							m.has_module_all = true
							for elt in stmt.value.elements {
								if elt is ast.Constant {
									m.state.module_all << clean_string_constant(elt.value)
								}
							}
						}
					}
				}
			}
			ast.AnnAssign {
				m.collect_names_from_expr(stmt.target, mut names)
				if stmt.target is ast.Name && stmt.target.id == '__all__' {
					m.has_module_all = true
				}
			}
			ast.If {
				m.collect_assigned_names(stmt.body, mut names)
				m.collect_assigned_names(stmt.orelse, mut names)
			}
			ast.For {
				m.collect_assigned_names(stmt.body, mut names)
				m.collect_assigned_names(stmt.orelse, mut names)
			}
			ast.While {
				m.collect_assigned_names(stmt.body, mut names)
				m.collect_assigned_names(stmt.orelse, mut names)
			}
			ast.With {
				m.collect_assigned_names(stmt.body, mut names)
			}
			ast.Try {
				m.collect_assigned_names(stmt.body, mut names)
				m.collect_assigned_names(stmt.orelse, mut names)
				m.collect_assigned_names(stmt.finalbody, mut names)
				for h in stmt.handlers {
					m.collect_assigned_names(h.body, mut names)
				}
			}
			ast.TryStar {
				m.collect_assigned_names(stmt.body, mut names)
				m.collect_assigned_names(stmt.orelse, mut names)
				m.collect_assigned_names(stmt.finalbody, mut names)
				for h in stmt.handlers {
					m.collect_assigned_names(h.body, mut names)
				}
			}
			ast.Import {
				for alias in stmt.names {
					names[alias.asname or { alias.name }] = true
				}
			}
			ast.ImportFrom {
				for alias in stmt.names {
					names[alias.asname or { alias.name }] = true
				}
			}
			ast.FunctionDef {
				names[stmt.name] = true
			}
			ast.ClassDef {
				names[stmt.name] = true
			}
			else {}
		}
	}
}

fn (m &ModuleTranslator) collect_names_from_expr(expr ast.Expression, mut names map[string]bool) {
	match expr {
		ast.Name {
			names[expr.id] = true
		}
		ast.Tuple {
			for elt in expr.elements {
				m.collect_names_from_expr(elt, mut names)
			}
		}
		ast.List {
			for elt in expr.elements {
				m.collect_names_from_expr(elt, mut names)
			}
		}
		ast.Starred {
			m.collect_names_from_expr(expr.value, mut names)
		}
		else {}
	}
}

fn (m &ModuleTranslator) collect_global_refs(node ast.ASTNode, top_level map[string]bool, mut assigned_locally map[string]bool, mut globals map[string]bool) {
	if node is ast.Module {
		for s in node.body { m.walk_stmt_refs(s, top_level, assigned_locally, mut globals) }
	} else if node is ast.FunctionDef {
		mut inner_assigned := assigned_locally.clone()
		for arg in node.args.args { inner_assigned[arg.arg] = true }
		for arg in node.args.posonlyargs { inner_assigned[arg.arg] = true }
		for arg in node.args.kwonlyargs { inner_assigned[arg.arg] = true }
		if va := node.args.vararg { inner_assigned[va.arg] = true }
		if ka := node.args.kwarg { inner_assigned[ka.arg] = true }
		
		m.collect_inner_assignments(node.body, mut inner_assigned)
		m.collect_inner_refs(node.body, top_level, inner_assigned, mut globals)
	} else if node is ast.ClassDef {
		mut inner_assigned := assigned_locally.clone()
		m.collect_inner_assignments(node.body, mut inner_assigned)
		m.collect_inner_refs(node.body, top_level, inner_assigned, mut globals)
	}
}

fn (m &ModuleTranslator) collect_inner_assignments(body []ast.Statement, mut assigned map[string]bool) {
	for stmt in body {
		match stmt {
			ast.Assign {
				for t in stmt.targets { m.collect_names_from_expr(t, mut assigned) }
			}
			ast.AnnAssign {
				m.collect_names_from_expr(stmt.target, mut assigned)
			}
			ast.If {
				m.collect_inner_assignments(stmt.body, mut assigned)
				m.collect_inner_assignments(stmt.orelse, mut assigned)
			}
			ast.For {
				m.collect_names_from_expr(stmt.target, mut assigned)
				m.collect_inner_assignments(stmt.body, mut assigned)
				m.collect_inner_assignments(stmt.orelse, mut assigned)
			}
			ast.While {
				m.collect_inner_assignments(stmt.body, mut assigned)
				m.collect_inner_assignments(stmt.orelse, mut assigned)
			}
			ast.With {
				for item in stmt.items {
					if opt := item.optional_vars { m.collect_names_from_expr(opt, mut assigned) }
				}
				m.collect_inner_assignments(stmt.body, mut assigned)
			}
			ast.Try {
				m.collect_inner_assignments(stmt.body, mut assigned)
				for h in stmt.handlers {
					if n := h.name { assigned[n] = true }
					m.collect_inner_assignments(h.body, mut assigned)
				}
				m.collect_inner_assignments(stmt.orelse, mut assigned)
				m.collect_inner_assignments(stmt.finalbody, mut assigned)
			}
			else {}
		}
	}
}

fn (m &ModuleTranslator) collect_inner_refs(body []ast.Statement, top_level map[string]bool, assigned map[string]bool, mut globals map[string]bool) {
	for stmt in body {
		m.walk_stmt_refs(stmt, top_level, assigned, mut globals)
	}
}

fn (m &ModuleTranslator) walk_stmt_refs(s ast.Statement, top_level map[string]bool, assigned map[string]bool, mut globals map[string]bool) {
	match s {
		ast.Expr { m.walk_expr_refs(s.value, top_level, assigned, mut globals) }
		ast.Assign {
			for t in s.targets { m.walk_expr_refs(t, top_level, assigned, mut globals) }
			m.walk_expr_refs(s.value, top_level, assigned, mut globals)
		}
		ast.AnnAssign {
			m.walk_expr_refs(s.target, top_level, assigned, mut globals)
			if v := s.value { m.walk_expr_refs(v, top_level, assigned, mut globals) }
		}
		ast.Return { if v := s.value { m.walk_expr_refs(v, top_level, assigned, mut globals) } }
		ast.If {
			m.walk_expr_refs(s.test, top_level, assigned, mut globals)
			for item in s.body { m.walk_stmt_refs(item, top_level, assigned, mut globals) }
			for item in s.orelse { m.walk_stmt_refs(item, top_level, assigned, mut globals) }
		}
		ast.While {
			m.walk_expr_refs(s.test, top_level, assigned, mut globals)
			for item in s.body { m.walk_stmt_refs(item, top_level, assigned, mut globals) }
			for item in s.orelse { m.walk_stmt_refs(item, top_level, assigned, mut globals) }
		}
		ast.For {
			m.walk_expr_refs(s.target, top_level, assigned, mut globals)
			m.walk_expr_refs(s.iter, top_level, assigned, mut globals)
			for item in s.body { m.walk_stmt_refs(item, top_level, assigned, mut globals) }
			for item in s.orelse { m.walk_stmt_refs(item, top_level, assigned, mut globals) }
		}
		ast.Global {
			for name in s.names { globals[name] = true }
		}
		else {}
	}
}

fn (m &ModuleTranslator) walk_expr_refs(e ast.Expression, top_level map[string]bool, assigned map[string]bool, mut globals map[string]bool) {
	match e {
		ast.Name {
			if e.ctx == .load && e.id in top_level && e.id !in assigned {
				globals[e.id] = true
			}
		}
		ast.Call {
			m.walk_expr_refs(e.func, top_level, assigned, mut globals)
			for a in e.args { m.walk_expr_refs(a, top_level, assigned, mut globals) }
		}
		ast.Attribute { m.walk_expr_refs(e.value, top_level, assigned, mut globals) }
		ast.BinaryOp {
			m.walk_expr_refs(e.left, top_level, assigned, mut globals)
			m.walk_expr_refs(e.right, top_level, assigned, mut globals)
		}
		ast.UnaryOp { m.walk_expr_refs(e.operand, top_level, assigned, mut globals) }
		ast.IfExp {
			m.walk_expr_refs(e.test, top_level, assigned, mut globals)
			m.walk_expr_refs(e.body, top_level, assigned, mut globals)
			m.walk_expr_refs(e.orelse, top_level, assigned, mut globals)
		}
		ast.Compare {
			m.walk_expr_refs(e.left, top_level, assigned, mut globals)
			for c in e.comparators { m.walk_expr_refs(c, top_level, assigned, mut globals) }
		}
		ast.Tuple { for item in e.elements { m.walk_expr_refs(item, top_level, assigned, mut globals) } }
		ast.List { for item in e.elements { m.walk_expr_refs(item, top_level, assigned, mut globals) } }
		ast.Set { for item in e.elements { m.walk_expr_refs(item, top_level, assigned, mut globals) } }
		ast.Dict {
			for k in e.keys { m.walk_expr_refs(k, top_level, assigned, mut globals) }
			for v in e.values { m.walk_expr_refs(v, top_level, assigned, mut globals) }
		}
		else {}
	}
}

fn (mut m ModuleTranslator) scan_module_symbols(node ast.Module) {
	m.state.module_all = []string{}
	m.has_module_all = false
	
	// Pre-scan for __all__
	for stmt in node.body {
		if stmt is ast.Assign {
			for target in stmt.targets {
				if target is ast.Name && target.id == '__all__' {
					if stmt.value is ast.List {
						m.has_module_all = true
						for elt in stmt.value.elements {
							if elt is ast.Constant {
								m.state.module_all << clean_string_constant(elt.value)
							}
						}
					} else if stmt.value is ast.Tuple {
						m.has_module_all = true
						for elt in stmt.value.elements {
							if elt is ast.Constant {
								m.state.module_all << clean_string_constant(elt.value)
							}
						}
					}
				}
			}
		}
	}

	mut top_level_names := map[string]bool{}
	m.collect_assigned_names(node.body, mut top_level_names)
	
	for name in top_level_names.keys() {
		m.record_defined_symbol(name)
	}
	
	mut globals := map[string]bool{}
	mut assigned_locally := map[string]bool{}
	m.collect_global_refs(node, top_level_names, mut assigned_locally, mut globals)
	
	for name in globals.keys() {
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
		m.emitter.add_helper_import('math')
	}
	if m.state.used_builtins['py_set_union'] || m.state.used_builtins['py_set_intersection']
		|| m.state.used_builtins['py_set_difference'] || m.state.used_builtins['py_set_xor']
		|| m.state.used_builtins['py_set_subset'] || m.state.used_builtins['py_set_strict_subset']
		|| m.state.used_builtins['py_set_superset'] || m.state.used_builtins['py_set_strict_superset']
		|| m.state.used_builtins['py_set_from_list'] || m.state.used_builtins['py_set_from_iter'] {
		m.emitter.add_helper_import('datatypes')
		if m.state.used_builtins['py_set_union'] {
			m.emitter.add_helper_function('fn py_set_union[K](a datatypes.Set[K], b datatypes.Set[K]) datatypes.Set[K] {
    mut res := a.clone()
    for k, _ in b.elements { res.add(k) }
    return res
}')
		}
		if m.state.used_builtins['py_set_intersection'] {
			m.emitter.add_helper_function('fn py_set_intersection[K](a datatypes.Set[K], b datatypes.Set[K]) datatypes.Set[K] {
    mut res := datatypes.Set[K]{}
    for k, _ in a.elements { if k in b.elements { res.add(k) } }
    return res
}')
		}
	}
	
	if m.state.imported_modules.values().contains('tempfile') {
		m.emitter.add_helper_import('os')
		m.emitter.add_helper_struct('struct PyTempDir { path string }')
		m.emitter.add_helper_function('fn (d PyTempDir) close() { os.rmdir_all(d.path) or {} }')
		m.emitter.add_helper_function("fn py_temp_dir() PyTempDir {
    p := os.mkdir_temp('') or { panic(err) }
    return PyTempDir{path: p}
}")
		m.emitter.add_helper_function("fn py_named_temp_file() os.File {
    f, _ := os.create_temp('') or { panic(err) }
    return f
}")
	}

	if m.state.imported_modules.values().contains('logging') {
		m.emitter.add_helper_import('log')
		m.emitter.add_helper_function('fn py_get_logger(name string) log.Log {
    mut l := log.Log{}
    l.set_level(.info)
    return l
}')
	}

	// Single dispatchers
	for func_name, registry in m.state.single_dispatch_functions {
		mut lines := []string{}
		lines << 'fn ${func_name}(arg Any) {'
		lines << '    // Singledispatch implementation'
		
		default_impl := registry['default'] or { '' }
		mut first := true
		for type_name, impl_name in registry {
			if type_name == 'default' { continue }
			pfx := if first { 'if' } else { ' else if' }
			lines << '    ${pfx} arg is ${type_name} {'
			lines << '        ${impl_name}(arg as ${type_name})'
			lines << '    }'
			first = false
		}
		if default_impl.len > 0 {
			if first {
				lines << '    ${default_impl}(arg)'
			} else {
				lines << '    else {'
				lines << '        ${default_impl}(arg)'
				lines << '    }'
			}
		}
		lines << '}'
		m.emitter.add_helper_function(lines.join('\n'))
	}

	if m.state.used_builtins['py_is_identical'] {
		m.emitter.add_helper_function('fn py_is_identical[T, U](a T, b U) bool { return voidptr(&a) == voidptr(&b) }')
	}




	if m.state.used_list_concat {
		m.emitter.add_helper_function('fn py_list_concat[T](lists ...[]T) []T {
    mut res := []T{}
    for l in lists {
        res << l
    }
    return res
}')
	}

	if m.state.used_dict_merge {
		m.emitter.add_helper_function('fn py_dict_merge[K, V](dicts ...map[K]V) map[K]V {
    mut res := map[K]V{}
    for d in dicts {
        for k, v in d {
            res[k] = v
        }
    }
    return res
}')
	}

	if m.state.used_string_format || m.state.used_builtins['py_bytes_format'] {
		m.emitter.add_helper_import('strconv')
		m.emitter.add_helper_import('strings')
		
				m.emitter.add_helper_function('fn py_string_format(fmt string, args ...Any) string {
    mut res := strings.new_builder(fmt.len + 16)
    mut arg_idx := 0
    mut i := 0
    for i < fmt.len {
        if fmt[i] == `%` {
            if i + 1 < fmt.len {
                if fmt[i+1] == `%` {
                    res.write_string("%")
                    i += 2
                    continue
                }
                // Handle simple placeholders %s, %d, %f, %r
                mut j := i + 1
				mut flag_zero := false
				for j < fmt.len && (fmt[j] == `0` || fmt[j] == `-`) { 
					if fmt[j] == `0` { flag_zero = true }
					j++ 
				}
				mut width := 0
				for j < fmt.len && fmt[j].is_digit() {
					width = width * 10 + int(fmt[j] - `0`)
					j++
				}
                if j < fmt.len {
                    spec := fmt[j]
                    if arg_idx < args.len {
                        arg := args[arg_idx]
                        arg_idx++
                        mut s := ""
                        if spec == `s` { s = "\x24{arg}" }
                        else if spec == `d` { s = "\x24{arg}" }
                        else if spec == `f` { s = "\x24{arg}" }
                        else if spec == `r` { s = "\x24{arg}" }
						
						if width > s.len {
							if flag_zero { s = "0".repeat(width - s.len) + s }
							else { s = " ".repeat(width - s.len) + s }
						}
                        res.write_string(s)
                        i = j + 1
                        continue
                    }
                }
            }
        }
        res.write_u8(fmt[i])
        i++
    }
    return res.str()
}')
	}

	if m.state.used_builtins['py_repr'] {
		m.emitter.add_helper_function('fn py_repr(arg Any) string { return "\x24{arg}" }')
	}

	if m.state.used_builtins['py_ascii'] {
		m.emitter.add_helper_function('fn py_ascii(arg Any) string { return "\x24{arg}" }')
	}

	if m.state.used_builtins['py_format'] {
		m.emitter.add_helper_import('strconv')
		m.emitter.add_helper_function("fn py_format(val Any, spec string) string {
    if spec == '' {
        if val is string { return val }
        return '\x24{val}'
    }
    mut fill := ` `
    mut align := `>`
    mut s := spec
    if s.len >= 2 && (s[1] == `<` || s[1] == `>` || s[1] == `^` || s[1] == `=`) {
        fill = s[0]
        align = s[1]
        s = s[2..]
    } else if s.len >= 1 && (s[0] == `<` || s[0] == `>` || s[0] == `^` || s[0] == `=`) {
        align = s[0]
        s = s[1..]
    }
    mut width := 0
    mut j := 0
    for j < s.len && s[j].is_digit() { j++ }
    if j > 0 { width = s[..j].int(); s = s[j..] }
    mut precision := -1
    if s.starts_with('.') {
        s = s[1..]
        mut k := 0
        for k < s.len && s[k].is_digit() { k++ }
        if k > 0 { precision = s[..k].int(); s = s[k..] }
    }
    typ := if s.len > 0 { s[s.len-1] } else { `s` }
    mut formatted := ''
    if val is f64 {
        if typ == `g` || typ == `G` { return val.str() }
        prec := if precision >= 0 { precision } else { 6 }
        formatted = strconv.format_f64(val, typ.to_lower(), prec, 64)
        if typ.is_upper() { formatted = formatted.to_upper() }
    } else { formatted = '\x24{val}' }
    if width > formatted.len {
        pad_len := width - formatted.len
        if align == `<` { formatted = formatted + fill.ascii_str().repeat(pad_len) }
        else if align == `>` { formatted = fill.ascii_str().repeat(pad_len) + formatted }
        else if align == `^` {
            left := pad_len / 2
            right := pad_len - left
            formatted = fill.ascii_str().repeat(left) + formatted + fill.ascii_str().repeat(right)
        }
    }
    return formatted
}")
	}

	if m.state.used_builtins['py_bytes_format'] {
		m.emitter.add_helper_import('strconv')
		m.emitter.add_helper_import('strings')
		m.emitter.add_helper_function("fn py_bytes_format_arg(arg Any) string {
    if arg is []u8 { return arg.bytestr() }
    return '\x24{arg}'
}
fn py_bytes_format(fmt []u8, args Any) []u8 {
    fmt_str := fmt.bytestr()
    mut arg_list := []Any{}
    if args is []Any { arg_list = args } else { arg_list = [args] }
    mut res := strings.new_builder(fmt_str.len + 16)
    mut arg_idx := 0
    mut i := 0
    for i < fmt_str.len {
        if fmt_str[i] == `%` {
            if i + 1 < fmt_str.len {
                if fmt_str[i+1] == `%` { res.write_string('%'); i += 2; continue }
                mut j := i + 1
                mut flag_zero := false
                for j < fmt_str.len && (fmt_str[j] == `0` || fmt_str[j] == `-`) { 
                    if fmt_str[j] == `0` { flag_zero = true }
                    j++ 
                }
                mut width := 0
                for j < fmt_str.len && fmt_str[j].is_digit() {
                    width = width * 10 + int(fmt_str[j] - `0`)
                    j++
                }
                if j < fmt_str.len {
                    spec := fmt_str[j]
                    if arg_idx < arg_list.len {
                        arg := arg_list[arg_idx]
                        arg_idx++
                        mut s := py_bytes_format_arg(arg)
                        if width > s.len {
                            if flag_zero { s = '0'.repeat(width - s.len) + s }
                            else { s = ' '.repeat(width - s.len) + s }
                        }
                        res.write_string(s)
                        i = j + 1
                        continue
                    }
                }
            }
        }
        res.write_u8(fmt_str[i])
        i++
    }
    return res.str().bytes()
}")
	}

	if m.state.used_builtins['py_subscript_int'] {
		m.emitter.add_helper_function('fn py_subscript_int[T](a []T, idx int) T {
    if idx < 0 { return a[a.len + idx] }
    return a[idx]
}')
	}

	if m.state.used_builtins['py_subscript_i64'] {
		m.emitter.add_helper_function('fn py_subscript_i64[T](a []T, idx i64) T {
    i := int(idx)
    if i < 0 { return a[a.len + i] }
    return a[i]
}')
	}


	if 'py_any' in m.state.used_builtins {
		m.emitter.add_helper_function('fn py_any[T](a []T) bool {
    for x in a { if py_bool(x) { return true } }
    return false
}')
		m.state.used_builtins['py_bool'] = true
	}

	if 'py_all' in m.state.used_builtins {
		m.emitter.add_helper_function('fn py_all[T](a []T) bool {
    for x in a { if !py_bool(x) { return false } }
    return true
}')
		m.state.used_builtins['py_bool'] = true
	}

	if 'py_is_identical' in m.state.used_builtins {
		m.emitter.add_helper_function('fn py_is_identical[T, U](a T, b U) bool {
    return voidptr(&a) == voidptr(&b)
}')
	}

	if 'py_repeat_list' in m.state.used_builtins {
		m.emitter.add_helper_function('fn py_repeat_list[T](a []T, n int) []T {
    mut res := []T{cap: a.len * n}
    for _ in 0 .. n { res << a }
    return res
}')
	}

	if 'py_round' in m.state.used_builtins || 'round' in m.state.used_builtins {
		m.emitter.add_helper_import('math')
		m.emitter.add_helper_function('fn py_round(number f64, ndigits int) f64 {
    p := math.pow(10, f64(ndigits))
    return math.round(number * p) / p
}')
	}

	if m.state.used_complex {
		m.emitter.add_helper_import('math')
		m.emitter.add_helper_struct('struct PyComplex { re f64 im f64 }')
		m.emitter.add_helper_function('fn py_complex(re f64, im f64) PyComplex { return PyComplex{re: re, im: im} }')
		m.emitter.add_helper_function('fn (a PyComplex) + (b PyComplex) PyComplex { return PyComplex{re: a.re + b.re, im: a.im + b.im} }')
		m.emitter.add_helper_function('fn (a PyComplex) - (b PyComplex) PyComplex { return PyComplex{re: a.re - b.re, im: a.im - b.im} }')
		m.emitter.add_helper_function('fn (a PyComplex) * (b PyComplex) PyComplex { return PyComplex{re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re} }')
		m.emitter.add_helper_function('fn (a PyComplex) / (b PyComplex) PyComplex {
    denom := b.re * b.re + b.im * b.im
    return PyComplex{re: (a.re * b.re + a.im * b.im) / denom, im: (a.im * b.re - a.re * b.im) / denom}
}')
		m.emitter.add_helper_function('fn (z PyComplex) str() string {
    sign := if z.im >= 0 { "+" } else { "-" }
    im_abs := if z.im >= 0 { z.im } else { -z.im }
    return "(\x24{z.re}\x24{sign}\x24{im_abs}j)"
}')
	}

	// collections
	if m.state.imported_modules.values().contains('collections') || m.state.used_builtins['py_counter'] {
		m.emitter.add_helper_function('fn py_counter[T](a []T) map[T]int {
    mut m := map[T]int{}
    for x in a { m[x]++ }
    return m
}')
	}

	// functools
	if m.state.imported_modules.values().contains('functools') || m.state.used_builtins['py_reduce'] {
		m.emitter.add_helper_function('fn py_reduce[T](op fn (acc T, x T) T, iter []T) T {
    if iter.len == 0 { panic("reduce() of empty sequence") }
    mut acc := iter[0]
    for i in 1..iter.len { acc = op(acc, iter[i]) }
    return acc
}')
	}

	if 'py_sorted' in m.state.used_builtins || 'sorted' in m.state.used_builtins {
		m.emitter.add_helper_function('fn py_sorted[T](a []T, reverse bool) []T {
    mut b := a.clone()
    b.sort()
    if reverse { b.reverse() }
    return b
}')
	}

	if 'reversed' in m.state.used_builtins || 'py_reversed' in m.state.used_builtins {
		m.emitter.add_helper_function('fn py_reversed[T](a []T) []T {
    mut b := a.clone()
    b.reverse()
    return b
}')
	}
	if m.state.used_builtins['py_list_pop_at'] {
		m.emitter.add_helper_function('fn py_list_pop_at[T](mut a []T, index int) T {
    mut i := index
    if i < 0 { i += a.len }
    res := a[i]
    a.delete(i)
    return res
}')
	}

	if m.state.used_builtins['py_list_remove'] {
		m.emitter.add_helper_function('fn py_list_remove[T](mut a []T, val T) {
    idx := a.index(val)
    if idx >= 0 { a.delete(idx) }
}')
	}

	if m.state.used_builtins['py_dict_pop'] {
		m.emitter.add_helper_function('fn py_dict_pop[K, V](mut d map[K]V, key K, default V) V {
    if key in d {
        val := d[key]
        d.delete(key)
        return val
    }
    return default
}')
	}

	if m.state.used_builtins['py_dict_update'] {
		m.emitter.add_helper_function('fn py_dict_update[K, V](mut d map[K]V, other ...map[K]V) map[K]V {
    for o in other { for k, v in o { d[k] = v } }
    return d
}')
	}

	if m.state.used_builtins['py_dict_setdefault'] {
		m.emitter.add_helper_function('fn py_dict_setdefault[K, V](mut d map[K]V, key K, default V) V {
    if key in d { return d[key] }
    d[key] = default
    return default
}')
	}

	if m.state.used_builtins['py_dict_fromkeys'] {
		m.emitter.add_helper_function('fn py_dict_fromkeys[M, K, V](keys []K, val V) M {
    mut res := M{}
    for k in keys { res[k] = val }
    return res
}')
	}

	if m.state.used_builtins['py_set_union'] {
		m.emitter.add_helper_function('fn py_set_union[K](a datatypes.Set[K], b datatypes.Set[K]) datatypes.Set[K] {
    mut res := a.clone()
    for k, _ in b.elements { res.add(k) }
    return res
}')
	}

	if m.state.used_builtins['py_set_intersection'] {
		m.emitter.add_helper_function('fn py_set_intersection[K](a datatypes.Set[K], b datatypes.Set[K]) datatypes.Set[K] {
    mut res := datatypes.Set[K]{}
    for k, _ in a.elements { if k in b.elements { res.add(k) } }
    return res
}')
	}

	if m.state.used_builtins['py_bool'] {
		m.emitter.add_helper_function('fn py_bool(val Any) bool {
    if val is bool { return val }
    if val is int { return val != 0 }
    if val is i64 { return val != 0 }
    if val is f64 { return val != 0.0 }
    if val is string { return val.len > 0 }
    if val is []Any { return val.len > 0 }
    if val is map[string]Any { return val.len > 0 }
    return true
}')
	}

	if m.state.used_builtins['py_slice'] {
		m.emitter.add_helper_function('fn py_slice(obj Any, lower ?Any, upper ?Any, step ?Any) Any {
    if obj is string { return py_str_slice(obj, lower, upper, step) }
    panic("py_slice: unsupported type")
    return false
}')
	}

	if m.state.used_builtins['py_str_slice'] {
		m.emitter.add_helper_function('fn py_str_slice(s string, lower ?Any, upper ?Any, step ?Any) string {
    mut l := 0
    if v := lower { if v is int { l = v } }
    mut u := s.len
    if v := upper { if v is int { u = v } }
    mut st := 1
    if v := step { if v is int { st = v } }
    if l < 0 { l += s.len }
    if u < 0 { u += s.len }
    if l < 0 { l = 0 }
    if u > s.len { u = s.len }
    if st == 1 { return s[l..u] }
    runes := s.runes()
    mut res := []rune{}
    if st > 0 { for i := l; i < u; i += st { if i >= 0 && i < runes.len { res << runes[i] } } }
    else { for i := l; i > u; i += st { if i >= 0 && i < runes.len { res << runes[i] } } }
    return res.string()
}')
	}

	if m.state.used_builtins['py_min'] {
		m.emitter.add_helper_function('fn py_min[T](a []T) T {
    if a.len == 0 { panic("min() arg is an empty sequence") }
    mut m := a[0]
    for x in a { if x < m { m = x } }
    return m
}')
	}

	if m.state.used_builtins['py_max'] {
		m.emitter.add_helper_function('fn py_max[T](a []T) T {
    if a.len == 0 { panic("max() arg is an empty sequence") }
    mut m := a[0]
    for x in a { if x > m { m = x } }
    return m
}')
	}

	if 'py_zip' in m.state.used_builtins {
		m.emitter.add_helper_struct('struct PyZipItem[T, U] { pub: a T b U }')
		m.emitter.add_helper_function('fn py_zip[T, U](a []T, b []U) []PyZipItem[T, U] {
    mut res := []PyZipItem[T, U]{}
    limit := if a.len < b.len { a.len } else { b.len }
    for i in 0..limit { res << PyZipItem[T, U]{a: a[i], b: b[i]} }
    return res
}')
	}

	if 'py_enumerate' in m.state.used_builtins {
		m.emitter.add_helper_struct('struct PyEnumerateItem[T] { pub: index int value T }')
		m.emitter.add_helper_function('fn py_enumerate[T](a []T) []PyEnumerateItem[T] {
    mut res := []PyEnumerateItem[T]{}
    for i, x in a { res << PyEnumerateItem[T]{index: i, value: x} }
    return res
}')
	}

	if 'py_range' in m.state.used_builtins {
		m.emitter.add_helper_function('fn py_range(args ...int) []int {
    mut res := []int{}
    if args.len == 1 { for i in 0..args[0] { res << i } }
    else if args.len == 2 { for i in args[0]..args[1] { res << i } }
    else if args.len == 3 {
        start, stop, step := args[0], args[1], args[2]
        if step > 0 { for i := start; i < stop; i += step { res << i } }
        else if step < 0 { for i := start; i > stop; i += step { res << i } }
    }
    return res
}')
	}

	if m.state.used_builtins['py_yield'] || m.state.used_builtins['PyGenerator'] {
		m.emitter.add_helper_struct('struct PyGeneratorInput { val Any is_exc bool exc_msg string }')
		m.emitter.add_helper_struct('struct PyGenerator[T] { mut: out chan T in_ chan PyGeneratorInput open bool = true }')
		m.emitter.add_helper_function('fn (mut g PyGenerator[T]) next() ?T {
    if !g.open { return none }
    g.in_ <- PyGeneratorInput{val: 0}
    res := <-g.out
    if res == none { g.open = false }
    return res
}')
		m.emitter.add_helper_function('fn (mut g PyGenerator[T]) send(val Any) ?T {
    if !g.open { panic("StopIteration") }
    g.in_ <- PyGeneratorInput{val: val}
    res := <-g.out
    if res == none { g.open = false }
    return res
}')
		m.emitter.add_helper_function('fn (mut g PyGenerator[T]) throw(msg string) ?T {
    if !g.open { panic("StopIteration") }
    g.in_ <- PyGeneratorInput{is_exc: true, exc_msg: msg}
    res := <-g.out
    if res == none { g.open = false }
    return res
}')
		m.emitter.add_helper_function('fn (mut g PyGenerator[T]) close() {
    g.open = false
    g.in_.close()
}')
		m.emitter.add_helper_function('fn py_yield[T](ch_out chan T, ch_in chan PyGeneratorInput, val T) Any {
    ch_out <- val
    inp := <-ch_in
    if inp.is_exc { panic(inp.exc_msg) }
    return inp.val
}')
	}

	if m.state.used_builtins['py_divmod'] {
		m.emitter.add_helper_import('math')
		m.emitter.add_helper_function('fn py_divmod[T](a T, b T) []T {
    \x24if T is f64 {
        q := math.floor(a / b)
        r := a - q * b
        return [q, r]
    } \x24else {
        return [a / b, a % b]
    }
}')
	}

	if m.state.used_builtins['py_random_sample'] {
		m.emitter.add_helper_import('rand')
		m.emitter.add_helper_function('fn py_random_sample[T](a []T, k int) []T {
    if k > a.len { panic("sample larger than population") }
    mut res := []T{}
    mut indices := []int{len: a.len}
    for i in 0..a.len { indices[i] = i }
    rand.shuffle(mut indices) or { panic(err) }
    for i in 0..k { res << a[indices[i]] }
    return res
}')
	}

	if m.state.imported_modules.values().contains('tempfile') {
		m.emitter.add_helper_import('os')
		m.emitter.add_helper_struct('struct PyTempDir { path string }')
		m.emitter.add_helper_function('fn (d PyTempDir) close() { os.rmdir_all(d.path) or {} }')
		m.emitter.add_helper_function('fn py_temp_dir() PyTempDir {
    p := os.mkdir_temp("") or { panic(err) }
    return PyTempDir{path: p}
}')
		m.emitter.add_helper_function('fn py_named_temp_file() os.File {
    f, _ := os.create_temp("") or { panic(err) }
    return f
}')
	}

	if m.state.imported_modules.values().contains('logging') {
		m.emitter.add_helper_import('log')
		m.emitter.add_helper_function('fn py_get_logger(name string) log.Log {
    mut l := log.Log{}
    l.set_level(.info)
    return l
}')
	}

	if m.state.imported_modules.values().contains('argparse') {
		m.emitter.add_helper_import('os')
		m.emitter.add_helper_struct('struct PyArgDef { name string }')
		m.emitter.add_helper_struct('struct PyArgumentParser { mut: definitions []PyArgDef }')
		m.emitter.add_helper_function('fn py_argparse_new() PyArgumentParser { return PyArgumentParser{} }')
		m.emitter.add_helper_function('fn (mut p PyArgumentParser) add_argument(name string) {
    p.definitions << PyArgDef{name: name}
}')
		m.emitter.add_helper_function('fn (mut p PyArgumentParser) parse_args() map[string]string {
    mut args := map[string]string{}
    for i := 0; i < os.args.len; i++ {
        arg := os.args[i]
        if arg.starts_with("--") {
            key := arg[2..]
            val := if i + 1 < os.args.len { os.args[i+1] } else { "" }
            args[key] = val
        }
    }
    return args
}')
	}

	if m.state.imported_modules.values().contains('itertools') {
		m.emitter.add_helper_function('fn py_chain[T](args ...[]T) []T {
    mut res := []T{}
    for arg in args { res << arg }
    return res
}')
		m.emitter.add_helper_struct('struct PyCountIterator { mut: val int step int }')
		m.emitter.add_helper_function('fn (mut i PyCountIterator) next() ?int {
    val := i.val
    i.val += i.step
    return val
}')
		m.emitter.add_helper_function('fn py_count(start int, step int) PyCountIterator { return PyCountIterator{val: start, step: step} }')
	}

	if m.state.imported_modules.values().contains('pathlib') || m.state.used_builtins['py_path_new'] {
		m.emitter.add_helper_import('os')
		m.emitter.add_helper_struct('struct PyPath { path string }')
		m.emitter.add_helper_function('fn py_path_new(p string) PyPath { return PyPath{path: p} }')
		m.emitter.add_helper_function('fn (p PyPath) / (other string) PyPath { return PyPath{path: os.join_path(p.path, other)} }')
		m.emitter.add_helper_function('fn (p PyPath) exists() bool { return os.exists(p.path) }')
		m.emitter.add_helper_function('fn (p PyPath) is_dir() bool { return os.is_dir(p.path) }')
		m.emitter.add_helper_function('fn (p PyPath) is_file() bool { return os.is_file(p.path) }')
		m.emitter.add_helper_function('fn (p PyPath) read_text() string { return os.read_file(p.path) or { panic(err) } }')
		m.emitter.add_helper_function('fn (p PyPath) write_text(text string) { os.write_file(p.path, text) or { panic(err) } }')
		m.emitter.add_helper_function('fn (p PyPath) str() string { return p.path }')
	}

	if m.state.imported_modules.values().contains('urllib.request') {
		m.emitter.add_helper_import('net.http')
		m.emitter.add_helper_struct('struct PyHttpResponse { body string }')
		m.emitter.add_helper_function('fn (r PyHttpResponse) read() string { return r.body }')
		m.emitter.add_helper_function('fn py_urlopen(url string) PyHttpResponse {
    resp := http.get(url) or { panic(err) }
    return PyHttpResponse{body: resp.body}
}')
	}

	if m.state.imported_modules.values().contains('csv') {
		m.emitter.add_helper_import('encoding.csv')
		m.emitter.add_helper_struct('struct PyCsvReader { mut: reader csv.Reader }')
		m.emitter.add_helper_function('fn py_csv_reader(f os.File) PyCsvReader { return PyCsvReader{reader: csv.new_reader(f)} }')
		m.emitter.add_helper_function('fn (mut r PyCsvReader) next() ?[]string {
    res := r.reader.read() or { return none }
    return res
}')
		m.emitter.add_helper_struct('struct PyCsvWriter { mut: writer csv.Writer }')
		m.emitter.add_helper_function('fn py_csv_writer(f os.File) PyCsvWriter { return PyCsvWriter{writer: csv.new_writer(f)} }')
		m.emitter.add_helper_function('fn (mut w PyCsvWriter) writerow(row []string) { w.writer.write(row) or { panic(err) } }')
	}

	if m.state.imported_modules.values().contains('sqlite3') {
		m.emitter.add_helper_import('db.sqlite')
		m.emitter.add_helper_struct('struct PySqliteConnection { db sqlite.DB }')
		m.emitter.add_helper_function('fn py_sqlite_connect(path string) PySqliteConnection {
    db := sqlite.connect(path) or { panic(err) }
    return PySqliteConnection{db: db}
}')
		m.emitter.add_helper_struct('struct PySqliteCursor { db sqlite.DB mut: rows []sqlite.Row }')
		m.emitter.add_helper_function('fn (c PySqliteConnection) cursor() PySqliteCursor { return PySqliteCursor{db: c.db} }')
		m.emitter.add_helper_function('fn (mut c PySqliteCursor) execute(sql string) {
    rows := c.db.exec(sql) or { panic(err) }
    c.rows = rows
}')
		m.emitter.add_helper_function('fn (c PySqliteCursor) fetchall() []sqlite.Row { return c.rows }')
		m.emitter.add_helper_function('fn (c PySqliteConnection) commit() { c.db.exec("COMMIT") or {} }')
		m.emitter.add_helper_function('fn (c PySqliteConnection) close() { c.db.close() or {} }')
	}

	if m.state.imported_modules.values().contains('subprocess') {
		m.emitter.add_helper_import('os')
		m.emitter.add_helper_struct('struct PyCompletedProcess { returncode int stdout string stderr string }')
		m.emitter.add_helper_function('fn py_subprocess_run(args []string) PyCompletedProcess {
    if args.len == 0 { return PyCompletedProcess{returncode: 1, stdout: "", stderr: "No arguments"} }
    mut p := os.new_process(args[0])
    p.set_args(args[1..])
    p.set_redirect_stdio()
    p.run()
    p.wait()
    res := PyCompletedProcess{returncode: p.code, stdout: p.stdout_slurp(), stderr: p.stderr_slurp()}
    p.close()
    return res
}')
		m.emitter.add_helper_function('fn py_subprocess_call(args []string) int {
    if args.len == 0 { return 1 }
    mut p := os.new_process(args[0])
    p.set_args(args[1..])
    p.run()
    p.wait()
    code := p.code
    p.close()
    return code
}')
	}

	if m.state.imported_modules.values().contains('platform') {
		m.emitter.add_helper_function('fn py_platform_machine() string { return os.uname().machine }')
	}

	if m.state.imported_modules.values().contains('hashlib') {
		m.emitter.add_helper_import('crypto.sha256')
		m.emitter.add_helper_import('crypto.md5')
		m.emitter.add_helper_struct('struct PyHashSha256 { mut: data []u8 }')
		m.emitter.add_helper_function('fn py_hash_sha256(data []u8) PyHashSha256 { return PyHashSha256{data: data} }')
		m.emitter.add_helper_function('fn (mut h PyHashSha256) update(data []u8) { h.data << data }')
		m.emitter.add_helper_function('fn (h PyHashSha256) digest() []u8 { return sha256.sum(h.data) }')
		m.emitter.add_helper_function('fn (h PyHashSha256) hexdigest() string { return sha256.hexhash(h.data) }')
		m.emitter.add_helper_struct('struct PyHashMd5 { mut: data []u8 }')
		m.emitter.add_helper_function('fn py_hash_md5(data []u8) PyHashMd5 { return PyHashMd5{data: data} }')
		m.emitter.add_helper_function('fn (mut h PyHashMd5) update(data []u8) { h.data << data }')
		m.emitter.add_helper_function('fn (h PyHashMd5) digest() []u8 { return md5.sum(h.data) }')
		m.emitter.add_helper_function('fn (h PyHashMd5) hexdigest() string { return md5.hexhash(h.data) }')
	}

	if m.state.imported_modules.values().contains('urllib.parse') || m.state.used_builtins['py_urllib_unquote'] {
		m.emitter.add_helper_import('net.urllib')
		m.emitter.add_helper_function('fn py_urllib_unquote(s string) string { return urllib.query_unescape(s) or { s } }')
		m.emitter.add_helper_function('fn py_urlencode(params map[string]string) string {
    mut v := urllib.new_values(map[string][]string{})
    for key, val in params { v.add(key, val) }
    return v.encode()
}')
		m.emitter.add_helper_function('fn py_urlparse(url string) urllib.URL { return urllib.parse(url) or { urllib.URL{} } }')
	}

	if m.state.imported_modules.values().contains('zlib') {
		m.emitter.add_helper_import('compress.zlib')
		m.emitter.add_helper_function('fn py_zlib_compress(data []u8) []u8 { return zlib.compress(data) or { panic(err) } }')
		m.emitter.add_helper_function('fn py_zlib_decompress(data []u8) []u8 { return zlib.decompress(data) or { panic(err) } }')
	}

	if m.state.imported_modules.values().contains('gzip') {
		m.emitter.add_helper_import('compress.gzip')
		m.emitter.add_helper_function('fn py_gzip_compress(data []u8) []u8 { return gzip.compress(data) or { panic(err) } }')
		m.emitter.add_helper_function('fn py_gzip_decompress(data []u8) []u8 { return gzip.decompress(data) or { panic(err) } }')
	}

	if m.state.imported_modules.values().contains('copy') || m.state.used_builtins['py_copy'] || m.state.used_builtins['py_deepcopy'] {
		m.emitter.add_helper_function("fn py_copy[T](x T) T {
    \x24if T is array { return x.clone() }
    \x24else \x24if T is map { return x.clone() }
    \x24else { return x }
}")
		m.emitter.add_helper_function("fn py_deepcopy[T](x T) T {
    \x24if T is array { return x.clone() }
    \x24else \x24if T is map { return x.clone() }
    \x24else { return x }
}")
	}

	if m.state.used_builtins['py_os_path_split'] {
		m.emitter.add_helper_import('os')
		m.emitter.add_helper_function('fn py_os_path_split(path string) []string { return [os.dir(path), os.base(path)] }')
	}

	if m.state.imported_modules.values().contains('struct') {
		m.emitter.add_helper_import('encoding.binary')
		m.emitter.add_helper_function('// struct.pack with dynamic formats is not implemented. Use specific helpers.')
		m.emitter.add_helper_function('fn py_struct_pack_I_be(val u32) []u8 { mut buf := []u8{len: 4} binary.big_endian_put_u32(mut buf, val) return buf }')
		m.emitter.add_helper_function('fn py_struct_unpack_I_be(buf []u8) u32 { return binary.big_endian_u32(buf) }')
		m.emitter.add_helper_function('fn py_struct_pack_i_be(val int) []u8 { mut buf := []u8{len: 4} binary.big_endian_put_u32(mut buf, u32(val)) return buf }')
		m.emitter.add_helper_function('fn py_struct_unpack_i_be(buf []u8) int { return int(binary.big_endian_u32(buf)) }')
	}

	if m.state.imported_modules.values().contains('array') {
		m.emitter.add_helper_function('fn py_array[T](code string, init []T) []T { return init }')
	}

	if m.state.imported_modules.values().contains('fractions') {
		m.emitter.add_helper_import('math.fractions')
		m.emitter.add_helper_function('fn py_fraction(val Any) fractions.Fraction {
    \x24if val is int { return fractions.fraction(i64(val), 1) }
    \x24else \x24if val is f64 { return fractions.from_f64(f64(val)) }
    return fractions.fraction(0, 1)
}')
	}

	if m.state.imported_modules.values().contains('statistics') {
		m.emitter.add_helper_import('math')
		m.emitter.add_helper_function('fn py_statistics_mean[T](data []T) f64 {
    if data.len == 0 { return 0.0 }
    mut sum := f64(0)
    for x in data { sum += f64(x) }
    return sum / f64(data.len)
}')
		m.emitter.add_helper_function('fn py_statistics_median[T](data []T) f64 {
    if data.len == 0 { return 0.0 }
    mut sd := data.clone()
    sd.sort()
    m := sd.len / 2
    if sd.len % 2 == 1 { return f64(sd[m]) }
    return (f64(sd[m-1]) + f64(sd[m])) / 2.0
}')
	}

	if m.state.imported_modules.values().contains('decimal') {
		m.emitter.add_helper_struct('type Decimal = f64')
		m.emitter.add_helper_function('fn py_decimal(val Any) Decimal {
    \x24if val is f64 { return val }
    \x24else \x24if val is int { return f64(val) }
    \x24else \x24if val is string { return val.f64() }
    return 0.0
}')
	}
	if m.state.used_builtins['py_os_path_split'] {
		m.emitter.add_helper_import('os')
		m.emitter.add_helper_function('fn py_os_path_split(path string) []string { return [os.dir(path), os.base(path)] }')
	}

	if m.state.used_builtins['py_os_path_splitext'] {
		m.emitter.add_helper_import('os')
		m.emitter.add_helper_function('fn py_os_path_splitext(path string) []string {
    ext := os.file_ext(path)
    return [path[..path.len - ext.len], ext]
}')
	}

	if m.state.used_builtins['py_dict_pop'] {
		m.emitter.add_helper_function('fn py_dict_pop[K, V](mut d map[K]V, key K, default V) V {
    if key in d {
        val := d[key]
        d.delete(key)
        return val
    }
    return default
}')
	}

	if m.state.used_builtins['py_dict_update'] {
		m.emitter.add_helper_function('fn py_dict_update[K, V](mut d map[K]V, other ...map[K]V) map[K]V {
    for o in other { for k, v in o { d[k] = v } }
    return d
}')
	}

	if m.state.used_builtins['py_repr'] {
		m.emitter.add_helper_function("fn py_repr(val Any) string {
    if val is string { return \"'\" + val + \"'\" }
    return \"\x24{val}\"
}")
	}

	if m.state.used_builtins['py_ascii'] {
		m.emitter.add_helper_function("fn py_ascii(val Any) string {
    s := \"\x24{val}\"
    mut res := ''
    for c in s {
        if c < 128 { res += c.ascii_str() }
        else { res += '\\\\u' + int(c).hex() }
    }
    return res
}")
	}

	if m.state.used_builtins['py_dict_setdefault'] {
		m.emitter.add_helper_function('fn py_dict_setdefault[K, V](mut d map[K]V, key K, default V) V {
    if key in d { return d[key] }
    d[key] = default
    return default
}')
	}

	if m.state.used_builtins['py_dict_residual'] {
		m.emitter.add_helper_function('fn py_dict_residual[K, V](m map[K]V, exclude []K) map[K]Any {
    mut res := map[K]Any{}
    for k, v in m { if k !in exclude { res[k] = Any(v) } }
    return res
}')
	}

	if m.state.imported_modules.values().contains('pickle') {
		m.emitter.add_helper_import('json')
		m.emitter.add_helper_function('fn py_pickle_dumps[T](obj T) string { return json.encode(obj) }')
		m.emitter.add_helper_function('fn py_pickle_loads[T](s string) T { return json.decode(T, s) or { panic(err) } }')
	}
}

pub fn (mut m ModuleTranslator) visit_module(node ast.Module) string {
	m.coroutine_handler.scan_module(node)
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
			m.state.output << '// @line: ${m.state.get_source_info(stmt.get_token())}'
		}
		
		if stmt is ast.FunctionDef || stmt is ast.ClassDef || stmt is ast.Import || stmt is ast.ImportFrom {
			m.state.in_main = false
			m.visit_stmt_fn(stmt)
			m.state.in_main = true
		} else {
			m.visit_stmt_fn(stmt)
		}

		for line in m.state.output {
			if stmt is ast.If && m.is_name_main(stmt) {
				m.emitter.add_main_statement(line.trim_space())
			} else if line.trim_space().starts_with('import ') {
				m.emitter.add_import(line.trim_space()['import '.len..].trim_space())
			} else if stmt is ast.FunctionDef {
				m.emitter.add_helper_function(line)
			} else if stmt is ast.ClassDef {
				m.emitter.add_helper_struct(line) // For now, handle as block
			} else {
				m.emitter.add_init_statement(line.trim_space())
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
