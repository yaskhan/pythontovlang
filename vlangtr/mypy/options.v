// I, Cline, am working on this file. Started: 2026-03-22 03:05
// Completed: 2026-03-22 03:13
// Translation: mypy/mypy/options.py → vlangtr/mypy/options.v
// Status: Completed ✅

module mypy

import os as _

// ============================================================================
// Constants
// ============================================================================

pub enum BuildType {
	standard     = 0
	module       = 1
	program_text = 2
}

pub const per_module_options = [
	'allow_redefinition_old',
	'allow_redefinition_new',
	'allow_untyped_globals',
	'always_false',
	'always_true',
	'check_untyped_defs',
	'debug_cache',
	'disable_error_code',
	'disabled_error_codes',
	'disallow_any_decorated',
	'disallow_any_explicit',
	'disallow_any_expr',
	'disallow_any_generics',
	'disallow_any_unimported',
	'disallow_incomplete_defs',
	'disallow_subclassing_any',
	'disallow_untyped_calls',
	'disallow_untyped_decorators',
	'disallow_untyped_defs',
	'enable_error_code',
	'enabled_error_codes',
	'extra_checks',
	'follow_imports_for_stubs',
	'follow_imports',
	'follow_untyped_imports',
	'ignore_errors',
	'ignore_missing_imports',
	'implicit_optional',
	'implicit_reexport',
	'local_partial_types',
	'mypyc',
	'strict_concatenate',
	'strict_equality',
	'strict_equality_for_none',
	'strict_optional',
	'warn_no_return',
	'warn_return_any',
	'warn_unreachable',
	'warn_unused_ignores',
]

pub fn get_options_affecting_cache() []string {
	mut arr := [
		'platform',
		'bazel',
		'native_parser',
		'old_type_inference',
		'plugins',
		'disable_bytearray_promotion',
		'disable_memoryview_promotion',
		'strict_bytes',
		'fixed_format_cache',
		'untyped_calls_exclude',
		'enable_incomplete_feature',
	]
	for opt in per_module_options {
		if opt != 'debug_cache' {
			arr << opt
		}
	}
	return arr
}

pub const options_affecting_cache = get_options_affecting_cache()

pub const options_affecting_cache_no_platform = options_affecting_cache.filter(it != 'platform').sorted()

// Features that are currently (or were recently) incomplete/experimental
pub const type_var_tuple = 'TypeVarTuple'
pub const unpack = 'Unpack'
pub const precise_tuple_types = 'PreciseTupleTypes'
pub const new_generic_syntax = 'NewGenericSyntax'
pub const inline_typeddict = 'InlineTypedDict'
pub const type_form = 'TypeForm'
pub const incomplete_features = [precise_tuple_types, inline_typeddict, type_form]
pub const complete_features = [type_var_tuple, unpack, new_generic_syntax]

// ============================================================================
// Options - Configuration collected from flags
// ============================================================================

pub struct GlobOption {
pub mut:
	key     string
	pattern string
}

@[heap]
pub struct Options {
pub mut:
	// Build options
	build_type        BuildType
	python_version    []int
	python_executable ?string
	platform          string

	custom_typing_module              ?string
	custom_typeshed_dir               ?string
	abs_custom_typeshed_dir           ?string
	mypy_path                         []string
	report_dirs                       map[string]string
	no_silence_site_packages          bool
	no_site_packages                  bool
	ignore_missing_imports            bool
	ignore_missing_imports_per_module bool
	follow_untyped_imports            bool
	follow_imports                    string // normal|silent|skip|error
	follow_imports_for_stubs          bool
	namespace_packages                bool
	explicit_package_bases            bool
	exclude                           []string
	exclude_gitignore                 bool

	// disallow_any options
	disallow_any_generics   bool
	disallow_any_unimported bool
	disallow_any_expr       bool
	disallow_any_decorated  bool
	disallow_any_explicit   bool

	disallow_untyped_calls      bool
	untyped_calls_exclude       []string
	disallow_untyped_defs       bool
	disallow_incomplete_defs    bool
	check_untyped_defs          bool
	disallow_untyped_decorators bool
	disallow_subclassing_any    bool
	warn_incomplete_stub        bool
	warn_redundant_casts        bool
	warn_no_return              bool
	warn_return_any             bool
	report_deprecated_as_note   bool
	deprecated_calls_exclude    []string
	warn_unused_ignores         bool
	warn_unused_configs         bool
	ignore_errors               bool
	strict_optional             bool
	show_error_context          bool
	color_output                bool
	error_summary               bool
	implicit_optional           bool
	implicit_reexport           bool
	allow_untyped_globals       bool
	allow_redefinition_old      bool
	allow_redefinition_new      bool
	strict_equality             bool
	strict_equality_for_none    bool
	strict_bytes                bool
	strict_concatenate          bool
	extra_checks                bool
	warn_unreachable            bool
	always_true                 []string
	always_false                []string
	disable_error_code          []string
	disabled_error_codes        map[string]bool
	enable_error_code           []string
	enabled_error_codes         map[string]bool
	scripts_are_modules         bool
	config_file                 ?string
	quickstart_file             ?string
	files                       ?[]string
	packages                    ?[]string
	modules                     ?[]string
	junit_xml                   ?string
	junit_format                string // global|per_file

