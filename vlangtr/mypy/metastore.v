// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 14:40
module mypy

import os
import time

// Интерфейсы для доступа к метаданным (кешу).
// Mypy кэширует семантические деревья и типы для быстрого перезапуска.

pub interface MetadataStore {
	getmtime(name string) !i64
	read(name string) ![]u8
	write(name string, data []u8, mtime ?i64) bool
	remove(name string) !
	commit()
	list_all() []string
	close()
}

pub struct FilesystemMetadataStore {
pub mut:
	cache_dir_prefix ?string
}

pub fn new_filesystem_metadata_store(cache_dir_prefix string) FilesystemMetadataStore {
	// Игнорируем os.devnull (в V это '/dev/null' на Unix)
	mut prefix := ?string(cache_dir_prefix)
	if cache_dir_prefix.starts_with('/dev/null') || cache_dir_prefix.starts_with('NUL') {
		prefix = none
	}
	return FilesystemMetadataStore{
		cache_dir_prefix: prefix
	}
}

pub fn (mut s FilesystemMetadataStore) getmtime(name string) !i64 {
	prefix := s.cache_dir_prefix or { return error('FileNotFoundError') }
	path := os.join_path(prefix, name)
	if !os.exists(path) {
		return error('FileNotFoundError')
	}
	return os.file_last_mod_unix(path)
}

pub fn (mut s FilesystemMetadataStore) read(name string) ![]u8 {
	if os.is_abs_path(name) {
		panic("Don't use absolute paths!")
	}
	prefix := s.cache_dir_prefix or { return error('FileNotFoundError') }
	path := os.join_path(prefix, name)
	
	if !os.exists(path) {
		return error('FileNotFoundError')
	}
	
	return os.read_bytes(path) or { return error('FileNotFoundError') }
}

pub fn (mut s FilesystemMetadataStore) write(name string, data []u8, mtime ?i64) bool {
	if os.is_abs_path(name) {
		panic("Don't use absolute paths!")
	}
	prefix := s.cache_dir_prefix or { return false }
	path := os.join_path(prefix, name)
	
	// Временный файл для атомарной записи
	tmp_filename := path + '.' + time.now().unix().str()
	
	dir := os.dir(path)
	if !os.exists(dir) {
		os.mkdir_all(dir) or { return false }
	}
	
	os.write_file_array(tmp_filename, data) or { return false }
	
	// Атомарное перемещение
	os.mv(tmp_filename, path) or { 
		os.rm(tmp_filename) or {}
		return false
	}
	
	if val := mtime {
		// К сожалению, в стандартной библиотеке V (os) нет прямого аналога os.utime.
		// Заглушка.
	}
	
	return true
}

pub fn (mut s FilesystemMetadataStore) remove(name string) ! {
	prefix := s.cache_dir_prefix or { return error('FileNotFoundError') }
	path := os.join_path(prefix, name)
	os.rm(path) or { return error('FileNotFoundError') }
}

pub fn (mut s FilesystemMetadataStore) commit() {
	// Ничего не делает для Filesystem store
}

pub fn (mut s FilesystemMetadataStore) list_all() []string {
	prefix := s.cache_dir_prefix or { return [] }
	mut results := []string{}
	
	// Ограниченный обход файлов (заглушка для os.walk)
	files := os.ls(prefix) or { return [] }
	for file in files {
		// TODO: рекурсивный обход os.walk
		results << file
	}
	
	return results
}

pub fn (mut s FilesystemMetadataStore) close() {
}

// Заглушка для SqliteMetadataStore (если потребуется)
pub struct SqliteMetadataStore {
pub mut:
	cache_dir_prefix ?string
	sync_off bool
}

pub fn new_sqlite_metadata_store(cache_dir_prefix string, sync_off bool) SqliteMetadataStore {
	return SqliteMetadataStore{
		cache_dir_prefix: cache_dir_prefix,
		sync_off: sync_off
	}
}

// TODO: SqliteMetadataStore implementation
