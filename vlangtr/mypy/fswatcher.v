// Я Codex работаю над этим файлом. Начало: 2026-03-22 14:48:30 +05:00
module mypy

// Lightweight stat payload consumed by FileSystemWatcher.
pub struct FileStatData {
pub:
	st_mtime f64
	st_size  i64
}

// Minimal filesystem cache API used by watcher.
pub interface FileSystemWatcherFs {
	hash_digest(path string) string
	stat_or_none(path string) ?FileStatData
}

pub struct FileData {
pub:
	st_mtime f64
	st_size  i64
	hash     string
}

pub struct FileSystemWatcher {
pub mut:
	fs        FileSystemWatcherFs
	paths     map[string]bool
	file_data map[string]?FileData
}

pub fn new_file_system_watcher(fs FileSystemWatcherFs) FileSystemWatcher {
	return FileSystemWatcher{
		fs:        fs
		paths:     map[string]bool{}
		file_data: map[string]?FileData{}
	}
}

pub fn (w &FileSystemWatcher) dump_file_data() map[string]FileData {
	mut out := map[string]FileData{}
	for path, data in w.file_data {
		if d := data {
			out[path] = d
		}
	}
	return out
}

pub fn (mut w FileSystemWatcher) set_file_data(path string, data FileData) {
	w.file_data[path] = data
}

pub fn (mut w FileSystemWatcher) add_watched_paths(paths []string) {
	for path in paths {
		if path !in w.paths {
			w.file_data[path] = none
		}
		w.paths[path] = true
	}
}

pub fn (mut w FileSystemWatcher) remove_watched_paths(paths []string) {
	for path in paths {
		w.paths.delete(path)
		w.file_data.delete(path)
	}
}

fn (mut w FileSystemWatcher) update(path string, st FileStatData) {
	hash_digest := w.fs.hash_digest(path)
	w.file_data[path] = FileData{
		st_mtime: st.st_mtime
		st_size:  st.st_size
		hash:     hash_digest
	}
}

fn (mut w FileSystemWatcher) find_changed_in(paths []string) map[string]bool {
	mut changed := map[string]bool{}
	for path in paths {
		old := w.file_data[path] or { none }
		st := w.fs.stat_or_none(path)
		if cur := st {
			if old == none {
				changed[path] = true
				w.update(path, cur)
			} else if prev := old {
				if cur.st_size != prev.st_size || int(cur.st_mtime) != int(prev.st_mtime) {
					new_hash := w.fs.hash_digest(path)
					w.update(path, cur)
					if cur.st_size != prev.st_size || new_hash != prev.hash {
						changed[path] = true
					}
				}
			}
		} else {
			if old != none {
				changed[path] = true
				w.file_data[path] = none
			}
		}
	}
	return changed
}

pub fn (mut w FileSystemWatcher) find_changed() map[string]bool {
	mut watched := []string{}
	for path, enabled in w.paths {
		if enabled {
			watched << path
		}
	}
	return w.find_changed_in(watched)
}

pub fn (mut w FileSystemWatcher) update_changed(remove []string, update []string) map[string]bool {
	w.remove_watched_paths(remove)
	w.add_watched_paths(update)
	return w.find_changed_in(update)
}
