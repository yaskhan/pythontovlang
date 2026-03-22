// error_formatter.v — Different custom formats in which mypy can output
// Translated from mypy/error_formatter.py to V 0.5.x
//
// Work in progress by Antigravity. Started: 2026-03-22 16:30

module mypy

import json

// MypyError — mypy error structure
pub struct MypyError {
pub mut:
	file_path  string
	line       int
	column     int
	end_line   ?int
	end_column ?int
	message    string
	hints      []string
	errorcode  ?string
	severity   string
}

// ErrorFormatter — interface for error formatting
pub interface ErrorFormatter {
	report_error(error MypyError) string
}

// JSONFormatter — error formatting to JSON
pub struct JSONFormatter {}

// report_error formats error as JSON string
pub fn (f JSONFormatter) report_error(error MypyError) string {
	// In V json.encode can be called directly on structures
	return json.encode(error)
}

// OUTPUT_CHOICES — available output options
// In V constant maps are declared differently if they are interfaces.
// pub const output_choices = {
// 	'json': JSONFormatter{}
// }

// get_formatter returns formatter by name
pub fn get_formatter(name string) ?ErrorFormatter {
	if name == 'json' {
		return ErrorFormatter(JSONFormatter{})
	}
	return none
}
