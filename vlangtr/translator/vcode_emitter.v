module translator

fn to_snake_case(name string) string {
	mut out := []u8{}
	for i, ch in name.bytes() {
		if ch >= `A` && ch <= `Z` {
			if i > 0 {
				prev := name.bytes()[i - 1]
				if prev != `_` && ((prev >= `a` && prev <= `z`) || (prev >= `0` && prev <= `9`)) {
					out << `_`
				}
			}
			out << ch + 32
		} else {
			out << ch
		}
	}
	return out.bytestr().replace('__', '_')
}

pub struct VCodeEmitter {
pub mut:
	module_name     string
	imports         []string
	structs         []string
	functions       []string
	main_body       []string
	init_body       []string
	globals         []string
	constants       []string
	helper_imports  []string
	helper_structs  []string
	helper_functions []string
}

pub fn new_vcode_emitter(module_name string) VCodeEmitter {
	return VCodeEmitter{
		module_name:     module_name
		imports:         []string{}
		structs:         []string{}
		functions:       []string{}
		main_body:       []string{}
		init_body:       []string{}
		globals:         []string{}
		constants:       []string{}
		helper_imports:  []string{}
		helper_structs:  []string{}
		helper_functions: []string{}
	}
}

pub fn (mut e VCodeEmitter) add_import(module_name string) {
	if module_name !in e.imports {
		e.imports << module_name
	}
}

pub fn (mut e VCodeEmitter) add_helper_import(module_name string) {
	if module_name !in e.helper_imports {
		e.helper_imports << module_name
	}
}

pub fn (mut e VCodeEmitter) add_global(global_def string) {
	e.globals << global_def
}

pub fn (mut e VCodeEmitter) add_constant(const_def string) {
	mut updated := const_def
	if const_def.starts_with('pub const ') {
		name_part := const_def[10..]
		if idx := name_part.index('=') {
			name := name_part[..idx].trim_space()
			rest := name_part[idx..]
			updated = 'pub const ${to_snake_case(name)} ${rest.trim_space()}'
		}
	} else if const_def.starts_with('const ') {
		name_part := const_def[6..]
		if idx := name_part.index('=') {
			name := name_part[..idx].trim_space()
			rest := name_part[idx..]
			updated = 'const ${to_snake_case(name)} ${rest.trim_space()}'
		}
	}
	e.constants << updated
}

pub fn (mut e VCodeEmitter) add_struct(struct_def string) {
	e.structs << struct_def
}

pub fn (mut e VCodeEmitter) add_helper_struct(struct_def string) {
	e.helper_structs << struct_def
}

pub fn (mut e VCodeEmitter) add_function(func_def string) {
	e.functions << func_def
}

pub fn (mut e VCodeEmitter) add_helper_function(func_def string) {
	e.helper_functions << func_def
}

pub fn (mut e VCodeEmitter) add_init_statement(stmt string) {
	e.init_body << stmt
}

pub fn (mut e VCodeEmitter) add_main_statement(stmt string) {
	e.main_body << stmt
}

pub fn (e &VCodeEmitter) emit() string {
	mut lines := []string{}
	lines << 'module ${e.module_name}'
	lines << ''

	if e.imports.len > 0 {
		mut imports := e.imports.clone()
		imports.sort()
		for imp in imports {
			lines << 'import ${imp}'
		}
		lines << ''
	}

	if e.structs.len > 0 {
		lines << e.structs.join('\n\n')
		lines << ''
	}

	if e.globals.len > 0 {
		lines << '// To compile with globals, use: v -enable-globals .'
		for g in e.globals {
			mut sanitized := g
			if sanitized.starts_with('pub ') {
				sanitized = sanitized[4..]
			}
			lines << '__global ${sanitized}'
		}
		lines << ''
	}

	if e.constants.len > 0 {
		for c in e.constants {
			if c.starts_with('pub ') {
				lines << c
			} else {
				lines << c
			}
		}
		lines << ''
	}

	if e.functions.len > 0 {
		lines << e.functions.join('\n\n')
		lines << ''
	}

	if e.init_body.len > 0 {
		lines << 'fn init() {'
		for stmt in e.init_body {
			lines << '    ${stmt}'
		}
		lines << '}'
		lines << ''
	}

	if e.main_body.len > 0 {
		lines << 'fn main() {'
		for stmt in e.main_body {
			lines << '    ${stmt}'
		}
		lines << '}'
	}

	return lines.join('\n')
}