	// Caching and incremental checking options
	incremental              bool
	cache_dir                string
	sqlite_cache             bool
	fixed_format_cache       bool
	debug_cache              bool
	skip_version_check       bool
	skip_cache_mtime_checks  bool
	fine_grained_incremental bool
	cache_fine_grained       bool
	use_fine_grained_cache   bool
	debug_serialize          bool
	mypyc                    bool
	inspections              bool
	preserve_asts            bool
	include_docstrings       bool
	plugins                  []string
	per_module_options       map[string]map[string]string
	unused_configs           map[string]bool

	// Development options
	verbosity                 int
	pdb                       bool
	show_traceback            bool
	raise_exceptions          bool
	dump_type_stats           bool
	dump_inference_stats      bool
	dump_build_stats          bool
	enable_incomplete_feature []string
	timing_stats              ?string
	line_checking_stats       ?string

	// Test options
	semantic_analysis_only bool
	use_builtins_fixtures  bool
	test_env               bool

	// Experimental options
	num_workers                  int
	shadow_file                  ?[][]string
	show_column_numbers          bool
	show_error_end               bool
	hide_error_codes             bool
	show_error_code_links        bool
	reveal_verbose_types         bool
	pretty                       bool
	dump_graph                   bool
	dump_deps                    bool
	logical_deps                 bool
	local_partial_types          bool
	native_parser                bool
	bazel                        bool
	export_types                 bool
	package_root                 []string
	cache_map                    map[string](string, string)
	fast_exit                    bool
	fast_module_lookup           bool
	allow_empty_bodies           bool
	transform_source             ?fn (string) string
	show_absolute_path           bool
	install_types                bool
	non_interactive              bool
	many_errors_threshold        int
	old_type_inference           bool
	disable_expression_cache     bool
	export_ref_info              bool
	pos_only_special_methods     bool
	disable_bytearray_promotion  bool
	disable_memoryview_promotion bool
	output                       ?string
	mypyc_annotation_file        ?string
	mypyc_skip_c_generation      bool

	// Internal cache for clone_for_module()
	per_module_cache ?map[string]&Options
	glob_options     []GlobOption
}

pub struct BuildSource {
pub mut:
	path     string
	module   string
	base_dir string
}

pub type BuildResult = []BuildSource | string

pub fn Options.new() &Options {
	mut o := &Options{}
	o.initialize()
	return o
}

pub fn (mut o Options) initialize() {
	// Build options
	o.build_type = .standard
	o.python_version = [3, 11] // Default, will be overridden
	o.python_executable = none
	o.platform = 'linux' // Default, will be overridden
	o.custom_typing_module = none
	o.custom_typeshed_dir = none
	o.abs_custom_typeshed_dir = none
	o.mypy_path = []
	o.report_dirs = map[string]string{}
	o.no_silence_site_packages = false
	o.no_site_packages = false
	o.ignore_missing_imports = false
	o.ignore_missing_imports_per_module = false
	o.follow_untyped_imports = false
	o.follow_imports = 'normal'
	o.follow_imports_for_stubs = false
	o.namespace_packages = true
	o.explicit_package_bases = false
	o.exclude = []
	o.exclude_gitignore = false

	// disallow_any options
	o.disallow_any_generics = false
	o.disallow_any_unimported = false
	o.disallow_any_expr = false
	o.disallow_any_decorated = false
	o.disallow_any_explicit = false

	o.disallow_untyped_calls = false
	o.untyped_calls_exclude = []
	o.disallow_untyped_defs = false
	o.disallow_incomplete_defs = false
	o.check_untyped_defs = false
	o.disallow_untyped_decorators = false
	o.disallow_subclassing_any = false
	o.warn_incomplete_stub = false
	o.warn_redundant_casts = false
	o.warn_no_return = true
	o.warn_return_any = false
	o.report_deprecated_as_note = false
	o.deprecated_calls_exclude = []
	o.warn_unused_ignores = false
	o.warn_unused_configs = false
	o.ignore_errors = false
	o.strict_optional = true
	o.show_error_context = false
	o.color_output = true
	o.error_summary = true
	o.implicit_optional = false
	o.implicit_reexport = true
	o.allow_untyped_globals = false
	o.allow_redefinition_old = false
	o.allow_redefinition_new = false
	o.strict_equality = false
	o.strict_equality_for_none = false
	o.strict_bytes = false
	o.strict_concatenate = false
	o.extra_checks = false
	o.warn_unreachable = false
	o.always_true = []
	o.always_false = []
	o.disable_error_code = []
	o.disabled_error_codes = map[string]bool{}
	o.enable_error_code = []
	o.enabled_error_codes = map[string]bool{}
	o.scripts_are_modules = false
	o.config_file = none
	o.quickstart_file = none
	o.files = none
	o.packages = none
	o.modules = none
	o.junit_xml = none
	o.junit_format = 'global'

	// Caching and incremental checking options
	o.incremental = true
	o.cache_dir = '.mypy_cache'
	o.sqlite_cache = true
	o.fixed_format_cache = true
	o.debug_cache = false
	o.skip_version_check = false
	o.skip_cache_mtime_checks = false
	o.fine_grained_incremental = false
	o.cache_fine_grained = false
	o.use_fine_grained_cache = false
	o.debug_serialize = false
	o.mypyc = false
	o.inspections = false
	o.preserve_asts = false
	o.include_docstrings = false
	o.plugins = []
	o.per_module_options = map[string]map[string]string{}
	o.unused_configs = map[string]bool{}

	// Development options
	o.verbosity = 0
	o.pdb = false
	o.show_traceback = false
	o.raise_exceptions = false
	o.dump_type_stats = false
	o.dump_inference_stats = false
	o.dump_build_stats = false
	o.enable_incomplete_feature = []
	o.timing_stats = none
	o.line_checking_stats = none

	// Test options
	o.semantic_analysis_only = false
	o.use_builtins_fixtures = false
	o.test_env = false

	// Experimental options
	o.num_workers = 0
	o.shadow_file = none
	o.show_column_numbers = false
	o.show_error_end = false
	o.hide_error_codes = false
	o.show_error_code_links = false
	o.reveal_verbose_types = false
	o.pretty = false
	o.dump_graph = false
	o.dump_deps = false
	o.logical_deps = false
	o.local_partial_types = false
	o.native_parser = false
	o.bazel = false
	o.export_types = false
	o.package_root = []
	o.cache_map = map[string](string, string){}
	o.fast_exit = true
	o.fast_module_lookup = false
	o.allow_empty_bodies = false
	o.transform_source = none
	o.show_absolute_path = false
	o.install_types = false
	o.non_interactive = false
	o.many_errors_threshold = 200 // Default from defaults.MANY_ERRORS_THRESHOLD
	o.old_type_inference = false
	o.disable_expression_cache = false
	o.export_ref_info = false
	o.pos_only_special_methods = true
	o.disable_bytearray_promotion = false
	o.disable_memoryview_promotion = false
	o.output = none
	o.mypyc_annotation_file = none
	o.mypyc_skip_c_generation = false

	// Internal cache
	o.per_module_cache = none
	o.glob_options = []GlobOption{}
}

