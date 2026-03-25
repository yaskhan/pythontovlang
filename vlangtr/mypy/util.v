module mypy

import os
import regex
import term

// Work in progress by Antigravity. Started: 2026-03-22 03:05

// Utility functions for mypy transpiler

pub const special_dunders = ['__init__', '__new__', '__call__', '__init_subclass__',
	'__class_getitem__']

pub fn is_dunder(name string, exclude_special bool) bool {
	if exclude_special && name in special_dunders {
		return false
	}
	return name.starts_with('__') && name.ends_with('__')
}

pub fn is_sunder(name string) bool {
	return !is_dunder(name, false) && name.starts_with('_') && name.ends_with('_') && name != '_'
}

pub fn split_module_names(mod_name string) []string {
	mut out := [mod_name]
	mut cur := mod_name
	for cur.contains('.') {
		idx := cur.last_index('.') or { break }
		cur = cur[..idx]
		out << cur
	}
	return out
}

pub fn module_prefix(modules []string, target string) ?string {
	result := split_target(modules, target) or { return none }
	return result.name
}

pub struct TargetSplit {
pub:
	name      string
	remaining string
}

pub fn split_target(modules []string, target string) ?TargetSplit {
	mut cur_target := target
	mut remaining := []string{}
	for {
		if cur_target in modules {
			return TargetSplit{
				name:      cur_target
				remaining: remaining.join('.')
			}
		}
		idx := cur_target.last_index('.') or { return none }
		comp := cur_target[idx + 1..]
		cur_target = cur_target[..idx]
		remaining.insert(0, comp)
	}
	return none
}

/*
pub fn short_type(obj any) string {
	// In V, 'any' stores type information.
	// This is a simplified version for transpiled code.
	t := typeof(obj).name
	parts := t.split('.')
	return parts.last()
}
*/

pub struct MypyIdMapper {
pub mut:
	id_map  map[string]int
	next_id int
}

pub fn (mut m MypyIdMapper) id(o voidptr) int {
	key := u64(o).str()
	if key in m.id_map {
		return m.id_map[key]
	}
	val := m.next_id
	m.id_map[key] = val
	m.next_id++
	return val
}

pub fn get_prefix(fullname string) string {
	idx := fullname.last_index('.') or { return fullname }
	return fullname[..idx]
}

pub fn hard_exit(status int) {
	os.flush()
	exit(status)
}

pub fn unmangle(name string) string {
	return name.trim_right("'")
}

pub fn get_unique_redefinition_name(name string, existing []string) string {
	r_name := name + '-redefinition'
	if r_name !in existing {
		return r_name
	}
	mut i := 2
	for {
		candidate := r_name + i.str()
		if candidate !in existing {
			return candidate
		}
		i++
	}
	return r_name // should not reach
}

pub fn count_stats(messages []string) (int, int, int) {
	mut errors := 0
	mut notes := 0
	mut error_files := map[string]bool{}
	for msg in messages {
		if msg.contains(': error:') {
			errors++
			parts := msg.split(':')
			if parts.len > 0 {
				error_files[parts[0]] = true
			}
		} else if msg.contains(': note:') {
			notes++
		}
	}
	return errors, notes, error_files.len
}

pub fn split_words(msg string) []string {
	mut next_word := ''
	mut res := []string{}
	mut allow_break := true
	for c in msg {
		if c == ` ` && allow_break {
			if next_word != '' {
				res << next_word
				next_word = ''
			}
			continue
		}
		if c == `"` {
			allow_break = !allow_break
		}
		next_word += c.str()
	}
	if next_word != '' {
		res << next_word
	}
	return res
}

pub fn get_terminal_width() int {
	force := os.getenv('MYPY_FORCE_TERMINAL_WIDTH')
	if force != '' {
		return force.int()
	}
	// V doesn't have a direct shutil.get_terminal_size() equivalent in std yet that is easy,
	// but we can default to 80 or use some os-specific calls if needed.
	// For now, let's assume 80 as default.
	return 80
}

