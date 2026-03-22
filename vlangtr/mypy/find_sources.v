// find_sources.v — Routines for finding sources that mypy will check
// Translated from mypy/find_sources.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 15:00

module mypy

import os

// PY_EXTENSIONS — расширения Python файлов
pub const py_extensions = ['.pyi', '.py']

// InvalidSourceList — исключение для проблем со списком источников
pub type InvalidSourceList = string

// create_source_list создаёт список BuildSource из списка путей
pub fn create_source_list(paths []string,
	options Options,
	fscache ?&FileSystemCache,
	allow_empty_dir bool) ![]BuildSource {
	// fscache := fscache or { &FileSystemCache{} }
	finder := SourceFinder{
		// fscache: fscache
		options: options
	}

	mut sources := []BuildSource{}
	for path in paths {
		path = os.clean(path)
		if path.ends_with('.py') || path.ends_with('.pyi') {
			// name, base_dir := finder.crawl_up(path)
			// sources << BuildSource{path: path, name: name, base_dir: base_dir}
			sources << BuildSource{
				path: path
			}
		} else if os.is_dir(path) {
			sub_sources := finder.find_sources_in_dir(path)
			if sub_sources.len == 0 && !allow_empty_dir {
				return InvalidSourceList('There are no .py[i] files in directory \'${path}\'')
			}
			for s in sub_sources {
				sources << s
			}
		} else {
			// mod := os.base(path) if options.scripts_are_modules else none
			sources << BuildSource{
				path: path
			}
		}
	}
	return sources
}

// keyfunc определяет порядок сортировки для списка директорий
pub fn keyfunc(name string) string {
	// Упрощённая версия — сортировка по имени
	return name
}

// normalise_package_base нормализует базовый путь пакета
pub fn normalise_package_base(root string) string {
	mut r := root
	if r == '' {
		r = os.curdir
	}
	r = os.abs(r) or { r }
	if r.ends_with(os.path_separator) {
		r = r[..r.len - 1]
	}
	return r
}

// SourceFinder — поиск источников
pub struct SourceFinder {
pub mut:
	// fscache               &FileSystemCache
	options                Options
	explicit_package_bases ?[]string
	namespace_packages     bool
	exclude                ?string
	exclude_gitignore      bool
	verbosity              int
}

// new_source_finder создаёт новый SourceFinder
pub fn new_source_finder(options Options) SourceFinder {
	mut explicit_bases := get_explicit_package_bases(options)
	return SourceFinder{
		options:                options
		explicit_package_bases: explicit_bases
		namespace_packages:     options.namespace_packages
		exclude:                options.exclude
		exclude_gitignore:      options.exclude_gitignore
		verbosity:              options.verbosity
	}
}

// is_explicit_package_base проверяет, является ли путь явной базой пакета
pub fn (f SourceFinder) is_explicit_package_base(path string) bool {
	if f.explicit_package_bases == none {
		return false
	}
	bases := f.explicit_package_bases or { []string{} }
	return normalise_package_base(path) in bases
}

// find_sources_in_dir находит источники в директории
pub fn (mut f SourceFinder) find_sources_in_dir(path string) []BuildSource {
	mut sources := []BuildSource{}
	mut seen := map[string]bool{}

	names := os.ls(path) or { []string{} }
	names.sort_with_key(keyfunc)

	for name in names {
		// Пропускаем определённые имена
		if name in ['__pycache__', 'site-packages', 'node_modules'] || name.starts_with('.') {
			continue
		}

		subpath := os.join_path(path, name)

		// TODO: matches_exclude, matches_gitignore

		if os.is_dir(subpath) {
			sub_sources := f.find_sources_in_dir(subpath)
			if sub_sources.len > 0 {
				seen[name] = true
				for s in sub_sources {
					sources << s
				}
			}
		} else {
			stem, suffix := os.splitext(name)
			if stem !in seen && suffix in py_extensions {
				seen[stem] = true
				// module, base_dir := f.crawl_up(subpath)
				// sources << BuildSource{path: subpath, name: module, base_dir: base_dir}
				sources << BuildSource{
					path: subpath
				}
			}
		}
	}

	return sources
}

// crawl_up给定一个 .py[i] 文件名，返回 module 和 base directory
pub fn (f SourceFinder) crawl_up(path string) !tuple[string, string] {
	path = os.abs(path) or { path }
	parent, filename := os.split(path)

	module_name := strip_py(filename) or { filename }

	parent_module, base_dir := f.crawl_up_dir(parent)
	if module_name == '__init__' {
		return parent_module, base_dir
	}

	mod := module_join(parent_module, module_name)
	return mod, base_dir
}

// crawl_up_dir обходит директорию вверх
pub fn (f SourceFinder) crawl_up_dir(dir string) tuple[string, string] {
	result := f.crawl_up_helper(dir)
	if result == none {
		return '', dir
	}
	return result
}

// crawl_up_helper вспомогательная функция для обхода вверх
pub fn (f SourceFinder) crawl_up_helper(dir string) ?tuple[string, string] {
	// Останавливаемся, если мы явная базовая директория
	if f.explicit_package_bases != none && f.is_explicit_package_base(dir) {
		return '', dir
	}

	parent, name := os.split(dir)
	name = name.trim_suffix('-stubs') // PEP-561 stub-only directory

	// Рекурсируем, если есть __init__.py
	init_file := f.get_init_file(dir)
	if init_file != none {
		if !name.is_identifier() {
			return InvalidSourceList('${name} contains ${os.base(init_file or { '' })} but is not a valid Python package name')
		}
		mod_prefix, base_dir := f.crawl_up_dir(parent)
		return module_join(mod_prefix, name), base_dir
	}

	// Останавливаемся, если кончились компоненты пути или имя невалидно
	if name == '' || parent == '' || !name.is_identifier() {
		return none
	}

	// Останавливаемся, если namespace packages выключен
	if !f.namespace_packages {
		return none
	}

	// Namespace packages включён, продолжаем обход
	result := f.crawl_up_helper(parent)
	if result == none {
		return none
	}

	mod_prefix, base_dir := result
	return module_join(mod_prefix, name), base_dir
}

// get_init_file проверяет, содержит ли директория __init__.py[i]
pub fn (f SourceFinder) get_init_file(dir string) ?string {
	for ext in py_extensions {
		f_path := os.join_path(dir, '__init__' + ext)
		if os.file_exists(f_path) {
			return f_path
		}
	}
	return none
}

// module_join соединяет module ids
pub fn module_join(parent string, child string) string {
	if parent != '' {
		return parent + '.' + child
	}
	return child
}

// strip_py удаляет суффикс .py или .pyi
pub fn strip_py(arg string) ?string {
	for ext in py_extensions {
		if arg.ends_with(ext) {
			return arg[..arg.len - ext.len]
		}
	}
	return none
}

// BuildSource — источник для сборки
pub struct BuildSource {
pub mut:
	path     string
	name     string
	text     ?string
	base_dir string
}

// FileSystemCache — кэш файловой системы (заглушка)
pub struct FileSystemCache {}

pub fn (f FileSystemCache) isdir(path string) bool {
	return os.is_dir(path)
}

pub fn (f FileSystemCache) isfile(path string) bool {
	return os.file_exists(path)
}

pub fn (f FileSystemCache) listdir(path string) []string {
	return os.ls(path) or { []string{} }
}

pub fn (f FileSystemCache) init_under_package_root(path string) bool {
	return false // Упрощённая версия
}
