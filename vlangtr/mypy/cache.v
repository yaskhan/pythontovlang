// cache.v — High-level logic for fixed format serialization
// Translated from mypy/cache.py

module mypy

// Cache version constant
pub const cache_version = 7

pub type CacheValue = bool
	| f64
	| int
	| string
	| []CacheValue
	| []int
	| []string
	| []u8
	| map[string]CacheValue
	| map[string][]string

// ErrorInfo — structure for representing errors

// CacheMeta — cache metadata for a module
pub struct CacheMeta {
pub mut:
	id                   string
	path                 string
	mtime                int
	size                 int
	hash                 string
	dependencies         []string
	data_mtime           int
	data_file            string
	suppressed           []string
	imports_ignored      map[int][]string
	options              map[string]CacheValue
	suppressed_deps_opts []u8
	dep_prios            []int
	dep_lines            []int
	dep_hashes           [][]u8
	interface_hash       []u8
	trans_dep_hash       []u8
	version_id           string
	ignore_all           bool
	plugin_data          CacheValue
}

// new_cache_meta creates a new CacheMeta
pub fn new_cache_meta(id string, path string, mtime int, size int, hash string, dependencies []string, data_mtime int, data_file string, suppressed []string, imports_ignored map[int][]string, options map[string]CacheValue, suppressed_deps_opts []u8, dep_prios []int, dep_lines []int, dep_hashes [][]u8, interface_hash []u8, trans_dep_hash []u8, version_id string, ignore_all bool, plugin_data CacheValue) CacheMeta {
	return CacheMeta{
		id:                   id
		path:                 path
		mtime:                mtime
		size:                 size
		hash:                 hash
		dependencies:         dependencies
		data_mtime:           data_mtime
		data_file:            data_file
		suppressed:           suppressed
		imports_ignored:      imports_ignored
		options:              options
		suppressed_deps_opts: suppressed_deps_opts
		dep_prios:            dep_prios
		dep_lines:            dep_lines
		dep_hashes:           dep_hashes
		interface_hash:       interface_hash
		trans_dep_hash:       trans_dep_hash
		version_id:           version_id
		ignore_all:           ignore_all
		plugin_data:          plugin_data
	}
}

// serialize converts CacheMeta to map
pub fn (cm CacheMeta) serialize() map[string]CacheValue {
	mut imports_ignored_serialized := map[string][]string{}
	for line, codes in cm.imports_ignored {
		imports_ignored_serialized[line.str()] = codes
	}
	return {
		'id':                   CacheValue(cm.id)
		'path':                 CacheValue(cm.path)
		'mtime':                CacheValue(cm.mtime)
		'size':                 CacheValue(cm.size)
		'hash':                 CacheValue(cm.hash)
		'data_mtime':           CacheValue(cm.data_mtime)
		'dependencies':         CacheValue(cm.dependencies)
		'suppressed':           CacheValue(cm.suppressed)
		'imports_ignored':      CacheValue(imports_ignored_serialized)
		'options':              CacheValue(cm.options)
		'suppressed_deps_opts': CacheValue(cm.suppressed_deps_opts.hex())
		'dep_prios':            CacheValue(cm.dep_prios)
		'dep_lines':            CacheValue(cm.dep_lines)
		'dep_hashes':           CacheValue(cm.dep_hashes.map(it.hex()))
		'interface_hash':       CacheValue(cm.interface_hash.hex())
		'trans_dep_hash':       CacheValue(cm.trans_dep_hash.hex())
		'version_id':           CacheValue(cm.version_id)
		'ignore_all':           CacheValue(cm.ignore_all)
		'plugin_data':          cm.plugin_data
	}
}

// deserialize converts map to CacheMeta
pub fn cache_meta_deserialize(meta map[string]CacheValue, data_file string) ?CacheMeta {
	id := meta['id'] or { return none } as string
	path := meta['path'] or { return none } as string
	mtime := meta['mtime'] or { return none } as int
	size := meta['size'] or { return none } as int
	hash := meta['hash'] or { return none } as string
	dependencies := meta['dependencies'] or { return none } as []string
	data_mtime := meta['data_mtime'] or { return none } as int
	suppressed := meta['suppressed'] or { return none } as []string
	options := meta['options'] or { return none } as map[string]CacheValue
	suppressed_deps_opts_hex := meta['suppressed_deps_opts'] or { return none } as string
	dep_prios := meta['dep_prios'] or { return none } as []int
	dep_lines := meta['dep_lines'] or { return none } as []int
	dep_hashes_hex := meta['dep_hashes'] or { return none } as []string
	interface_hash_hex := meta['interface_hash'] or { return none } as string
	trans_dep_hash_hex := meta['trans_dep_hash'] or { return none } as string
	version_id := meta['version_id'] or { return none } as string
	ignore_all := meta['ignore_all'] or { return none } as bool
	plugin_data := meta['plugin_data'] or { return none }

	return CacheMeta{
		id:                   id
		path:                 path
		mtime:                mtime
		size:                 size
		hash:                 hash
		dependencies:         dependencies
		data_mtime:           data_mtime
		data_file:            data_file
		suppressed:           suppressed
		imports_ignored:      map[int][]string{}
		options:              options
		suppressed_deps_opts: suppressed_deps_opts_hex.bytes()
		dep_prios:            dep_prios
		dep_lines:            dep_lines
		dep_hashes:           dep_hashes_hex.map(it.bytes())
		interface_hash:       interface_hash_hex.bytes()
		trans_dep_hash:       trans_dep_hash_hex.bytes()
		version_id:           version_id
		ignore_all:           ignore_all
		plugin_data:          plugin_data
	}
}

