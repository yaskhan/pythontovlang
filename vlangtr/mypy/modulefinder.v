// Я Cline работаю над этим файлом. Начало: 2026-03-22 15:23
// modulefinder.v — Low-level infrastructure to find modules
// Переведён из mypy/modulefinder.py

module mypy

import os

// Расширения Python файлов
pub const python_extensions = ['.pyi', '.py']

// SearchPaths — пути для поиска модулей
pub struct SearchPaths {
pub:
	python_path   []string
	mypy_path     []string
	package_path  []string
	typeshed_path []string
}

// new_search_paths создаёт новый SearchPaths
pub fn new_search_paths(python_path []string, mypy_path []string, package_path []string, typeshed_path []string) SearchPaths {
	return SearchPaths{
		python_path:   python_path.map(os.abs_path(it))
		mypy_path:     mypy_path.map(os.abs_path(it))
		package_path:  package_path.map(os.abs_path(it))
		typeshed_path: typeshed_path.map(os.abs_path(it))
	}
}

// ModuleNotFoundReason — причина, по которой модуль не найден
pub enum ModuleNotFoundReason {
	not_found
	found_without_type_hints
	wrong_working_directory
	approved_stubs_not_installed
}

// error_message_templates возвращает шаблоны сообщений об ошибках
pub fn (r ModuleNotFoundReason) error_message_templates(daemon bool) (string, []string) {
	doc_link := 'See https://mypy.readthedocs.io/en/stable/running_mypy.html#missing-imports'
	match r {
		.not_found {
			return 'Cannot find implementation or library stub for module named "{module}"', [
				doc_link,
			]
		}
		.wrong_working_directory {
			return 'Cannot find implementation or library stub for module named "{module}"', [
				'You may be running mypy in a subpackage, mypy should be run on the package root',
			]
		}
		.found_without_type_hints {
			return 'Skipping analyzing "{module}": module is installed, but missing library stubs or py.typed marker', [
				doc_link,
			]
		}
		.approved_stubs_not_installed {
			mut notes := ['Hint: "python3 -m pip install {stub_dist}"']
			if !daemon {
				notes << '(or run "mypy --install-types" to install all missing stub packages)'
			}
			notes << doc_link
			return 'Library stubs not installed for "{module}"', notes
		}
	}
}

// ModuleSearchResult — результат поиска модуля
pub type ModuleSearchResult = ModuleNotFoundReason | string

// BuildSource — исходный файл для сборки
pub struct BuildSource {
pub:
	path     ?string
	module   string
	text     ?string
	base_dir ?string
	followed bool
}

// new_build_source создаёт новый BuildSource
pub fn new_build_source(path ?string, mod_name ?string, text ?string, base_dir ?string, followed bool) BuildSource {
	return BuildSource{
		path:     path
		module:   mod_name or { '__main__' }
		text:     text
		base_dir: base_dir
		followed: followed
	}
}

// str возвращает строковое представление BuildSource
pub fn (bs BuildSource) str() string {
	return 'BuildSource(path=${bs.path}, module=${bs.module}, has_text=${bs.text != none}, base_dir=${bs.base_dir}, followed=${bs.followed})'
}

// BuildSourceSet — набор исходных файлов для быстрой проверки принадлежности
pub struct BuildSourceSet {
pub mut:
	source_text_present bool
	source_modules      map[string]string
	source_paths        map[string]bool
}

// new_build_source_set создаёт новый BuildSourceSet
pub fn new_build_source_set(sources []BuildSource) BuildSourceSet {
	mut bss := BuildSourceSet{
		source_text_present: false
		source_modules:      map[string]string{}
		source_paths:        map[string]bool{}
	}
	for source in sources {
		if source.text != none {
			bss.source_text_present = true
		}
		if path := source.path {
			bss.source_paths[path] = true
		}
		bss.source_modules[source.module] = source.path or { '' }
	}
	return bss
}

// FindModuleCache — кэш для поиска модулей
pub struct FindModuleCache {
pub mut:
	search_paths       SearchPaths
	source_set         ?BuildSourceSet
	fscache            FileSystemCache
	initial_components map[string]map[string][]string
	results            map[string]ModuleSearchResult
	ns_ancestors       map[string]string
	options            ?Options
	stdlib_py_versions map[string]((int, int), ?(int, int))
}

// new_find_module_cache создаёт новый FindModuleCache
pub fn new_find_module_cache(search_paths SearchPaths, fscache FileSystemCache, options ?Options) FindModuleCache {
	return FindModuleCache{
		search_paths:       search_paths
		source_set:         none
		fscache:            fscache
		initial_components: map[string]map[string][]string{}
		results:            map[string]ModuleSearchResult{}
		ns_ancestors:       map[string]string{}
		options:            options
		stdlib_py_versions: map[string]((int, int), ?(int, int)){}
	}
}

// clear очищает кэш
pub fn (mut fmc FindModuleCache) clear() {
	fmc.results.clear()
	fmc.initial_components.clear()
	fmc.ns_ancestors.clear()
}

// find_module ищет модуль и возвращает путь или причину неудачи
pub fn (mut fmc FindModuleCache) find_module(id string) ModuleSearchResult {
	if id in fmc.results {
		return fmc.results[id]
	}

	result := fmc.find_module_internal(id)
	fmc.results[id] = result
	return result
}

