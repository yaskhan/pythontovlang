// Я Cline работаю над этим файлом. Начало: 2026-03-22 15:32
// main.v — Mypy type checker command line tool
// Переведён из mypy/main.py

module mypy

import os
import time

// main — главная точка входа в проверку типов
pub fn main(args []string, mut stdout File, mut stderr File) {
	util.check_python_version('mypy')
	t0 := time.now()
	os.set_recursion_limit(defaults.recursion_limit)

	mut fscache := FileSystemCache{}
	sources, options := process_options(args, stdout, stderr, fscache)

	formatter := util.new_fancy_formatter(stdout, stderr, options.hide_error_codes, options.output.len > 0)

	if options.allow_redefinition_new && !options.local_partial_types {
		fail('error: --local-partial-types must be enabled if using --allow-redefinition-new',
			stderr, options)
	}

	if options.allow_redefinition_new && options.allow_redefinition_old {
		fail('--allow-redefinition-old and --allow-redefinition-new should not be used together',
			stderr, options)
	}

	if options.install_types && sources.len == 0 {
		install_types(formatter, options, false)
		return
	}

	res, messages, blockers := run_build(sources, options, fscache, t0, stdout, stderr)

	code := 0
	n_errors, n_notes, n_files := util.count_stats(messages)
	if messages.len > 0 && n_notes < messages.len {
		code = if blockers { 2 } else { 1 }
	}

	if options.error_summary {
		if n_errors > 0 {
			summary := formatter.format_error(n_errors, n_files, sources.len, blockers,
				options.color_output)
			stdout.write_string(summary + '\n')
		} else if messages.len == 0 || n_notes == messages.len {
			stdout.write_string(formatter.format_success(sources.len, options.color_output) + '\n')
		}
		stdout.flush()
	}

	if options.install_types && !options.non_interactive {
		result := install_types(formatter, options, true)
		if result {
			print('note: Run mypy again for up-to-date results with installed types')
			code = 2
		}
	}

	if options.fast_exit {
		util.hard_exit(code)
	} else if code != 0 {
		exit(code)
	}
}

// run_build запускает сборку
pub fn run_build(sources []BuildSource, options Options, fscache FileSystemCache, t0 f64, mut stdout File, mut stderr File) (?BuildResult, []string, bool) {
	formatter := util.new_fancy_formatter(stdout, stderr, options.hide_error_codes, options.output.len > 0)

	mut messages := []string{}
	mut messages_by_file := map[string][]string{}

	mut serious := false
	mut blockers := false
	mut res := ?BuildResult(none)

	res = build.build(sources, options, none, flush_errors, fscache, stdout, stderr) or {
		blockers = true
		none
	}

	maybe_write_junit_xml(time.now() - t0, serious, messages, messages_by_file, options)
	return res, messages, blockers
}

// flush_errors обрабатывает ошибки
fn flush_errors(filename ?string, new_messages []string, is_serious bool, mut stdout File, mut stderr File, options Options, mut messages []string, mut messages_by_file map[string][]string) {
	messages << new_messages
	if new_messages.len > 0 {
		key := filename or { 'none' }
		messages_by_file[key] << new_messages
	}
	if options.non_interactive {
		return
	}
	f := if is_serious { stderr } else { stdout }
	for msg in new_messages {
		f.write_string(msg + '\n')
	}
	f.flush()
}

// show_messages выводит сообщения
fn show_messages(messages []string, mut f File, options Options) {
	for msg in messages {
		f.write_string(msg + '\n')
	}
	f.flush()
}

// fail завершает работу с ошибкой
fn fail(msg string, mut stderr File, options Options) {
	stderr.write_string('${msg}\n')
	maybe_write_junit_xml(0.0, true, [msg], {
		'none': [msg]
	}, options)
	exit(2)
}

// maybe_write_junit_xml записывает JUnit XML если настроено
fn maybe_write_junit_xml(td f64, serious bool, all_messages []string, messages_by_file map[string][]string, options Options) {
	if options.junit_xml.len > 0 {
		py_version := '${options.python_version[0]}_${options.python_version[1]}'
		if options.junit_format == 'global' {
			util.write_junit_xml(td, serious, {
				'none': all_messages
			}, options.junit_xml, py_version, options.platform)
		} else {
			util.write_junit_xml(td, serious, messages_by_file, options.junit_xml, py_version,
				options.platform)
		}
	}
}

// install_types устанавливает пакеты с типами
fn install_types(formatter util.FancyFormatter, options Options, non_interactive bool) bool {
	packages := read_types_packages_to_install(options.cache_dir)
	if packages.len == 0 {
		return false
	}
	print('Installing missing stub packages:')
	assert options.python_executable.len > 0
	cmd := [options.python_executable, '-m', 'pip', 'install'] + packages
	print(formatter.style(cmd.join(' '), 'none', true))
	print()
	if !non_interactive {
		print('Install? [yN] ')
		x := os.input('')
		if x.trim_space().len == 0 || !x.to_lower().starts_with('y') {
			print(formatter.style('mypy: Skipping installation', 'red', true))
			exit(2)
		}
		print()
	}
	os.execute(cmd.join(' '))
	return true
}

// read_types_packages_to_install читает список пакетов для установки
fn read_types_packages_to_install(cache_dir string) []string {
	if !os.is_dir(cache_dir) {
		return []
	}
	fnam := build.missing_stubs_file(cache_dir)
	if !os.is_file(fnam) {
		return []
	}
	lines := os.read_lines(fnam) or { return [] }
	return lines.map(it.trim_space())
}

// process_options обрабатывает аргументы командной строки
fn process_options(args []string, mut stdout File, mut stderr File, mut fscache FileSystemCache) ([]BuildSource, Options) {
	// TODO: полная реализация парсинга аргументов
	options := Options{}

	mut sources := []BuildSource{}
	if args.len > 0 {
		for arg in args {
			if arg.ends_with('.py') || arg.ends_with('.pyi') {
				sources << BuildSource{
					path:   arg
					module: '__main__'
				}
			}
		}
	}

	return sources, options
}

// Вспомогательные типы
pub struct File {
}

pub fn (mut f File) write_string(s string) {
	// TODO: реализация
}

pub fn (mut f File) flush() {
	// TODO: реализация
}

pub struct BuildResult {
}

pub struct FileSystemCache {
}
