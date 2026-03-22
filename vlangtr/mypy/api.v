// Я Codex работаю над этим файлом. Начало: 2026-03-22 14:45:16 +05:00
module mypy

import strings

pub struct ApiBuffers {
pub mut:
	stdout strings.Builder
	stderr strings.Builder
}

pub type MainWrapperFn = fn (mut ApiBuffers) !

// _run mirrors Python api._run: capture stdout/stderr and return exit status.
pub fn _run(main_wrapper MainWrapperFn) (string, string, int) {
	mut buffers := ApiBuffers{
		stdout: strings.new_builder(0)
		stderr: strings.new_builder(0)
	}
	mut exit_status := 0

	main_wrapper(mut buffers) or {
		exit_status = 2
		buffers.stderr.write_string(err.msg()) or {}
		buffers.stderr.write_string('\n') or {}
	}

	return buffers.stdout.str(), buffers.stderr.str(), exit_status
}

// run is kept intentionally lightweight until mypy/main.py is translated.
pub fn run(args []string) (string, string, int) {
	_ = args
	return _run(fn [args] (mut buffers ApiBuffers) ! {
		_ = args
		buffers.stderr.write_string('mypy.api.run: mypy/main.py is not translated yet') or {}
		return error('SystemExit: 2')
	})
}
