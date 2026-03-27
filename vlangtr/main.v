module main

import analyzer
import os
import translator

pub struct TranspilerConfig {
pub mut:
	warn_dynamic        bool
	no_helpers          bool
	helpers_only        bool
	include_all_symbols bool
	strict_exports      bool
	experimental        bool
	run                 bool
	analyze_deps        bool
	skip_dirs           []string
}

pub struct Transpiler {}

pub fn new_transpiler() Transpiler {
	return Transpiler{}
}

pub fn (t Transpiler) transpile(source_code string) string {
	_ = t
	mut tr := translator.new_translator()
	return tr.translate(source_code, '')
}

pub fn generate_all_helpers(output_path string) bool {
	helpers_code := translator.VCodeEmitter.emit_global_helpers(
		[]string{},
		[]string{},
		[]string{},
		'main',
	)
	os.write_file(output_path, helpers_code) or {
		println('Error writing global helpers to ${output_path}: ${err}')
		return false
	}
	println('Success: generated global helper library at ${output_path}')
	return true
}

fn is_python_file(path string) bool {
	return path.ends_with('.py') || path.ends_with('.pyi')
}

fn relative_path(root string, path string) string {
	mut root_norm := root.replace('\\', '/').trim_right('/')
	path_norm := path.replace('\\', '/')
	if root_norm.len == 0 {
		return path_norm.trim_left('/')
	}
	if path_norm.starts_with(root_norm) {
		return path_norm[root_norm.len..].trim_left('/')
	}
	return path_norm
}

fn should_skip_path(rel_path string, skip_dirs []string) bool {
	for skip in skip_dirs {
		skip_norm := skip.replace('\\', '/').trim('/')
		if skip_norm.len == 0 {
			continue
		}
		if rel_path == skip_norm || rel_path.starts_with('${skip_norm}/') {
			return true
		}
	}
	return false
}

pub fn transpile_file(source_file string, config TranspilerConfig, output_path string) bool {
	println('Transpiling ${source_file}...')

	source_code := os.read_file(source_file) or {
		println('Error reading ${source_file}: ${err}')
		return false
	}

	mut transpiler := new_transpiler()
	v_code := transpiler.transpile(source_code)

	final_output := if output_path.len > 0 {
		output_path
	} else if source_file.ends_with('.pyi') {
		source_file[..source_file.len - 4] + '.v'
	} else if source_file.ends_with('.py') {
		source_file[..source_file.len - 3] + '.v'
	} else {
		source_file + '.v'
	}

	os.write_file(final_output, v_code) or {
		println('Error writing ${final_output}: ${err}')
		return false
	}

	println('Success: ${final_output}')

	if config.run {
		if !run_v_code(final_output) {
			return false
		}
	}

	return true
}

pub fn process_directory(path string, config TranspilerConfig, recursive bool) {
	println('Processing directory: ${path} (recursive=${recursive})')
	mut files := []string{}
	root := os.abs_path(path)

	os.walk(root, fn [mut files, root, recursive, config] (item string) {
		if !os.is_file(item) || !is_python_file(item) {
			return
		}
		rel := relative_path(root, item)
		if should_skip_path(rel, config.skip_dirs) {
			return
		}
		if !recursive && rel.contains('/') {
			return
		}
		files << item
	})

	files.sort()
	mut processed := 0
	for file in files {
		output_path := if file.ends_with('.pyi') {
			file[..file.len - 4] + '.v'
		} else {
			file[..file.len - 3] + '.v'
		}
		if transpile_file(file, config, output_path) {
			processed++
		}
	}
	println('Processed ${processed}/${files.len} files.')
}

pub fn run_v_code(v_file string) bool {
	v_file_abs := os.abs_path(v_file)
	println('Compiling and running: ${os.file_name(v_file_abs)}')
	println('-'.repeat(50))

	result := os.execute('v run "${v_file_abs}"')

	println('-'.repeat(50))
	if result.exit_code != 0 {
		println('V compilation/execution failed with exit code: ${result.exit_code}')
		if result.output.len > 0 {
			println(result.output)
		}
		return false
	}
	return true
}