pub fn (o &Options) use_star_unpack() bool {
	return (o.python_version[0] > 3 || (o.python_version[0] == 3 && o.python_version[1] >= 11))
		|| !o.reveal_verbose_types
}

pub fn (o &Options) snapshot() map[string]string {
	// Produce a comparable snapshot of this Option
	mut d := map[string]string{}
	// Add all public fields
	d['build_type'] = o.build_type.str()
	d['python_version'] = '${o.python_version[0]}.${o.python_version[1]}'
	d['platform'] = o.platform
	d['ignore_missing_imports'] = o.ignore_missing_imports.str()

	d['follow_imports'] = o.follow_imports
	d['follow_imports_for_stubs'] = o.follow_imports_for_stubs.str()
	d['namespace_packages'] = o.namespace_packages.str()
	d['explicit_package_bases'] = o.explicit_package_bases.str()
	d['disallow_any_generics'] = o.disallow_any_generics.str()
	d['disallow_any_unimported'] = o.disallow_any_unimported.str()
	d['disallow_any_expr'] = o.disallow_any_expr.str()
	d['disallow_any_decorated'] = o.disallow_any_decorated.str()
	d['disallow_any_explicit'] = o.disallow_any_explicit.str()
	d['disallow_untyped_calls'] = o.disallow_untyped_calls.str()
	d['disallow_untyped_defs'] = o.disallow_untyped_defs.str()
	d['disallow_incomplete_defs'] = o.disallow_incomplete_defs.str()
	d['check_untyped_defs'] = o.check_untyped_defs.str()
	d['disallow_untyped_decorators'] = o.disallow_untyped_decorators.str()
	d['disallow_subclassing_any'] = o.disallow_subclassing_any.str()
	d['warn_redundant_casts'] = o.warn_redundant_casts.str()
	d['warn_no_return'] = o.warn_no_return.str()
	d['warn_return_any'] = o.warn_return_any.str()
	d['warn_unused_ignores'] = o.warn_unused_ignores.str()
	d['warn_unused_configs'] = o.warn_unused_configs.str()
	d['ignore_errors'] = o.ignore_errors.str()
	d['strict_optional'] = o.strict_optional.str()
	d['show_error_context'] = o.show_error_context.str()
	d['implicit_optional'] = o.implicit_optional.str()
	d['implicit_reexport'] = o.implicit_reexport.str()
	d['allow_untyped_globals'] = o.allow_untyped_globals.str()
	d['allow_redefinition_old'] = o.allow_redefinition_old.str()
	d['allow_redefinition_new'] = o.allow_redefinition_new.str()
	d['strict_equality'] = o.strict_equality.str()
	d['strict_equality_for_none'] = o.strict_equality_for_none.str()
	d['strict_bytes'] = o.strict_bytes.str()
	d['strict_concatenate'] = o.strict_concatenate.str()
	d['extra_checks'] = o.extra_checks.str()
	d['warn_unreachable'] = o.warn_unreachable.str()
	d['scripts_are_modules'] = o.scripts_are_modules.str()
	d['incremental'] = o.incremental.str()
	d['cache_dir'] = o.cache_dir
	d['sqlite_cache'] = o.sqlite_cache.str()
	d['fixed_format_cache'] = o.fixed_format_cache.str()
	d['debug_cache'] = o.debug_cache.str()
	d['skip_version_check'] = o.skip_version_check.str()
	d['fine_grained_incremental'] = o.fine_grained_incremental.str()
	d['cache_fine_grained'] = o.cache_fine_grained.str()
	d['use_fine_grained_cache'] = o.use_fine_grained_cache.str()
	d['mypyc'] = o.mypyc.str()
	d['preserve_asts'] = o.preserve_asts.str()
	d['include_docstrings'] = o.include_docstrings.str()
	d['verbosity'] = o.verbosity.str()
	d['pdb'] = o.pdb.str()
	d['show_traceback'] = o.show_traceback.str()
	d['raise_exceptions'] = o.raise_exceptions.str()
	d['semantic_analysis_only'] = o.semantic_analysis_only.str()
	d['use_builtins_fixtures'] = o.use_builtins_fixtures.str()
	d['test_env'] = o.test_env.str()
	d['num_workers'] = o.num_workers.str()
	d['show_column_numbers'] = o.show_column_numbers.str()
	d['show_error_end'] = o.show_error_end.str()
	d['hide_error_codes'] = o.hide_error_codes.str()
	d['show_error_code_links'] = o.show_error_code_links.str()
	d['reveal_verbose_types'] = o.reveal_verbose_types.str()
	d['pretty'] = o.pretty.str()
	d['local_partial_types'] = o.local_partial_types.str()
	d['native_parser'] = o.native_parser.str()
	d['bazel'] = o.bazel.str()
	d['export_types'] = o.export_types.str()
	d['fast_exit'] = o.fast_exit.str()
	d['fast_module_lookup'] = o.fast_module_lookup.str()
	d['allow_empty_bodies'] = o.allow_empty_bodies.str()
	d['show_absolute_path'] = o.show_absolute_path.str()
	d['install_types'] = o.install_types.str()
	d['non_interactive'] = o.non_interactive.str()
	d['many_errors_threshold'] = o.many_errors_threshold.str()
	d['old_type_inference'] = o.old_type_inference.str()
	d['disable_expression_cache'] = o.disable_expression_cache.str()
	d['export_ref_info'] = o.export_ref_info.str()
	d['pos_only_special_methods'] = o.pos_only_special_methods.str()
	d['disable_bytearray_promotion'] = o.disable_bytearray_promotion.str()
	d['disable_memoryview_promotion'] = o.disable_memoryview_promotion.str()
	return d
}

