module utils

pub struct CompatibilityLayer {
}

pub fn new_compatibility_layer() CompatibilityLayer {
	return CompatibilityLayer{}
}

pub fn (c CompatibilityLayer) is_v_reserved(name string) bool {
	return name in v_reserved_keywords() || name.to_lower() in v_reserved_keywords()
}

pub fn (c CompatibilityLayer) is_python_soft_keyword(name string) bool {
	return name in python_soft_keywords()
}

pub fn (c CompatibilityLayer) preprocess_source(source string) string {
	mut result := c.preprocess_tstrings(source)
	result = c.preprocess_bracketless_except(result)
	result = c.preprocess_generic_match(result)
	return result
}

fn v_reserved_keywords() []string {
	return [
		'fn',
		'type',
		'struct',
		'mut',
		'if',
		'else',
		'for',
		'return',
		'match',
		'interface',
		'enum',
		'pub',
		'import',
		'module',
		'const',
		'unsafe',
		'defer',
		'go',
		'chan',
		'shared',
		'spawn',
		'assert',
		'sizeof',
		'typeof',
		'__global',
		'as',
		'in',
		'is',
		'none',
		'map',
		'array',
		'string',
		'bool',
		'any',
		'Any',
		'union',
	]
}

fn python_soft_keywords() []string {
	return ['match', 'case', 'type', 'soft']
}

fn (c CompatibilityLayer) preprocess_tstrings(source string) string {
	mut result := []u8{}
	mut i := 0
	for i < source.len {
		ch := source[i]
		if c.is_tstring_prefix_start(source, i) {
			prefix_end, quote, quote_len, raw_prefix := c.scan_tstring_prefix(source, i)
			if prefix_end > i {
				if raw_prefix {
					result << `r`
				}
				result << `f`
				result << quote
				if quote_len == 3 {
					result << quote
					result << quote
				}
				result << '__py2v_t__'.bytes()
				i = prefix_end + quote_len
				continue
			}
		}
		result << ch
		i++
	}
	return result.bytestr()
}

fn (c CompatibilityLayer) is_tstring_prefix_start(source string, index int) bool {
	if index >= source.len {
		return false
	}
	ch := source[index]
	if ch != `t` && ch != `T` && ch != `r` && ch != `R` {
		return false
	}
	if index > 0 {
		prev := source[index - 1]
		if !(prev.is_space() || prev == `=` || prev == `(` || prev == `[` || prev == `{`
			|| prev == `,` || prev == `:` || prev == `!` || prev == `|` || prev == `&`) {
			return false
		}
	}
	return true
}

fn (c CompatibilityLayer) scan_tstring_prefix(source string, index int) (int, u8, int, bool) {
	mut i := index
	mut has_t := false
	mut raw_prefix := false
	for i < source.len {
		ch := source[i]
		if ch == `t` || ch == `T` {
			has_t = true
			i++
			continue
		}
		if ch == `r` || ch == `R` {
			raw_prefix = true
			i++
			continue
		}
		break
	}
	if !has_t || i >= source.len {
		return index, 0, 0, false
	}
	quote := source[i]
	if quote != `"` && quote != `'` {
		return index, 0, 0, false
	}
	if i + 2 < source.len && source[i + 1] == quote && source[i + 2] == quote {
		return i, quote, 3, raw_prefix
	}
	return i, quote, 1, raw_prefix
}

fn (c CompatibilityLayer) preprocess_bracketless_except(source string) string {
	lines := source.split('\n')
	mut result := []string{}
	mut i := 0
	for i < lines.len {
		line := lines[i]
		header := c.match_except_header(line)
		if header.kind == '' {
			result << line
			i++
			continue
		}

		mut full_header := header.rest
		mut j := i
		for c.find_header_colon(full_header) == -1 && j + 1 < lines.len {
			j++
			full_header += '\n${lines[j]}'
		}

		colon_index := c.find_header_colon(full_header)
		if colon_index == -1 {
			result << line
			i++
			continue
		}

		clause := full_header[..colon_index]
		suffix := full_header[colon_index + 1..]
		rewritten_clause := c.wrap_bracketless_except_clause(clause)
		result << '${header.indent}${header.kind}${rewritten_clause}:${suffix}'
		i = j + 1
	}
	return result.join('\n')
}

struct ExceptHeader {
	indent string
	kind   string
	rest   string
}

fn (c CompatibilityLayer) match_except_header(line string) ExceptHeader {
	mut i := 0
	for i < line.len && (line[i] == ` ` || line[i] == `\t`) {
		i++
	}
	indent := line[..i]
	if i + 6 > line.len {
		return ExceptHeader{}
	}
	if line[i..].starts_with('except* ') {
		return ExceptHeader{
			indent: indent
			kind:   'except* '
			rest:   line[i + 8..]
		}
	}
	if line[i..].starts_with('except ') {
		return ExceptHeader{
			indent: indent
			kind:   'except '
			rest:   line[i + 7..]
		}
	}
	return ExceptHeader{}
}

