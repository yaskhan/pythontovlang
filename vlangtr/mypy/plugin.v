// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 13:00
module mypy

// plugin.v — Система плагинов Mypy
// В Mypy плагины используются для кастомизации вывода типов и анализа классов.
// Библиотеки (например, dataclasses, pydantic, sqlalchemy) используют эту систему.

// Контексты, передаваемые функциям-хукам:

pub struct AnalyzeTypeContext {
pub mut:
	context    MypyNode
	typ        UnboundType
	api        &TypeAnalyzerPluginInterface
}

pub struct FunctionSigContext {
pub mut:
	args       [][]Expression
	default_   CallableType
	context    Context
	api        &CheckerPluginInterface
}

pub struct FunctionContext {
pub mut:
	arg_types  [][]MypyTypeNode
	arg_kinds  [][]int
	callee_arg_names []?string
	arg_names  [][]?string
	default_ret_type MypyTypeNode
	args       [][]Expression
	context    Context
	api        &CheckerPluginInterface
}

pub struct MethodSigContext {
pub mut:
	type_      MypyTypeNode
	args       [][]Expression
	default_   CallableType
	context    Context
	api        &CheckerPluginInterface
}

pub struct MethodContext {
pub mut:
	type_      MypyTypeNode
	arg_types  [][]MypyTypeNode
	arg_kinds  [][]int
	callee_arg_names []?string
	arg_names  [][]?string
	default_ret_type MypyTypeNode
	args       [][]Expression
	context    Context
	api        &CheckerPluginInterface
}

pub struct AttributeContext {
pub mut:
	type_      MypyTypeNode
	default_   MypyTypeNode
	context    Context
	api        &CheckerPluginInterface
}

pub struct ClassDefContext {
pub mut:
	cls        &ClassDef
	reason     Expression
	api        &SemanticAnalyzerPluginInterface
}

pub struct DynamicClassDefContext {
pub mut:
	call       &CallExpr
	name       string
	api        &SemanticAnalyzerPluginInterface
}

// CommonPluginApi для общих методов плагинов
pub interface CommonPluginApi {
}

// Интерфейсы, предоставляемые Mypy для плагинов (TypeAnalyzer, Checker, SemAnal)
pub interface TypeAnalyzerPluginInterface {
	fail(msg string, ctx Context)
}

pub interface CheckerPluginInterface {
	fail(msg string, ctx Context)
}

pub interface SemanticAnalyzerPluginInterface {
	fail(msg string, ctx Context)
}

// Типы коллбэков
pub type TypeHook = fn (ctx &AnalyzeTypeContext) MypyTypeNode
pub type FunctionSigHook = fn (ctx &FunctionSigContext) CallableType
pub type FunctionHook = fn (ctx &FunctionContext) MypyTypeNode
pub type MethodSigHook = fn (ctx &MethodSigContext) CallableType
pub type MethodHook = fn (ctx &MethodContext) MypyTypeNode
pub type AttributeHook = fn (ctx &AttributeContext) MypyTypeNode
pub type ClassDefHook = fn (ctx &ClassDefContext) bool
pub type DynamicClassDefHook = fn (ctx &DynamicClassDefContext)

// Базовый класс/структура плагина
pub struct Plugin {
pub mut:
	options &Options
}

// Mypy плагины регистрируются, возвращая нужный хук по 'fullname' функции/класса.
pub interface PluginInterface {
	get_type_analyze_hook(fullname string) ?TypeHook
	get_function_signature_hook(fullname string) ?FunctionSigHook
	get_function_hook(fullname string) ?FunctionHook
	get_method_signature_hook(fullname string) ?MethodSigHook
	get_method_hook(fullname string) ?MethodHook
	get_attribute_hook(fullname string) ?AttributeHook
	get_class_decorator_hook(fullname string) ?ClassDefHook
	get_metaclass_hook(fullname string) ?ClassDefHook
	get_base_class_hook(fullname string) ?ClassDefHook
	get_dynamic_class_hook(fullname string) ?DynamicClassDefHook
}

// ChainedPlugin (цепочка плагинов) для работы сразу нескольких плагинов (напр., pydantic + attrs)
pub struct ChainedPlugin {
pub mut:
	plugins []PluginInterface
}

pub fn (mut cp ChainedPlugin) get_function_hook(fullname string) ?FunctionHook {
	for mut p in cp.plugins {
		if hook := p.get_function_hook(fullname) {
			return hook
		}
	}
	return none
}

// ... и аналогично для всех остальных хуков в ChainedPlugin
