module tests

import os
import translator

struct ExpectedGroup {
	mut:
	alternatives []string
}

struct ExpectedRules {
	mut:
	required []ExpectedGroup
	forbidden []string
}

struct MarkerHit {
	kind string
	pos  int
}

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
	
	mut files := collect_py_files(cases_dir)
	files.sort()
	
	mut passed := 0
	mut failed := 0
	mut skipped := 0
	mut total := 0
	mut failures := []string{}
	
	for py_path in files {
		total++
		
		expected_path := py_path.replace('.py', '.expected.v')
		
		if !os.exists(expected_path) {
			println('SKIP: ${py_path} (no .expected.v)')
			skipped++
			continue
		}
		
		source := os.read_file(py_path) or { continue }
		expected := os.read_file(expected_path) or { continue }
		
		// Use the shared translator
		// (Assuming it's safe to reuse it, which is the point of shared initialization)
		actual := t.translate(source, py_path)
		
		is_ok := check_expected_output(actual, expected, expected_path) or {
			failures << format_failure(py_path, expected_path, expected, actual, err.msg())
			failed++
			continue
		}
		if !is_ok {
			failures << format_failure(py_path, expected_path, expected, actual, 'expected output mismatch')
			failed++
		} else {
			println('PASS: ${py_path}')
			passed++
		}
	}
	
	checked := passed + failed
	success_rate := if checked > 0 { f64(passed) * 100.0 / f64(checked) } else { 0.0 }
	println('Tests summary:')
	println('  total: ${total}')
	println('  checked: ${checked}')
	println('  passed: ${passed}')
	println('  failed: ${failed}')
	println('  skipped: ${skipped}')
	println('  success_rate: ${success_rate:.1f}%')
	if failures.len > 0 {
		println('')
		println('Failures (${failures.len}):')
		for failure in failures {
			println(failure)
			println('')
		}
		assert false
	}
}

fn collect_py_files(root string) []string {
	mut files := []string{}
	entries := os.ls(root) or { return files }
	for entry in entries {
		path := os.join_path(root, entry)
		if os.is_dir(path) {
			files << collect_py_files(path)
		} else if path.ends_with('.py') {
			files << path
		}
	}
	return files
}

fn test_directive_expectations() {
	actual := 'let a = 1\nassert False\nb := py_any(a)\n'
	expected := '@@in# "b := py_any(a)"\n@@notin# "missing snippet"\n@@in# "assert False" @@or# "assert false"\n'

	assert check_expected_output(actual, expected, 'directive_expectations.expected.v') or { panic(err) }
}

fn format_failure(py_path string, expected_path string, expected string, actual string, reason string) string {
	return 'FAIL: ${py_path}\nExpected file: ${expected_path}\nReason: ${reason}\nExpected:\n---\n${expected}\n---\nActual:\n---\n${actual}\n---'
}

fn check_expected_output(actual string, expected string, expected_path string) !bool {
	if expected.contains('@@in#') || expected.contains('@@notin#') || expected.contains('@@or#') {
		return check_expected_directives(actual, expected, expected_path)
	}
	return actual.trim_space() == expected.trim_space()
}

fn check_expected_directives(actual string, expected string, expected_path string) !bool {
	rules := parse_expected_rules(expected, expected_path)!
	norm_actual := normalize_text(actual)

	for group in rules.required {
		mut matched := false
		for alternative in group.alternatives {
			norm_alternative := normalize_text(alternative)
			if norm_alternative != '' && norm_actual.contains(norm_alternative) {
				matched = true
				break
			}
		}
		if !matched {
			return error('expected file ${expected_path}: missing required snippet group: ${group.alternatives.join(' | ')}')
		}
	}

	for forbidden in rules.forbidden {
		norm_forbidden := normalize_text(forbidden)
		if norm_forbidden != '' && norm_actual.contains(norm_forbidden) {
			return error('expected file ${expected_path}: forbidden snippet found: ${forbidden}')
		}
	}

	return true
}

