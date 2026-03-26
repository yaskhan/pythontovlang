module analyzer

import os

pub struct DependencyAnalyzer {
pub mut:
	dependencies []string
	file_index    map[string]bool
	dir_index     map[string]bool
}

pub fn new_dependency_analyzer() DependencyAnalyzer {
	return DependencyAnalyzer{
		dependencies: []string{}
		file_index:   map[string]bool{}
		dir_index:    map[string]bool{}
	}
}

pub fn (mut d DependencyAnalyzer) index_project(root_path string, skip_dirs []string) {
	d.file_index = map[string]bool{}
	d.dir_index = map[string]bool{}

	os.walk(root_path, fn [mut d, root_path, skip_dirs] (path string) {
		rel := relative_path(root_path, path)
		if rel == '' {
			return
		}
		if should_skip_rel(rel, skip_dirs) {
			return
		}
		if os.is_dir(path) {
			d.dir_index[rel] = true
		} else if os.is_file(path) {
			d.file_index[rel] = true
		}
	})
}

pub fn (mut d DependencyAnalyzer) analyze_file(file_path string) []string {
	d.dependencies = []string{}
	source := os.read_file(file_path) or { return []string{} }
	for line in source.split('\n') {
		parse_import_line(line, mut d.dependencies)
	}
	return d.dependencies.clone()
}

fn parse_import_line(line string, mut dependencies []string) {
	trimmed := line.trim_space()
	if trimmed.len == 0 || trimmed.starts_with('#') {
		return
	}

	if trimmed.starts_with('import ') {
		rest := trimmed[7..]
		for part in rest.split(',') {
			mut name := part.trim_space()
			if name.len == 0 {
				continue
			}
			if name.contains(' as ') {
				name = name.split(' as ')[0].trim_space()
			}
			if name.len > 0 {
				dependencies << name
			}
		}
		return
	}

	if trimmed.starts_with('from ') && trimmed.contains(' import ') {
		after_from := trimmed[5..]
		idx := after_from.index(' import ') or { return }
		module_name := after_from[..idx].trim_space()
		if module_name.len > 0 {
			dependencies << module_name
		}
	}
}

pub fn (d DependencyAnalyzer) resolve_module_to_path(module_name string, root_path string, current_file_path string) ?string {
	mod_name := module_name.trim_space().trim_left('.')
	if mod_name.len == 0 {
		return none
	}
	parts := mod_name.split('.')

	for i in 0 .. parts.len {
		sub_parts := parts[i..]
		potential_rel := sub_parts.join('/')

		if '${potential_rel}.py' in d.file_index {
			return '${potential_rel}.py'
		}
		if '${potential_rel}.pyi' in d.file_index {
			return '${potential_rel}.pyi'
		}

		if potential_rel in d.dir_index {
			init_py := '${potential_rel}/__init__.py'
			if init_py in d.file_index {
				return init_py
			}
			init_pyi := '${potential_rel}/__init__.pyi'
			if init_pyi in d.file_index {
				return init_pyi
			}
		}
	}

	current_dir_rel := normalize_path(os.dir(current_file_path))
	mut prefix := ''
	if current_dir_rel != '.' && current_dir_rel.len > 0 {
		prefix = '${current_dir_rel}/'
	}
	potential_rel := prefix + parts.join('/')

	if '${potential_rel}.py' in d.file_index {
		return '${potential_rel}.py'
	}
	if '${potential_rel}.pyi' in d.file_index {
		return '${potential_rel}.pyi'
	}
	if potential_rel in d.dir_index {
		init_py := '${potential_rel}/__init__.py'
		if init_py in d.file_index {
			return init_py
		}
		init_pyi := '${potential_rel}/__init__.pyi'
		if init_pyi in d.file_index {
			return init_pyi
		}
	}

	return none
}

