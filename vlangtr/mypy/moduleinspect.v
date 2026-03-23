// moduleinspect.v — Basic introspection of modules
// Translated from mypy/moduleinspect.py to V 0.5.x
//
// Work in progress by Antigravity. Started: 2026-03-22 14:30

module mypy

import os

// ModuleProperties — module/package properties
pub struct ModuleProperties {
pub mut:
	name        string    // __name__ attribute
	file        ?string   // __file__ attribute
	path        ?[]string // __path__ attribute
	all         ?[]string // __all__ attribute
	is_c_module bool
	subpackages []string
}

// new_module_properties creates a new ModuleProperties
pub fn new_module_properties(name string,
	file ?string,
	path ?[]string,
	all ?[]string,
	is_c_module bool,
	subpackages ?[]string) ModuleProperties {
	return ModuleProperties{
		name:        name
		file:        file
		path:        path
		all:         all
		is_c_module: is_c_module
		subpackages: subpackages or { []string{} }
	}
}

// is_c_module checks if module is a C extension
pub fn is_c_module(module_file ?string) bool {
	if module_file == none {
		// May be namespace package
		return true
	}
	ext := os.file_ext(module_file or { '' })
	return ext in ['.so', '.pyd', '.dll']
}

// is_pyc_only checks if file is .pyc only
pub fn is_pyc_only(file ?string) bool {
	if file == none {
		return false
	}
	f := file or { '' }
	return f.ends_with('.pyc') && !os.exists(f[..f.len - 1])
}

// InspectError — introspection error
pub type InspectError = string

// get_package_properties gets package properties via runtime introspection
// Simplified version — without actual module imports
pub fn get_package_properties(package_id string) !ModuleProperties {
	// V has no direct analog of importlib.import_module
	// This function should be implemented via plugin or external calls

	// For stub return basic properties
	return ModuleProperties{
		name:        package_id
		file:        none
		path:        none
		all:         none
		is_c_module: false
		subpackages: []string{}
	}
}

// ModuleInspect — runtime module introspection
// Simplified version without using separate processes
@[heap]
pub struct ModuleInspect {
pub mut:
	counter int // Number of successful requests
}

// new_module_inspect creates a new ModuleInspect
pub fn new_module_inspect() !ModuleInspect {
	mut m := ModuleInspect{
		counter: 0
	}
	return m
}

// close releases resources
pub fn (mut m ModuleInspect) close() {
	// In simplified version do nothing
	m.counter = 0
}

// get_package_properties returns module/package properties
pub fn (mut m ModuleInspect) get_package_properties(package_id string) !ModuleProperties {
	// Simplified version — without process and queue
	prop := get_package_properties(package_id) or {
		return error('Cannot import ${package_id}')
	}
	m.counter++
	return prop
}

// enter for context manager
pub fn (mut m ModuleInspect) enter() &ModuleInspect {
	return &m
}

// exit for context manager
pub fn (mut m ModuleInspect) exit() {
	m.close()
}
