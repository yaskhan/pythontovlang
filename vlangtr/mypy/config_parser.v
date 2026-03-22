// Work in progress by Antigravity. Started: 2026-03-22 03:05
// config_parser.v — Configuration file parsing for mypy
// Translated from mypy/config_parser.py
//
// ---------------------------------------------------------------------------

module mypy

import os

// VersionTypeError — version error type with fallback value
pub struct VersionTypeError {
pub:
	fallback (int, int)
	msg      string
}

// parse_version parses a Python version string of the form "x.y"
pub fn parse_version(v string) !PythonVersion {
	parts := v.split('.')
	if parts.len != 2 {
		return error("Invalid python version '${v}' (expected format: 'x.y')")
	}
	major := parts[0].int()
	minor := parts[1].int()
	if major == 2 && minor == 7 {
		// Error raised elsewhere
	} else if major == 3 {
		if minor < python3_version_min.minor {
			msg := 'Python 3.${minor} is not supported (must be ${python3_version_min.major}.${python3_version_min.minor} or higher)'
			return error(msg)
		}
	} else {
		return error("Python major version '${major}' out of range (must be 3)")
	}
	return PythonVersion{major, minor}
}

// try_split splits a string or list into a list of strings
pub fn try_split(v string, split_regex string) []string {
	mut items := v.split(split_regex)
	if items.len > 0 && items[items.len - 1] == '' {
		items.pop()
	}
	return items.map(it.trim_space())
}

// expand_path expands ~ and environment variables in a path
pub fn expand_path(path string) string {
    // V 0.5.x expansion
	return path.replace('~', os.home_dir())
}

// split_commas splits a string by commas
pub fn split_commas(value string) []string {
	mut items := value.split(',')
	if items.len > 0 && items[items.len - 1] == '' {
		items.pop()
	}
	return items.map(it.trim_space())
}

// str_or_array_as_list converts a string or array to a list of strings
pub fn str_or_array_as_list(v string) []string {
	trimmed := v.trim_space()
	if trimmed.len == 0 {
		return []string{}
	}
	return [trimmed]
}

// split_and_match_files_list processes a list of paths with glob support
pub fn split_and_match_files_list(paths []string) []string {
	mut expanded := []string{}
	for path in paths {
		p := expand_path(path.trim_space())
		// TODO: glob support
		expanded << p
	}
	return expanded
}

// split_and_match_files processes a path string
pub fn split_and_match_files(paths string) []string {
	return split_and_match_files_list(split_commas(paths))
}

// check_follow_imports checks the follow_imports value
pub fn check_follow_imports(choice string) string {
	choices := ['normal', 'silent', 'skip', 'error']
	if choice !in choices {
		panic("invalid choice '${choice}' (choose from ${choices.join(', ')})")
	}
	return choice
}

// check_junit_format checks the junit_format value
pub fn check_junit_format(choice string) string {
	choices := ['global', 'per_file']
	if choice !in choices {
		panic("invalid choice '${choice}' (choose from ${choices.join(', ')})")
	}
	return choice
}

// validate_package_allow_list validates the allowed packages list
pub fn validate_package_allow_list(allow_list []string) []string {
	for p in allow_list {
		if p.contains('*') {
			panic('Invalid allow list entry: ${p} (entries are already prefixes so must not contain *)')
		}
		if p.contains('\\') || p.contains('/') {
			panic('Invalid allow list entry: ${p} (entries must be packages like foo.bar not directories or files)')
		}
	}
	return allow_list
}

// ConfigValueTypes — configuration value types
pub type ConfigValueTypes = PythonVersion
	| bool
	| f64
	| int
	| map[string]string
	| string
	| []string

// ConfigParserFunc — value parsing function
pub type ConfigParserFunc = fn (string) ConfigValueTypes

