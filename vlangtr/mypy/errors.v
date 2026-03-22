// Я Antigravity работаю над этим файлом. Начало: 2026-03-21 23:30
module mypy

import os

// ============================================================================
// Constants and Metadata
// ============================================================================

pub const base_rtd_url = 'https://mypy.rtfd.io/en/stable/_refs.html#code'

// Keep track of the original error code when the error code of a message is changed
pub const original_error_codes = {
	'literal-req':   'misc'
	'type-abstract': 'misc'
}

// Error codes that are not links to the documentation
pub const hide_link_codes = ['misc', 'note', 'error']

// ErrorTuple for formatted error output
pub struct ErrorTuple {
pub:
	file       ?string
	line       int
	column     int
	end_line   int
	end_column int
	severity   string
	message    string
	code       ?string
}

// ============================================================================
// ErrorInfo - Representation of a single error message
// ============================================================================

@[heap]
pub struct ErrorInfo {
pub mut:
	import_ctx     []ImportContext
	local_type     ?string
	local_function ?string
	line           int
	column         int
	end_line       ?int
	end_column     ?int

	severity       string
	message        string
	code           ?ErrorCode

	blocker        bool
	only_once      bool

	// These two are used by the daemon:
	// The fully-qualified id of the source module for this error
	mod ?string

	// Fine-grained incremental target where this was reported
	target ?string

	// Lines where `type: ignores` will have effect on this error
	origin_span []int

	// For errors on the same line you can use this to customize their sorting
	// (lower value means show first)
	priority int

	// If true, don't show this message in output, but still record the error
	hidden bool

	// For notes, specifies (optionally) the error this note is attached to
	parent_error ?&ErrorInfo
}

// ImportContext is a (path, line number) struct
pub struct ImportContext {
pub:
	path string
	line int
}

// ErrorInfo.new is replaced by direct struct initialization in report()


// ============================================================================
// ErrorWatcher - Context manager for tracking new errors
// ============================================================================

@[heap]
pub struct ErrorWatcher {


pub:
	errors               &Errors
pub mut:
	has_new_errors       bool
	filter_errors        bool
	filter_deprecated    bool
	filter_revealed_type bool
	filtered             ?[]&ErrorInfo
}


pub fn ErrorWatcher.new(errors &Errors,
	filter_errors bool,
	save_filtered_errors bool,
	filter_deprecated bool,
	filter_revealed_type bool) ErrorWatcher {
	return ErrorWatcher{
		errors:               errors
		has_new_errors:       false
		filter_errors:        filter_errors
		filter_deprecated:    filter_deprecated
		filter_revealed_type: filter_revealed_type
		filtered:             if save_filtered_errors { []&ErrorInfo{} } else { none }
	}
}

pub fn (mut w ErrorWatcher) enter() {
	w.errors.watchers << w
}

pub fn (mut w ErrorWatcher) exit() {
	last := w.errors.watchers.pop()
}

pub fn (mut w ErrorWatcher) on_error(file string, info &ErrorInfo) bool {
	if code := info.code {
		if code.code == 'deprecated' {
			if !w.filter_deprecated {
				return false
			}
		}
	}


	w.has_new_errors = true
	should_filter := w.filter_errors
	if should_filter {
		if mut f := w.filtered {
			f << info
		}
	}

	return should_filter
}

// ============================================================================
// Errors - Container for compile errors
// ============================================================================

@[heap]
pub struct Errors {


pub mut:
	error_info_map     map[string][]&ErrorInfo
	has_blockers       map[string]bool
	flushed_files      map[string]bool
	import_ctx         []ImportContext
	ignore_prefix      ?string
	file               string
	ignored_lines      map[string]map[int][]string
	skipped_lines      map[string]map[int]bool
	used_ignored_lines map[string]map[int][]string
	ignored_files      map[string]bool
	only_once_messages map[string]bool
	target_module      ?string
	scope              ?&Scope
	seen_import_error  bool
	watchers           []&ErrorWatcher
	global_watcher     bool
	recorded           map[string][]&ErrorInfo
pub:
	options            &Options
pub mut:
	read_source        ?fn (string) []string
	hide_error_codes   bool
	function_or_member []?string
}


pub fn Errors.new(options &Options, read_source ?fn (string) []string, hide_error_codes ?bool) Errors {
	mut e := Errors{
		options:          options
		read_source:      read_source
		hide_error_codes: hide_error_codes or { options.hide_error_codes }
	}
	e.initialize()
	return e
}