fn (c CompatibilityLayer) find_header_colon(text string) int {
	mut depth := 0
	for i, ch in text {
		if ch == `(` || ch == `[` || ch == `{` {
			depth++
		} else if ch == `)` || ch == `]` || ch == `}` {
			if depth > 0 {
				depth--
			}
		} else if ch == `:` && depth == 0 {
			return i
		}
	}
	return -1
}

fn (c CompatibilityLayer) wrap_bracketless_except_clause(clause string) string {
	stripped := clause.trim_space()
	if stripped.len == 0 || stripped.starts_with('(') {
		return clause
	}
	head, as_clause := c.split_except_alias(clause)
	if !c.has_top_level_comma(head) {
		return clause
	}
	return '(${head.trim_space()})${as_clause}'
}

fn (c CompatibilityLayer) split_except_alias(clause string) (string, string) {
	mut depth := 0
	mut idx := 0
	for idx < clause.len {
		ch := clause[idx]
		if ch == `(` || ch == `[` || ch == `{` {
			depth++
		} else if ch == `)` || ch == `]` || ch == `}` {
			if depth > 0 {
				depth--
			}
		} else if depth == 0 && idx + 4 <= clause.len && clause[idx..idx + 4] == ' as ' {
			return clause[..idx], clause[idx..]
		}
		idx++
	}
	return clause, ''
}

fn (c CompatibilityLayer) has_top_level_comma(text string) bool {
	mut depth := 0
	for ch in text {
		if ch == `(` || ch == `[` || ch == `{` {
			depth++
		} else if ch == `)` || ch == `]` || ch == `}` {
			if depth > 0 {
				depth--
			}
		} else if ch == `,` && depth == 0 {
			return true
		}
	}
	return false
}

fn (c CompatibilityLayer) preprocess_generic_match(source string) string {
	lines := source.split('\n')
	mut result := []string{}
	mut i := 0
	for i < lines.len {
		line := lines[i]
		case_header := c.match_case_header(line)
		if case_header.kind == '' {
			result << line
			i++
			continue
		}

		mut full_case := case_header.rest
		mut j := i
		for c.find_header_colon(full_case) == -1 && j + 1 < lines.len {
			j++
			full_case += '\n${lines[j]}'
		}

		colon_index := c.find_header_colon(full_case)
		if colon_index == -1 {
			result << line
			i++
			continue
		}

		pattern := full_case[..colon_index]
		rest := full_case[colon_index + 1..]
		mangled := c.mangle_recursive(pattern)
		result << '${case_header.indent}case ${mangled}:${rest}'
		i = j + 1
	}
	return result.join('\n')
}

struct CaseHeader {
	indent string
	kind   string
	rest   string
}

fn (c CompatibilityLayer) match_case_header(line string) CaseHeader {
	mut i := 0
	for i < line.len && (line[i] == ` ` || line[i] == `\t`) {
		i++
	}
	if i + 5 > line.len || !line[i..].starts_with('case ') {
		return CaseHeader{}
	}
	return CaseHeader{
		indent: line[..i]
		kind:   'case '
		rest:   line[i + 5..]
	}
}

fn (c CompatibilityLayer) mangle_recursive(text string) string {
	mut current := text
	for {
		mut changed := false
		mut depth := 0
		mut i := 0
		for i < current.len {
			ch := current[i]
			if ch == `[` {
				if depth == 0 {
					mut left := i
					for left > 0 {
						prev := current[left - 1]
						if prev.is_letter() || prev.is_digit() || prev == `_` || prev == `.` {
							left--
						} else {
							break
						}
					}
					if left < i {
						end := c.find_matching_bracket(current, i)
						if end != -1 {
							name := current[left..i]
							args := current[i + 1..end]
							mangled_args := c.mangle_recursive(args).replace(', ', '__py2v_gen_C__').replace(',', '__py2v_gen_C__').replace(' ', '')
							replacement := '${name}__py2v_gen_L__${mangled_args}__py2v_gen_R__'
							current = current[..left] + replacement + current[end + 1..]
							changed = true
							break
						}
					}
				}
				depth++
			} else if ch == `]` {
				if depth > 0 {
					depth--
				}
			}
			i++
		}
		if !changed {
			break
		}
	}
	return current
}

fn (c CompatibilityLayer) find_matching_bracket(text string, start int) int {
	mut depth := 0
	for i := start; i < text.len; i++ {
		ch := text[i]
		if ch == `[` {
			depth++
		} else if ch == `]` {
			depth--
			if depth == 0 {
				return i
			}
		}
	}
	return -1
}