// Tags for types in FF format
pub const literal_false = u8(0)
pub const literal_true = u8(1)
pub const literal_none = u8(2)
pub const literal_int = u8(3)
pub const literal_str = u8(4)
pub const literal_bytes = u8(5)
pub const literal_float = u8(6)
pub const literal_complex = u8(7)

// Tags for collections
pub const list_gen = u8(20)
pub const list_int = u8(21)
pub const list_str = u8(22)
pub const list_bytes = u8(23)
pub const tuple_gen = u8(24)
pub const dict_str_gen = u8(30)
pub const dict_int_gen = u8(31)

// Special tags
pub const extra_attrs = u8(150)
pub const dt_spec = u8(151)
pub const location = u8(152)
pub const end_tag = u8(255)

// read_literal reads a literal from buffer
pub fn read_literal(data []u8, tag u8) CacheValue {
	if tag == literal_int {
		mut local := data.clone()
		return read_int_bare(mut local)
	} else if tag == literal_str {
		mut local := data.clone()
		return read_str_bare(mut local)
	} else if tag == literal_false {
		return false
	} else if tag == literal_true {
		return true
	} else if tag == literal_float {
		mut local := data.clone()
		return read_float_bare(mut local)
	}
	panic('Unknown literal tag ${tag}')
}

// write_literal writes a literal to buffer
pub fn write_literal(mut data []u8, value CacheValue) {
	if value is bool {
		write_bool(mut data, value)
	} else if value is int {
		write_tag(mut data, literal_int)
		write_int_bare(mut data, value)
	} else if value is string {
		write_tag(mut data, literal_str)
		write_str_bare(mut data, value)
	} else if value is f64 {
		write_tag(mut data, literal_float)
		write_float_bare(mut data, value)
	} else {
		write_tag(mut data, literal_none)
	}
}

// read_int reads int from buffer
pub fn read_int(mut data []u8) int {
	assert read_tag(mut data) == literal_int
	return read_int_bare(mut data)
}

// write_int writes int to buffer
pub fn write_int(mut data []u8, value int) {
	write_tag(mut data, literal_int)
	write_int_bare(mut data, value)
}

// read_str reads a string from buffer
pub fn read_str(mut data []u8) string {
	assert read_tag(mut data) == literal_str
	return read_str_bare(mut data)
}

// write_str writes a string to buffer
pub fn write_str(mut data []u8, value string) {
	write_tag(mut data, literal_str)
	write_str_bare(mut data, value)
}

// read_bytes reads bytes from buffer
pub fn read_bytes(mut data []u8) []u8 {
	assert read_tag(mut data) == literal_bytes
	return read_bytes_bare(mut data)
}

// write_bytes writes bytes to buffer
pub fn write_bytes(mut data []u8, value []u8) {
	write_tag(mut data, literal_bytes)
	write_bytes_bare(mut data, value)
}

// read_int_list reads a list of ints from buffer
pub fn read_int_list(mut data []u8) []int {
	assert read_tag(mut data) == list_int
	size := read_int_bare(mut data)
	mut result := []int{}
	for _ in 0 .. size {
		result << read_int_bare(mut data)
	}
	return result
}

// write_int_list writes a list of ints to buffer
pub fn write_int_list(mut data []u8, value []int) {
	write_tag(mut data, list_int)
	write_int_bare(mut data, value.len)
	for item in value {
		write_int_bare(mut data, item)
	}
}

// read_str_list reads a list of strings from buffer
pub fn read_str_list(mut data []u8) []string {
	assert read_tag(mut data) == list_str
	size := read_int_bare(mut data)
	mut result := []string{}
	for _ in 0 .. size {
		result << read_str_bare(mut data)
	}
	return result
}

// write_str_list writes a list of strings to buffer
pub fn write_str_list(mut data []u8, value []string) {
	write_tag(mut data, list_str)
	write_int_bare(mut data, value.len)
	for item in value {
		write_str_bare(mut data, item)
	}
}

