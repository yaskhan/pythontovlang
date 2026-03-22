// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 03:10
module mypy

import json

// ErrorFormatter describes how a single mypy error is serialized.
pub interface ErrorFormatter {
	report_error(err &ErrorInfo) string
}

// JSONFormatter emits one static JSON object per error.
pub struct JSONFormatter {}

struct JsonErrorLine {
	file       string  @[json: file]
	line       int     @[json: line]
	column     int     @[json: column]
	end_line   int     @[json: end_line]
	end_column int     @[json: end_column]
	message    string  @[json: message]
	hint       ?string @[json: hint]
	code       ?string @[json: code]
	severity   string  @[json: severity]
}

pub fn (f JSONFormatter) report_error(err &ErrorInfo) string {
	// В ErrorInfo нет hints, используем message
	return json.encode(JsonErrorLine{
		file:       err.file
		line:       err.line
		column:     err.column
		end_line:   err.end_line
		end_column: err.end_column
		message:    err.message
		hint:       none
		code:       err.code
		severity:   err.severity
	})
}

pub fn output_choices() map[string]ErrorFormatter {
	return {
		'json': ErrorFormatter(JSONFormatter{})
	}
}
