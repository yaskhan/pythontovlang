// Work in progress by Cline. Started: 2026-03-22 15:23
// modulefinder.v — Low-level infrastructure to find modules
// Translated from mypy/modulefinder.py
//
// ---------------------------------------------------------------------------

module mypy

import os

// Python file extensions
pub const python_extensions = ['.pyi', '.py']

// SearchPaths — paths for module search
pub struct SearchPaths {
pub:
	python_path   []string
	mypy_path     []string
	package_path  []string
	typeshed_path []string
}

// new_search_paths creates a new SearchPaths
pub fn new_search_paths(python_path []string, mypy_path []string, package_path []string, typeshed_path []string) SearchPaths {
	return SearchPaths{
		python_path:   python_path.map(os.abs_path(it))
		mypy_path:     mypy_path.map(os.abs_path(it))
		package_path:  package_path.map(os.abs_path(it))
		typeshed_path: typeshed_path.map(os.abs_path(it))
	}
}

// ModuleNotFoundReason — reason why module was not found
// error_message_templates returns error message templates
pub fn (r ModuleNotFoundReason) error_message_templates(daemon bool) (string, []string) {
	doc_link := 'See https://mypy.readthedocs.io/en/stable/running_mypy.html#missing-imports'
	match r {
		.not_found {
			return 'Cannot find implementation or library stub for module named "{module}"', [
				doc_link,
			]
		}
		.wrong_working_directory {
			return 'Cannot find implementation or library stub for module named "{module}"', [
				'You may be running mypy in a subpackage, mypy should be run on the package root',
			]
		}
		.found_without_type_hints {
			return 'Skipping analyzing "{module}": module is installed, but missing library stubs or py.typed marker', [
				doc_link,
			]
		}
		.approved_stubs_not_installed {
			mut notes := ['Hint: "python3 -m pip install {stub_dist}"']
			if !daemon {
				notes << '(or run "mypy --install-types" to install all missing stub packages)'
			}
			notes << doc_link
			return 'Library stubs not installed for "{module}"', notes
		}
	}
}

// ModuleSearchResult — module search result
// MypyBuildSource — source file for build
pub struct MypyBuildSource {
pub:
	path     ?string
	module   string
	text     ?string
	base_dir ?string
	followed bool
}

// new_build_source creates a new MypyBuildSource
pub fn new_build_source(path ?string, mod_name ?string, text ?string, base_dir ?string, followed bool) MypyBuildSource {
	return MypyBuildSource{
		path:     path
		module:   mod_name or { '__main__' }
		text:     text
		base_dir: base_dir
		followed: followed
	}
}

// str returns string representation of MypyBuildSource
pub fn (bs MypyBuildSource) str() string {
	return 'MypyBuildSource(path=${bs.path}, module=${bs.module}, has_text=${bs.text != none}, base_dir=${bs.base_dir}, followed=${bs.followed})'
}

// BuildSourceSet — set of source files for quick membership check
pub struct BuildSourceSet {
pub mut:
	source_text_present bool
	source_modules      map[string]string
	source_paths        map[string]bool
}

// new_build_source_set creates a new BuildSourceSet
pub fn new_build_source_set(sources []MypyBuildSource) BuildSourceSet {
	mut bss := BuildSourceSet{
		source_text_present: false
		source_modules:      map[string]string{}
		source_paths:        map[string]bool{}
	}
	for source in sources {
		if source.text != none {
			bss.source_text_present = true
		}
		if path := source.path {
			bss.source_paths[path] = true
		}
		bss.source_modules[source.module] = source.path or { '' }
	}
	return bss
}

// MypyFindModuleCache — cache for module search
pub struct MypyFindModuleCache {
pub mut:
	search_paths       SearchPaths
	source_set         ?BuildSourceSet
	initial_components map[string]map[string][]string
	results            map[string]ModuleSearchResult
	ns_ancestors       map[string]string
	options            ?Options
	stdlib_py_versions map[string]StdlibPyVersionRange
}

pub struct StdlibPyVersionRange {
pub:
	min_major int
	min_minor int
	max_major ?int
	max_minor ?int
}

// new_find_module_cache creates a new MypyFindModuleCache
pub fn new_find_module_cache(search_paths SearchPaths, options ?Options) MypyFindModuleCache {
	return MypyFindModuleCache{
		search_paths:       search_paths
		source_set:         none
		initial_components: map[string]map[string][]string{}
		results:            map[string]ModuleSearchResult{}
		ns_ancestors:       map[string]string{}
		options:            options
		stdlib_py_versions: map[string]StdlibPyVersionRange{}
	}
}

// clear clears the cache
pub fn (mut fmc MypyFindModuleCache) clear() {
	fmc.results.clear()
	fmc.initial_components.clear()
	fmc.ns_ancestors.clear()
}