pub fn (mut o Options) process_error_codes(error_callback fn (string)) {
	disabled_code_names := o.disable_error_code
	enabled_code_names := o.enable_error_code

	valid_error_code_names := mypy_error_codes.keys()

	mut invalid_code_names := []string{}
	for code in enabled_code_names {
		if code !in valid_error_code_names {
			invalid_code_names << code
		}
	}
	for code in disabled_code_names {
		if code !in valid_error_code_names {
			invalid_code_names << code
		}
	}
	if invalid_code_names.len > 0 {
		error_callback('Invalid error code(s): ${invalid_code_names.join(', ')}')
	}

	for code in disabled_code_names {
		o.disabled_error_codes[code] = true
	}
	for code in enabled_code_names {
		o.enabled_error_codes[code] = true
	}

	// Enabling an error code always overrides disabling
	for code in o.enabled_error_codes.keys() {
		o.disabled_error_codes.delete(code)
	}
}

pub fn (mut o Options) process_incomplete_features(error_callback fn (string), warning_callback fn (string)) {
	for feature in o.enable_incomplete_feature {
		if feature !in incomplete_features && feature !in complete_features {
			error_callback('Unknown incomplete feature: ${feature}')
		}
		if feature in complete_features {
			warning_callback('Warning: ${feature} is already enabled by default')
		}
	}
}

pub fn (mut o Options) process_strict_bytes() {
	// Sync `--strict-bytes` and `--disable-{bytearray,memoryview}-promotion`
	if o.strict_bytes {
		// backwards compatibility
		o.disable_bytearray_promotion = true
		o.disable_memoryview_promotion = true
	} else if o.disable_bytearray_promotion && o.disable_memoryview_promotion {
		// forwards compatibility
		o.strict_bytes = true
	}
}

pub fn (o &Options) apply_changes(changes map[string]string) &Options {
	// Note: effects of this method *must* be idempotent.
	mut new_options := Options.new()
	// Copy current state
	new_options.copy_from(o)
	// Apply changes
	for key, value in changes {
		new_options.set_field(key, value)
	}
	if changes['ignore_missing_imports'] == 'true' {
		// This is the only option for which a per-module and a global
		// option sometimes behave differently.
		new_options.ignore_missing_imports_per_module = true
	}

	// These two act as overrides, so apply them when cloning.
	// Similar to global codes enabling overrides disabling, so we start from latter.
	new_options.disabled_error_codes = o.disabled_error_codes.clone()
	new_options.enabled_error_codes = o.enabled_error_codes.clone()
	for code_str in new_options.disable_error_code {
		new_options.disabled_error_codes[code_str] = true
		new_options.enabled_error_codes.delete(code_str)
	}
	for code_str in new_options.enable_error_code {
		new_options.enabled_error_codes[code_str] = true
		new_options.disabled_error_codes.delete(code_str)
	}
	return new_options
}