// ini_config_types — mapping of option names to parsing functions for INI
pub const ini_config_types = {
	'python_version':            fn (s string) ConfigValueTypes {
		return parse_version(s) or { PythonVersion{3, 0} }
	}
	'custom_typing_module':      fn (s string) ConfigValueTypes {
		return s
	}
	'custom_typeshed_dir':       fn (s string) ConfigValueTypes {
		return expand_path(s)
	}
	'mypy_path':                 fn (s string) ConfigValueTypes {
		return s.split(',').map(expand_path(it.trim_space()))
	}
	'files':                     fn (s string) ConfigValueTypes {
		return split_and_match_files(s)
	}
	'quickstart_file':           fn (s string) ConfigValueTypes {
		return expand_path(s)
	}
	'junit_xml':                 fn (s string) ConfigValueTypes {
		return expand_path(s)
	}
	'junit_format':              fn (s string) ConfigValueTypes {
		return check_junit_format(s)
	}
	'follow_imports':            fn (s string) ConfigValueTypes {
		return check_follow_imports(s)
	}
	'no_site_packages':          fn (s string) ConfigValueTypes {
		return s == 'true'
	}
	'plugins':                   fn (s string) ConfigValueTypes {
		return split_commas(s).map(it.trim_space())
	}
	'always_true':               fn (s string) ConfigValueTypes {
		return split_commas(s).map(it.trim_space())
	}
	'always_false':              fn (s string) ConfigValueTypes {
		return split_commas(s).map(it.trim_space())
	}
	'untyped_calls_exclude':     fn (s string) ConfigValueTypes {
		return validate_package_allow_list(split_commas(s).map(it.trim_space()))
	}
	'enable_incomplete_feature': fn (s string) ConfigValueTypes {
		return split_commas(s).map(it.trim_space())
	}
	'disable_error_code':        fn (s string) ConfigValueTypes {
		return split_commas(s).map(it.trim_space())
	}
	'enable_error_code':         fn (s string) ConfigValueTypes {
		return split_commas(s).map(it.trim_space())
	}
	'package_root':              fn (s string) ConfigValueTypes {
		return split_commas(s).map(it.trim_space())
	}
	'cache_dir':                 fn (s string) ConfigValueTypes {
		return expand_path(s)
	}
	'python_executable':         fn (s string) ConfigValueTypes {
		return expand_path(s)
	}
	'strict':                    fn (s string) ConfigValueTypes {
		return s == 'true'
	}
	'exclude':                   fn (s string) ConfigValueTypes {
		return [s.trim_space()]
	}
	'packages':                  fn (s string) ConfigValueTypes {
		return try_split(s, ',')
	}
	'modules':                   fn (s string) ConfigValueTypes {
		return try_split(s, ',')
	}
}

// toml_config_types returns the mapping for TOML configuration
pub fn toml_config_types() map[string]ConfigParserFunc {
	mut m := map[string]ConfigParserFunc{}
	for k, v in ini_config_types {
		m[k] = v
	}
	m['mypy_path'] = fn (s string) ConfigValueTypes {
		return try_split(s, ',').map(expand_path(it))
	}
	m['files'] = fn (s string) ConfigValueTypes {
		return split_and_match_files_list(try_split(s, ','))
	}
	m['plugins'] = fn (s string) ConfigValueTypes {
		return try_split(s, ',')
	}
	m['always_true'] = fn (s string) ConfigValueTypes {
		return try_split(s, ',')
	}
	m['always_false'] = fn (s string) ConfigValueTypes {
		return try_split(s, ',')
	}
	return m
}

// is_toml checks if a file is TOML
pub fn is_toml(filename string) bool {
	return filename.to_lower().ends_with('.toml')
}

// split_directive splits a string by commas, ignoring quotes
pub fn split_directive(s string) ([]string, []string) {
	mut parts := []string{}
	mut cur := []string{}
	mut errors := []string{}
	mut i := 0
	for i < s.len {
		if s[i] == `,` {
			parts << cur.join('').trim_space()
			cur = []
		} else if s[i] == `"` {
			i++
			for i < s.len && s[i] != `"` {
				cur << s[i].str()
				i++
			}
			if i == s.len {
				errors << 'Unterminated quote in configuration comment'
				cur = []
			}
		} else {
			cur << s[i].str()
		}
		i++
	}
	if cur.len > 0 {
		parts << cur.join('').trim_space()
	}
	return parts, errors
}

// mypy_comments_to_config_map converts mypy comments to an options map
pub fn mypy_comments_to_config_map(line string) (map[string]string, []string) {
	mut options := map[string]string{}
	entries, errors := split_directive(line)
	for entry in entries {
		mut name := ''
		mut value := 'True'
		if entry.contains('=') {
			parts := entry.split('=')
			name = parts[0].trim_space()
			value = parts[1].trim_space()
		} else {
			name = entry.trim_space()
		}
		name = name.replace('-', '_')
		options[name] = value
	}
	return options, errors
}

// convert_to_boolean converts a value to boolean
pub fn convert_to_boolean(value string) bool {
	if value.to_lower() in ['true', '1', 'yes', 'on'] {
		return true
	}
	if value.to_lower() in ['false', '0', 'no', 'off'] {
		return false
	}
	panic('Not a boolean: ${value}')
}

// get_config_module_names returns module names for configuration
pub fn get_config_module_names(filename string, modules []string) string {
	if filename.len == 0 || modules.len == 0 {
		return ''
	}
	if !is_toml(filename) {
		return modules.map('[mypy-${it}]').join(', ')
	}
    mut sorted_modules := modules.clone()
    sorted_modules.sort()
	return "module = ['${sorted_modules.join("', '")}']"
}

// ConfigTOMLValueError — TOML configuration value error
pub struct ConfigTOMLValueError {
	msg string
}

// error returns an error
pub fn (e ConfigTOMLValueError) error() string {
	return e.msg
}