pub fn soft_wrap(msg string, max_len int, first_offset int, num_indent int) string {
	words := split_words(msg)
	if words.len == 0 {
		return ''
	}
	mut next_line := words[0]
	mut remaining_words := words[1..].clone()
	mut lines := []string{}
	for remaining_words.len > 0 {
		next_word := remaining_words[0]
		remaining_words = remaining_words[1..].clone()
		max_line_len := if lines.len > 0 { max_len - num_indent } else { max_len - first_offset }
		if next_line.len + next_word.len + 1 <= max_line_len {
			next_line += ' ' + next_word
		} else {
			lines << next_line
			next_line = next_word
		}
	}
	lines << next_line
	padding := '\n' + ' '.repeat(num_indent)
	return lines.join(padding)
}

pub fn plural_s(count int) string {
	if count != 1 {
		return 's'
	}
	return ''
}

pub fn find_python_encoding(text []u8) (string, int) {
	// ENCODING_RE: ([ \t\v]*#.*(\r\n?|\n))??[ \t\v]*#.*coding[:=][ \t]*([-\w.]+)
	// This is bit complex for direct regex in V if we want exact same behavior,
	// but we can use a simpler approach or the regex module.
	mut re := regex.regex_opt(r'([ \t\v]*#.*(\r\n?|\n))??[ \t\v]*#.*coding[:=][ \t]*([-\w.]+)') or {
		return 'utf8', -1
	}
	res := re.find_all_str(text.bytestr())
	if res.len > 0 {
		// This is a simplification. The original extraction of group 3 is needed.
		// Let's assume we can find it.
		mut encoding := 'utf8'
		mut line := 1
		// ... extraction logic ...
		return encoding, line
	}
	return 'utf8', -1
}

pub const encoding_re_str = r'([ \t\v]*#.*(\r\n?|\n))??[ \t\v]*#.*coding[:=][ \t]*([-\w.]+)'

pub fn decode_python_encoding(source []u8) string {
	mut src := source.clone()
	if src.len >= 3 && src[0] == 0xef && src[1] == 0xbb && src[2] == 0xbf {
		src = src[3..].clone()
		return src.bytestr()
	}
	_, _ = find_python_encoding(src)
	// V's bytestr() assumes UTF-8. For other encodings we might need a library.
	// Mypy mostly deals with utf8, latin1.
	return src.bytestr()
}

pub fn trim_source_line(line string, max_len int, col int, min_width int) (string, int) {
	mut m_len := max_len
	if m_len < 2 * min_width + 1 {
		m_len = 2 * min_width + 1
	}

	if line.len <= m_len {
		return line, 0
	}

	if col + min_width < m_len {
		return line[..m_len] + '...', 0
	}

	if col < line.len - min_width - 1 {
		offset := col - m_len + min_width + 1
		return '...' + line[offset..col + min_width + 1] + '...', offset - 3
	}

	return '...' + line[line.len - m_len..], line.len - m_len - 3
}

pub struct MypyComment {
pub:
	line int
	text string
}

pub fn get_mypy_comments(source string) []MypyComment {
	prefix := '# mypy: '
	if !source.contains(prefix) {
		return []
	}
	lines := source.split('\n')
	mut results := []MypyComment{}
	for i, line in lines {
		if line.starts_with(prefix) {
			results << MypyComment{
				line: i + 1
				text: line[prefix.len..]
			}
		}
	}
	return results
}

pub fn is_typeshed_file(typeshed_dir ?string, file string) bool {
	tdir := typeshed_dir or { '/mypy/typeshed' } // Default placeholder
	abs_file := os.abs_path(file)
	return abs_file.starts_with(tdir)
}

pub fn is_stdlib_file(typeshed_dir ?string, file string) bool {
	if !file.contains('stdlib') {
		return false
	}
	tdir := typeshed_dir or { '/mypy/typeshed' }
	stdlib_dir := os.join_path(tdir, 'stdlib')
	abs_file := os.abs_path(file)
	return abs_file.starts_with(stdlib_dir)
}

pub fn is_stub_package_file(file string) bool {
	if !file.ends_with('.pyi') {
		return false
	}
	abs_file := os.abs_path(file)
	// split into components
	parts := abs_file.split(os.path_separator)
	for p in parts {
		if p.ends_with('-stubs') {
			return true
		}
	}
	return false
}

pub fn unnamed_function(name ?string) bool {
	if n := name {
		return n == '_'
	}
	return false
}