fn parse_expected_rules(expected string, expected_path string) !ExpectedRules {
	mut rules := ExpectedRules{}
	lines := expected.split_into_lines()

	for idx, raw_line in lines {
		line := raw_line.trim_space()
		if line == '' {
			continue
		}

		if !line.contains('@@') {
			rules.required << ExpectedGroup{
				alternatives: [line]
			}
			continue
		}

		parse_expected_line(line, expected_path, idx + 1, mut rules)!
	}

	return rules
}

fn parse_expected_line(line string, expected_path string, line_no int, mut rules ExpectedRules) !bool {
	mut pos := 0
	mut current_group := ExpectedGroup{}
	mut has_group := false
	mut saw_marker := false

	for pos < line.len {
		hit := next_marker(line, pos) or {
			if line.contains('@@') {
				return error('expected file ${expected_path}:${line_no}: invalid directive syntax: ${line}')
			}
			break
		}
		saw_marker = true

		if hit.pos > pos {
			plain := line[pos..hit.pos].trim_space()
			if plain != '' {
				if has_group {
					rules.required << current_group
					current_group = ExpectedGroup{}
					has_group = false
				}
				rules.required << ExpectedGroup{
					alternatives: [plain]
				}
			}
		}

		marker_end := hit.pos + hit.kind.len
		next_hit := next_marker(line, marker_end) or { MarkerHit{ kind: '', pos: line.len } }
		snippet := clean_expected_snippet(line[marker_end..next_hit.pos])
		if snippet.len == 0 {
			return error('expected file ${expected_path}:${line_no}: empty snippet for ${hit.kind}')
		}

		match hit.kind {
			'@@in#' {
				if has_group {
					rules.required << current_group
				}
				current_group = ExpectedGroup{
					alternatives: [snippet]
				}
				has_group = true
			}
			'@@or#' {
				if !has_group {
					current_group = ExpectedGroup{
						alternatives: [snippet]
					}
					has_group = true
				} else {
					current_group.alternatives << snippet
				}
			}
			'@@notin#' {
				if has_group {
					rules.required << current_group
					current_group = ExpectedGroup{}
					has_group = false
				}
				rules.forbidden << snippet
			}
			else {
				return error('expected file ${expected_path}:${line_no}: unknown directive: ${hit.kind}')
			}
		}

		pos = next_hit.pos
	}

	if !saw_marker && line.contains('@@') {
		return error('expected file ${expected_path}:${line_no}: invalid directive syntax: ${line}')
	}

	if has_group && current_group.alternatives.len > 0 {
		rules.required << current_group
	}

	return true
}

fn next_marker(line string, start int) ?MarkerHit {
	markers := ['@@notin#', '@@in#', '@@or#']
	mut best_pos := -1
	mut best_kind := ''

	for marker in markers {
		if start >= line.len {
			continue
		}
		relative := line[start..].index(marker) or { -1 }
		if relative < 0 {
			continue
		}
		pos := start + relative
		if best_pos < 0 || pos < best_pos {
			best_pos = pos
			best_kind = marker
		}
	}

	if best_pos < 0 {
		return none
	}

	return MarkerHit{
		kind: best_kind
		pos: best_pos
	}
}

fn clean_expected_snippet(snippet string) string {
	mut cleaned := snippet.trim_space()
	if cleaned.len >= 2 {
		first := cleaned[0]
		last := cleaned[cleaned.len - 1]
		if (first == `"` && last == `"`) || (first == `'` && last == `'`) {
			cleaned = cleaned[1..cleaned.len - 1].trim_space()
		}
	}
	return cleaned
}

fn normalize_text(code string) string {
	lines := code.split_into_lines()
	mut normalized := []string{}

	for line in lines {
		trimmed := line.trim_space()
		if trimmed != '' {
			normalized << trimmed
		}
	}

	return normalized.join('\n')
}