pub fn (mut e Errors) initialize() {
	e.error_info_map = map[string][]&ErrorInfo{}
	e.flushed_files = map[string]bool{}
	e.import_ctx = []
	e.function_or_member = []
	e.function_or_member << ?string(none)
	e.ignored_lines = map[string]map[int][]string{}
	e.skipped_lines = map[string]map[int]bool{}
	e.used_ignored_lines = map[string]map[int][]string{}
	e.ignored_files = map[string]bool{}
	e.only_once_messages = map[string]bool{}
	e.has_blockers = map[string]bool{}
	e.scope = none
	e.target_module = none
	e.seen_import_error = false
	e.watchers = []
	e.global_watcher = false
	e.recorded = map[string][]&ErrorInfo{}
}

pub fn (mut e Errors) reset() {
	e.initialize()
}

pub fn (mut e Errors) set_ignore_prefix(prefix string) {
	mut p := os.norm_path(prefix)
	if os.file_name(p) != '' {
		p += os.path_separator
	}
	e.ignore_prefix = p
}

pub fn (e &Errors) simplify_path(file string) string {
	if e.options.show_absolute_path {
		return os.abs_path(file)
	} else {
		f := os.norm_path(file)
		return remove_path_prefix(f, e.ignore_prefix)
	}
}fn remove_path_prefix(path string, prefix ?string) string {
	if p := prefix {
		if path.starts_with(p) {
			return path.replace(p, '')
		}
	}
	return path
}

pub fn (mut e Errors) set_file(file string, mod ?string, options &Options, scope ?&Scope) {
	e.file = file
	e.target_module = mod
	e.scope = scope
	e.options = options
}

pub fn (mut e Errors) set_file_ignored_lines(file string, ignored_lines map[int][]string, ignore_all bool) {
	e.ignored_lines[file] = ignored_lines.clone()
	if ignore_all {
		e.ignored_files[file] = true
	}
}

pub fn (mut e Errors) set_skipped_lines(file string, skipped_lines map[int]bool) {
	e.skipped_lines[file] = skipped_lines.clone()
}

pub fn (e &Errors) current_target() ?string {
	if s := e.scope {
		return s.current_target()
	}
	return e.target_module
}

pub fn (e &Errors) current_module() ?string {
	return e.target_module
}

pub fn (e &Errors) import_context() []ImportContext {
	return e.import_ctx.clone()
}

pub fn (mut e Errors) set_import_context(ctx []ImportContext) {
	e.import_ctx = ctx.clone()
}

pub fn (mut e Errors) report(line int,
	column ?int,
	message string,
	code ?&ErrorCode,
	blocker bool,
	severity string,
	only_once bool,
	origin_span ?[]int,
	offset int,
	end_line ?int,
	end_column ?int,
	parent_error ?&ErrorInfo) &ErrorInfo {
	mut type_name := ?string(none)
	mut function_name := ?string(none)

	if s := e.scope {
		type_name = s.current_type_name()
		if s.ignored > 0 {
			type_name = none
		}
		function_name = s.current_function_name()
	}

	actual_end_line := if el := end_line {
		if el < line { line } else { el }
	} else {
		line
	}

	actual_column := if c := column { c } else { -1 }
	mut actual_end_column := if ec := end_column {
		ec
	} else {
		if actual_column == -1 { -1 } else { actual_column + 1 }
	}

	if line == actual_end_line && actual_end_column <= actual_column {
		actual_end_column = actual_column + 1
	}

	mut actual_message := message
	if offset > 0 {
		actual_message = ' '.repeat(offset) + message
	}

	mut actual_code := code
	if actual_code == none && parent_error != none {
		actual_code = parent_error.code
	}

	info := &ErrorInfo{
		import_ctx:     e.import_context()
		local_type:     type_name
		local_function: function_name
		line:           line
		column:         actual_column
		end_line:       actual_end_line
		end_column:     actual_end_column
		severity:       severity
		message:        actual_message
		code:           actual_code
		blocker:        blocker
		only_once:      only_once
		mod:            e.current_module()
		target:         e.current_target()
		origin_span:    origin_span or { []int{len: 1, init: line} }
		priority:       0
		parent_error:   parent_error
	}


	if e.global_watcher {
		e.recorded[e.file] << info
	}
	e.add_error_info(info, none)
	return info
}

