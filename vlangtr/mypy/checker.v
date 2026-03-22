// Я Cline работаю над этом файлом. Начало: 2026-03-22 20:47
// checker.v — Mypy type checker
// Переведён из mypy/checker.py
// Примечание: это очень большой файл (~4000 строк), транслированы основные структуры и ключевые функции

module mypy

// Константы
pub const default_last_pass = 2
pub const max_precise_tuple_size = 8

// DeferredNodeType — тип отложенного узла
pub type DeferredNodeType = FuncDef | OverloadedFuncDef | Decorator

// FineGrainedDeferredNodeType — тип для fine-grained режима
pub type FineGrainedDeferredNodeType = FuncDef | MypyFile | OverloadedFuncDef

// DeferredNode — узел, отложенный для обработки в следующем проходе
pub struct DeferredNode {
pub:
	node            DeferredNodeType
	active_typeinfo ?TypeInfo
}

// FineGrainedDeferredNode — узел для fine-grained режима
pub struct FineGrainedDeferredNode {
pub:
	node            FineGrainedDeferredNodeType
	active_typeinfo ?TypeInfo
}

// TypeMap — маппинг выражений на типы
pub type TypeMap = map[Expression]MypyTypeNode

// PartialTypeScope — область частичных типов
pub struct PartialTypeScope {
pub:
	map         map[Var]NodeBase
	is_function bool
	is_local    bool
}

// TypeChecker — проверяльщик типов mypy
pub struct TypeChecker {
pub mut:
	is_stub                  bool
	errors                   Errors
	msg                      MessageBuilder
	_type_maps               []map[Expression]MypyTypeNode
	binder                   ConditionalTypeBinder
	expr_checker             ExpressionChecker
	pattern_checker          PatternChecker
	tscope                   Scope
	scope                    CheckerScope
	_type                    ?TypeInfo
	return_types             []MypyTypeNode
	dynamic_funcs            []bool
	partial_types            []PartialTypeScope
	partial_reported         map[string]bool
	widened_vars             []string
	globals                  SymbolTable
	modules                  map[string]MypyFile
	deferred_nodes           []DeferredNode
	pass_num                 int
	last_pass                int
	current_node_deferred    bool
	is_typeshed_stub         bool
	options                  Options
	inferred_attribute_types ?map[Var]MypyTypeNode
	no_partial_types         bool
	module_refs              map[string]bool
	var_decl_frames          map[Var]map[int]bool
	plugin                   Plugin
	tree                     MypyFile
	path                     string
	_unique_id               int
	_is_final_def            bool
	overload_impl_stack      []OverloadPart
	checking_missing_await   bool
	allow_abstract_call      bool
	recurse_into_functions   bool
}

// new_type_checker создаёт новый TypeChecker
pub fn new_type_checker(errors Errors, modules map[string]MypyFile, options Options, tree MypyFile, path string, plugin Plugin) TypeChecker {
	return TypeChecker{
		is_stub:                  tree.is_stub
		errors:                   errors
		msg:                      MessageBuilder{
			errors:  errors
			modules: modules
		}
		_type_maps:               [map[Expression]MypyTypeNode{}]
		binder:                   new_conditional_type_binder(options)
		tscope:                   Scope{}
		scope:                    new_checker_scope(tree)
		_type:                    none
		return_types:             []MypyTypeNode{}
		dynamic_funcs:            []bool{}
		partial_types:            []PartialTypeScope{}
		partial_reported:         map[string]bool{}
		widened_vars:             []string{}
		globals:                  tree.names
		modules:                  modules
		deferred_nodes:           []DeferredNode{}
		pass_num:                 0
		last_pass:                default_last_pass
		current_node_deferred:    false
		is_typeshed_stub:         tree.is_typeshed_file(options)
		options:                  options
		inferred_attribute_types: none
		no_partial_types:         false
		module_refs:              map[string]bool{}
		var_decl_frames:          map[Var]map[int]bool{}
		plugin:                   plugin
		tree:                     tree
		path:                     path
		_unique_id:               0
		_is_final_def:            false
		overload_impl_stack:      []OverloadPart{}
		checking_missing_await:   false
		allow_abstract_call:      false
		recurse_into_functions:   true
		expr_checker:             ExpressionChecker{}
		pattern_checker:          PatternChecker{}
	}
}