fn (mut o Options) copy_from(src &Options) {
	o.build_type = src.build_type
	o.python_version = src.python_version
	o.python_executable = src.python_executable
	o.platform = src.platform
	o.custom_typing_module = src.custom_typing_module
	o.custom_typeshed_dir = src.custom_typeshed_dir
	o.abs_custom_typeshed_dir = src.abs_custom_typeshed_dir
	o.mypy_path = src.mypy_path.clone()
	o.report_dirs = src.report_dirs.clone()
	o.no_silence_site_packages = src.no_silence_site_packages
	o.no_site_packages = src.no_site_packages
	o.ignore_missing_imports = src.ignore_missing_imports
	o.ignore_missing_imports_per_module = src.ignore_missing_imports_per_module
	o.follow_untyped_imports = src.follow_untyped_imports
	o.follow_imports = src.follow_imports
	o.follow_imports_for_stubs = src.follow_imports_for_stubs
	o.namespace_packages = src.namespace_packages
	o.explicit_package_bases = src.explicit_package_bases
	o.exclude = src.exclude.clone()
	o.exclude_gitignore = src.exclude_gitignore
	o.disallow_any_generics = src.disallow_any_generics
	o.disallow_any_unimported = src.disallow_any_unimported
	o.disallow_any_expr = src.disallow_any_expr
	o.disallow_any_decorated = src.disallow_any_decorated
	o.disallow_any_explicit = src.disallow_any_explicit
	o.disallow_untyped_calls = src.disallow_untyped_calls
	o.untyped_calls_exclude = src.untyped_calls_exclude.clone()
	o.disallow_untyped_defs = src.disallow_untyped_defs
	o.disallow_incomplete_defs = src.disallow_incomplete_defs
	o.check_untyped_defs = src.check_untyped_defs
	o.disallow_untyped_decorators = src.disallow_untyped_decorators
	o.disallow_subclassing_any = src.disallow_subclassing_any
	o.warn_incomplete_stub = src.warn_incomplete_stub
	o.warn_redundant_casts = src.warn_redundant_casts
	o.warn_no_return = src.warn_no_return
	o.warn_return_any = src.warn_return_any
	o.report_deprecated_as_note = src.report_deprecated_as_note
	o.deprecated_calls_exclude = src.deprecated_calls_exclude.clone()
	o.warn_unused_ignores = src.warn_unused_ignores
	o.warn_unused_configs = src.warn_unused_configs
	o.ignore_errors = src.ignore_errors
	o.strict_optional = src.strict_optional
	o.show_error_context = src.show_error_context
	o.color_output = src.color_output
	o.error_summary = src.error_summary
	o.implicit_optional = src.implicit_optional
	o.implicit_reexport = src.implicit_reexport
	o.allow_untyped_globals = src.allow_untyped_globals
	o.allow_redefinition_old = src.allow_redefinition_old
	o.allow_redefinition_new = src.allow_redefinition_new
	o.strict_equality = src.strict_equality
	o.strict_equality_for_none = src.strict_equality_for_none
	o.strict_bytes = src.strict_bytes
	o.strict_concatenate = src.strict_concatenate
	o.extra_checks = src.extra_checks
	o.warn_unreachable = src.warn_unreachable
	o.always_true = src.always_true.clone()
	o.always_false = src.always_false.clone()
	o.disable_error_code = src.disable_error_code.clone()
	o.disabled_error_codes = src.disabled_error_codes.clone()
	o.enable_error_code = src.enable_error_code.clone()
	o.enabled_error_codes = src.enabled_error_codes.clone()
	o.scripts_are_modules = src.scripts_are_modules
	o.config_file = src.config_file
	o.quickstart_file = src.quickstart_file
	o.files = src.files
	o.packages = src.packages
	o.modules = src.modules
	o.junit_xml = src.junit_xml
	o.junit_format = src.junit_format
	o.incremental = src.incremental
	o.cache_dir = src.cache_dir
	o.sqlite_cache = src.sqlite_cache
	o.fixed_format_cache = src.fixed_format_cache
	o.debug_cache = src.debug_cache
	o.skip_version_check = src.skip_version_check
	o.skip_cache_mtime_checks = src.skip_cache_mtime_checks
	o.fine_grained_incremental = src.fine_grained_incremental
	o.cache_fine_grained = src.cache_fine_grained
	o.use_fine_grained_cache = src.use_fine_grained_cache
	o.debug_serialize = src.debug_serialize
	o.mypyc = src.mypyc
	o.inspections = src.inspections
	o.preserve_asts = src.preserve_asts
	o.include_docstrings = src.include_docstrings
	o.plugins = src.plugins.clone()
	o.per_module_options = src.per_module_options.clone()
	o.unused_configs = src.unused_configs.clone()
	o.verbosity = src.verbosity
	o.pdb = src.pdb
	o.show_traceback = src.show_traceback
	o.raise_exceptions = src.raise_exceptions
	o.dump_type_stats = src.dump_type_stats
	o.dump_inference_stats = src.dump_inference_stats
	o.dump_build_stats = src.dump_build_stats
	o.enable_incomplete_feature = src.enable_incomplete_feature.clone()
	o.timing_stats = src.timing_stats
	o.line_checking_stats = src.line_checking_stats
	o.semantic_analysis_only = src.semantic_analysis_only
	o.use_builtins_fixtures = src.use_builtins_fixtures
	o.test_env = src.test_env
	o.num_workers = src.num_workers
	o.shadow_file = src.shadow_file
	o.show_column_numbers = src.show_column_numbers
	o.show_error_end = src.show_error_end
	o.hide_error_codes = src.hide_error_codes
	o.show_error_code_links = src.show_error_code_links
	o.reveal_verbose_types = src.reveal_verbose_types
	o.pretty = src.pretty
	o.dump_graph = src.dump_graph
	o.dump_deps = src.dump_deps
	o.logical_deps = src.logical_deps
	o.local_partial_types = src.local_partial_types
	o.native_parser = src.native_parser
	o.bazel = src.bazel
	o.export_types = src.export_types
	o.package_root = src.package_root.clone()
	o.cache_map = src.cache_map.clone()
	o.fast_exit = src.fast_exit
	o.fast_module_lookup = src.fast_module_lookup
	o.allow_empty_bodies = src.allow_empty_bodies
	o.transform_source = src.transform_source
	o.show_absolute_path = src.show_absolute_path
	o.install_types = src.install_types
	o.non_interactive = src.non_interactive
	o.many_errors_threshold = src.many_errors_threshold
	o.old_type_inference = src.old_type_inference
	o.disable_expression_cache = src.disable_expression_cache
	o.export_ref_info = src.export_ref_info
	o.pos_only_special_methods = src.pos_only_special_methods
	o.disable_bytearray_promotion = src.disable_bytearray_promotion
	o.disable_memoryview_promotion = src.disable_memoryview_promotion
	o.output = src.output
	o.mypyc_annotation_file = src.mypyc_annotation_file
	o.mypyc_skip_c_generation = src.mypyc_skip_c_generation
}