fn (mut e Errors) filter_error(file string, info &ErrorInfo) bool {
	for i := e.watchers.len - 1; i >= 0; i-- {
		if e.watchers[i].on_error(file, info) {
			return true
		}
	}
	return false
}

pub fn (mut e Errors) add_error_info(info &ErrorInfo, file ?string) {
	actual_file := file or { e.file }

	if e.filter_error(actual_file, info) {
		return
	}

	if !info.blocker {
		if actual_file in e.ignored_lines {
			for scope_line in info.origin_span {
				if e.is_ignored_error(scope_line, info, e.ignored_lines[actual_file]) {
					err_code_str := if c := info.code { c.code } else { 'misc' }
					if !e.is_error_code_enabled(err_code_str) {
						return
					}
					if actual_file !in e.used_ignored_lines {
						e.used_ignored_lines[actual_file] = map[int][]string{}
					}
					if scope_line !in e.used_ignored_lines[actual_file] {
						e.used_ignored_lines[actual_file][scope_line] = []
					}
					e.used_ignored_lines[actual_file][scope_line] << err_code_str
					return
				}
			}
		}
		if actual_file in e.ignored_files {
			return
		}
	}

	if info.only_once {
		if info.message in e.only_once_messages {
			return
		}
		e.only_once_messages[info.message] = true
	}

	if e.seen_import_error && e.has_many_errors() {
		if code := info.code {
			if code.code !in ['import', 'import-untyped', 'import-not-found'] {
				mut hidden_info := *info
				hidden_info.hidden = true
				e.report_hidden_errors(actual_file, &hidden_info)
			}
		}
	}


	if actual_file !in e.error_info_map {
		e.error_info_map[actual_file] = []
	}
	e.error_info_map[actual_file] << info
	if info.blocker {
		e.has_blockers[actual_file] = true
	}
	if code := info.code {
		if code.code in ['import', 'import-untyped', 'import-not-found'] {
			e.seen_import_error = true
		}
	}


	if actual_file in e.ignored_lines {
		ignored_codes := e.ignored_lines[actual_file][info.line] or { []string{} }
		if ignored_codes.len > 0 && info.code != none {
			err_code_str := info.code.code
			if err_code_str !in ignored_codes {
				mut msg := 'Error code "${err_code_str}" not covered by "type: ignore" comment'
				if err_code_str in original_error_codes {
					old_code := original_error_codes[err_code_str]
					if old_code in ignored_codes {
						msg = 'Error code changed to ${err_code_str}; "type: ignore" comment may be out of date'
					}
				}
				e.note_for_info(actual_file, info, msg, none, false, 0)
			}
		}
	}

	if e.options.show_error_code_links && !e.options.hide_error_codes {
		if code := info.code {
			if code.code !in hide_link_codes && code.code in mypy_error_codes {
				link_msg := 'See ${base_rtd_url}-${code.code} for more info'
				if link_msg !in e.only_once_messages {
					e.only_once_messages[link_msg] = true
					e.note_for_info(actual_file, info, link_msg, info.code, true, 20)
				}
			}
		}
	}

}

fn (e &Errors) has_many_errors() bool {
	if e.options.many_errors_threshold < 0 {
		return false
	}
	mut total := 0
	for errs in e.error_info_map.values() {
		total += errs.len
	}
	return total >= e.options.many_errors_threshold
}

fn (mut e Errors) report_hidden_errors(file string, info &ErrorInfo) {
	msg := '(Skipping most remaining errors due to unresolved imports or missing stubs; fix these first)'
	if msg in e.only_once_messages {
		return
	}
	e.only_once_messages[msg] = true
	e.note_for_info(file, info, msg, none, true, 0)
}

pub fn (mut e Errors) note_for_info(file string, info &ErrorInfo, message string, code ?&ErrorCode, only_once bool, priority int) {
	note := &ErrorInfo{
		import_ctx:     info.import_ctx
		local_type:     info.local_type
		local_function: info.local_function
		line:           info.line
		column:         info.column
		end_line:       info.end_line
		end_column:     info.end_column
		severity:       'note'
		message:        message
		code:           code
		blocker:        false
		only_once:      only_once
		mod:            info.mod
		target:         info.target
		origin_span:    info.origin_span
		priority:       priority
		parent_error:   none
	}
	e.filter_error(file, note)
	if file !in e.error_info_map {
		e.error_info_map[file] = []
	}
	e.error_info_map[file] << note
}

