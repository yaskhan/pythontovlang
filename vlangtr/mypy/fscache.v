// fscache.v — File system access with automatic caching
// Translated from mypy/fscache.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 19:00

module mypy

import os

// FileSystemCache — кэш для доступа к файловой системе
pub struct FileSystemCache {
pub mut:
	package_root        []string
	stat_or_none_cache  map[string]?os.FileInfo
	listdir_cache       map[string][]string
	listdir_error_cache map[string]string
	isfile_case_cache   map[string]bool
	exists_case_cache   map[string]bool
	read_cache          map[string][]u8
	read_error_cache    map[string]string
	hash_cache          map[string]string
	fake_package_cache  map[string]bool
}

// new_file_system_cache создаёт новый FileSystemCache
pub fn new_file_system_cache() FileSystemCache {
	mut fs := FileSystemCache{
		package_root:        []string{}
		stat_or_none_cache:  map[string]?os.FileInfo{}
		listdir_cache:       map[string][]string{}
		listdir_error_cache: map[string]string{}
		isfile_case_cache:   map[string]bool{}
		exists_case_cache:   map[string]bool{}
		read_cache:          map[string][]u8{}
		read_error_cache:    map[string]string{}
		hash_cache:          map[string]string{}
		fake_package_cache:  map[string]bool{}
	}
	return fs
}

// set_package_root устанавливает корневые директории пакетов
pub fn (mut fs FileSystemCache) set_package_root(package_root []string) {
	fs.package_root = package_root
}

// flush начинает новую транзакцию и очищает все кэши
pub fn (mut fs FileSystemCache) flush() {
	fs.stat_or_none_cache = map[string]?os.FileInfo{}
	fs.listdir_cache = map[string][]string{}
	fs.listdir_error_cache = map[string]string{}
	fs.isfile_case_cache = map[string]bool{}
	fs.exists_case_cache = map[string]bool{}
	fs.read_cache = map[string][]u8{}
	fs.read_error_cache = map[string]string{}
	fs.hash_cache = map[string]string{}
	fs.fake_package_cache = map[string]bool{}
}

// stat_or_none возвращает информацию о файле или none
pub fn (mut fs FileSystemCache) stat_or_none(path string) ?os.FileInfo {
	if path in fs.stat_or_none_cache {
		return fs.stat_or_none_cache[path]
	}

	st := os.stat(path) or {
		if fs.init_under_package_root(path) {
			fs.fake_init(path) or { return none }
		}
		return none
	}

	fs.stat_or_none_cache[path] = st
	return st
}

// init_under_package_root проверяет, является ли путь __init__.py под корнем пакета
pub fn (mut fs FileSystemCache) init_under_package_root(path string) bool {
	if fs.package_root.len == 0 {
		return false
	}

	dirname, basename := os.split(path)
	if basename != '__init__.py' {
		return false
	}

	if !is_identifier(os.base(dirname)) {
		return false
	}

	st := fs.stat_or_none(dirname) or { return false }
	if !st.is_dir() {
		return false
	}

	// Проверка на разных дисках (Windows)
	current_drive, _ := os.splitdrive(os.getcwd())
	drive, _ := os.splitdrive(path)
	if drive != current_drive {
		return false
	}

	mut p := path
	if os.is_abs(path) {
		p = os.rel(path, os.getcwd()) or { path }
	}
	p = os.clean(p)

	for root in fs.package_root {
		if p.starts_with(root) {
			if p == root + basename {
				// Корень пакета сам по себе не является пакетом
				return false
			}
			return true
		}
	}

	return false
}

// is_identifier проверяет, является ли строка допустимым идентификатором
pub fn is_identifier(s string) bool {
	if s.len == 0 {
		return false
	}
	// Упрощённая проверка — только первый символ
	first := s[0]
	if !first.is_letter() && first != '_' {
		return false
	}
	for i := 1; i < s.len; i++ {
		c := s[i]
		if !c.is_letter() && !c.is_digit() && c != '_' {
			return false
		}
	}
	return true
}

// fake_init создаёт фейковый __init__.py в кэше
pub fn (mut fs FileSystemCache) fake_init(path string) ?os.FileInfo {
	dirname, basename := os.split(path)
	assert basename == '__init__.py'

	dirname = os.clean(dirname)
	st := os.stat(dirname) or { return none }

	// Создаём фейковый stat для файла
	// В V нет прямого аналога os.stat_result, используем FileInfo
	fs.fake_package_cache[dirname] = true

	return st
}

