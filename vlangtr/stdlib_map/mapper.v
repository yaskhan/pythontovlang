module stdlib_map

// StdLibMapper - маппер стандартной библиотеки Python в V
pub struct StdLibMapper {
pub mut:
	mappings  map[string]map[string]string
	v_imports map[string][]string
}

// new_stdlib_mapper создает новый экземпляр StdLibMapper
pub fn new_stdlib_mapper() StdLibMapper {
	mut mapper := StdLibMapper{
		mappings: map[string]map[string]string{}
		v_imports: map[string][]string{}
	}
	mapper.init_mappings()
	mapper.init_imports()
	return mapper
}

// init_mappings инициализирует маппинги
fn (mut m StdLibMapper) init_mappings() {
	// Math
	m.mappings['math'] = {
		'sqrt': 'math.sqrt'
		'sin': 'math.sin'
		'cos': 'math.cos'
		'tan': 'math.tan'
		'asin': 'math.asin'
		'acos': 'math.acos'
		'atan': 'math.atan'
		'atan2': 'math.atan2'
		'sinh': 'math.sinh'
		'cosh': 'math.cosh'
		'tanh': 'math.tanh'
		'exp': 'math.exp'
		'log': 'math.log'
		'log10': 'math.log10'
		'pow': 'math.pow'
		'ceil': 'math.ceil'
		'floor': 'math.floor'
		'fabs': 'math.abs'
		'pi': 'math.pi'
		'e': 'math.e'
		'degrees': 'math.degrees'
		'radians': 'math.radians'
	}

	// Random
	m.mappings['random'] = {
		'randint': 'rand.intn'
		'random': 'rand.f64'
		'choice': 'py_random_choice'
		'seed': 'rand.seed'
		'sample': 'py_random_sample'
		'shuffle': 'rand.shuffle'
		'uniform': 'rand.f64_in_range'
		'gauss': 'rand.normal'
	}

	// JSON
	m.mappings['json'] = {
		'loads': 'json.decode'
		'dumps': 'json.encode'
	}

	// Time
	m.mappings['time'] = {
		'time': 'time.now'
		'sleep': 'time.sleep'
	}

	// DateTime
	m.mappings['datetime'] = {
		'datetime.now': 'time.now'
		'date.today': 'time.now'
		'datetime': 'time.Time'
		'date': 'time.Time'
	}

	// Sys
	m.mappings['sys'] = {
		'exit': 'exit'
		'argv': 'os.args'
		'platform': 'os.user_os'
	}

	// IO
	m.mappings['io'] = {
		'StringIO': 'strings.new_builder'
	}

	// OS
	m.mappings['os'] = {
		'environ': 'os.environ'
		'getcwd': 'os.getwd'
		'system': 'os.system'
		'getenv': 'os.getenv'
		'mkdir': 'os.mkdir'
		'makedirs': 'os.mkdir_all'
		'remove': 'os.rm'
		'rmdir': 'os.rmdir'
		'listdir': 'os.ls'
		'path.join': 'os.join_path'
		'path.exists': 'os.exists'
		'path.isfile': 'os.is_file'
		'path.isdir': 'os.is_dir'
		'path.abspath': 'os.abs_path'
		'path.basename': 'os.base'
		'path.dirname': 'os.dir'
	}

	// Re
	m.mappings['re'] = {
		'match': 'regex.regex_opt'
		'search': 'regex.regex_opt'
		'compile': 'regex.regex_opt'
	}

	// Shutil
	m.mappings['shutil'] = {
		'copy': 'os.cp'
		'copy2': 'os.cp'
		'copyfile': 'os.cp'
		'move': 'os.mv'
		'rmtree': 'os.rmdir_all'
		'copytree': 'os.cp_all'
		'which': 'os.find_abs_path_of_executable'
		'chown': 'os.chown'
	}

	// Tempfile
	m.mappings['tempfile'] = {
		'gettempdir': 'os.temp_dir'
		'mkdtemp': 'os.mkdir_temp'
	}

	// Logging
	m.mappings['logging'] = {
		'info': 'log.info'
		'warning': 'log.warn'
		'error': 'log.error'
		'debug': 'log.debug'
		'critical': 'log.error'
	}

	// Argparse
	m.mappings['argparse'] = {
		'ArgumentParser': 'py_argparse_new'
	}

	// UUID
	m.mappings['uuid'] = {
		'uuid4': 'rand.uuid_v4'
	}

	// Collections
	m.mappings['collections'] = {
		'defaultdict': 'map[string]int'
		'Counter': 'py_counter'
	}

	// Itertools
	m.mappings['itertools'] = {
		'chain': 'py_chain'
		'repeat': 'py_repeat'
		'count': 'py_count'
		'cycle': 'py_cycle'
	}

	// Functools
	m.mappings['functools'] = {
		'reduce': 'py_reduce'
	}

	// Operator
	m.mappings['operator'] = {
		'add': 'py_op_add'
		'sub': 'py_op_sub'
		'mul': 'py_op_mul'
		'truediv': 'py_op_div'
		'floordiv': 'py_op_div'
		'mod': 'py_op_mod'
		'pow': 'math.pow'
		'eq': 'py_op_eq'
		'ne': 'py_op_ne'
		'lt': 'py_op_lt'
		'le': 'py_op_le'
		'gt': 'py_op_gt'
		'ge': 'py_op_ge'
		'not_': 'py_op_not'
		'and_': 'py_op_and'
		'or_': 'py_op_or'
		'xor': 'py_op_xor'
	}

	// Threading
	m.mappings['threading'] = {
		'Thread': 'PyThread'
		'Lock': 'sync.new_mutex'
	}

	// Socket
	m.mappings['socket'] = {
		'socket': 'py_socket_new'
		'AF_INET': 'py_AF_INET'
		'SOCK_STREAM': 'py_SOCK_STREAM'
	}

	// Pathlib
	m.mappings['pathlib'] = {
		'Path': 'py_path_new'
	}

	// URLlib
	m.mappings['urllib.request'] = {
		'urlopen': 'py_urlopen'
	}

	// HTTP
	m.mappings['http.client'] = {
		'HTTPConnection': 'py_http_connection'
	}

	// CSV
	m.mappings['csv'] = {
		'reader': 'py_csv_reader'
		'writer': 'py_csv_writer'
	}

	// SQLite
	m.mappings['sqlite3'] = {
		'connect': 'py_sqlite_connect'
	}

	// Subprocess
	m.mappings['subprocess'] = {
		'run': 'py_subprocess_run'
		'call': 'py_subprocess_call'
	}

	// Platform
	m.mappings['platform'] = {
		'system': 'os.user_os'
		'machine': 'py_platform_machine'
		'python_implementation': 'py_platform_python_implementation'
	}

	// Hashlib
	m.mappings['hashlib'] = {
		'sha256': 'py_hash_sha256'
		'md5': 'py_hash_md5'
	}

	// Base64
	m.mappings['base64'] = {
		'b64encode': 'base64.encode'
		'b64decode': 'base64.decode'
		'standard_b64encode': 'base64.encode'
		'standard_b64decode': 'base64.decode'
		'urlsafe_b64encode': 'base64.url_encode'
		'urlsafe_b64decode': 'base64.url_decode'
	}

	// URLlib Parse
	m.mappings['urllib.parse'] = {
		'urlparse': 'py_urlparse'
		'quote': 'urllib.query_escape'
		'quote_plus': 'urllib.query_escape'
		'unquote': 'py_urllib_unquote'
		'unquote_plus': 'py_urllib_unquote'
		'urlencode': 'py_urlencode'
	}

	// Zlib
	m.mappings['zlib'] = {
		'compress': 'py_zlib_compress'
		'decompress': 'py_zlib_decompress'
	}

	// Gzip
	m.mappings['gzip'] = {
		'compress': 'py_gzip_compress'
		'decompress': 'py_gzip_decompress'
	}

	// Copy
	m.mappings['copy'] = {
		'copy': 'py_copy'
		'deepcopy': 'py_deepcopy'
	}

	// Struct
	m.mappings['struct'] = {
		'pack': 'py_struct_pack'
		'unpack': 'py_struct_unpack'
		'calcsize': 'py_struct_calcsize'
	}

	// Array
	m.mappings['array'] = {
		'array': 'py_array'
	}

	// Fractions
	m.mappings['fractions'] = {
		'Fraction': 'fractions.fraction'
	}

	// Statistics
	m.mappings['statistics'] = {
		'mean': 'py_statistics_mean'
		'median': 'py_statistics_median'
		'mode': 'py_statistics_mode'
		'stdev': 'py_statistics_stdev'
		'variance': 'py_statistics_variance'
	}

	// Decimal
	m.mappings['decimal'] = {
		'Decimal': 'py_decimal'
		'localcontext': 'py_decimal_localcontext'
		'getcontext': 'py_decimal_getcontext'
	}

	// Pickle
	m.mappings['pickle'] = {
		'dumps': 'py_pickle_dumps'
		'loads': 'py_pickle_loads'
		'dump': 'py_pickle_dump'
		'load': 'py_pickle_load'
	}

	// Contextlib
	m.mappings['contextlib'] = {
		'closing': 'py_contextlib_closing'
		'nullcontext': 'py_contextlib_nullcontext'
		'suppress': 'py_contextlib_suppress'
		'redirect_stdout': 'py_contextlib_redirect_stdout'
	}

	// Typing
	m.mappings['typing'] = {
		'cast': 'py_typing_cast'
		'get_type_hints': 'py_get_type_hints'
	}

	// Annotationlib
	m.mappings['annotationlib'] = {
		'get_annotations': 'py_get_type_hints'
		'Format': 'PyAnnotationFormat'
	}
}