fn (e &Errors) is_ignored_error(line int, info &ErrorInfo, ignores map[int][]string) bool {
	if info.blocker {
		return false
	}
	if code := info.code {
		if !e.is_error_code_enabled(code.code) {
			return true
		}
	}
	if line !in ignores {
		return false
	}
	line_ignores := ignores[line]
	if line_ignores.len == 0 {
		return true
	}
	if code := info.code {
		if e.is_error_code_enabled(code.code) {
			if code.code in line_ignores {
				return true
			}
			if sub := code.sub_code_of {
				if sub.code in line_ignores {
					return true
				}
			}
		}
	}
	return false

}

fn (e &Errors) is_error_code_enabled(error_code string) bool {
	if e.options.disabled_error_codes.len > 0 || e.options.enabled_error_codes.len > 0 {
		if error_code in e.options.disabled_error_codes {
			return false
		} else if error_code in e.options.enabled_error_codes {
			return true
		}
	}
	for code, _ in e.options.disabled_error_codes {
		if error_code.starts_with(code + '-') {
			return false
		}
	}
	return true
}

pub fn (mut e Errors) clear_errors_in_targets(path string, targets map[string]bool) {
	if path in e.error_info_map {
		mut new_errors := []&ErrorInfo{}
		mut has_blocker := false
		for info in e.error_info_map[path] {
			if target := info.target {
				if target !in targets {
					new_errors << info
					has_blocker = has_blocker || info.blocker
				} else if info.only_once {
					e.only_once_messages.delete(info.message)
				}
			} else {
				new_errors << info
				has_blocker = has_blocker || info.blocker
			}
		}

		e.error_info_map[path] = new_errors
		if !has_blocker && path in e.has_blockers {
			e.has_blockers.delete(path)
		}
	}
}

pub fn (mut e Errors) generate_unused_ignore_errors(file string, is_typeshed bool) {
	if is_typeshed || file in e.ignored_files {
		return
	}
	ignored_lines := e.ignored_lines[file] or {
		map[int][]string{}
	}.clone()
	used_ignored_lines := e.used_ignored_lines[file] or {
		map[int][]string{}
	}.clone()

	for line, ignored_codes in ignored_lines {
		mut skipped := e.skipped_lines[file].clone()
		if skipped.len == 0 {
			skipped = map[int]bool{}
		}


		if line in skipped {
			continue
		}
		if 'unused-ignore' in ignored_codes {
			continue
		}
		used_codes := used_ignored_lines[line] or { []string{} }
		mut unused_ignored_codes := []string{}
		for c in ignored_codes {
			if c !in used_codes {
				unused_ignored_codes << c
			}
		}
		if (ignored_codes.len == 0 && used_codes.len > 0)
			|| (ignored_codes.len > 0 && unused_ignored_codes.len == 0) {
			continue
		}
		mut unused_codes_message := ''
		if ignored_codes.len > 1 && unused_ignored_codes.len > 0 {
			unused_codes_message = '[${unused_ignored_codes.join(', ')}]'
		}
		msg := 'Unused "type: ignore${unused_codes_message}" comment'
		e.report_simple_error(file, line, msg, none)
	}
}

pub fn (mut e Errors) report_simple_error(file string, line int, message string, code ?&ErrorCode) {
	info := &ErrorInfo{
		import_ctx:     e.import_context()
		local_type:     none
		local_function: none
		line:           line
		column:         -1
		end_line:       line
		end_column:     -1
		severity:       'error'
		message:        message
		code:           code
		blocker:        false
		only_once:      false
		mod:            e.current_module()
		target:         e.current_target()
		origin_span:    []int{len: 1, init: line}
		priority:       0
		parent_error:   none
	}
	e.filter_error(file, info)
	if file !in e.error_info_map {
		e.error_info_map[file] = []
	}
	e.error_info_map[file] << info
}

pub fn (e &Errors) num_messages() int {
	mut total := 0
	for errs in e.error_info_map.values() {
		total += errs.len
	}
	return total
}

pub fn (e &Errors) is_errors() bool {
	return e.error_info_map.len > 0
}

