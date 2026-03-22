// defaults.v — Default values and constants for mypy
// Translated from mypy/defaults.py to V 0.5.x

module mypy

// ---------------------------------------------------------------------------
// Python version constants
// ---------------------------------------------------------------------------

pub struct PythonVersion {
pub:
	major int
	minor int
}

// Earliest fully supported Python 3.x version.
pub const python3_version = PythonVersion{
	major: 3
	minor: 10
}

// Earliest Python 3.x version supported via --python-version 3.x.
pub const python3_version_min = PythonVersion{
	major: 3
	minor: 9
}

// ---------------------------------------------------------------------------
// Cache and config constants
// ---------------------------------------------------------------------------

pub const cache_dir = '.mypy_cache'

pub const config_names = ['mypy.ini', '.mypy.ini']
pub const shared_config_names = ['pyproject.toml', 'setup.cfg']

// ---------------------------------------------------------------------------
// Reporter names
// ---------------------------------------------------------------------------

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

pub const many_errors_threshold = -1

pub const recursion_limit = 1 << 14 // 2^14

// ---------------------------------------------------------------------------
// Worker timeouts
// ---------------------------------------------------------------------------

pub const worker_start_interval = 0.01
pub const worker_start_timeout = 3
pub const worker_connection_timeout = 10
pub const worker_done_timeout = 600
