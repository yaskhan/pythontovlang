// Я Codex работаю над этим файлом. Начало: 2026-03-22 21:24:00 +05:00
module mypy

import os

pub struct FileSystemCache {
pub mut:
	package_root        []string            = []string{}
	stat_cache          map[string]os.Stat  = map[string]os.Stat{}
	missing_stat_cache  map[string]bool     = map[string]bool{}
	listdir_cache       map[string][]string = map[string][]string{}
	listdir_error_cache map[string]string   = map[string]string{}
	isfile_case_cache   map[string]bool     = map[string]bool{}
	exists_case_cache   map[string]bool     = map[string]bool{}
	read_cache          map[string][]u8     = map[string][]u8{}
	read_error_cache    map[string]string   = map[string]string{}
	hash_cache          map[string]string   = map[string]string{}
	fake_package_cache  map[string]bool     = map[string]bool{}
}

pub fn new_file_system_cache() FileSystemCache {
	return FileSystemCache{}
}

pub fn (mut fs FileSystemCache) set_package_root(package_root []string) {
	fs.package_root = package_root.clone()
}

pub fn (mut fs FileSystemCache) flush() {
	fs.stat_cache = map[string]os.Stat{}
	fs.missing_stat_cache = map[string]bool{}
	fs.listdir_cache = map[string][]string{}
	fs.listdir_error_cache = map[string]string{}
	fs.isfile_case_cache = map[string]bool{}
	fs.exists_case_cache = map[string]bool{}
	fs.read_cache = map[string][]u8{}
	fs.read_error_cache = map[string]string{}
	fs.hash_cache = map[string]string{}
	fs.fake_package_cache = map[string]bool{}
}

pub fn (mut fs FileSystemCache) stat_or_none(path string) ?FileStatData {
	st := fs.cached_stat_or_none(path)?
	return stat_to_file_data(st)
}

fn (mut fs FileSystemCache) cached_stat_or_none(path string) ?os.Stat {
	if path in fs.stat_cache {
		return fs.stat_cache[path]
	}
	if path in fs.missing_stat_cache {
		return none
	}

	st := os.stat(path) or {
		if fs.init_under_package_root(path) {
			fake_st := fs.fake_init(path) or {
				fs.missing_stat_cache[path] = true
				return none
			}
			fs.stat_cache[path] = fake_st
			return fake_st
		}
		fs.missing_stat_cache[path] = true
		return none
	}
	fs.stat_cache[path] = st
	return st
}

pub fn (mut fs FileSystemCache) init_under_package_root(path string) bool {
	if fs.package_root.len == 0 {
		return false
	}

	dirname := os.dir(path)
	basename := os.base(path)
	if basename != '__init__.py' {
		return false
	}
	if !is_identifier(os.base(dirname)) {
		return false
	}

	st := fs.cached_stat_or_none(dirname) or { return false }
	if st.get_filetype() != .directory {
		return false
	}

	current_drive := drive_prefix(os.abs_path(os.getwd()))
	drive := drive_prefix(path)
	if drive != '' && current_drive != '' && drive.to_lower() != current_drive.to_lower() {
		return false
	}

	mut normalized := path
	if os.is_abs_path(path) {
		normalized = relativize_to_cwd(path)
	}
	normalized = normalize_rel_path(normalized)

	for root in fs.package_root {
		norm_root := normalize_rel_path(root)
		if normalized.starts_with(norm_root) {
			if normalized == norm_root + '__init__.py' {
				return false
			}
			return true
		}
	}
	return false
}

pub fn is_identifier(s string) bool {
	if s.len == 0 {
		return false
	}
	first := s[0]
	if !first.is_letter() && first != `_` {
		return false
	}
	for i := 1; i < s.len; i++ {
		c := s[i]
		if !c.is_letter() && !c.is_digit() && c != `_` {
			return false
		}
	}
	return true
}

fn (mut fs FileSystemCache) fake_init(path string) ?os.Stat {
	dirname := normalize_rel_path(os.dir(path))
	if os.exists(path) {
		return none
	}
	st := os.stat(dirname) or { return none }
	fs.fake_package_cache[dirname] = true
	return st
}

pub fn (mut fs FileSystemCache) listdir(path string) ![]string {
	normalized := normalize_rel_path(path)
	if normalized in fs.listdir_cache {
		mut res := fs.listdir_cache[normalized].clone()
		if normalized in fs.fake_package_cache && '__init__.py' !in res {
			res << '__init__.py'
			fs.listdir_cache[normalized] = res.clone()
		}
		return res
	}
	if normalized in fs.listdir_error_cache {
		return error(fs.listdir_error_cache[normalized])
	}

	mut results := os.ls(normalized) or {
		fs.listdir_error_cache[normalized] = err.msg()
		return err
	}
	if normalized in fs.fake_package_cache && '__init__.py' !in results {
		results << '__init__.py'
	}
	fs.listdir_cache[normalized] = results.clone()
	return results
}

