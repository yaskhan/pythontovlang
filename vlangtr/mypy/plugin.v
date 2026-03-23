// I, Cline, am working on this file. Started: 2026-03-22 19:50
// plugin.v — Plugin system for extending mypy
// Translated from mypy/plugin.py

module mypy

// AnalyzeTypeContext — context for type semantic analysis hook
pub struct AnalyzeTypeContext {
pub:
	typ     UnboundType
	context NodeBase
	api     TypeAnalyzerPluginInterface
}

// ReportConfigContext — context for requesting module configuration data
pub struct ReportConfigContext {
pub:
	id       string
	path     string
	is_check bool
}

// FunctionSigContext — context for function signature hook
pub struct FunctionSigContext {
pub:
	args              [][]Expression
	default_signature CallableType
	context           NodeBase
	api               CheckerPluginInterface
}

// FunctionContext — context for function hook
pub struct FunctionContext {
pub:
	arg_types           [][]MypyTypeNode
	arg_kinds           [][]ArgKind
	callee_arg_names    []string
	arg_names           [][]string
	default_return_type MypyTypeNode
	args                [][]Expression
	context             NodeBase
	api                 CheckerPluginInterface
}

// MethodSigContext — context for method signature hook
pub struct MethodSigContext {
pub:
	typ               ProperType
	args              [][]Expression
	default_signature CallableType
	context           NodeBase
	api               CheckerPluginInterface
}

// MethodContext — context for method hook
pub struct MethodContext {
pub:
	typ                 ProperType
	arg_types           [][]MypyTypeNode
	arg_kinds           [][]ArgKind
	callee_arg_names    []string
	arg_names           [][]string
	default_return_type MypyTypeNode
	args                [][]Expression
	context             NodeBase
	api                 CheckerPluginInterface
}

// AttributeContext — context for attribute type hook
pub struct AttributeContext {
pub:
	typ               ProperType
	default_attr_type MypyTypeNode
	is_lvalue         bool
	context           NodeBase
	api               CheckerPluginInterface
}

// ClassDefContext — context for class definition hook
pub struct ClassDefContext {
pub:
	cls    ClassDef
	reason Expression
	api    SemanticAnalyzerPluginInterface
}

// DynamicClassDefContext — context for dynamic class definition
pub struct DynamicClassDefContext {
pub:
	call CallExpr
	name string
	api  SemanticAnalyzerPluginInterface
}

// Plugin — base class of all mypy plugins
pub struct Plugin {
pub mut:
	options        Options
	python_version (int, int)
	modules        ?map[string]MypyFile
}

// new_plugin creates a new Plugin
pub fn new_plugin(options Options) Plugin {
	return Plugin{
		options:        options
		python_version: options.python_version
		modules:        none
	}
}

// set_modules sets modules for the plugin
pub fn (mut p Plugin) set_modules(modules map[string]MypyFile) {
	p.modules = modules
}

// lookup_fully_qualified looks up a symbol by its fully qualified name
pub fn (p Plugin) lookup_fully_qualified(fullname string) ?SymbolTableNode {
	if modules := p.modules {
		return lookup_fully_qualified(fullname, modules)
	}
	return none
}

// report_config_data returns configuration data for a module
pub fn (p Plugin) report_config_data(ctx ReportConfigContext) ?Any {
	return none
}

// get_additional_deps returns additional dependencies for a module
pub fn (p Plugin) get_additional_deps(file MypyFile) []Dependency {
	return []Dependency{}
}

// get_type_analyze_hook returns a hook for type analysis
pub fn (p Plugin) get_type_analyze_hook(fullname string) ?fn (AnalyzeTypeContext) MypyTypeNode {
	return none
}

// get_function_signature_hook returns a hook for function signature
pub fn (p Plugin) get_function_signature_hook(fullname string) ?fn (FunctionSigContext) MypyTypeNode {
	return none
}

// get_function_hook returns a hook for function
pub fn (p Plugin) get_function_hook(fullname string) ?fn (FunctionContext) MypyTypeNode {
	return none
}

// get_method_signature_hook returns a hook for method signature
pub fn (p Plugin) get_method_signature_hook(fullname string) ?fn (MethodSigContext) MypyTypeNode {
	return none
}

// get_method_hook returns a hook for method
pub fn (p Plugin) get_method_hook(fullname string) ?fn (MethodContext) MypyTypeNode {
	return none
}

// get_attribute_hook returns a hook for attribute
pub fn (p Plugin) get_attribute_hook(fullname string) ?fn (AttributeContext) MypyTypeNode {
	return none
}

// get_class_attribute_hook returns a hook for class attribute
pub fn (p Plugin) get_class_attribute_hook(fullname string) ?fn (AttributeContext) MypyTypeNode {
	return none
}

// get_class_decorator_hook returns a hook for class decorator
pub fn (p Plugin) get_class_decorator_hook(fullname string) ?fn (ClassDefContext) {
	return none
}