pub fn (e &Errors) is_blockers() bool {
	return e.has_blockers.len > 0
}

pub fn (e &Errors) blocker_module() ?string {
	for path in e.has_blockers.keys() {
		for err in e.error_info_map[path] {
			if err.blocker {
				return err.mod
			}
		}
	}
	return none
}

pub fn (e &Errors) file_messages(path string) []ErrorTuple {
	if path !in e.error_info_map {
		return []
	}
	mut error_info := e.error_info_map[path]
	error_info = error_info.filter(!it.hidden)
	error_info = e.remove_duplicates(e.sort_messages(error_info))
	return e.render_messages(path, error_info)
}

pub fn (mut e Errors) format_messages(path string, error_tuples []ErrorTuple, formatter ?&Errors) []string {
	e.flushed_files[path] = true
	mut source_lines := ?[]string(none)

	if e.options.pretty && e.read_source != none {
		mapped_path := e.find_shadow_file_mapping(path)
		source_lines = e.read_source(mapped_path or { path })
	}
	return e.format_messages_default(error_tuples, source_lines)
}

pub fn (e &Errors) find_shadow_file_mapping(path string) ?string {
	if s := e.options.shadow_file {
		for i in s {
			if i[0] == path {
				return i[1]
			}
		}
	}
	return none
}

pub fn (mut e Errors) new_messages() []string {
	mut msgs := []string{}
	for path in e.error_info_map.keys() {
		if path !in e.flushed_files {
			error_tuples := e.file_messages(path)
			msgs << e.format_messages(path, error_tuples, none)
		}
	}
	return msgs
}

pub fn (e &Errors) targets() map[string]bool {
	mut result := map[string]bool{}
	for errs in e.error_info_map.values() {
		for info in errs {
			if t := info.target {
				result[t] = true
			}
		}
	}
	return result
}

pub fn (e &Errors) render_messages(file string, errors []&ErrorInfo) []ErrorTuple {
	simplified_file := e.simplify_path(file)
	mut result := []ErrorTuple{}
	mut prev_import_context := []ImportContext{}
	mut prev_function := ?string(none)
	mut prev_type := ?string(none)


	for err in errors {
		if e.options.show_error_context && err.import_ctx != prev_import_context {
			last := err.import_ctx.len - 1
			for i := last; i >= 0; i-- {
				item := err.import_ctx[i]
				mut fmt := '${item.path}:${item.line}: note: In module imported here'
				if i < last {
					fmt = '${item.path}:${item.line}: note: ... from here'
				}
				fmt += if i > 0 { ',' } else { ':' }
				simplified_path := remove_path_prefix(item.path, e.ignore_prefix)
				result << ErrorTuple{
					file:       none
					line:       -1
					column:     -1
					end_line:   -1
					end_column: -1
					severity:   'note'
					message:    fmt.replace(item.path, simplified_path)
					code:       none
				}
			}
		}

		if e.options.show_error_context
			&& (err.local_function != prev_function || err.local_type != prev_type) {
			mut note := ''
			if err.local_function == none {
				note = if err.local_type == none {
					'At top level:'
				} else {
					'In class "${err.local_type}":'
				}
			} else {
				note = if err.local_type == none {
					'In function "${err.local_function}":'
				} else {
					'In member "${err.local_function}" of class "${err.local_type}":'
				}
			}
			result << ErrorTuple{
				file:       simplified_file
				line:       -1
				column:     -1
				end_line:   -1
				end_column: -1
				severity:   'note'
				message:    note
				code:       none
			}
		}

		code_str := if c := err.code { c.code } else { none }
		result << ErrorTuple{
			file:       simplified_file
			line:       err.line
			column:     err.column
			end_line:   err.end_line
			end_column: err.end_column
			severity:   err.severity
			message:    err.message
			code:       code_str
		}

		prev_import_context = err.import_ctx.clone()
		prev_function = err.local_function
		prev_type = err.local_type

	}
	return result
}

fn (e &Errors) sort_messages(errors []&ErrorInfo) []&ErrorInfo {
	mut sorted := errors.clone()
	sorted.sort_with_compare(fn (a &&ErrorInfo, b &&ErrorInfo) int {
		if a.line != b.line {
			return if a.line < b.line { -1 } else { 1 }
		}
		if a.column != b.column {
			return if a.column < b.column { -1 } else { 1 }
		}
		if a.priority != b.priority {
			return if a.priority < b.priority { -1 } else { 1 }
		}
		return 0
	})
	return sorted
}