pub fn (mut d DependencyAnalyzer) analyze_project(root_path string, recursive bool, skip_dirs []string) map[string][]string {
	_ = recursive
	println('Indexing project: ${root_path}')
	d.index_project(root_path, skip_dirs)
	println('Index complete: ${d.file_index.len} files, ${d.dir_index.len} dirs')

	mut raw_graph := map[string][]string{}
	mut count := 0
	for rel_path in d.file_index.keys() {
		if rel_path.ends_with('.py') || rel_path.ends_with('.pyi') {
			count++
			if count % 100 == 0 {
				println('Analyzing dependencies: ${count}/${d.file_index.len} files...')
			}
			full_path := os.join_path(root_path, rel_path)
			dot_path := module_key_from_path(rel_path)
			deps := d.analyze_file(full_path)
			raw_graph[rel_path] = deps.clone()
			raw_graph[dot_path] = deps.clone()
		}
	}

	mut resolved_graph := map[string][]string{}
	for file, deps in raw_graph {
		if !file.ends_with('.py') && !file.ends_with('.pyi') {
			continue
		}
		mut resolved_deps := []string{}
		for dep in deps {
			if resolved_path := d.resolve_module_to_path(dep, root_path, file) {
				if resolved_path in raw_graph {
					if resolved_path !in resolved_deps {
						resolved_deps << resolved_path
					}
				}
			} else if dep in raw_graph {
				if dep !in resolved_deps {
					resolved_deps << dep
				}
			}
		}
		resolved_graph[file] = resolved_deps
	}

	return resolved_graph
}

pub fn (mut d DependencyAnalyzer) find_sccs(root_path string, recursive bool, skip_dirs []string) [][]string {
	graph := d.analyze_project(root_path, recursive, skip_dirs)
	mut vertices := graph.keys()
	vertices.sort()
	return strongly_connected_components(vertices, graph)
}

pub fn strongly_connected_components(vertices []string, edges map[string][]string) [][]string {
	mut ctx := SCCContext{
		index:    0
		stack:    []string{}
		on_stack: map[string]bool{}
		indices:  map[string]int{}
		lowlinks: map[string]int{}
		sccs:     [][]string{}
	}

	for v in vertices {
		if v !in ctx.indices {
			ctx.strong_connect(v, edges)
		}
	}
	return ctx.sccs
}

struct SCCContext {
pub mut:
	index    int
	stack    []string
	on_stack map[string]bool
	indices  map[string]int
	lowlinks map[string]int
	sccs     [][]string
}

fn (mut ctx SCCContext) strong_connect(v string, edges map[string][]string) {
	ctx.indices[v] = ctx.index
	ctx.lowlinks[v] = ctx.index
	ctx.index++
	ctx.stack << v
	ctx.on_stack[v] = true

	for w in edges[v] or { []string{} } {
		if w !in ctx.indices {
			ctx.strong_connect(w, edges)
			ctx.lowlinks[v] = if ctx.lowlinks[w] < ctx.lowlinks[v] {
				ctx.lowlinks[w]
			} else {
				ctx.lowlinks[v]
			}
		} else if ctx.on_stack[w] or { false } {
			ctx.lowlinks[v] = if ctx.indices[w] < ctx.lowlinks[v] {
				ctx.indices[w]
			} else {
				ctx.lowlinks[v]
			}
		}
	}

	if ctx.lowlinks[v] == ctx.indices[v] {
		mut scc := []string{}
		for {
			w := ctx.stack.pop()
			ctx.on_stack[w] = false
			scc << w
			if w == v {
				break
			}
		}
		ctx.sccs << scc
	}
}

fn normalize_path(path string) string {
	return path.replace('\\', '/')
}

fn relative_path(root string, path string) string {
	root_norm := normalize_path(root).trim_right('/')
	path_norm := normalize_path(path)
	if root_norm.len == 0 {
		return path_norm.trim_left('/')
	}
	if path_norm.starts_with(root_norm) {
		return path_norm[root_norm.len..].trim_left('/')
	}
	return path_norm
}

fn should_skip_rel(rel string, skip_dirs []string) bool {
	for skip in skip_dirs {
		skip_norm := normalize_path(skip).trim('/')
		if skip_norm.len == 0 {
			continue
		}
		if rel == skip_norm || rel.starts_with('${skip_norm}/') {
			return true
		}
	}
	return false
}

fn module_key_from_path(rel_path string) string {
	mut key := normalize_path(rel_path)
	if key.ends_with('.pyi') {
		key = key[..key.len - 4]
	} else if key.ends_with('.py') {
		key = key[..key.len - 3]
	}
	return key.replace('/', '.')
}