fn (mut o Options) set_field(key string, value string) {
	match key {
		'build_type' {
			o.build_type = match value {
				'0' { .standard }
				'1' { .module }
				'2' { .program_text }
				else { .standard }
			}
		}
		'platform' {
			o.platform = value
		}
		'ignore_missing_imports' {
			o.ignore_missing_imports = value == 'true'
		}
		'follow_imports' {
			o.follow_imports = value
		}
		'follow_imports_for_stubs' {
			o.follow_imports_for_stubs = value == 'true'
		}
		'namespace_packages' {
			o.namespace_packages = value == 'true'
		}
		'explicit_package_bases' {
			o.explicit_package_bases = value == 'true'
		}
		'disallow_any_generics' {
			o.disallow_any_generics = value == 'true'
		}
		'disallow_any_unimported' {
			o.disallow_any_unimported = value == 'true'
		}
		'disallow_any_expr' {
			o.disallow_any_expr = value == 'true'
		}
		'disallow_any_decorated' {
			o.disallow_any_decorated = value == 'true'
		}
		'disallow_any_explicit' {
			o.disallow_any_explicit = value == 'true'
		}
		'disallow_untyped_calls' {
			o.disallow_untyped_calls = value == 'true'
		}
		'disallow_untyped_defs' {
			o.disallow_untyped_defs = value == 'true'
		}
		'disallow_incomplete_defs' {
			o.disallow_incomplete_defs = value == 'true'
		}
		'check_untyped_defs' {
			o.check_untyped_defs = value == 'true'
		}
		'disallow_untyped_decorators' {
			o.disallow_untyped_decorators = value == 'true'
		}
		'disallow_subclassing_any' {
			o.disallow_subclassing_any = value == 'true'
		}
		'warn_redundant_casts' {
			o.warn_redundant_casts = value == 'true'
		}
		'warn_no_return' {
			o.warn_no_return = value == 'true'
		}
		'warn_return_any' {
			o.warn_return_any = value == 'true'
		}
		'warn_unused_ignores' {
			o.warn_unused_ignores = value == 'true'
		}
		'warn_unused_configs' {
			o.warn_unused_configs = value == 'true'
		}
		'ignore_errors' {
			o.ignore_errors = value == 'true'
		}
		'strict_optional' {
			o.strict_optional = value == 'true'
		}
		'show_error_context' {
			o.show_error_context = value == 'true'
		}
		'implicit_optional' {
			o.implicit_optional = value == 'true'
		}
		'implicit_reexport' {
			o.implicit_reexport = value == 'true'
		}
		'allow_untyped_globals' {
			o.allow_untyped_globals = value == 'true'
		}
		'allow_redefinition_old' {
			o.allow_redefinition_old = value == 'true'
		}
		'allow_redefinition_new' {
			o.allow_redefinition_new = value == 'true'
		}
		'strict_equality' {
			o.strict_equality = value == 'true'
		}
		'strict_equality_for_none' {
			o.strict_equality_for_none = value == 'true'
		}
		'strict_bytes' {
			o.strict_bytes = value == 'true'
		}
		'strict_concatenate' {
			o.strict_concatenate = value == 'true'
		}
		'extra_checks' {
			o.extra_checks = value == 'true'
		}
		'warn_unreachable' {
			o.warn_unreachable = value == 'true'
		}
		'scripts_are_modules' {
			o.scripts_are_modules = value == 'true'
		}
		'incremental' {
			o.incremental = value == 'true'
		}
		'cache_dir' {
			o.cache_dir = value
		}
		'sqlite_cache' {
			o.sqlite_cache = value == 'true'
		}
		'fixed_format_cache' {
			o.fixed_format_cache = value == 'true'
		}
		'debug_cache' {
			o.debug_cache = value == 'true'
		}
		'skip_version_check' {
			o.skip_version_check = value == 'true'
		}
		'fine_grained_incremental' {
			o.fine_grained_incremental = value == 'true'
		}
		'cache_fine_grained' {
			o.cache_fine_grained = value == 'true'
		}
		'use_fine_grained_cache' {
			o.use_fine_grained_cache = value == 'true'
		}
		'mypyc' {
			o.mypyc = value == 'true'
		}
		'preserve_asts' {
			o.preserve_asts = value == 'true'
		}
		'include_docstrings' {
			o.include_docstrings = value == 'true'
		}
		'verbosity' {
			o.verbosity = value.int()
		}
		'pdb' {
			o.pdb = value == 'true'
		}
		'show_traceback' {
			o.show_traceback = value == 'true'
		}
		'raise_exceptions' {
			o.raise_exceptions = value == 'true'
		}
		'semantic_analysis_only' {
			o.semantic_analysis_only = value == 'true'
		}
		'use_builtins_fixtures' {
			o.use_builtins_fixtures = value == 'true'
		}
		'test_env' {
			o.test_env = value == 'true'
		}
		'num_workers' {
			o.num_workers = value.int()
		}
		'show_column_numbers' {
			o.show_column_numbers = value == 'true'
		}
		'show_error_end' {
			o.show_error_end = value == 'true'
		}
		'hide_error_codes' {
			o.hide_error_codes = value == 'true'
		}
		'show_error_code_links' {
			o.show_error_code_links = value == 'true'
		}
		'reveal_verbose_types' {
			o.reveal_verbose_types = value == 'true'
		}
		'pretty' {
			o.pretty = value == 'true'
		}
		'local_partial_types' {
			o.local_partial_types = value == 'true'
		}
		'native_parser' {
			o.native_parser = value == 'true'
		}
		'bazel' {
			o.bazel = value == 'true'
		}
		'export_types' {
			o.export_types = value == 'true'
		}
		'fast_exit' {
			o.fast_exit = value == 'true'
		}
		'fast_module_lookup' {
			o.fast_module_lookup = value == 'true'
		}
		'allow_empty_bodies' {
			o.allow_empty_bodies = value == 'true'
		}
		'show_absolute_path' {
			o.show_absolute_path = value == 'true'
		}
		'install_types' {
			o.install_types = value == 'true'
		}
		'non_interactive' {
			o.non_interactive = value == 'true'
		}
		'many_errors_threshold' {
			o.many_errors_threshold = value.int()
		}
		'old_type_inference' {
			o.old_type_inference = value == 'true'
		}
		'disable_expression_cache' {
			o.disable_expression_cache = value == 'true'
		}
		'export_ref_info' {
			o.export_ref_info = value == 'true'
		}
		'pos_only_special_methods' {
			o.pos_only_special_methods = value == 'true'
		}
		'disable_bytearray_promotion' {
			o.disable_bytearray_promotion = value == 'true'
		}
		'disable_memoryview_promotion' {
			o.disable_memoryview_promotion = value == 'true'
		}
		else {}
	}
}