// find_module finds a module and returns the path or failure reason
pub fn (mut fmc MypyFindModuleCache) find_module(id string) ModuleSearchResult {
	if id in fmc.results {
		return fmc.results[id]
	}

	result := fmc.find_module_internal(id)
	fmc.results[id] = result
	return result
}

// find_module_internal — internal implementation of module search
fn (mut fmc MypyFindModuleCache) find_module_internal(id string) ModuleSearchResult {
	components := id.split('.')
	dir_chain := components[..components.len - 1].join(os.path_separator)

	// Search in package_path
	for pkg_dir in fmc.search_paths.package_path {
		stub_name := components[0] + '-stubs'
		stub_dir := os.join_path(pkg_dir, stub_name)
		if os.is_dir(stub_dir) {
			path := os.join_path(pkg_dir, stub_name, dir_chain, components.last() + '.pyi')
			if os.is_file(path) {
				return path
			}
		}

		// Normal search
		mut path := os.join_path(pkg_dir, dir_chain, components.last() + '.pyi')
		if os.is_file(path) {
			return path
		}
		path = os.join_path(pkg_dir, dir_chain, components.last() + '.py')
		if os.is_file(path) {
			return path
		}
	}

	// Search in mypy_path and python_path
	mut search_dirs := []string{}
	search_dirs << fmc.search_paths.mypy_path
	search_dirs << fmc.search_paths.python_path
	for dir in search_dirs {
		mut path := os.join_path(dir, dir_chain, components.last() + '.pyi')
		if os.is_file(path) {
			return path
		}
		path = os.join_path(dir, dir_chain, components.last() + '.py')
		if os.is_file(path) {
			return path
		}
	}

	// Search in typeshed_path
	for dir in fmc.search_paths.typeshed_path {
		path := os.join_path(dir, dir_chain, components.last() + '.pyi')
		if os.is_file(path) {
			return path
		}
	}

	return ModuleNotFoundReason.not_found
}

// find_lib_path_dirs finds directories in lib_path containing the module
pub fn (mut fmc MypyFindModuleCache) find_lib_path_dirs(id string, lib_path []string) []string {
	components := id.split('.')
	dir_chain := components[..components.len - 1].join(os.path_separator)

	mut dirs := []string{}
	for pathitem in fmc.get_toplevel_possibilities(lib_path, components[0]) {
		if dir_chain.len > 0 {
			dir := os.join_path(pathitem, dir_chain)
			if os.is_dir(dir) {
				dirs << dir
			}
		} else {
			if os.is_dir(pathitem) {
				dirs << pathitem
			}
		}
	}
	return dirs
}

// get_toplevel_possibilities finds possible directories for top-level module
pub fn (mut fmc MypyFindModuleCache) get_toplevel_possibilities(lib_path []string, id string) []string {
	lib_path_key := lib_path.join(':')
	if lib_path_key in fmc.initial_components {
		return fmc.initial_components[lib_path_key][id] or { []string{} }
	}

	mut components := map[string][]string{}
	for dir in lib_path {
		contents := os.ls(dir) or { []string{} }
		for name in contents {
			stem := name.all_before_last('.')
			if stem !in components {
				components[stem] = []string{}
			}
			components[stem] << dir
		}
	}

	fmc.initial_components[lib_path_key] = components.clone()
	return components[id] or { []string{} }
}

// is_init_file checks if the file is __init__.py[i]
pub fn is_init_file(path string) bool {
	base := os.base(path)
	return base == '__init__.py' || base == '__init__.pyi'
}

// verify_module verifies that all packages containing id have __init__ file
pub fn verify_module(id string, path string) bool {
	mut check_path := if is_init_file(path) { os.dir(path) } else { path }
	for _ in 0 .. id.count('.') {
		check_path = os.dir(check_path)
		has_init := python_extensions.any(os.is_file(os.join_path(check_path, '__init__' + it)))
		if !has_init {
			return false
		}
	}
	return true
}

// compute_search_paths computes module search paths
pub fn compute_search_paths(sources []MypyBuildSource, options Options, data_dir string, alt_lib_path ?string) SearchPaths {
	mut lib_path := []string{}

	// Add standard library
	lib_path << os.join_path(data_dir, 'typeshed', 'stdlib')

	// Python path
	mut python_path := []string{}
	if alt_lib_path == none {
		for source in sources {
			if base_dir := source.base_dir {
				if base_dir !in python_path {
					python_path << base_dir
				}
			}
		}
		python_path << os.getwd()
	}

	// MYPYPATH
	mut mypypath := []string{}
	if alt_lib := alt_lib_path {
		mypypath << alt_lib
	}
	mypypath << options.mypy_path

	// Package path (site-packages)
	package_path := []string{} // TODO: get from pyinfo

	return SearchPaths{
		python_path:   python_path.reverse()
		mypy_path:     mypypath
		package_path:  package_path
		typeshed_path: lib_path
	}
}
