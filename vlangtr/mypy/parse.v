// I, Codex, am working on this file. Started: 2026-03-22 15:11:48 +05:00
module mypy

import os

// Raw parse error payload used by load_from_raw.
pub struct RawParseError {
pub:
	line    int
	column  int
	message string
	blocker bool = true
	code    ?string
}

// FileRawData is a lightweight transport used by native parser cache.
pub struct FileRawData {
pub:
	defs                    []u8
	imports                 []u8
	ignored_lines           map[int][]string
	is_partial_stub_package bool
	uses_template_strings   bool
	raw_errors              []RawParseError
}

fn capitalize_first_word(message string) string {
	if message.len == 0 {
		return message
	}
	first := message[..1].to_upper()
	if message.len == 1 {
		return first
	}
	return first + message[1..]
}

fn empty_tree(fnam string, mod_name ?string) MypyFile {
	return MypyFile{
		defs:                    []Statement{}
		imports:                 []ImportBase{}
		names:                   SymbolTable{
			symbols: map[string]SymbolTableNode{}
		}
		path:                    fnam
		fullname:                mod_name or { '' }
		is_stub:                 fnam.ends_with('.pyi')
		is_partial_stub_package: false
		plugin_deps:             map[string]bool{}
	}
}

pub fn parse(source string, fnam string, mod_name ?string, mut errors Errors, options Options, raise_on_error bool, imports_only bool) MypyFile {
	mut src := source
	if options.native_parser && os.exists(fnam) {
		ignore_errors := options.ignore_errors || fnam in errors.ignored_files
		strip_function_bodies := ignore_errors && !options.preserve_asts
		_ = strip_function_bodies
		errors.set_file(fnam, mod_name)
		mut tree := empty_tree(fnam, mod_name)
		tree.is_stub = fnam.ends_with('.pyi')
		if raise_on_error && errors.is_errors() {
			return tree
		}
		return tree
	}

	if imports_only {
		return empty_tree(fnam, mod_name)
	}
	if transform := options.transform_source {
		src = transform(src)
	}
	_ = src
	mut tree := empty_tree(fnam, mod_name)
	if raise_on_error && errors.is_errors() {
		return tree
	}
	return tree
}

pub fn load_from_raw(fnam string, mod_name ?string, raw_data FileRawData, mut errors Errors, options Options) MypyFile {
	mut tree := empty_tree(fnam, mod_name)
	tree.ignored_lines = raw_data.ignored_lines.keys()
	tree.is_partial_stub_package = raw_data.is_partial_stub_package
	tree.is_stub = fnam.ends_with('.pyi')
	errors.set_file(fnam, mod_name)

	for e in raw_data.raw_errors {
		mut code := syntax
		if code_name := e.code {
			code = mypy_error_codes[code_name] or { syntax }
		}
		errors.report(e.line, e.column, capitalize_first_word(e.message), code.code,
			if e.blocker { 'error' } else { 'warning' }, e.blocker, false)
	}
	return tree
}