// init_imports инициализирует импорты
fn (mut m StdLibMapper) init_imports() {
	m.v_imports['math'] = ['math']
	m.v_imports['random'] = ['rand']
	m.v_imports['json'] = ['json']
	m.v_imports['time'] = ['time']
	m.v_imports['datetime'] = ['time']
	m.v_imports['sys'] = ['os']
	m.v_imports['io'] = ['strings']
	m.v_imports['os'] = ['os']
	m.v_imports['re'] = ['regex']
	m.v_imports['shutil'] = ['os']
	m.v_imports['tempfile'] = ['os']
	m.v_imports['logging'] = ['log']
	m.v_imports['argparse'] = ['os']
	m.v_imports['uuid'] = ['rand']
	m.v_imports['threading'] = ['sync']
	m.v_imports['socket'] = ['net']
	m.v_imports['pathlib'] = ['os']
	m.v_imports['urllib.request'] = ['net.http']
	m.v_imports['http.client'] = ['net.http']
	m.v_imports['csv'] = ['encoding.csv']
	m.v_imports['sqlite3'] = ['db.sqlite']
	m.v_imports['subprocess'] = ['os']
	m.v_imports['platform'] = ['os']
	m.v_imports['hashlib'] = ['crypto.sha256', 'crypto.md5', 'encoding.hex']
	m.v_imports['base64'] = ['encoding.base64']
	m.v_imports['urllib.parse'] = ['net.urllib']
	m.v_imports['zlib'] = ['compress.zlib']
	m.v_imports['gzip'] = ['compress.gzip']
	m.v_imports['struct'] = ['encoding.binary']
	m.v_imports['fractions'] = ['math.fractions']
	m.v_imports['statistics'] = ['math']
	m.v_imports['pickle'] = ['json']
	m.v_imports['string'] = ['strings']
}