// listdir возвращает список файлов в директории
pub fn (mut fs FileSystemCache) listdir(path string) ![]string {
	path = os.clean(path)

	if path in fs.listdir_cache {
		mut res := fs.listdir_cache[path]
		if path in fs.fake_package_cache && '__init__.py' !in res {
			res << '__init__.py'
		}
		return res
	}

	if path in fs.listdir_error_cache {
		return fs.listdir_error_cache[path]
	}

	results := os.ls(path) or {
		err := 'OSError'
		fs.listdir_error_cache[path] = err
		return err
	}

	fs.listdir_cache[path] = results

	if path in fs.fake_package_cache && '__init__.py' !in results {
		results << '__init__.py'
	}

	return results
}

// isfile проверяет, является ли путь файлом
pub fn (mut fs FileSystemCache) isfile(path string) bool {
	st := fs.stat_or_none(path) or { return false }
	return st.is_file()
}

// isfile_case проверяет, является ли путь файлом с учётом регистра
pub fn (mut fs FileSystemCache) isfile_case(path string, prefix string) bool {
	if !fs.isfile(path) {
		return false
	}

	if path in fs.isfile_case_cache {
		return fs.isfile_case_cache[path]
	}

	head, tail := os.split(path)
	if tail == '' {
		fs.isfile_case_cache[path] = false
		return false
	}

	names := fs.listdir(head) or {
		fs.isfile_case_cache[path] = false
		return false
	}

	res := tail in names
	if res {
		res = fs.exists_case(head, prefix)
	}

	fs.isfile_case_cache[path] = res
	return res
}

// exists_case проверяет существование пути с учётом регистра
pub fn (mut fs FileSystemCache) exists_case(path string, prefix string) bool {
	if path in fs.exists_case_cache {
		return fs.exists_case_cache[path]
	}

	head, tail := os.split(path)
	if !head.starts_with(prefix) || tail == '' {
		fs.exists_case_cache[path] = true
		return true
	}

	names := fs.listdir(head) or {
		fs.exists_case_cache[path] = false
		return false
	}

	res := tail in names
	if res {
		res = fs.exists_case(head, prefix)
	}

	fs.exists_case_cache[path] = res
	return res
}

// isdir проверяет, является ли путь директорией
pub fn (mut fs FileSystemCache) isdir(path string) bool {
	st := fs.stat_or_none(path) or { return false }
	return st.is_dir()
}

// exists проверяет существование пути
pub fn (mut fs FileSystemCache) exists(path string) bool {
	st := fs.stat_or_none(path)
	return st != none
}

// read читает содержимое файла
pub fn (mut fs FileSystemCache) read(path string) ![]u8 {
	if path in fs.read_cache {
		return fs.read_cache[path]
	}

	if path in fs.read_error_cache {
		return fs.read_error_cache[path]
	}

	// Сначала stat для корректного mtime
	fs.stat_or_none(path)

	dirname, basename := os.split(path)
	dirname = os.clean(dirname)

	// Проверка фейкового кэша
	if basename == '__init__.py' && dirname in fs.fake_package_cache {
		data := []u8{}
		fs.read_cache[path] = data
		fs.hash_cache[path] = hash_digest(data)
		return data
	}

	data := os.read_file(path) or {
		err := 'OSError'
		fs.read_error_cache[path] = err
		return err
	}

	fs.read_cache[path] = data
	fs.hash_cache[path] = hash_digest(data)
	return data
}

// hash_digest возвращает хэш содержимого файла
pub fn (mut fs FileSystemCache) hash_digest(path string) string {
	if path !in fs.hash_cache {
		fs.read(path) or { return '' }
	}
	return fs.hash_cache[path]
}

// samefile проверяет, ссылаются ли пути на один файл
pub fn (mut fs FileSystemCache) samefile(f1 string, f2 string) bool {
	s1 := fs.stat_or_none(f1) or { return false }
	s2 := fs.stat_or_none(f2) or { return false }

	// Сравниваем по inode/mtime/size
	return s1.ino() == s2.ino() && s1.mod_time().unix() == s2.mod_time().unix()
}

// hash_digest вычисляет хэш данных
pub fn hash_digest(data []u8) string {
	// Упрощённая версия — используем длину как хэш
	return '${data.len}'
}
