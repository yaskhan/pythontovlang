// I, Qwen Code, am working on this file. Started: 2026-03-22 22:00
// Stub information utilities for mypy (stubinfo.py)

module mypy

import os

// stub_distribution_name returns the name of the stub distribution for a module.
// For example, 'types-requests' for 'requests' module.
// Returns none if the module doesn't have a separate stub distribution.
// Map of module names to their stub package names
const module_to_stub = {
	'requests':        'types-requests'
	'urllib3':         'types-urllib3'
	'six':             'types-six'
	'dateutil':        'types-python-dateutil'
	'pytz':            'types-pytz'
	'cachetools':      'types-cachetools'
	'yaml':            'types-PyYAML'
	'setuptools':      'types-setuptools'
	'google.protobuf': 'types-protobuf'
	'toml':            'types-toml'
	'redis':           'types-redis'
	'paramiko':        'types-paramiko'
	'OpenSSL':         'types-pyOpenSSL'
	'jmespath':        'types-jmespath'
	'docutils':        'types-docutils'
	'scribe':          'types-pyscribe'
	'colorama':        'types-colorama'
	'waitress':        'types-waitress'
	'freezegun':       'types-freezegun'
	'mock':            'types-mock'
	'tabulate':        'types-tabulate'
	'tqdm':            'types-tqdm'
	'werkzeug':        'types-Werkzeug'
	'flask':           'types-Flask'
	'jwt':             'types-PyJWT'
	'bleach':          'types-bleach'
	'html5lib':        'types-html5lib'
	'markdown':        'types-Markdown'
	'PIL':             'types-Pillow'
	'attr':            'types-attrs'
	'winreg':          'types-pywin32'
	'_winapi':         'types-pywin32'
	'winsound':        'types-pywin32'
	'wsgiref':         'types-wsgiref'
}

pub fn stub_distribution_name(mod_name string) ?string {
	// Check direct mapping
	if mod_name in module_to_stub {
		return module_to_stub[mod_name]
	}
	// Check if module starts with a known package prefix
	for prefix, stub in module_to_stub {
		if mod_name.starts_with(prefix + '.') {
			return stub
		}
	}
	return none
}

// is_module_from_legacy_bundled_package checks if a module is from a legacy bundled package.
// Legacy bundled packages are those that were included with mypy in older versions.
// List of modules that were historically bundled with mypy
const legacy_bundled_packages = [
	'six',
	'typing',
	'typing_extensions',
	'mypy_extensions',
	'typed_ast',
]

pub fn is_module_from_legacy_bundled_package(mod_name string) bool {
	// Check exact match
	if mod_name in legacy_bundled_packages {
		return true
	}
	// Check if it's a submodule of a legacy package
	for pkg in legacy_bundled_packages {
		if mod_name.starts_with(pkg + '.') {
			return true
		}
	}
	return false
}

// known_stub_packages returns a list of known stub package names.
pub fn known_stub_packages() []string {
	// Common stub packages from typeshed and PyPI
	return [
		'types-requests',
		'types-urllib3',
		'types-six',
		'types-python-dateutil',
		'types-pytz',
		'types-cachetools',
		'types-PyYAML',
		'types-setuptools',
		'types-protobuf',
		'types-toml',
	]
}

