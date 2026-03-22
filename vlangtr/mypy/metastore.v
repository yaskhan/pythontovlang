// metastore.v — Interfaces for accessing metadata
// Translated from mypy/metastore.py to V 0.5.x
//
// Work in progress by Antigravity. Started: 2026-03-22 15:30

module mypy

import os
import time

// MetadataStore — interface for metadata storage
pub interface MetadataStore {
	getmtime(name string) !f64
	read(name string) ![]u8
	write(name string, data []u8, mtime ?f64) bool
	remove(name string) !
	commit()
	list_all() []string
	close()
}

// random_string generates random string
pub fn random_string() string {
	// Simplified version — use time
	return '${time.now().unixNano()}'
}

// FilesystemMetadataStore — filesystem-based implementation
pub struct FilesystemMetadataStore {
pub mut:
	cache_dir_prefix ?string
}

// new_filesystem_metadata_store creates a new FilesystemMetadataStore
pub fn new_filesystem_metadata_store(cache_dir_prefix string) FilesystemMetadataStore {
	// Check if path is os.devnull
	if cache_dir_prefix.starts_with(os.devnull) {
		return FilesystemMetadataStore{
			cache_dir_prefix: none
		}
	}
	return FilesystemMetadataStore{
		cache_dir_prefix: cache_dir_prefix
	}
}

// getmtime читает mtime записи метаданных
pub fn (mut fs FilesystemMetadataStore) getmtime(name string) !f64 {
	if fs.cache_dir_prefix == none {
		return error('FileNotFound')
	}

	prefix := fs.cache_dir_prefix or { '' }
	path := os.join_path(prefix, name)
	info := os.stat(path) or { return error('FileNotFound') }
	return info.mod_time().unix()
}

// read читает содержимое записи метаданных
pub fn (mut fs FilesystemMetadataStore) read(name string) ![]u8 {
	if fs.cache_dir_prefix == none {
		return error('FileNotFound')
	}

	prefix := fs.cache_dir_prefix or { '' }
	path := os.join_path(prefix, name)
	return os.read_file(path)
}

// write записывает запись метаданных
pub fn (mut fs FilesystemMetadataStore) write(name string, data []u8, mtime ?f64) bool {
	if fs.cache_dir_prefix == none {
		return false
	}

	prefix := fs.cache_dir_prefix or { '' }
	path := os.join_path(prefix, name)
	tmp_filename := path + '.' + random_string()

	os.mkdir_all(os.dir(path), os.default_dir_mod) or { return false }

	os.write_file(tmp_filename, data) or { return false }
	os.rename(tmp_filename, path) or { return false }

	if mtime != none {
		mt := mtime or { 0.0 }
		// os.utime(path, mt, mt) or { /* ignore */ }
	}

	return true
}

// remove удаляет запись метаданных
pub fn (mut fs FilesystemMetadataStore) remove(name string) ! {
	if fs.cache_dir_prefix == none {
		return error('FileNotFound')
	}

	prefix := fs.cache_dir_prefix or { '' }
	path := os.join_path(prefix, name)
	os.rm(path) or { return error('FileNotFound') }
}

// commit performs commit (does nothing for filesystem)
pub fn (mut fs FilesystemMetadataStore) commit() {
	// Do nothing
}

// list_all returns all metadata records
pub fn (mut fs FilesystemMetadataStore) list_all() []string {
	mut result := []string{}

	if fs.cache_dir_prefix == none {
		return result
	}

	prefix := fs.cache_dir_prefix or { '' }
	walk_fn := fn (path string, info &os.FileInfo) bool {
		if !info.is_dir() {
			rel_path := os.rel(path, prefix) or { path }
			result << os.normpath(rel_path)
		}
		return true
	}
	os.walk(prefix, walk_fn) or {
		// ignore
	}

	return result
}

// close releases resources
pub fn (mut fs FilesystemMetadataStore) close() {
	// Do nothing
}

// SqliteMetadataStore — SQLite-based implementation (stub)
// Full version would require sqlite connection
pub struct SqliteMetadataStore {
pub mut:
	cache_dir_prefix ?string
	db               voidptr // Stub for sqlite connection
}

// new_sqlite_metadata_store creates a new SqliteMetadataStore
pub fn new_sqlite_metadata_store(cache_dir_prefix string, sync_off bool) SqliteMetadataStore {
	if cache_dir_prefix.starts_with(os.devnull) {
		return SqliteMetadataStore{
			cache_dir_prefix: none
			db:               voidptr(none)
		}
	}

	os.mkdir_all(cache_dir_prefix, os.default_dir_mod) or {
		// ignore
	}

	// In full version would be sqlite connection here
	// db := connect_db(os.join_path(cache_dir_prefix, 'cache.db'), sync_off)

	return SqliteMetadataStore{
		cache_dir_prefix: cache_dir_prefix
		db:               voidptr(none)
	}
}

// getmtime reads mtime of metadata record
pub fn (mut sq SqliteMetadataStore) getmtime(name string) !f64 {
	if sq.db == voidptr(none) {
		return error('FileNotFound')
	}
	// In full version: SELECT mtime FROM files2 WHERE path = ?
	return 0.0
}

// read reads contents of metadata record
pub fn (mut sq SqliteMetadataStore) read(name string) ![]u8 {
	if sq.db == voidptr(none) {
		return error('FileNotFound')
	}
	// In full version: SELECT data FROM files2 WHERE path = ?
	return []u8{}
}

// write writes metadata record
pub fn (mut sq SqliteMetadataStore) write(name string, data []u8, mtime ?f64) bool {
	if sq.db == voidptr(none) {
		return false
	}

	mt := mtime or { time.now().unix() }
	// In full version: INSERT OR REPLACE INTO files2(path, mtime, data) VALUES(?, ?, ?)
	_ = mt
	return true
}

// remove removes metadata record
pub fn (mut sq SqliteMetadataStore) remove(name string) ! {
	if sq.db == voidptr(none) {
		return error('FileNotFound')
	}
	// In full version: DELETE FROM files2 WHERE path = ?
}

// commit performs commit
pub fn (mut sq SqliteMetadataStore) commit() {
	// In full version: db.commit()
}

// list_all returns all metadata records
pub fn (mut sq SqliteMetadataStore) list_all() []string {
	// In full version: SELECT path FROM files2
	return []string{}
}

// close releases resources
pub fn (mut sq SqliteMetadataStore) close() {
	if sq.db != voidptr(none) {
		// In full version: db.close()
		sq.db = voidptr(none)
	}
}
