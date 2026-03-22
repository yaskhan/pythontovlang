// defaults.v — Default values and constants for mypy
// Translated from mypy/defaults.py to V 0.5.x
//
// Я Cline работаю над этим файлом. Начало: 2026-03-22 08:35
//
// Translation notes:
//   - Python Final constants → V module-level constants
//   - Python os.environ → V os.environ (similar)
//   - Python list comprehension → V array initialization

module mypy

// ---------------------------------------------------------------------------
// Python version constants
// ---------------------------------------------------------------------------

// Earliest fully supported Python 3.x version. Used as the default Python
// version in tests. Mypy wheels should be built starting with this version,
// and CI tests should be run on this version (and later versions).
pub const python3_version = struct {major, int, minor, int}

{
	3, 10
}

// Earliest Python 3.x version supported via --python-version 3.x. To run
// mypy, at least version PYTHON3_VERSION is needed.
pub const python3_version_min = struct {major, int, minor, int}

{
	3, 9
}
// Keep in sync with typeshed's python support

// ---------------------------------------------------------------------------
// Cache and config constants
// ---------------------------------------------------------------------------

pub const cache_dir = '.mypy_cache'

pub const config_names = ['mypy.ini', '.mypy.ini']
pub const shared_config_names = ['pyproject.toml', 'setup.cfg']

// ---------------------------------------------------------------------------
// Reporter names
// ---------------------------------------------------------------------------

// This must include all reporters defined in mypy.report. This is defined here
// to make reporter names available without importing mypy.report -- this speeds
// up startup.
pub const reporter_names = [
	'linecount',
	'any-exprs',
	'linecoverage',
	'memory-xml',
	'cobertura-xml',
	'xml',
	'xslt-html',
	'xslt-txt',
	'html',
	'txt',
	'lineprecision',
]

// ---------------------------------------------------------------------------
// Thresholds and limits
// ---------------------------------------------------------------------------

// Threshold after which we sometimes filter out most errors to avoid very
// verbose output. The default is to show all errors.
pub const many_errors_threshold = -1

pub const recursion_limit = 1 << 14 // 2^14

// ---------------------------------------------------------------------------
// Worker timeouts
// ---------------------------------------------------------------------------

pub const worker_start_interval = 0.01
pub const worker_start_timeout = 3
pub const worker_connection_timeout = 10
pub const worker_done_timeout = 600