// reset очищает состояние для повторного использования
pub fn (mut tc TypeChecker) reset() {
	tc.partial_reported.clear()
	tc.module_refs.clear()
	tc.binder = new_conditional_type_binder(tc.options)
	tc._type_maps = [map[Expression]MypyTypeNode{}]
	tc.deferred_nodes = []
	tc.partial_types = []
	tc.inferred_attribute_types = none
	tc.scope = new_checker_scope(tc.tree)
}

// check_first_pass проверяет файл в первом проходе
pub fn (mut tc TypeChecker) check_first_pass() {
	tc.recurse_into_functions = true
	tc.errors.set_file(tc.path, tc.tree.fullname, scope: tc.tscope, options: tc.options)

	for d in tc.tree.defs {
		tc.accept(d)
	}
}

// check_second_pass проверяет отложенные узлы
pub fn (mut tc TypeChecker) check_second_pass() bool {
	tc.recurse_into_functions = true
	if tc.deferred_nodes.len == 0 {
		return false
	}
	tc.pass_num++
	mut todo := tc.deferred_nodes.clone()
	tc.deferred_nodes = []

	for item in todo {
		node := item.node
		if node is MypyFile {
			tc.check_top_level(node)
		} else if node is FuncDef {
			tc.accept(node)
		} else if node is OverloadedFuncDef {
			tc.accept(node)
		} else if node is Decorator {
			tc.accept(node)
		}
	}
	return true
}

// check_top_level проверяет только верхний уровень модуля
pub fn (mut tc TypeChecker) check_top_level(node MypyFile) {
	tc.recurse_into_functions = false
	for d in node.defs {
		tc.accept(d)
	}
}

// accept принимает узел для проверки
pub fn (mut tc TypeChecker) accept(stmt Statement) {
	// TODO: вызов stmt.accept(tc)
}

// visit_func_def проверяет определение функции
pub fn (mut tc TypeChecker) visit_func_def(defn FuncDef) {
	if !tc.recurse_into_functions && !defn.def_or_infer_vars {
		return
	}
	tc.check_func_item(defn, name: defn.name)
}

// check_func_item проверяет элемент функции
pub fn (mut tc TypeChecker) check_func_item(defn FuncItem, name string) {
	tc.dynamic_funcs << defn.is_dynamic()

	if defn is FuncDef {
		tc.check_func_def(defn, name)
	}

	tc.dynamic_funcs.pop()
}

// check_func_def проверяет определение функции
fn (mut tc TypeChecker) check_func_def(defn FuncDef, name string) {
	if defn.type == none {
		return
	}
	typ := defn.type as CallableTypeNode

	// Сохраняем тип возврата
	tc.return_types << typ.ret_type

	// Проверяем тело функции
	defn.body.accept(tc)

	tc.return_types.pop()
}

// visit_class_def проверяет определение класса
pub fn (mut tc TypeChecker) visit_class_def(defn ClassDef) {
	typ := defn.info

	// Проверяем, что базовые классы не final
	for base in typ.mro[1..] {
		if base.is_final {
			tc.fail('Cannot inherit from final class "${base.name}"', defn)
		}
	}

	tc._type = typ
	defn.defs.accept(tc)
	tc._type = none
}

// visit_assignment_stmt проверяет присваивание
pub fn (mut tc TypeChecker) visit_assignment_stmt(s AssignmentStmt) {
	tc.check_assignment(s.lvalues.last(), s.rvalue)
}

// check_assignment проверяет присваивание
fn (mut tc TypeChecker) check_assignment(lvalue Lvalue, rvalue Expression) {
	if lvalue is TupleExpr || lvalue is ListExpr {
		// Проверяем множественное присваивание
		// TODO: реализация
	} else {
		tc.check_simple_assignment(lvalue, rvalue)
	}
}