pub fn (e &VCodeEmitter) emit_helpers() string {
	return VCodeEmitter.emit_global_helpers(e.helper_imports, e.helper_structs, e.helper_functions, 'main')
}

pub fn VCodeEmitter.emit_global_helpers(imports []string, structs []string, functions []string, module_name string) string {
	mut lines := []string{}
	lines << 'module ${module_name}'
	lines << ''

	mut seen_imports := map[string]bool{}
	mut unique_imports := []string{}
	for imp in imports {
		if imp !in seen_imports {
			seen_imports[imp] = true
			unique_imports << imp
		}
	}
	unique_imports.sort()
	for imp in unique_imports {
		lines << 'import ${imp}'
	}
	if unique_imports.len > 0 {
		lines << ''
	}

	lines << 'pub struct NoneType {}'
	lines << 'pub fn (n NoneType) str() string {'
	lines << "    return 'None'"
	lines << '}'
	lines << ''

	lines << 'pub struct Interpolation {'
	lines << 'pub:'
	lines << '    value       any'
	lines << '    expression  string'
	lines << '    conversion  string'
	lines << '    format_spec string'
	lines << '}'
	lines << ''

	lines << 'pub struct Template {'
	lines << 'pub:'
	lines << '    strings        []string'
	lines << '    interpolations []Interpolation'
	lines << '}'
	lines << ''

	lines << 'pub fn (t Template) values() []any {'
	lines << '    mut res := []any{cap: t.interpolations.len}'
	lines << '    for i in t.interpolations {'
	lines << '        res << i.value'
	lines << '    }'
	lines << '    return res'
	lines << '}'
	lines << ''

	lines << 'pub fn (t1 Template) + (t2 Template) Template {'
	lines << '    if t1.strings.len == 0 { return t2 }'
	lines << '    if t2.strings.len == 0 { return t1 }'
	lines << '    mut new_strings := t1.strings[..t1.strings.len - 1].clone()'
	lines << '    new_strings << t1.strings.last() + t2.strings[0]'
	lines << '    if t2.strings.len > 1 {'
	lines << '        new_strings << t2.strings[1..]'
	lines << '    }'
	lines << '    mut new_interpolations := t1.interpolations.clone()'
	lines << '    new_interpolations << t2.interpolations'
	lines << '    return Template{'
	lines << '        strings: new_strings'
	lines << '        interpolations: new_interpolations'
	lines << '    }'
	lines << '}'
	lines << ''

	lines << 'pub type Any = Interpolation | NoneType | Template | []any | []u8 | bool | f64 | i64 | int | map[string]any | string'
	lines << ''

	lines << 'pub enum PyAnnotationFormat { value forwardref string }'
	lines << ''

	lines << 'pub fn py_get_type_hints[T]() map[string]string {'
	lines << '    mut hints := map[string]string{}'
	lines << '    ' + '$' + 'for field in T.fields {'
	lines << '        hints[field.name] = field.typ'
	lines << '    }'
	lines << '    return hints'
	lines << '}'
	lines << ''

	lines << 'pub fn py_get_type_hints_generic(obj any) map[string]string {'
	lines << '    return map[string]string{}'
	lines << '}'
	lines << ''

	mut seen_structs := map[string]bool{}
	for s in structs {
		if s !in seen_structs {
			seen_structs[s] = true
			lines << s
		}
	}
	if structs.len > 0 {
		lines << ''
	}

	mut seen_funcs := map[string]bool{}
	for f in functions {
		if f !in seen_funcs {
			seen_funcs[f] = true
			lines << f
		}
	}
	if functions.len > 0 {
		lines << ''
	}

	return lines.join('\n')
}
