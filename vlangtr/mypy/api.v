// Work in progress by Codex. Started: 2026-03-22 21:31:00 +05:00
module mypy

import strings

pub struct ApiBuffers {
pub mut:
	stdout strings.Builder
	stderr strings.Builder
}

pub type MainWrapperFn = fn (mut ApiBuffers) !

fn run_main_wrapper(main_wrapper MainWrapperFn) (string, string, int) {
	mut buffers := ApiBuffers{
		stdout: strings.new_builder(0)
		stderr: strings.new_builder(0)
	}
	mut exit_status := 0

	main_wrapper(mut buffers) or {
		exit_status = 2
		buffers.stderr.write_string(err.msg())
		buffers.stderr.write_string('\n')
	}

	return buffers.stdout.str(), buffers.stderr.str(), exit_status
}

pub fn run(args []string) (string, string, int) {
	_ = args
	return run_main_wrapper(fn [args] (mut buffers ApiBuffers) ! {
		_ = args
		buffers.stderr.write_string('mypy.api.run: mypy/main.py is not translated yet')
		return error('SystemExit: 2')
	})
}