fn (e &Errors) remove_duplicates(errors []&ErrorInfo) []&ErrorInfo {
	mut filtered := []&ErrorInfo{}
	mut seen := map[string]bool{}
	for err in errors {
		key := '${err.line}|${err.severity}|${err.message}'
		if key !in seen {
			filtered << err
			seen[key] = true
		}
	}
	return filtered
}

pub fn (e &Errors) format_messages_default(error_tuples []ErrorTuple, source_lines ?[]string) []string {
	mut a := []string{}
	for t in error_tuples {
		mut s := ''
		if f := t.file {
			s = if e.options.show_column_numbers && t.line >= 0 && t.column >= 0 {
				'${f}:${t.line + 1}:${t.column + 1}: '
			} else if t.line >= 0 {
				'${f}:${t.line + 1}: '
			} else {
				'${f}: '
			}
		}
		s += '${t.severity}: ${t.message}'
		if c := t.code {
			if !e.options.hide_error_codes {
				s += '  [${c}]'
			}
		}
		a << s
	}
	return a
}

// ============================================================================
// Iteration Error Watcher
// ============================================================================

pub struct IterationErrorWatcher {
	ErrorWatcher
pub mut:
	iteration_dependent_errors &IterationDependentErrors
}

pub struct IterationDependentErrors {
pub mut:
	errors             []map[string]bool
	uselessness_errors []map[string]bool
	unreachable_lines  []map[int]bool
}


pub fn IterationErrorWatcher.new(errors &Errors,
	iteration_dependent_errors &IterationDependentErrors,
	filter_errors bool,
	save_filtered_errors bool,
	filter_deprecated bool) IterationErrorWatcher {
	mut w := IterationErrorWatcher{
		ErrorWatcher:               ErrorWatcher.new(errors, filter_errors, save_filtered_errors,
			filter_deprecated, false)
		iteration_dependent_errors: iteration_dependent_errors
	}
	return w
}

pub fn (mut w IterationErrorWatcher) on_error(file string, info &ErrorInfo) bool {
	iter_errors := w.iteration_dependent_errors

	if code := info.code {
		if code.code in ['unreachable', 'redundant-expr', 'redundant-cast'] {
			key := '${code.code}|${info.message}|${info.line}|${info.column}|${info.end_line}|${info.end_column}'
			mut ud := w.iteration_dependent_errors.uselessness_errors.last()
			ud[key] = true
			if code.code == 'unreachable' {
				mut ul := w.iteration_dependent_errors.unreachable_lines.last()
				for i in info.line .. info.end_line + 1 {
					ul[i] = true
				}
			}
			return true
		}
	}


	return w.ErrorWatcher.on_error(file, info)
}

// ============================================================================
// CompileError - Exception raised when there is a compile error
// ============================================================================

pub struct CompileError {
pub:
	messages            []string
	use_stdout          bool
	module_with_blocker ?string
	msg                 string
}

pub fn CompileError.new(messages []string, use_stdout bool, module_with_blocker ?string) CompileError {
	return CompileError{
		messages:            messages
		use_stdout:          use_stdout
		module_with_blocker: module_with_blocker
		msg:                 messages.join('\n')
	}
}

// ============================================================================
// MypyError - Simple error representation
// ============================================================================

pub struct MypyError {
pub mut:
	file_path  string
	line       int
	column     int
	end_line   int
	end_column int
	message    string
	errorcode  ?string
	severity   string
	hints      []string
}

pub fn MypyError.new(file_path string,
	line int,
	column int,
	end_line int,
	end_column int,
	message string,
	errorcode ?string,
	severity string) MypyError {
	return MypyError{
		file_path:  file_path
		line:       line
		column:     column
		end_line:   end_line
		end_column: end_column
		message:    message
		errorcode:  errorcode
		severity:   severity
		hints:      []
	}
}

pub fn create_errors(error_tuples []ErrorTuple) []MypyError {
	mut errors := []MypyError{}
	for t in error_tuples {
		if file := t.file {
			errors << MypyError.new(file, t.line, t.column, t.end_line, t.end_column,
				t.message, t.code, t.severity)
		}
	}
	return errors
}



const show_note_codes = ['note']
const mypy_version = '1.11.0'
