// error_formatter.v — Different custom formats in which mypy can output
// Translated from mypy/error_formatter.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 16:30

module mypy

import json

// MypyError — структура ошибки mypy
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

// ErrorFormatter — интерфейс для форматирования ошибок
pub interface ErrorFormatter {
	report_error(error MypyError) string
}

// JSONFormatter — форматирование ошибок в JSON
pub struct JSONFormatter {}

// report_error форматирует ошибку как JSON строку
pub fn (f JSONFormatter) report_error(error MypyError) string {
	// В V json.encode можно вызывать напрямую на структурах
	return json.encode(error)
}

// OUTPUT_CHOICES — доступные варианты вывода
// В V константные мапы объявляются по-другому, если это интерфейсы.
// pub const output_choices = {
// 	'json': JSONFormatter{}
// }

// get_formatter возвращает форматтер по имени
pub fn get_formatter(name string) ?ErrorFormatter {
	if name == 'json' {
		return ErrorFormatter(JSONFormatter{})
	}
	return none
}
