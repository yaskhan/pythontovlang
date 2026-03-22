// main.v — Mypy type checker command line tool
// Translated from mypy/main.py

module mypy

import os
import time

pub struct ProcessOptionsResult {
pub:
	sources []BuildSource
	options Options
}

// main — main entry point for type checking
pub fn main(args []string, mut stdout os.File, mut stderr os.File) {
	t1 := time.now()

	mut fscache := FileSystemCache{}
	res_opt := process_options(args, mut stdout, mut stderr, mut fscache)
	sources := res_opt.sources
	options := res_opt.options

	mut formatter := util.new_fancy_formatter(stdout, stderr, options.hide_error_codes, options.output.len > 0)

	if options.allow_redefinition_new && !options.local_partial_types {
		fail("error: --local-partial-types must be enabled if using --allow-redefinition-new",
			mut stderr, options)
	}

	if options.allow_redefinition_new && options.allow_redefinition_old {
		fail("--allow-redefinition-old and --allow-redefinition-new should not be used together",
			mut stderr, options)
	}

	if options.install_types && sources.len == 0 {
		// install_types(mut formatter, options, false)
		return
	}

	res, messages, blockers := run_build(sources, options, fscache, t1.unix_f(), mut stdout, mut stderr)

	code := 0
	n_errors, n_notes, n_files := util.count_stats(messages)
	if messages.len > 0 && n_notes < messages.len {
		if blockers {
			code = 2
		} else {
			code = 1
		}
	}

	if options.error_summary {
		if n_errors > 0 {
			summary := formatter.format_error(n_errors, n_files, sources.len, blockers,
				options.color_output)
			stdout.write_string(summary + "\n") or { panic(err) }
		} else if messages.len == 0 || n_notes == messages.len {
			stdout.write_string(formatter.format_success(sources.len, options.color_output) + "\n") or { panic(err) }
		}
		stdout.flush()
	}

	if code != 0 {
		exit(code)
	}
}

// run_build runs the build
pub fn run_build(sources []BuildSource, options Options, fscache FileSystemCache, t0 f64, mut stdout os.File, mut stderr os.File) (?&BuildResult, []string, bool) {
	mut messages := []string{}
	mut messages_by_file := map[string][]string{}
	mut serious := false
	mut blockers := false
	mut res := ?&BuildResult(none)

	res = build.build(sources, options, none, flush_errors, fscache, mut stdout, mut stderr) or {
		blockers = true
		none
	}

	maybe_write_junit_xml(time.now().unix_f() - t0, serious, messages, messages_by_file, options)
	return res, messages, blockers
}

// flush_errors handles errors
fn flush_errors(filename ?string, new_messages []string, is_serious bool, mut stdout os.File, mut stderr os.File, options Options, mut messages []string, mut messages_by_file map[string][]string) {
	messages << new_messages
	if new_messages.len > 0 {
		key := filename or { "none" }
		messages_by_file[key] << new_messages
	}
	if options.non_interactive {
		return
	}
	mut f := if is_serious { stderr } else { stdout }
	for msg in new_messages {
		f.write_string(msg + "\n") or { panic(err) }
	}
	f.flush()
}

// show_messages outputs messages
fn show_messages(messages []string, mut f os.File, options Options) {
	for msg in messages {
		f.write_string(msg + "\n") or { panic(err) }
	}
	f.flush()
}

// fail terminates with an error
fn fail(msg string, mut stderr os.File, options Options) {
	stderr.write_string("${msg}\n") or { panic(err) }
	mut msgs_map := map[string][]string{}
	msgs_map["none"] = [msg]
	maybe_write_junit_xml(0.0, true, [msg], msgs_map, options)
	exit(2)
}

// maybe_write_junit_xml writes JUnit XML if configured
fn maybe_write_junit_xml(td f64, serious bool, all_messages []string, messages_by_file map[string][]string, options Options) {
	if options.junit_xml.len > 0 {
		py_version := "${options.python_version[0]}_${options.python_version[1]}"
		if options.junit_format == "global" {
			mut global_map := map[string][]string{}
			global_map["none"] = all_messages
			util.write_junit_xml(td, serious, global_map, options.junit_xml, py_version, options.platform)
		} else {
			util.write_junit_xml(td, serious, messages_by_file, options.junit_xml, py_version,
				options.platform)
		}
	}
}

// process_options processes command line arguments
fn process_options(args []string, mut stdout os.File, mut stderr os.File, mut fscache FileSystemCache) ProcessOptionsResult {
	options := Options{}
	mut sources := []BuildSource{}
	for arg in args {
		if arg.ends_with(".py") || arg.ends_with(".pyi") {
			sources << BuildSource{
				path:   arg
				module: "__main__"
			}
		}
	}
	return ProcessOptionsResult{sources: sources, options: options}
}
