// I, Antigravity, am working on this file. Started: 2026-03-22 03:05
// errors.v — Mypy error reporter
// Translated from mypy/errors.py
//
// ---------------------------------------------------------------------------

module mypy

import os

// ImportContext — import context for tracking import chain
pub struct ImportContext {
pub:
	path   string
	line   int
	module string
}

// ErrorWatcher — interface for listening to errors
pub interface ErrorWatcher {
	on_error(file string, line int, offset int, msg string, severity string, code ?string)
}

// ErrorIcon — error icon
pub enum ErrorIcon {
	none
	error
	warning
	note
}

@[heap]
pub struct ErrorInfo {
pub mut:
	import_ctx      []ImportContext
	file            string
	module          ?string
	function        ?string
	line            int
	column          int
	end_line        int
	end_column      int
	severity        string
	message         string
	code            ?string
	blocker         bool
	only_once       bool
	allow_not_found bool
}

// Errors — main class for collecting and outputting errors
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
	options            &Options
	read_source        ?fn (string) []string
	hide_error_codes   bool
	function_or_member []?string
}

pub fn Errors.new(options &Options, read_source ?fn (string) []string, hide_error_codes ?bool) Errors {
	return Errors{
		error_info_map:     map[string][]&ErrorInfo{}
		has_blockers:       map[string]bool{}
		flushed_files:      map[string]bool{}
		import_ctx:         []ImportContext{}
		ignore_prefix:      none
		file:               ''
		ignored_lines:      map[string]map[int][]string{}
		skipped_lines:      map[string]map[int]bool{}
		used_ignored_lines: map[string]map[int][]string{}
		ignored_files:      map[string]bool{}
		only_once_messages: map[string]bool{}
		target_module:      none
		scope:              none
		seen_import_error:  false
		watchers:           []&ErrorWatcher{}
		global_watcher:     false
		recorded:           map[string][]&ErrorInfo{}
		options:            options
		read_source:        read_source
		hide_error_codes:   hide_error_codes or { options.hide_error_codes }
		function_or_member: []?string{}
	}
}

// reset clears all errors
pub fn (mut e Errors) reset() {
	e.error_info_map.clear()
	e.has_blockers.clear()
	e.flushed_files.clear()
	e.import_ctx.clear()
	e.recorded.clear()
	e.seen_import_error = false
}

// set_file sets the current file for errors
pub fn (mut e Errors) set_file(file string, module_name ?string) {
	e.file = file
	e.target_module = module_name
}

// report reports an error
pub fn (mut e Errors) report(line int, column int, message string, code ?string, severity string, blocker bool, only_once bool) {
	if only_once && message in e.only_once_messages {
		return
	}
	if only_once {
		e.only_once_messages[message] = true
	}

	info := &ErrorInfo{
		import_ctx:      e.import_ctx.clone()
		file:            e.file
		module:          e.target_module
		function:        if e.function_or_member.len > 0 {
			e.function_or_member.last()
		} else {
			none
		}
		line:            line
		column:          column
		severity:        severity
		message:         message
		code:            code
		blocker:         blocker
		only_once:       only_once
		allow_not_found: false
	}

	if blocker {
		e.has_blockers[e.file] = true
	}

	if e.file !in e.error_info_map {
		e.error_info_map[e.file] = []&ErrorInfo{}
	}
	e.error_info_map[e.file] << info

	for watcher in e.watchers {
		watcher.on_error(e.file, line, column, message, severity, code)
	}
}