// Standard library modules that have built-in stubs in typeshed
const stdlib_modules = {
	'__future__':      true
	'abc':             true
	'aifc':            true
	'argparse':        true
	'array':           true
	'ast':             true
	'asynchat':        true
	'asyncio':         true
	'asyncore':        true
	'atexit':          true
	'audioop':         true
	'base64':          true
	'bdb':             true
	'binascii':        true
	'binhex':          true
	'bisect':          true
	'builtins':        true
	'bz2':             true
	'calendar':        true
	'cgi':             true
	'cgitb':           true
	'chunk':           true
	'cmath':           true
	'cmd':             true
	'code':            true
	'codecs':          true
	'codeop':          true
	'collections':     true
	'colorsys':        true
	'compileall':      true
	'concurrent':      true
	'configparser':    true
	'contextlib':      true
	'contextvars':     true
	'copy':            true
	'copyreg':         true
	'cProfile':        true
	'crypt':           true
	'csv':             true
	'ctypes':          true
	'curses':          true
	'dataclasses':     true
	'datetime':        true
	'dbm':             true
	'decimal':         true
	'difflib':         true
	'dis':             true
	'distutils':       true
	'doctest':         true
	'email':           true
	'encodings':       true
	'enum':            true
	'errno':           true
	'faulthandler':    true
	'fcntl':           true
	'filecmp':         true
	'fileinput':       true
	'fnmatch':         true
	'fractions':       true
	'ftplib':          true
	'functools':       true
	'gc':              true
	'getopt':          true
	'getpass':         true
	'gettext':         true
	'glob':            true
	'graphlib':        true
	'grp':             true
	'gzip':            true
	'hashlib':         true
	'heapq':           true
	'hmac':            true
	'html':            true
	'http':            true
	'idlelib':         true
	'imaplib':         true
	'imghdr':          true
	'imp':             true
	'importlib':       true
	'inspect':         true
	'io':              true
	'ipaddress':       true
	'itertools':       true
	'json':            true
	'keyword':         true
	'lib2to3':         true
	'linecache':       true
	'locale':          true
	'logging':         true
	'lzma':            true
	'mailbox':         true
	'mailcap':         true
	'marshal':         true
	'math':            true
	'mimetypes':       true
	'mmap':            true
	'modulefinder':    true
	'msvcrt':          true
	'multiprocessing': true
	'netrc':           true
	'nis':             true
	'nntplib':         true
	'numbers':         true
	'operator':        true
	'optparse':        true
	'os':              true
	'ossaudiodev':     true
	'parser':          true
	'pathlib':         true
	'pdb':             true
	'pickle':          true
	'pickletools':     true
	'pipes':           true
	'pkgutil':         true
	'platform':        true
	'plistlib':        true
	'poplib':          true
	'posix':           true
	'pprint':          true
	'profile':         true
	'pstats':          true
	'pty':             true
	'pwd':             true
	'py_compile':      true
	'pyclbr':          true
	'pydoc':           true
	'queue':           true
	'quopri':          true
	'random':          true
	're':              true
	'readline':        true
	'reprlib':         true
	'resource':        true
	'rlcompleter':     true
	'runpy':           true
	'sched':           true
	'secrets':         true
	'select':          true
	'selectors':       true
	'shelve':          true
	'shlex':           true
	'shutil':          true
	'signal':          true
	'site':            true
	'smtpd':           true
	'smtplib':         true
	'sndhdr':          true
	'socket':          true
	'socketserver':    true
	'spdb':            true
	'spwd':            true
	'sqlite3':         true
	'ssl':             true
	'stat':            true
	'statistics':      true
	'string':          true
	'stringprep':      true
	'struct':          true
	'subprocess':      true
	'sunau':           true
	'symtable':        true
	'sys':             true
	'sysconfig':       true
	'syslog':          true
	'tabnanny':        true
	'tarfile':         true
	'telnetlib':       true
	'tempfile':        true
	'termios':         true
	'test':            true
	'textwrap':        true
	'thread':          true
	'threading':       true
	'time':            true
	'timeit':          true
	'tkinter':         true
	'token':           true
	'tokenize':        true
	'tomllib':         true
	'trace':           true
	'traceback':       true
	'trlib':           true
	'tty':             true
	'turtle':          true
	'turtledemo':      true
	'types':           true
	'typing':          true
	'unicodedata':     true
	'unittest':        true
	'unittest.mock':   true
	'urllib':          true
	'uu':              true
	'uuid':            true
	'venvpkg':         true
	'warnings':        true
	'wave':            true
	'weakref':         true
	'webbrowser':      true
	'winreg':          true
	'winsound':        true
	'wsgiref':         true
	'xdrlib':          true
	'xml':             true
	'xmlrpc':          true
	'zipapp':          true
	'zipfile':         true
	'zipimport':       true
	'zlib':            true
	'zoneinfo':        true
}

pub fn has_stubs(mod_name string) bool {
	// Check if module has a stub distribution
	if stub_distribution_name(mod_name) != none {
		return true
	}

	// Check if module is in the standard library (has built-in stubs)
	base_mod := mod_name.split('.')[0]
	return base_mod in stdlib_modules
}

// get_stub_path returns the path to stubs for a module.
pub fn get_stub_path(mod_name string) ?string {
	// Convert module name to path components
	parts := mod_name.split('.')

	// 1. Check typeshed directory (stdlib stubs)
	typeshed_stdlib := os.join_path('typeshed', 'stdlib')
	mut path := os.join_path(typeshed_stdlib, ...parts) + '.pyi'
	if os.is_file(path) {
		return path
	}
	// Check for package __init__.pyi
	path = os.join_path(typeshed_stdlib, ...parts, '__init__.pyi')
	if os.is_file(path) {
		return path
	}

	// 2. Check installed stub packages
	stub_dist := stub_distribution_name(mod_name) or { return none }
	stub_dir := os.join_path('site-packages', stub_dist.replace('-', '_'))
	path = os.join_path(stub_dir, ...parts) + '.pyi'
	if os.is_file(path) {
		return path
	}
	path = os.join_path(stub_dir, ...parts, '__init__.pyi')
	if os.is_file(path) {
		return path
	}

	// 3. Check custom stub directories (from MYPYPATH or config)
	// This would typically read from mypy configuration
	// For now, return none if not found in standard locations
	return none
}