// check_simple_assignment проверяет простое присваивание
fn (mut tc TypeChecker) check_simple_assignment(lvalue Lvalue, rvalue Expression) {
	// TODO: полная реализация проверки присваивания
}

// visit_return_stmt проверяет return
pub fn (mut tc TypeChecker) visit_return_stmt(s ReturnStmt) {
	if s.expr != none {
		ret_type := tc.return_types.last()
		// TODO: проверка типа возврата
	}
	tc.binder.unreachable()
}

// visit_if_stmt проверяет if
pub fn (mut tc TypeChecker) visit_if_stmt(s IfStmt) {
	for i in 0 .. s.expr.len {
		s.expr[i].accept(tc)
		s.body[i].accept(tc)
	}
	if s.else_body != none {
		s.else_body.accept(tc)
	}
}

// visit_while_stmt проверяет while
pub fn (mut tc TypeChecker) visit_while_stmt(s WhileStmt) {
	s.expr.accept(tc)
	s.body.accept(tc)
	if s.else_body != none {
		s.else_body.accept(tc)
	}
}

// visit_for_stmt проверяет for
pub fn (mut tc TypeChecker) visit_for_stmt(s ForStmt) {
	s.expr.accept(tc)
	tc.check_assignment(s.index, s.expr)
	s.body.accept(tc)
	if s.else_body != none {
		s.else_body.accept(tc)
	}
}

// visit_try_stmt проверяет try
pub fn (mut tc TypeChecker) visit_try_stmt(s TryStmt) {
	s.body.accept(tc)
	for i in 0 .. s.types.len {
		if s.types[i] != none {
			s.types[i].accept(tc)
		}
		s.handlers[i].accept(tc)
	}
	if s.else_body != none {
		s.else_body.accept(tc)
	}
	if s.finally_body != none {
		s.finally_body.accept(tc)
	}
}

// visit_block проверяет блок
pub fn (mut tc TypeChecker) visit_block(b Block) {
	if b.is_unreachable {
		tc.binder.unreachable()
		return
	}
	for s in b.body {
		if tc.binder.is_unreachable() {
			tc.msg.unreachable_statement(s)
			break
		}
		tc.accept(s)
	}
}

// visit_decorator проверяет декоратор
pub fn (mut tc TypeChecker) visit_decorator(e Decorator) {
	tc.visit_func_def(e.func)
}

// visit_expression_stmt проверяет expression statement
pub fn (mut tc TypeChecker) visit_expression_stmt(s ExpressionStmt) {
	tc.expr_checker.accept(s.expr)
}

// visit_break_stmt проверяет break
pub fn (mut tc TypeChecker) visit_break_stmt(s BreakStmt) {
	tc.binder.handle_break()
}

// visit_continue_stmt проверяет continue
pub fn (mut tc TypeChecker) visit_continue_stmt(s ContinueStmt) {
	tc.binder.handle_continue()
}

// visit_pass_stmt проверяет pass
pub fn (tc TypeChecker) visit_pass_stmt(s PassStmt) {
	// Ничего не делаем
}

// find_isinstance_check находит проверки isinstance
pub fn (tc TypeChecker) find_isinstance_check(node Expression) (TypeMap, TypeMap) {
	// TODO: полная реализация
	return TypeMap{}, TypeMap{}
}

// push_type_map добавляет карту типов
pub fn (mut tc TypeChecker) push_type_map(type_map TypeMap) {
	if tc.is_unreachable_map(type_map) {
		tc.binder.unreachable()
	} else {
		for expr, typ in type_map {
			tc.binder.put(expr, typ)
		}
	}
}

// is_unreachable_map проверяет, содержит ли карта UninhabitedType
fn (tc TypeChecker) is_unreachable_map(type_map TypeMap) bool {
	for v in type_map.values {
		if v is UninhabitedTypeNode {
			return true
		}
	}
	return false
}

