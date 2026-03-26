module analyzer

pub const mypy_tips = {
	'union-attr': 'In V, you must explicitly check the type (e.g., using `if x is Type`) before accessing a union attribute.'
	'arg-type':   'In V, function arguments are strictly typed. Ensure the passed value matches the expected type or use a sum type.'
	'return-value': 'V requires the return value to strictly match the function signature.'
	'assignment': 'V is statically typed; ensure the variable type matches the value being assigned. Re-assignments to different types are not allowed.'
	'index':      'V array indices must be integers. Map keys must match the declared key type.'
	'attr-defined': 'Ensure the struct field or method exists in the V definition. V does not allow dynamic attribute addition.'
	'operator':   'V is strict about operand types. Ensure both sides of the operator have compatible types.'
	'call-arg':   'V function calls must match the exact number of defined parameters. Optional arguments in Python are often handled via Optionals or default values in V.'
	'name-defined': 'In V, all variables and functions must be declared before use or be visible in the current module scope.'
	'variance':   'Variance violation detected. Python 3.13+ PEP 695 variance modifiers must be strictly followed in generic definitions.'
}

pub fn get_mypy_tips(mypy_output string) string {
	if mypy_output.len == 0 {
		return ''
	}

	mut found_codes := map[string]bool{}
	for code in extract_error_codes(mypy_output) {
		found_codes[code] = true
	}

	mut tips := []string{}
	for code in found_codes.keys().sorted() {
		if code in mypy_tips {
			tips << '- [${code}] ${mypy_tips[code]}'
		}
	}

	if tips.len == 0 {
		return ''
	}

	return '\nV-specific tips for found Mypy errors:\n${tips.join("\n")}\n'
}

fn extract_error_codes(mypy_output string) []string {
	mut codes := []string{}
	mut i := 0
	for i < mypy_output.len {
		if mypy_output[i] == `[` {
			j := mypy_output.index_after(']', i + 1) or {
				i++
				continue
			}
			code := mypy_output[i + 1..j]
			if is_error_code(code) {
				codes << code
			}
			i = j + 1
			continue
		}
		i++
	}
	return codes
}

fn is_error_code(code string) bool {
	if code.len == 0 {
		return false
	}
	for ch in code {
		if !(ch.is_letter() || ch == `-`) {
			return false
		}
	}
	return true
}
