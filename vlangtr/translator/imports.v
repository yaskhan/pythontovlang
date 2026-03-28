module translator

import ast
import base
import stdlib_map

fn matches_scc(module_name string, scc_file string) bool {
	if scc_file.len == 0 {
		return false
	}
	normalized := scc_file.replace('.py', '').replace('/', '.').replace('\\', '.')
	return module_name.ends_with(normalized)
}

fn (mut t Translator) register_imported_module(alias string, module_name string) {
	if alias.len == 0 {
		return
	}
	t.state.imported_modules[alias] = module_name
}

fn (mut t Translator) register_imported_symbol(alias string, full_name string) {
	if alias.len == 0 {
		return
	}
	t.state.imported_symbols[alias] = full_name
}

pub fn (mut t Translator) visit_import(node ast.Import) {
	for alias in node.names {
		module_name := alias.name
		as_name := alias.asname or { module_name }
		mut is_same_scc := false
		for scc_file in t.state.scc_files.keys() {
			if matches_scc(module_name, scc_file) {
				is_same_scc = true
				break
			}
		}

		t.register_imported_module(as_name, module_name)
		if is_same_scc {
			continue
		}
		if module_name in ['typing', 'unittest', '__future__'] {
			continue
		}
		
		if t.state.mapper != unsafe { nil } {
			mapper := unsafe { &stdlib_map.StdLibMapper(t.state.mapper) }
			if v_imps := mapper.get_imports(module_name) {
				for imp in v_imps {
					t.state.output << 'import ${imp}'
				}
				continue
			}
		}

		if module_name == 'strconv' {
			t.state.output << 'import strconv'
			continue
		}
	}
}

pub fn (mut t Translator) visit_import_from(node ast.ImportFrom) {
	module_name := node.module
	if module_name.len == 0 {
		for alias in node.names {
			name := alias.name
			if name == '*' {
				continue
			}
			as_name := alias.asname or { name }
			t.register_imported_symbol(as_name, name)
		}
		return
	}

	mut is_same_scc := false
	for scc_file in t.state.scc_files.keys() {
		if matches_scc(module_name, scc_file) {
			is_same_scc = true
			break
		}
	}

	for alias in node.names {
		name := alias.name
		as_name := alias.asname or { name }
		if name == '*' {
			continue
		}
		if is_same_scc {
			prefix := base.get_scc_prefix(module_name)
			t.register_imported_symbol(as_name, '${prefix}__${name}')
		} else {
			t.register_imported_symbol(as_name, '${module_name}.${name}')
		}
	}

	if module_name in ['typing', 'unittest', '__future__'] {
		return
	}

	if t.state.mapper != unsafe { nil } {
		mapper := unsafe { &stdlib_map.StdLibMapper(t.state.mapper) }
		if v_imps := mapper.get_imports(module_name) {
			for imp in v_imps {
				t.state.output << 'import ${imp}'
			}
		}
	}
}