// check_subtype проверяет подтип
pub fn (tc TypeChecker) check_subtype(subtype MypyTypeNode, supertype MypyTypeNode, context NodeBase, msg string) bool {
	if is_subtype(subtype, supertype) {
		return true
	}
	tc.fail(msg, context)
	return false
}

// fail сообщает об ошибке
pub fn (mut tc TypeChecker) fail(msg string, context NodeBase) {
	tc.msg.fail(msg, context)
}

// note сообщает информационное сообщение
pub fn (mut tc TypeChecker) note(msg string, context NodeBase) {
	tc.msg.note(msg, context)
}

// store_type сохраняет тип узла
pub fn (mut tc TypeChecker) store_type(node Expression, typ MypyTypeNode) {
	tc._type_maps.last()[node] = typ
}

// has_type проверяет, есть ли тип для узла
pub fn (tc TypeChecker) has_type(node Expression) bool {
	for m in tc._type_maps {
		if node in m {
			return true
		}
	}
	return false
}

// lookup_type ищет тип узла
pub fn (tc TypeChecker) lookup_type(node Expression) MypyTypeNode {
	for m in tc._type_maps.rev() {
		if node in m {
			return m[node]
		}
	}
	panic('Type not found for node')
}

// lookup_type_or_none ищет тип узла или возвращает none
pub fn (tc TypeChecker) lookup_type_or_none(node Expression) ?MypyTypeNode {
	for m in tc._type_maps.rev() {
		if node in m {
			return m[node]
		}
	}
	return none
}

// named_type возвращает Instance с заданным именем
pub fn (tc TypeChecker) named_type(name string) InstanceNode {
	sym := tc.lookup_qualified(name)
	node := sym.node
	assert node is TypeInfoNode
	return InstanceNode{
		typ:  node
		args: []
	}
}

// named_generic_type возвращает Instance с аргументами
pub fn (tc TypeChecker) named_generic_type(name string, args []MypyTypeNode) InstanceNode {
	info := tc.lookup_typeinfo(name)
	return InstanceNode{
		typ:  info
		args: args
	}
}

// lookup_typeinfo ищет TypeInfo
fn (tc TypeChecker) lookup_typeinfo(fullname string) TypeInfoNode {
	sym := tc.lookup_qualified(fullname)
	assert sym.node is TypeInfoNode
	return sym.node as TypeInfoNode
}

// lookup ищет символ
pub fn (tc TypeChecker) lookup(name string) SymbolTableNode {
	if name in tc.globals {
		return tc.globals[name]
	}
	b := tc.globals['__builtins__'] or { panic('Failed lookup: ${name}') }
	assert b.node is MypyFile
	table := (b.node as MypyFile).names
	if name in table {
		return table[name]
	}
	panic('Failed lookup: ${name}')
}

// lookup_qualified ищет квалифицированное имя
pub fn (tc TypeChecker) lookup_qualified(name string) SymbolTableNode {
	if '.' !in name {
		return tc.lookup(name)
	}
	parts := name.split('.')
	n := tc.modules[parts[0]]
	for i in 1 .. parts.len - 1 {
		sym := n.names[parts[i]] or { panic('Failed qualified lookup: ${name}') }
		assert sym.node is MypyFile
		n = sym.node as MypyFile
	}
	last := parts.last()
	if last in n.names {
		return n.names[last]
	}
	panic('Failed qualified lookup: ${name}')
}

// type_type возвращает тип 'type'
pub fn (tc TypeChecker) type_type() InstanceNode {
	return tc.named_type('builtins.type')
}

// function_type возвращает тип функции
pub fn (tc TypeChecker) function_type(func FuncBase) FunctionLikeNode {
	return function_type(func, tc.named_type('builtins.function'))
}

// Вспомогательные функции-заглушки
fn is_subtype(left MypyTypeNode, right MypyTypeNode) bool {
	return true
}

fn function_type(func FuncBase, fallback InstanceNode) FunctionLikeNode {
	// TODO: реализация
	return CallableTypeNode{
		fallback: fallback
	}
}