// find_module_internal — внутренняя реализация поиска модуля
fn (mut fmc FindModuleCache) find_module_internal(id string) ModuleSearchResult {
	components := id.split('.')
	dir_chain := components[..components.len - 1].join(os.path_separator)

	// Поиск в package_path
	for pkg_dir in fmc.search_paths.package_path {
		stub_name := components[0] + '-stubs'
		stub_dir := os.join_path(pkg_dir, stub_name)
		if os.is_dir(stub_dir) {
			path := os.join_path(pkg_dir, stub_name, dir_chain, components.last() + '.pyi')
			if os.is_file(path) {
				return path
			}
		}

		// Обычный поиск
		path := os.join_path(pkg_dir, dir_chain, components.last() + '.pyi')
		if os.is_file(path) {
			return path
		}
		path = os.join_path(pkg_dir, dir_chain, components.last() + '.py')
		if os.is_file(path) {
			return path
		}
	}

	// Поиск в mypy_path и python_path
	for dir in fmc.search_paths.mypy_path + fmc.search_paths.python_path {
		path := os.join_path(dir, dir_chain, components.last() + '.pyi')
		if os.is_file(path) {
			return path
		}
		path = os.join_path(dir, dir_chain, components.last() + '.py')
		if os.is_file(path) {
			return path
		}
	}

	// Поиск в typeshed_path
	for dir in fmc.search_paths.typeshed_path {
		path := os.join_path(dir, dir_chain, components.last() + '.pyi')
		if os.is_file(path) {
			return path
		}
	}

	return ModuleNotFoundReason.not_found
}

// find_lib_path_dirs находит директории в lib_path, содержащие модуль
pub fn (fmc FindModuleCache) find_lib_path_dirs(id string, lib_path []string) []string {
	components := id.split('.')
	dir_chain := components[..components.len - 1].join(os.path_separator)

	mut dirs := []string{}
	for pathitem in fmc.get_toplevel_possibilities(lib_path, components[0]) {
		if dir_chain.len > 0 {
			dir := os.join_path(pathitem, dir_chain)
			if os.is_dir(dir) {
				dirs << dir
			}
		} else {
			if os.is_dir(pathitem) {
				dirs << pathitem
			}
		}
	}
	return dirs
}

// get_toplevel_possibilities находит возможные директории для top-level модуля
pub fn (mut fmc FindModuleCache) get_toplevel_possibilities(lib_path []string, id string) []string {
	lib_path_key := lib_path.join(':')
	if lib_path_key in fmc.initial_components {
		return fmc.initial_components[lib_path_key][id] or { []string{} }
	}

	mut components := map[string][]string{}
	for dir in lib_path {
		contents := os.ls(dir) or { []string{} }
		for name in contents {
			stem := name.all_before_last('.')
			if stem !in components {
				components[stem] = []string{}
			}
			components[stem] << dir
		}
	}

	fmc.initial_components[lib_path_key] = components
	return components[id] or { []string{} }
}

// is_init_file проверяет, является ли файл __init__.py[i]
pub fn is_init_file(path string) bool {
	base := os.base(path)
	return base == '__init__.py' || base == '__init__.pyi'
}

// verify_module проверяет, что все пакеты, содержащие id, имеют __init__ файл
pub fn verify_module(fscache FileSystemCache, id string, path string) bool {
	mut check_path := if is_init_file(path) { os.dir(path) } else { path }
	for _ in 0 .. id.count('.') {
		check_path = os.dir(check_path)
		has_init := python_extensions.any(os.is_file(os.join_path(check_path, '__init__' + it)))
		if !has_init {
			return false
		}
	}
	return true
}

// compute_search_paths вычисляет пути поиска модулей
pub fn compute_search_paths(sources []BuildSource, options Options, data_dir string, alt_lib_path ?string) SearchPaths {
	mut lib_path := []string{}

	// Добавляем стандартную библиотеку
	lib_path << os.join_path(data_dir, 'typeshed', 'stdlib')

	// Python path
	mut python_path := []string{}
	if alt_lib_path == none {
		for source in sources {
			if base_dir := source.base_dir {
				if base_dir !in python_path {
					python_path << base_dir
				}
			}
		}
		python_path << os.getwd()
	}

	// MYPYPATH
	mut mypypath := []string{}
	if alt_lib := alt_lib_path {
		mypypath << alt_lib
	}
	mypypath << options.mypy_path

	// Package path (site-packages)
	package_path := []string{} // TODO: получить из pyinfo

	return SearchPaths{
		python_path:   python_path.reverse()
		mypy_path:     mypypath
		package_path:  package_path
		typeshed_path: lib_path
	}
}

// Вспомогательные типы
pub struct FileSystemCache {
}

// is_file проверяет существование файла
pub fn (fsc FileSystemCache) is_file(path string) bool {
	return os.is_file(path)
}

// is_dir проверяет существование директории
pub fn (fsc FileSystemCache) is_dir(path string) bool {
	return os.is_dir(path)
}

// listdir возвращает список файлов в директории
pub fn (fsc FileSystemCache) listdir(path string) []string {
	return os.ls(path) or { []string{} }
}