// get_mapping возвращает V код для вызова Python функции
pub fn (m &StdLibMapper) get_mapping(module string, func string, args []string) ?string {
	if module !in m.mappings {
		// Обрабатываем подмодули
		if module.contains('.') {
			parts := module.split('.')
			for i := parts.len - 1; i > 0; i-- {
				prefix := parts[..i].join('.')
				suffix := parts[i..].join('.')
				if prefix in m.mappings {
					return m.get_mapping(prefix, '${suffix}.${func}', args)
				}
			}
		}
		return none
	}

	module_map := m.mappings[module]
	if func !in module_map {
		return none
	}

	handler := module_map[func]
	return '${handler}(${args.join(", ")})'
}

// get_constant_mapping возвращает V код для константы Python
pub fn (m &StdLibMapper) get_constant_mapping(module string, name string) ?string {
	if module !in m.mappings {
		// Обрабатываем подмодули
		if module.contains('.') {
			parts := module.split('.')
			for i := parts.len - 1; i > 0; i-- {
				prefix := parts[..i].join('.')
				suffix := parts[i..].join('.')
				if prefix in m.mappings {
					return m.get_constant_mapping(prefix, '${suffix}.${name}')
				}
			}
		}
		return none
	}

	module_map := m.mappings[module]
	if name !in module_map {
		return none
	}

	return module_map[name]
}

// get_imports возвращает список V импортов для Python модуля
pub fn (m &StdLibMapper) get_imports(module string) ?[]string {
	if module in m.v_imports {
		return m.v_imports[module]
	}

	// Обрабатываем подмодули
	if module.contains('.') {
		parts := module.split('.')
		for i := parts.len - 1; i > 0; i-- {
			prefix := parts[..i].join('.')
			if prefix in m.v_imports {
				return m.v_imports[prefix]
			}
		}
	}

	return none
}