// find_sources.v — Routines for finding sources that mypy will check
// Translated from mypy/find_sources.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 15:00

module mypy

import os

// PY_EXTENSIONS — расширения Python файлов
pub const py_extensions = ['.pyi', '.py']

// InvalidSourceList — исключение для проблем со списком источников
pub struct InvalidSourceList {
pub:
	msg string
}

pub fn (e InvalidSourceList) msg() string { return e.msg }

// create_source_list создаёт список BuildSource из списка путей
pub fn create_source_list(paths []string,
	options Options,
	fscache ?&FileSystemCache,
	allow_empty_dir bool) ![]BuildSource {
	// fscache := fscache or { &FileSystemCache{} }
	mut finder := SourceFinder{
		// fscache: fscache
		options: options
	}

	mut sources := []BuildSource{}
	for path in paths {
		mut clean_path := os.abs_path(path)
		if clean_path.ends_with('.py') || clean_path.ends_with('.pyi') {
			// name, base_dir := finder.crawl_up(path)
			// sources << BuildSource{path: path, name: name, base_dir: base_dir}
			sources << BuildSource{
				path: clean_path
			}
		} else if os.is_dir(clean_path) {
			sub_sources := finder.find_sources_in_dir(clean_path)
			if sub_sources.len == 0 && !allow_empty_dir {
				return error('There are no .py[i] files in directory \'${clean_path}\'')
			}
			for s in sub_sources {
				sources << s
			}
		} else {
			// mod := os.base(path) if options.scripts_are_modules else none
			sources << BuildSource{
				path: clean_path
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
		r = '.'
	}
	r = os.abs_path(r)
	if r.ends_with(os.path_separator) {
		r = r[..r.len - 1]
	}
	return r
}

// ---------------------------------------------------------------------------
// Остальная часть файла ...
// ---------------------------------------------------------------------------

// SourceFinder — поиск источников
pub struct SourceFinder {
pub mut:
	// fscache               &FileSystemCache
	options                Options
	explicit_package_bases ?[]string
	namespace_packages     bool
	exclude                []string
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

// get_explicit_package_bases placeholder
fn get_explicit_package_bases(options Options) ?[]string { return none }

// is_explicit_package_base проверяет, является ли путь явной базой пакета
pub fn (f SourceFinder) is_explicit_package_base(path string) bool {
    if bases := f.explicit_package_bases {
        for base in bases {
            if base == path { return true }
        }
    }
	return false
}

// find_sources_in_dir placeholder
pub fn (mut f SourceFinder) find_sources_in_dir(path string) []BuildSource {
    return []BuildSource{}
}