// read_json_value reads a JSON value from buffer
pub fn read_json_value(mut data []u8) CacheValue {
	tag := read_tag(mut data)
	if tag == literal_none {
		return ''
	}
	if tag == literal_false {
		return false
	}
	if tag == literal_true {
		return true
	}
	if tag == literal_int {
		return read_int_bare(mut data)
	}
	if tag == literal_str {
		return read_str_bare(mut data)
	}
	if tag == list_gen {
		size := read_int_bare(mut data)
		mut result := []CacheValue{}
		for _ in 0 .. size {
			result << read_json_value(mut data)
		}
		return result
	}
	if tag == dict_str_gen {
		size := read_int_bare(mut data)
		mut result := map[string]CacheValue{}
		for _ in 0 .. size {
			key := read_str_bare(mut data)
			result[key] = read_json_value(mut data)
		}
		return result
	}
	panic('Invalid JSON tag: ${tag}')
}

// write_json_value writes a JSON value to buffer
pub fn write_json_value(mut data []u8, value CacheValue) {
	if value is bool {
		write_bool(mut data, value)
	} else if value is int {
		write_tag(mut data, literal_int)
		write_int_bare(mut data, value)
	} else if value is string {
		write_tag(mut data, literal_str)
		write_str_bare(mut data, value)
	} else if value is []CacheValue {
		write_tag(mut data, list_gen)
		write_int_bare(mut data, value.len)
		for val in value {
			write_json_value(mut data, val)
		}
	} else if value is map[string]CacheValue {
		write_tag(mut data, dict_str_gen)
		write_int_bare(mut data, value.len)
		for key in value.keys().sorted() {
			write_str_bare(mut data, key)
			write_json_value(mut data, value[key] or { continue })
		}
	} else {
		write_tag(mut data, literal_none)
	}
}

// write_errors writes a list of errors to buffer
pub fn write_errors(mut data []u8, errs []ErrorInfo) {
	write_tag(mut data, list_gen)
	write_int_bare(mut data, errs.len)
	for err in errs {
		write_tag(mut data, tuple_gen)
		write_str_opt(mut data, if err.file != '' { err.file } else { none })
		write_int(mut data, err.line)
		write_int(mut data, err.column)
		write_int(mut data, err.end_line)
		write_int(mut data, err.end_column)
		write_str(mut data, err.severity)
		write_str(mut data, err.message)
		write_str_opt(mut data, err.code)
	}
}

// read_errors reads a list of errors from buffer
pub fn read_errors(mut data []u8) []ErrorInfo {
	assert read_tag(mut data) == list_gen
	mut result := []ErrorInfo{}
	for _ in 0 .. read_int_bare(mut data) {
		assert read_tag(mut data) == tuple_gen
		result << ErrorInfo{
			file:       read_str_opt(mut data) or { '' }
			line:       read_int(mut data)
			column:     read_int(mut data)
			end_line:   read_int(mut data)
			end_column: read_int(mut data)
			severity:   read_str(mut data)
			message:    read_str(mut data)
			code:       read_str_opt(mut data)
		}
	}
	return result
}

// Helper stub functions
fn read_tag(mut data []u8) u8 {
	if data.len > 0 {
		tag := data[0]
		data = data[1..]
		return tag
	}
	return 0
}

fn write_tag(mut data []u8, tag u8) {
	data << tag
}

fn read_int_bare(mut data []u8) int {
	// TODO: implementation of reading int from buffer
	return 0
}

fn write_int_bare(mut data []u8, value int) {
	// TODO: implementation of writing int to buffer
}

fn read_str_bare(mut data []u8) string {
	// TODO: implementation of reading string from buffer
	return ''
}

fn write_str_bare(mut data []u8, value string) {
	// TODO: implementation of writing string to buffer
}

fn read_bytes_bare(mut data []u8) []u8 {
	// TODO: implementation of reading bytes from buffer
	return []
}

fn write_bytes_bare(mut data []u8, value []u8) {
	// TODO: implementation of writing bytes to buffer
}

fn read_float_bare(mut data []u8) f64 {
	// TODO: implementation of reading float from buffer
	return 0.0
}

fn write_float_bare(mut data []u8, value f64) {
	// TODO: implementation of writing float to buffer
}

fn write_bool(mut data []u8, value bool) {
	if value {
		write_tag(mut data, literal_true)
	} else {
		write_tag(mut data, literal_false)
	}
}

fn read_bool(mut data []u8) bool {
	tag := read_tag(mut data)
	return tag == literal_true
}

fn read_str_opt(mut data []u8) ?string {
	tag := read_tag(mut data)
	if tag == literal_none {
		return none
	}
	assert tag == literal_str
	return read_str_bare(mut data)
}

fn write_str_opt(mut data []u8, value ?string) {
	if value != none {
		write_tag(mut data, literal_str)
		write_str_bare(mut data, value)
	} else {
		write_tag(mut data, literal_none)
	}
}
