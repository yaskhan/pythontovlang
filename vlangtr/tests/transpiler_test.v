module tests

import os
import translator

fn test_transpilation() {
	mut t := translator.new_translator()
	
	// Cases are in vlangtr/tests/cases
	// Note: @FILE is the current file path
	current_dir := os.dir(@FILE)
	cases_dir := os.join_path(current_dir, 'cases')
	
	if !os.exists(cases_dir) {
		println('Cases directory not found: ${cases_dir}')
		assert false
		return
	}
	
	files := os.ls(cases_dir) or { 
		println('Could not list cases: ${err}')
		assert false
		return 
	}
	
	mut passed := 0
	mut total := 0
	
	for file in files {
		if !file.ends_with('.py') {
			continue
		}
		
		total++
		
		py_path := os.join_path(cases_dir, file)
		expected_path := py_path.replace('.py', '.expected.v')
		
		if !os.exists(expected_path) {
			println('SKIP: ${file} (no .expected.v)')
			continue
		}
		
		source := os.read_file(py_path) or { continue }
		expected := os.read_file(expected_path) or { continue }
		
		// Use the shared translator
		// (Assuming it's safe to reuse it, which is the point of shared initialization)
		actual := t.translate(source)
		
		if actual.trim_space() != expected.trim_space() {
			println('FAIL: ${file}')
			println('Expected:\n---\n${expected}\n---')
			println('Actual:\n---\n${actual}\n---')
			assert false 
		} else {
			println('PASS: ${file}')
			passed++
		}
	}
	
	println('Tests summary: ${passed}/${total} cases passed.')
}