pub fn correct_relative_import(cur_mod_id string, relative int, target string, is_cur_package_init_file bool) (string, bool) {
	if relative == 0 {
		return target, true
	}
	parts := cur_mod_id.split('.')
	mut rel := relative
	if is_cur_package_init_file {
		rel--
	}
	ok := parts.len >= rel
	mut result_mod_id := cur_mod_id
	if rel != 0 && ok {
		result_mod_id = parts[..parts.len - rel].join('.')
	}
	suffix := if target != '' { '.' + target } else { '' }
	return result_mod_id + suffix, ok
}

pub fn should_force_color() bool {
	env_var := os.getenv('MYPY_FORCE_COLOR')
	if env_var == '' {
		env_var2 := os.getenv('FORCE_COLOR')
		if env_var2 == '' {
			return false
		}
		return env_var2 != '0'
	}
	return env_var != '0'
}

pub fn read_py_file(path string, read_fn fn (string) ![]u8) ?[]string {
	source := read_fn(path) or { return none }
	decoded := decode_python_encoding(source)
	return decoded.split('\n')
}

pub fn bytes_to_human_readable_repr(b []u8) string {
	// Simplified repr for bytes
	return b.bytestr()
}

pub fn quote_docstring(docstr string) string {
	// Basic implementation
	return '"""' + docstr + '"""'
}

// Utility struct for fancy formatting

pub fn new_fancy_formatter(stdout os.File, stderr os.File, hide_error_codes bool, hide_success bool) FancyFormatter {
	return FancyFormatter{
		hide_error_codes: hide_error_codes
		hide_success:     hide_success
		dummy_term:       false
	}
}

pub struct FancyFormatter {
pub mut:
	hide_error_codes bool
	hide_success     bool
	dummy_term       bool
}

pub fn (mut f FancyFormatter) style(text string, color string, bold bool, underline bool, dim bool) string {
	if f.dummy_term {
		return text
	}
	mut out := text
	match color {
		'red' { out = term.red(out) }
		'green' { out = term.green(out) }
		'blue' { out = term.blue(out) }
		'yellow' { out = term.yellow(out) }
		else {}
	}
	if bold {
		out = term.bold(out)
	}
	if dim {
		out = term.dim(out)
	}
	if underline {
		out = '\033[4m' + out + '\033[24m' // Using ANSI for underline
	}
	return out
}

pub fn (f &FancyFormatter) is_marker_line(line string) bool {
	s_line := line.trim_left(' ')
	if !line.starts_with('    ') {
		return false
	}
	if !s_line.starts_with('^') {
		return false
	}
	for c in s_line {
		if c != `^` && c != `~` && c != ` ` && c != `\n` && c != `\r` {
			return false
		}
	}
	return true
}

pub fn (mut f FancyFormatter) colorize(error string) string {
	if f.is_marker_line(error) {
		return f.style(error, 'red', false, false, false)
	}
	if error.contains(': error:') {
		parts := error.split_any('error:')
		if parts.len >= 2 {
			loc := parts[0]
			msg := parts[1..].join('error:')
			return loc + f.style('error:', 'red', true, false, false) + msg
		}
	}
	if error.contains(': note:') {
		parts := error.split_any('note:')
		if parts.len >= 2 {
			loc := parts[0]
			msg := parts[1..].join('note:')
			return loc + f.style('note:', 'blue', false, false, false) + msg
		}
	}
	return error
}

pub fn (mut f FancyFormatter) initialize_colors() {
	if should_force_color() {
		f.dummy_term = false
		return
	}
	// V's os.isatty check
	if os.is_atty(1) == 0 || os.is_atty(2) == 0 {
		f.dummy_term = true
	}
}

pub fn (f FancyFormatter) format_error(n_errors int, n_files int, total_files int, blockers bool, color bool) string {
	mut res := ''
	if blockers {
		res = 'Found ${n_errors} error${plural_s(n_errors)} in ${n_files} file${plural_s(n_files)} (errors were blocked)'
	} else {
		res = 'Found ${n_errors} error${plural_s(n_errors)} in ${n_files} file${plural_s(n_files)} (checked ${total_files} source file${plural_s(total_files)})'
	}
	return res
}

pub fn (f FancyFormatter) format_success(total_files int, color bool) string {
	return 'Success: no issues found in ${total_files} source file${plural_s(total_files)}'
}

pub fn plural_s_sized(s []any) string {
	if s.len != 1 {
		return 's'
	}
	return ''
}

// Added for compatibility with mypy types
pub fn is_typeshed_file_alt(typeshed_dir ?string, file string) bool {
	return is_typeshed_file(typeshed_dir, file)
}