pub fn print_banner() {
	banner := '
=================================================================
                    Py2V Transpiler
              Python to V Language Compiler
=================================================================

Usage: py2v <path> [options]

Arguments:
  path                  Path to Python file (.py/.pyi) or directory

Options:
  -r, --recursive       Recursively process directories
  --analyze-deps        Analyze dependencies (for directories)
  --warn-dynamic        Warn when falling back to dynamic Any type
  --no-helpers          Do not generate a helper V file
  --helpers-only        Only generate the helper V file
  --include-all-symbols Include all symbols (not just __all__)
  --strict-exports      Warn about symbols missing from __all__
  --experimental        Enable experimental PEP features
  --run                 Compile and run V code after transpilation
  -h, --help            Show this help message

Examples:
  py2v script.py                    # Transpile a single file
  py2v script.py --run              # Transpile and run V code
  py2v src/ -r                      # Transpile all files in directory
  py2v project/ --helpers-only      # Generate only helpers file

Quick Start:
  py2v your_script.py --run
=================================================================
'
	println(banner)
}

fn parse_args() (string, TranspilerConfig, bool) {
	mut path := ''
	mut recursive := false
	mut config := TranspilerConfig{
		skip_dirs: []string{}
	}

	for i := 1; i < os.args.len; i++ {
		arg := os.args[i]
		match arg {
			'-r', '--recursive' {
				recursive = true
			}
			'--analyze-deps' {
				config.analyze_deps = true
			}
			'--warn-dynamic' {
				config.warn_dynamic = true
			}
			'--no-helpers' {
				config.no_helpers = true
			}
			'--helpers-only' {
				config.helpers_only = true
			}
			'--include-all-symbols' {
				config.include_all_symbols = true
			}
			'--strict-exports' {
				config.strict_exports = true
			}
			'--experimental' {
				config.experimental = true
			}
			'--run' {
				config.run = true
			}
			'--skip-dir' {
				if i + 1 < os.args.len {
					config.skip_dirs << os.args[i + 1]
					i++
				}
			}
			else {
				if arg.starts_with('--skip-dir=') {
					config.skip_dirs << arg.all_after('=')
				} else if arg.len > 0 && !arg.starts_with('-') && path.len == 0 {
					path = arg
				}
			}
		}
	}

	return path, config, recursive
}

fn print_dependency_report(path string, recursive bool, config TranspilerConfig) {
	mut dep_analyzer := analyzer.new_dependency_analyzer()
	println('Analyzing dependencies for: ${path}')
	graph := dep_analyzer.analyze_project(path, recursive, config.skip_dirs)
	mut files := graph.keys().clone()
	files.sort()
	for file in files {
		deps := graph[file]
		if deps.len == 0 {
			println('${file}: No imports')
		} else {
			println('${file}: ${deps.join(', ')}')
		}
	}
}

fn main() {
	if os.args.len == 1 {
		print_banner()
		return
	}

	path, mut config, recursive := parse_args()
	if path.len == 0 {
		print_banner()
		return
	}

	if !os.exists(path) {
		println("Error: Path '${path}' not found.")
		exit(1)
	}

	if config.analyze_deps {
		if !os.is_dir(path) {
			println('Error: --analyze-deps requires a directory.')
			exit(1)
		}
		print_dependency_report(path, recursive, config)
		return
	}

	if config.helpers_only {
		output_dir := if os.is_dir(path) {
			path
		} else {
			os.dir(path)
		}
		mut target_dir := output_dir
		if target_dir.len == 0 {
			target_dir = '.'
		}
		output_path := os.join_path(target_dir, 'py2v_helpers.v')
		if !generate_all_helpers(output_path) {
			exit(1)
		}
		return
	}

	if os.is_file(path) {
		if !is_python_file(path) {
			println('Error: Input file must be a Python script (.py or .pyi)')
			exit(1)
		}
		if !transpile_file(path, config, '') {
			exit(1)
		}
		return
	}

	if os.is_dir(path) {
		process_directory(path, config, recursive)
		return
	}

	println('Error: Invalid path type.')
	exit(1)
}