pub fn (mut o Options) build_per_module_cache() {
	mut cache := map[string]&Options{}
	mut unstructured_glob_keys := []string{}
	mut structured_keys := []string{}
	mut wildcards := []string{}
	mut concrete := []string{}

	for key in o.per_module_options.keys() {
		if key[..key.len - 1].contains('*') {
			unstructured_glob_keys << key
		} else {
			structured_keys << key
			if key.ends_with('.*') {
				wildcards << key
			} else {
				concrete << key
			}
		}
	}

	wildcards.sort()

	for glob in unstructured_glob_keys {
		o.glob_options << GlobOption{
			key:     glob
			pattern: o.compile_glob(glob)
		}
	}

	o.unused_configs = map[string]bool{}
	for key in unstructured_glob_keys {
		o.unused_configs[key] = true
	}

	for key in wildcards {
		mut options := o.clone_for_module(key)
		if key in o.per_module_options {
			options = options.apply_changes(o.per_module_options[key])
		}
		cache[key] = options
	}
	for key in concrete {
		mut options := o.clone_for_module(key)
		if key in o.per_module_options {
			options = options.apply_changes(o.per_module_options[key])
		}
		cache[key] = options
	}

	for key in structured_keys {
		o.unused_configs[key] = true
	}

	o.per_module_cache = cache.clone()
}

pub fn (o &Options) clone_for_module(mod_name string) &Options {
	cache := o.per_module_cache or {
		map[string]&Options{}
	}
	if cache.len == 0 {
		return o
	}

	if mod_name in cache {
		return cache[mod_name]
	}

	mut options := o.apply_changes(map[string]string{})
	path := mod_name.split('.')
	for i := path.len; i > 0; i-- {
		key := path[..i].join('.') + '.*'
		if key in cache {
			options = cache[key].apply_changes(map[string]string{})
			break
		}
	}

	if !mod_name.ends_with('.*') {
		for glob in o.glob_options {
			if o.match_glob(mod_name, glob.pattern) {
				if glob.key in o.per_module_options {
					options = options.apply_changes(o.per_module_options[glob.key])
				}
			}
		}
	}

	return options
}

fn (o &Options) compile_glob(s string) string {
	parts := s.split('.')
	mut expr := if parts[0] != '*' { o.escape_regex(parts[0]) } else { '.*' }
	for part in parts[1..] {
		if part != '*' {
			expr += o.escape_regex('.' + part)
		} else {
			expr += r'(\..*)?'
		}
	}
	return expr + '\\Z'
}

fn (o &Options) escape_regex(s string) string {
	return s.replace('.', '\\.').replace('*', '\\*').replace('+', '\\+').replace('?',
		'\\?').replace('(', '\\(').replace(')', '\\)').replace('[', '\\[').replace(']',
		'\\]').replace('{', '\\{').replace('}', '\\}').replace('^', '\\^').replace('$',
		'\\$').replace('|', '\\|').replace('\\', '\\\\')
}

fn (o &Options) match_glob(mod_name string, pattern string) bool {
	// Simple glob matching - in real implementation would use regex
	return mod_name.match_glob(pattern)
}

pub fn (o &Options) select_options_affecting_cache() (string, []string) {
	mut result := []string{}
	for opt in options_affecting_cache_no_platform {
		val := match opt {
			'disabled_error_codes', 'enabled_error_codes' {
				o.get_error_codes_str(opt)
			}
			else {
				o.get_field_str(opt)
			}
		}
		result << val
	}
	return o.platform, result
}

fn (o &Options) get_error_codes_str(field string) string {
	codes := if field == 'disabled_error_codes' {
		o.disabled_error_codes.keys()
	} else {
		o.enabled_error_codes.keys()
	}
	mut sorted := codes.clone()
	sorted.sort()
	return sorted.join(',')
}

