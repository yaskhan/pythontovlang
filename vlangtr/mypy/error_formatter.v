// Я Codex работаю над этим файлом. Начало: 2026-03-22 14:45:16 +05:00
module mypy

import json

// ErrorFormatter describes how a single mypy error is serialized.
pub interface ErrorFormatter {
	report_error(err MypyError) string
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

pub fn (f JSONFormatter) report_error(err MypyError) string {
	hint := if err.hints.len == 0 { none } else { err.hints.join('\n') }
	return json.encode(JsonErrorLine{
		file:       err.file_path
		line:       err.line
		column:     err.column
		end_line:   err.end_line
		end_column: err.end_column
		message:    err.message
		hint:       hint
		code:       err.errorcode
		severity:   err.severity
	})
}

pub fn output_choices() map[string]ErrorFormatter {
	return {
		'json': ErrorFormatter(JSONFormatter{})
	}
}