// get_class_decorator_hook_2 returns a hook for class decorator (after resolving placeholders)
pub fn (p Plugin) get_class_decorator_hook_2(fullname string) ?fn (ClassDefContext) bool {
	return none
}

// get_metaclass_hook returns a hook for metaclass
pub fn (p Plugin) get_metaclass_hook(fullname string) ?fn (ClassDefContext) {
	return none
}

// get_base_class_hook returns a hook for base class
pub fn (p Plugin) get_base_class_hook(fullname string) ?fn (ClassDefContext) {
	return none
}

// get_customize_class_mro_hook returns a hook for MRO customization
pub fn (p Plugin) get_customize_class_mro_hook(fullname string) ?fn (ClassDefContext) {
	return none
}

// get_dynamic_class_hook returns a hook for dynamic class
pub fn (p Plugin) get_dynamic_class_hook(fullname string) ?fn (DynamicClassDefContext) {
	return none
}

// ChainedPlugin — plugin representing a chain of plugins
pub struct ChainedPlugin {
	Plugin
pub:
	plugins []Plugin
}

// new_chained_plugin creates a new ChainedPlugin
pub fn new_chained_plugin(options Options, plugins []Plugin) ChainedPlugin {
	return ChainedPlugin{
		Plugin:  new_plugin(options)
		plugins: plugins
	}
}

// set_modules sets modules for all plugins
pub fn (mut cp ChainedPlugin) set_modules(modules map[string]MypyFile) {
	for mut plugin in cp.plugins {
		plugin.set_modules(modules)
	}
}

// get_type_analyze_hook finds the first non-null hook
pub fn (cp ChainedPlugin) get_type_analyze_hook(fullname string) ?fn (AnalyzeTypeContext) MypyTypeNode {
	for plugin in cp.plugins {
		hook := plugin.get_type_analyze_hook(fullname)
		if hook != none {
			return hook
		}
	}
	return none
}

// get_function_hook finds the first non-null hook
pub fn (cp ChainedPlugin) get_function_hook(fullname string) ?fn (FunctionContext) MypyTypeNode {
	for plugin in cp.plugins {
		hook := plugin.get_function_hook(fullname)
		if hook != none {
			return hook
		}
	}
	return none
}

// get_method_hook finds the first non-null hook
pub fn (cp ChainedPlugin) get_method_hook(fullname string) ?fn (MethodContext) MypyTypeNode {
	for plugin in cp.plugins {
		hook := plugin.get_method_hook(fullname)
		if hook != none {
			return hook
		}
	}
	return none
}

// get_attribute_hook finds the first non-null hook
pub fn (cp ChainedPlugin) get_attribute_hook(fullname string) ?fn (AttributeContext) MypyTypeNode {
	for plugin in cp.plugins {
		hook := plugin.get_attribute_hook(fullname)
		if hook != none {
			return hook
		}
	}
	return none
}

// Helper types
pub struct Dependency {
pub:
	priority int
	module   string
	line     int
}

// Plugin interfaces (stubs)
pub interface TypeAnalyzerPluginInterface {
	options Options
	fail(msg string, ctx NodeBase, code ?ErrorCode)
	named_type(fullname string, args []MypyTypeNode) Instance
	analyze_type(typ MypyTypeNode) MypyTypeNode
}

pub interface CheckerPluginInterface {
	msg     MessageBuilder
	options Options
	path    string
	fail(msg string, ctx NodeBase, code ?ErrorCode) ?ErrorInfo
	named_generic_type(name string, args []MypyTypeNode) Instance
	get_expression_type(node Expression, type_context ?MypyTypeNode) MypyTypeNode
}

pub interface SemanticAnalyzerPluginInterface {
	modules         map[string]MypyFile
	options         Options
	cur_mod_id      string
	msg             MessageBuilder
	final_iteration bool
	named_type(fullname string, args ?[]MypyTypeNode) Instance
	builtin_type(fullname string) Instance
	fail(msg string, ctx NodeBase, serious bool, blocker bool, code ?ErrorCode)
	anal_type(typ MypyTypeNode, allow_unbound_tvars bool) ?MypyTypeNode
	lookup_fully_qualified(fullname string) SymbolTableNode
	lookup_qualified(name string, ctx NodeBase, suppress_errors bool) ?SymbolTableNode
	add_plugin_dependency(trigger string, target ?string)
	defer()
}

// Helper stub functions
fn lookup_fully_qualified(fullname string, modules map[string]MypyFile) ?SymbolTableNode {
	// Split fullname into module and name parts
	parts := fullname.split('.')
	if parts.len < 2 {
		return none
	}

	// Find module
	module_name := parts[0]
	mod := modules[module_name] or { return none }

	// Lookup in module namespace
	current := mod.names
	for i in 1 .. parts.len {
		name := parts[i]
		if name in current {
			sym := current[name]
			if i == parts.len - 1 {
				return sym
			}
			// Continue lookup in nested namespace
			if sym.node is TypeInfo {
				current = sym.node.names
			} else {
				return none
			}
		} else {
			return none
		}
	}

	return none
}