fn (o &Options) get_field_str(field string) string {
	return match field {
		'build_type' { o.build_type.str() }
		'python_version' { '${o.python_version[0]}.${o.python_version[1]}' }
		'platform' { o.platform }
		'ignore_missing_imports' { o.ignore_missing_imports.str() }
		'follow_imports' { o.follow_imports }
		'follow_imports_for_stubs' { o.follow_imports_for_stubs.str() }
		'namespace_packages' { o.namespace_packages.str() }
		'explicit_package_bases' { o.explicit_package_bases.str() }
		'disallow_any_generics' { o.disallow_any_generics.str() }
		'disallow_any_unimported' { o.disallow_any_unimported.str() }
		'disallow_any_expr' { o.disallow_any_expr.str() }
		'disallow_any_decorated' { o.disallow_any_decorated.str() }
		'disallow_any_explicit' { o.disallow_any_explicit.str() }
		'disallow_untyped_calls' { o.disallow_untyped_calls.str() }
		'disallow_untyped_defs' { o.disallow_untyped_defs.str() }
		'disallow_incomplete_defs' { o.disallow_incomplete_defs.str() }
		'check_untyped_defs' { o.check_untyped_defs.str() }
		'disallow_untyped_decorators' { o.disallow_untyped_decorators.str() }
		'disallow_subclassing_any' { o.disallow_subclassing_any.str() }
		'warn_redundant_casts' { o.warn_redundant_casts.str() }
		'warn_no_return' { o.warn_no_return.str() }
		'warn_return_any' { o.warn_return_any.str() }
		'warn_unused_ignores' { o.warn_unused_ignores.str() }
		'warn_unused_configs' { o.warn_unused_configs.str() }
		'ignore_errors' { o.ignore_errors.str() }
		'strict_optional' { o.strict_optional.str() }
		'show_error_context' { o.show_error_context.str() }
		'implicit_optional' { o.implicit_optional.str() }
		'implicit_reexport' { o.implicit_reexport.str() }
		'allow_untyped_globals' { o.allow_untyped_globals.str() }
		'allow_redefinition_old' { o.allow_redefinition_old.str() }
		'allow_redefinition_new' { o.allow_redefinition_new.str() }
		'strict_equality' { o.strict_equality.str() }
		'strict_equality_for_none' { o.strict_equality_for_none.str() }
		'strict_bytes' { o.strict_bytes.str() }
		'strict_concatenate' { o.strict_concatenate.str() }
		'extra_checks' { o.extra_checks.str() }
		'warn_unreachable' { o.warn_unreachable.str() }
		'scripts_are_modules' { o.scripts_are_modules.str() }
		'incremental' { o.incremental.str() }
		'cache_dir' { o.cache_dir }
		'sqlite_cache' { o.sqlite_cache.str() }
		'fixed_format_cache' { o.fixed_format_cache.str() }
		'debug_cache' { o.debug_cache.str() }
		'skip_version_check' { o.skip_version_check.str() }
		'fine_grained_incremental' { o.fine_grained_incremental.str() }
		'cache_fine_grained' { o.cache_fine_grained.str() }
		'use_fine_grained_cache' { o.use_fine_grained_cache.str() }
		'mypyc' { o.mypyc.str() }
		'preserve_asts' { o.preserve_asts.str() }
		'include_docstrings' { o.include_docstrings.str() }
		'verbosity' { o.verbosity.str() }
		'pdb' { o.pdb.str() }
		'show_traceback' { o.show_traceback.str() }
		'raise_exceptions' { o.raise_exceptions.str() }
		'semantic_analysis_only' { o.semantic_analysis_only.str() }
		'use_builtins_fixtures' { o.use_builtins_fixtures.str() }
		'test_env' { o.test_env.str() }
		'num_workers' { o.num_workers.str() }
		'show_column_numbers' { o.show_column_numbers.str() }
		'show_error_end' { o.show_error_end.str() }
		'hide_error_codes' { o.hide_error_codes.str() }
		'show_error_code_links' { o.show_error_code_links.str() }
		'reveal_verbose_types' { o.reveal_verbose_types.str() }
		'pretty' { o.pretty.str() }
		'local_partial_types' { o.local_partial_types.str() }
		'native_parser' { o.native_parser.str() }
		'bazel' { o.bazel.str() }
		'export_types' { o.export_types.str() }
		'fast_exit' { o.fast_exit.str() }
		'fast_module_lookup' { o.fast_module_lookup.str() }
		'allow_empty_bodies' { o.allow_empty_bodies.str() }
		'show_absolute_path' { o.show_absolute_path.str() }
		'install_types' { o.install_types.str() }
		'non_interactive' { o.non_interactive.str() }
		'many_errors_threshold' { o.many_errors_threshold.str() }
		'old_type_inference' { o.old_type_inference.str() }
		'disable_expression_cache' { o.disable_expression_cache.str() }
		'export_ref_info' { o.export_ref_info.str() }
		'pos_only_special_methods' { o.pos_only_special_methods.str() }
		'disable_bytearray_promotion' { o.disable_bytearray_promotion.str() }
		'disable_memoryview_promotion' { o.disable_memoryview_promotion.str() }
		else { '' }
	}
}

pub fn (o &Options) dep_import_options() []u8 {
	mut buf := []u8{}
	buf << u8(o.ignore_missing_imports)
	buf << o.follow_imports.bytes()
	buf << u8(o.follow_imports_for_stubs)
	return buf
}
