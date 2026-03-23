// Я Cline работаю над этим файлом. Начало: 2026-03-22 19:50
// plugin.v — Plugin system for extending mypy
// Переведён из mypy/plugin.py

module mypy

// AnalyzeTypeContext — контекст для хука семантического анализа типа
pub struct AnalyzeTypeContext {
pub:
	typ     UnboundType
	context NodeBase
	api     TypeAnalyzerPluginInterface
}

// ReportConfigContext — контекст для запроса данных конфигурации модуля
pub struct ReportConfigContext {
pub:
	id       string
	path     string
	is_check bool
}

// FunctionSigContext — контекст для хука сигнатуры функции
pub struct FunctionSigContext {
pub:
	args              [][]Expression
	default_signature CallableType
	context           NodeBase
	api               CheckerPluginInterface
}

// FunctionContext — контекст для хука функции
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

// MethodSigContext — контекст для хука сигнатуры метода
pub struct MethodSigContext {
pub:
	typ               ProperType
	args              [][]Expression
	default_signature CallableType
	context           NodeBase
	api               CheckerPluginInterface
}

// MethodContext — контекст для хука метода
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

// AttributeContext — контекст для хука типа атрибута
pub struct AttributeContext {
pub:
	typ               ProperType
	default_attr_type MypyTypeNode
	is_lvalue         bool
	context           NodeBase
	api               CheckerPluginInterface
}

// ClassDefContext — контекст для хука определения класса
pub struct ClassDefContext {
pub:
	cls    ClassDef
	reason Expression
	api    SemanticAnalyzerPluginInterface
}

// DynamicClassDefContext — контекст для динамического определения класса
pub struct DynamicClassDefContext {
pub:
	call CallExpr
	name string
	api  SemanticAnalyzerPluginInterface
}

// Plugin — базовый класс всех плагинов mypy
pub struct Plugin {
pub mut:
	options        Options
	python_version (int, int)
	modules        ?map[string]MypyFile
}

// new_plugin создаёт новый Plugin
pub fn new_plugin(options Options) Plugin {
	return Plugin{
		options:        options
		python_version: options.python_version
		modules:        none
	}
}

// set_modules устанавливает модули для плагина
pub fn (mut p Plugin) set_modules(modules map[string]MypyFile) {
	p.modules = modules
}

// lookup_fully_qualified ищет символ по полному имени
pub fn (p Plugin) lookup_fully_qualified(fullname string) ?SymbolTableNode {
	if modules := p.modules {
		return lookup_fully_qualified(fullname, modules)
	}
	return none
}

// report_config_data возвращает данные конфигурации для модуля
pub fn (p Plugin) report_config_data(ctx ReportConfigContext) ?Any {
	return none
}

// get_additional_deps возвращает дополнительные зависимости для модуля
pub fn (p Plugin) get_additional_deps(file MypyFile) []Dependency {
	return []Dependency{}
}

// get_type_analyze_hook возвращает хук для анализа типа
pub fn (p Plugin) get_type_analyze_hook(fullname string) ?fn (AnalyzeTypeContext) MypyTypeNode {
	return none
}

// get_function_signature_hook возвращает хук для сигнатуры функции
pub fn (p Plugin) get_function_signature_hook(fullname string) ?fn (FunctionSigContext) MypyTypeNode {
	return none
}

// get_function_hook возвращает хук для функции
pub fn (p Plugin) get_function_hook(fullname string) ?fn (FunctionContext) MypyTypeNode {
	return none
}

// get_method_signature_hook возвращает хук для сигнатуры метода
pub fn (p Plugin) get_method_signature_hook(fullname string) ?fn (MethodSigContext) MypyTypeNode {
	return none
}

// get_method_hook возвращает хук для метода
pub fn (p Plugin) get_method_hook(fullname string) ?fn (MethodContext) MypyTypeNode {
	return none
}

// get_attribute_hook возвращает хук для атрибута
pub fn (p Plugin) get_attribute_hook(fullname string) ?fn (AttributeContext) MypyTypeNode {
	return none
}

// get_class_attribute_hook возвращает хук для атрибута класса
pub fn (p Plugin) get_class_attribute_hook(fullname string) ?fn (AttributeContext) MypyTypeNode {
	return none
}

// get_class_decorator_hook возвращает хук для декоратора класса
pub fn (p Plugin) get_class_decorator_hook(fullname string) ?fn (ClassDefContext) {
	return none
}

// get_class_decorator_hook_2 возвращает хук для декоратора класса (после разрешения placeholders)
pub fn (p Plugin) get_class_decorator_hook_2(fullname string) ?fn (ClassDefContext) bool {
	return none
}

// get_metaclass_hook возвращает хук для метакласса
pub fn (p Plugin) get_metaclass_hook(fullname string) ?fn (ClassDefContext) {
	return none
}

// get_base_class_hook возвращает хук для базового класса
pub fn (p Plugin) get_base_class_hook(fullname string) ?fn (ClassDefContext) {
	return none
}

// get_customize_class_mro_hook возвращает хук для настройки MRO
pub fn (p Plugin) get_customize_class_mro_hook(fullname string) ?fn (ClassDefContext) {
	return none
}

// get_dynamic_class_hook возвращает хук для динамического класса
pub fn (p Plugin) get_dynamic_class_hook(fullname string) ?fn (DynamicClassDefContext) {
	return none
}

// ChainedPlugin — плагин, представляющий цепочку плагинов
pub struct ChainedPlugin {
	Plugin
pub:
	plugins []Plugin
}

// new_chained_plugin создаёт новый ChainedPlugin
pub fn new_chained_plugin(options Options, plugins []Plugin) ChainedPlugin {
	return ChainedPlugin{
		Plugin:  new_plugin(options)
		plugins: plugins
	}
}

// set_modules устанавливает модули для всех плагинов
pub fn (mut cp ChainedPlugin) set_modules(modules map[string]MypyFile) {
	for mut plugin in cp.plugins {
		plugin.set_modules(modules)
	}
}

// get_type_analyze_hook ищет первый ненулевой хук
pub fn (cp ChainedPlugin) get_type_analyze_hook(fullname string) ?fn (AnalyzeTypeContext) MypyTypeNode {
	for plugin in cp.plugins {
		hook := plugin.get_type_analyze_hook(fullname)
		if hook != none {
			return hook
		}
	}
	return none
}

// get_function_hook ищет первый ненулевой хук
pub fn (cp ChainedPlugin) get_function_hook(fullname string) ?fn (FunctionContext) MypyTypeNode {
	for plugin in cp.plugins {
		hook := plugin.get_function_hook(fullname)
		if hook != none {
			return hook
		}
	}
	return none
}

// get_method_hook ищет первый ненулевой хук
pub fn (cp ChainedPlugin) get_method_hook(fullname string) ?fn (MethodContext) MypyTypeNode {
	for plugin in cp.plugins {
		hook := plugin.get_method_hook(fullname)
		if hook != none {
			return hook
		}
	}
	return none
}

// get_attribute_hook ищет первый ненулевой хук
pub fn (cp ChainedPlugin) get_attribute_hook(fullname string) ?fn (AttributeContext) MypyTypeNode {
	for plugin in cp.plugins {
		hook := plugin.get_attribute_hook(fullname)
		if hook != none {
			return hook
		}
	}
	return none
}

// Вспомогательные типы
pub struct Dependency {
pub:
	priority int
	module   string
	line     int
}

// Интерфейсы плагинов (заглушки)
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

// Вспомогательные функции-заглушки
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
