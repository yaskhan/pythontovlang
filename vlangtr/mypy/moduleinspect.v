// moduleinspect.v — Basic introspection of modules
// Translated from mypy/moduleinspect.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 14:30

module mypy

import os

// ModuleProperties — свойства модуля/пакета
pub struct ModuleProperties {
pub mut:
	name        string    // __name__ атрибут
	file        ?string   // __file__ атрибут
	path        ?[]string // __path__ атрибут
	all         ?[]string // __all__ атрибут
	is_c_module bool
	subpackages []string
}

// new_module_properties создаёт новый ModuleProperties
pub fn new_module_properties(name string,
	file ?string,
	path ?[]string,
	all ?[]string,
	is_c_module bool,
	subpackages ?[]string) ModuleProperties {
	return ModuleProperties{
		name:        name
		file:        file
		path:        path
		all:         all
		is_c_module: is_c_module
		subpackages: subpackages or { []string{} }
	}
}

// is_c_module проверяет, является ли модуль C extension
pub fn is_c_module(module_file ?string) bool {
	if module_file == none {
		// Может быть namespace package
		return true
	}
	ext := os.ext(module_file or { '' })
	return ext in ['.so', '.pyd', '.dll']
}

// is_pyc_only проверяет, является ли файл только .pyc
pub fn is_pyc_only(file ?string) bool {
	if file == none {
		return false
	}
	f := file or { '' }
	return f.ends_with('.pyc') && !os.file_exists(f[..f.len - 1])
}

// InspectError — ошибка интроспекции
pub type InspectError = string

// get_package_properties получает свойства пакета через runtime introspection
// Упрощённая версия — без реального импорта модулей
pub fn get_package_properties(package_id string) !ModuleProperties {
	// В V нет прямого аналога importlib.import_module
	// Эта функция должна быть реализована через plugin или external вызовы

	// Для заглушки возвращаем базовые свойства
	return ModuleProperties{
		name:        package_id
		file:        none
		path:        none
		all:         none
		is_c_module: false
		subpackages: []string{}
	}
}

// ModuleInspect — runtime интроспекция модулей
// В упрощённой версии без использования отдельных процессов
pub struct ModuleInspect {
pub mut:
	counter int // Количество успешных запросов
}

// new_module_inspect создаёт новый ModuleInspect
pub fn new_module_inspect() !ModuleInspect {
	mut m := ModuleInspect{
		counter: 0
	}
	return m
}

// close освобождает ресурсы
pub fn (mut m ModuleInspect) close() {
	// В упрощённой версии ничего не делаем
	m.counter = 0
}

// get_package_properties возвращает свойства модуля/пакета
pub fn (mut m ModuleInspect) get_package_properties(package_id string) !ModuleProperties {
	// Упрощённая версия — без процесса и очереди
	prop := get_package_properties(package_id) or {
		return InspectError('Cannot import ${package_id}')
	}
	m.counter++
	return prop
}

// enter для context manager
pub fn (mut m ModuleInspect) enter() &ModuleInspect {
	return &m
}

// exit для context manager
pub fn (mut m ModuleInspect) exit() {
	m.close()
}