pub fn (mut fs FileSystemCache) isfile(path string) bool {
	st := fs.cached_stat_or_none(path) or { return false }
	return st.get_filetype() == .regular || st.get_filetype() == .symbolic_link
}

pub fn (mut fs FileSystemCache) isfile_case(path string, prefix string) bool {
	if !fs.isfile(path) {
		return false
	}
	if path in fs.isfile_case_cache {
		return fs.isfile_case_cache[path]
	}

	head := os.dir(path)
	tail := os.base(path)
	if tail == '' || tail == '.' {
		fs.isfile_case_cache[path] = false
		return false
	}

	names := fs.listdir(head) or {
		fs.isfile_case_cache[path] = false
		return false
	}
	mut res := tail in names
	if res {
		res = fs.exists_case(head, prefix)
	}
	fs.isfile_case_cache[path] = res
	return res
}

pub fn (mut fs FileSystemCache) exists_case(path string, prefix string) bool {
	if path in fs.exists_case_cache {
		return fs.exists_case_cache[path]
	}

	head := os.dir(path)
	tail := os.base(path)
	if !head.starts_with(prefix) || tail == '' || tail == '.' {
		fs.exists_case_cache[path] = true
		return true
	}

	names := fs.listdir(head) or {
		fs.exists_case_cache[path] = false
		return false
	}
	mut res := tail in names
	if res {
		res = fs.exists_case(head, prefix)
	}
	fs.exists_case_cache[path] = res
	return res
}

pub fn (mut fs FileSystemCache) isdir(path string) bool {
	st := fs.cached_stat_or_none(path) or { return false }
	return st.get_filetype() == .directory
}

pub fn (mut fs FileSystemCache) exists(path string) bool {
	if _ := fs.cached_stat_or_none(path) {
		return true
	}
	return false
}

pub fn (mut fs FileSystemCache) read(path string) ![]u8 {
	if path in fs.read_cache {
		return fs.read_cache[path]
	}
	if path in fs.read_error_cache {
		return error(fs.read_error_cache[path])
	}

	fs.cached_stat_or_none(path) or {}

	dirname := normalize_rel_path(os.dir(path))
	basename := os.base(path)
	if basename == '__init__.py' && dirname in fs.fake_package_cache {
		data := []u8{}
		fs.read_cache[path] = data
		fs.hash_cache[path] = hash_bytes_digest(data)
		return data
	}

	data := os.read_bytes(path) or {
		fs.read_error_cache[path] = err.msg()
		return err
	}
	fs.read_cache[path] = data.clone()
	fs.hash_cache[path] = hash_bytes_digest(data)
	return data
}

pub fn (mut fs FileSystemCache) hash_digest(path string) string {
	if path !in fs.hash_cache {
		fs.read(path) or { return '' }
	}
	return fs.hash_cache[path]
}

pub fn (mut fs FileSystemCache) samefile(f1 string, f2 string) bool {
	s1 := fs.cached_stat_or_none(f1) or { return false }
	s2 := fs.cached_stat_or_none(f2) or { return false }

	if s1.dev == s2.dev && s1.inode != 0 && s1.inode == s2.inode {
		return true
	}
	return os.norm_path(os.abs_path(f1)) == os.norm_path(os.abs_path(f2))
}

fn stat_to_file_data(st os.Stat) FileStatData {
	return FileStatData{
		st_mtime: f64(st.mtime)
		st_size:  st.size
	}
}

fn hash_bytes_digest(data []u8) string {
	return '${data.len}'
}

fn drive_prefix(path string) string {
	if path.len >= 2 && path[1] == `:` {
		return path[..2]
	}
	return ''
}

fn normalize_rel_path(path string) string {
	mut normalized := os.norm_path(path)
	if normalized == '' {
		return '.'
	}
	if normalized.ends_with(os.path_separator.str()) && normalized.len > 1 {
		normalized = normalized.trim_right(os.path_separator.str())
	}
	return normalized
}

fn relativize_to_cwd(path string) string {
	cwd := normalize_rel_path(os.abs_path(os.getwd()))
	target := normalize_rel_path(os.abs_path(path))
	if drive_prefix(cwd).to_lower() != drive_prefix(target).to_lower() {
		return target
	}
	if target == cwd {
		return '.'
	}
	prefix := cwd + os.path_separator.str()
	if target.starts_with(prefix) {
		return target[prefix.len..]
	}
	return target
}
