// Я Cline работаю над этим файлом. Начало: 2026-03-22 20:31
// semanal.v — The semantic analyzer
// Переведён из mypy/semanal.py
// Примечание: это очень большой файл (~3000 строк), транслированы основные структуры и ключевые функции

module mypy

// Константы для областей видимости
pub const scope_global = 0
pub const scope_class = 1
pub const scope_func = 2
pub const scope_comprehension = 3
pub const scope_annotation = 4

// FUTURE_IMPORTS — маппинг future imports на флаги
pub const future_imports = {
	'__future__.nested_scopes':    'nested_scopes'
	'__future__.generators':       'generators'
	'__future__.division':         'division'
	'__future__.absolute_import':  'absolute_import'
	'__future__.with_statement':   'with_statement'
	'__future__.print_function':   'print_function'
	'__future__.unicode_literals': 'unicode_literals'
	'__future__.barry_as_FLUFL':   'barry_as_FLUFL'
	'__future__.generator_stop':   'generator_stop'
	'__future__.annotations':      'annotations'
}

// CORE_BUILTIN_CLASSES — базовые классы builtins
pub const core_builtin_classes = ['object', 'bool', 'function']

// SemanticAnalyzer — семантический анализатор mypy
pub struct SemanticAnalyzer {
pub mut:
	modules                              map[string]MypyFile
	globals                              SymbolTable
	global_decls                         []map[string]bool
	nonlocal_decls                       []map[string]bool
	locals                               []?SymbolTable
	scope_stack                          []int
	block_depth                          []int
	_type                                ?TypeInfo
	type_stack                           []?TypeInfo
	tvar_scope                           TypeVarLikeScope
	options                              Options
	function_stack                       []FuncItem
	progress                             bool
	deferred                             bool
	incomplete                           bool
	_final_iteration                     bool
	missing_names                        []map[string]bool
	loop_depth                           []int
	cur_mod_id                           string
	_is_stub_file                        bool
	_is_typeshed_stub_file               bool
	imports                              map[string]bool
	errors                               Errors
	plugin                               Plugin
	statement                            ?Statement
	cur_mod_node                         ?MypyFile
	msg                                  MessageBuilder
	scope                                Scope
	incomplete_type_stack                []bool
	allow_unbound_tvars                  bool
	basic_type_applications              bool
	current_overload_item                ?int
	inside_except_star_block             bool
	return_stmt_inside_except_star_block bool
	all_exports                          []string
	saved_locals                         map[string]SymbolTable
	incomplete_namespaces                map[string]bool
	deferral_debug_context               [][]string
	transitive_submodule_imports         map[string]map[string]bool
}

// new_semantic_analyzer создаёт новый SemanticAnalyzer
pub fn new_semantic_analyzer(modules map[string]MypyFile, errors Errors, plugin Plugin, options Options) SemanticAnalyzer {
	return SemanticAnalyzer{
		modules:                              modules
		globals:                              SymbolTable{}
		global_decls:                         [map[string]bool{}]
		nonlocal_decls:                       [map[string]bool{}]
		locals:                               [?SymbolTable(none)]
		scope_stack:                          [scope_global]
		block_depth:                          [0]
		_type:                                none
		type_stack:                           []?TypeInfo{}
		tvar_scope:                           TypeVarLikeScope{}
		options:                              options
		function_stack:                       []FuncItem{}
		progress:                             false
		deferred:                             false
		incomplete:                           false
		_final_iteration:                     false
		missing_names:                        [map[string]bool{}]
		loop_depth:                           [0]
		cur_mod_id:                           ''
		_is_stub_file:                        false
		_is_typeshed_stub_file:               false
		imports:                              map[string]bool{}
		errors:                               errors
		plugin:                               plugin
		statement:                            none
		cur_mod_node:                         none
		msg:                                  MessageBuilder{}
		scope:                                Scope{}
		incomplete_type_stack:                []bool{}
		allow_unbound_tvars:                  false
		basic_type_applications:              false
		current_overload_item:                none
		inside_except_star_block:             false
		return_stmt_inside_except_star_block: false
		all_exports:                          []string{}
		saved_locals:                         map[string]SymbolTable{}
		incomplete_namespaces:                map[string]bool{}
		deferral_debug_context:               [][]string{}
		transitive_submodule_imports:         map[string]map[string]bool{}
	}
}

// type возвращает текущий TypeInfo
pub fn (sa SemanticAnalyzer) type() ?TypeInfo {
	return sa._type
}

// is_stub_file проверяет, является ли файл stub
pub fn (sa SemanticAnalyzer) is_stub_file() bool {
	return sa._is_stub_file
}

// is_typeshed_stub_file проверяет, является ли файл stub из typeshed
pub fn (sa SemanticAnalyzer) is_typeshed_stub_file() bool {
	return sa._is_typeshed_stub_file
}

// final_iteration проверяет, является ли это финальной итерацией
pub fn (sa SemanticAnalyzer) final_iteration() bool {
	return sa._final_iteration
}

// prepare_file подготавливает файл к анализу
pub fn (mut sa SemanticAnalyzer) prepare_file(file_node MypyFile) {
	if 'builtins' in sa.modules {
		file_node.names['__builtins__'] = SymbolTableNode{
			kind: 0 // GDEF
			node: sa.modules['builtins']
		}
	}
	if file_node.fullname == 'builtins' {
		sa.prepare_builtins_namespace(file_node)
	}
}

// prepare_builtins_namespace добавляет специальные определения в builtins
fn (mut sa SemanticAnalyzer) prepare_builtins_namespace(file_node MypyFile) {
	names := file_node.names

	// Добавляем пустые определения для базовых классов
	for name in core_builtin_classes {
		cdef := ClassDef{
			name: name
			defs: Block{
				body: []
			}
		}
		info := new_type_info(names, cdef, 'builtins')
		info._fullname = 'builtins.${name}'
		names[name] = SymbolTableNode{
			kind: 0
			node: info
		}
	}

	// Добавляем специальные переменные
	bool_info := names['bool'].node
	assert bool_info is TypeInfoNode

	special_names := ['None', 'reveal_type', 'reveal_locals', 'True', 'False', '__debug__']
	special_types := [
		NoneTypeNode{},
		AnyTypeNode{
			reason: TypeOfAny.special_form
		},
		AnyTypeNode{
			reason: TypeOfAny.special_form
		},
		InstanceNode{
			typ:  bool_info
			args: []
		},
		InstanceNode{
			typ:  bool_info
			args: []
		},
		InstanceNode{
			typ:  bool_info
			args: []
		},
	]

	for i, name in special_names {
		typ := special_types[i]
		v := Var{
			name:            name
			type_annotation: typ
		}
		v._fullname = 'builtins.${name}'
		names[name] = SymbolTableNode{
			kind: 0
			node: v
		}
	}
}

// visit_mypy_file обрабатывает MypyFile
pub fn (mut sa SemanticAnalyzer) visit_mypy_file(file_node MypyFile) {
	sa.cur_mod_node = file_node
	sa.cur_mod_id = file_node.fullname
	sa.globals = file_node.names

	for defn in file_node.defs {
		sa.accept(defn)
	}
}

// visit_func_def обрабатывает определение функции
pub fn (mut sa SemanticAnalyzer) visit_func_def(defn FuncDef) {
	sa.statement = defn

	for arg in defn.arguments {
		if arg.initializer != none {
			// TODO: accept arg.initializer
		}
	}

	defn.is_conditional = sa.block_depth.last() > 0
	defn._fullname = sa.qualified_name(defn.name)

	if !sa.recurse_into_functions() || sa.function_stack.len > 0 {
		if !defn.is_decorated && !defn.is_overload {
			sa.add_function_to_symbol_table(defn)
		}
	}

	if !sa.recurse_into_functions() && !defn.def_or_infer_vars {
		return
	}

	sa.function_stack << defn
	sa.analyze_func_def(defn)
	sa.function_stack.pop()
}

// analyze_func_def анализирует определение функции
fn (mut sa SemanticAnalyzer) analyze_func_def(defn FuncDef) {
	if sa.push_type_args(defn.type_args, defn) == none {
		sa.defer(defn)
		return
	}

	sa.function_stack << defn

	mut has_self_type := false
	if defn.type != none {
		has_self_type = sa.update_function_type_variables(defn.type as CallableTypeNode,
			defn)
	}

	sa.function_stack.pop()

	if sa.is_class_scope() {
		defn.info = sa._type
	}

	// TODO: анализ сигнатуры функции
	sa.analyze_function_body(defn)
	sa.pop_type_args(defn.type_args)
}

// visit_class_def обрабатывает определение класса
pub fn (mut sa SemanticAnalyzer) visit_class_def(defn ClassDef) {
	sa.statement = defn
	sa.incomplete_type_stack << (defn.info == none)

	namespace := sa.qualified_name(defn.name)
	if sa.push_type_args(defn.type_args, defn) == none {
		sa.mark_incomplete(defn.name, defn)
		return
	}

	sa.analyze_class(defn)
	sa.pop_type_args(defn.type_args)
	sa.incomplete_type_stack.pop()
}

// analyze_class анализирует определение класса
fn (mut sa SemanticAnalyzer) analyze_class(defn ClassDef) {
	fullname := sa.qualified_name(defn.name)

	if defn.info == none && !sa.is_core_builtin_class(defn) {
		placeholder := PlaceholderNode{
			fullname:         fullname
			node:             defn
			line:             defn.line
			becomes_typeinfo: true
		}
		sa.add_symbol(defn.name, placeholder, defn)
	}

	// TODO: полная реализация анализа класса
	sa.prepare_class_def(defn)
	sa.setup_type_vars(defn, [])

	sa.enter_class(defn.info or { return })
	defn.defs.accept(sa)
	sa.leave_class()
}

// visit_import обрабатывает import
pub fn (mut sa SemanticAnalyzer) visit_import(i Import) {
	sa.statement = i
	for id, as_id in i.ids {
		use_implicit_reexport := !sa.is_stub_file() && sa.options.implicit_reexport
		base_id := if as_id != none { id } else { id.split('.')[0] }
		imported_id := if as_id != none { as_id } else { base_id }
		module_public := use_implicit_reexport || (as_id != none && id == as_id)

		if base_id in sa.modules {
			node := sa.modules[base_id]
			kind := if sa.is_func_scope() {
				2
			} else if sa._type != none {
				1
			} else {
				0
			}
			symbol := SymbolTableNode{
				kind:          kind
				node:          node
				module_public: module_public
				module_hidden: !module_public
			}
			sa.add_imported_symbol(imported_id, symbol, i, module_public, !module_public)
		} else {
			sa.add_unknown_imported_symbol(imported_id, i, base_id, module_public, !module_public)
		}
	}
}

// visit_import_from обрабатывает from ... import
pub fn (mut sa SemanticAnalyzer) visit_import_from(imp ImportFrom) {
	sa.statement = imp
	mod_id := sa.correct_relative_import(imp)
	mod := sa.modules[mod_id] or { none }

	for id, as_id in imp.names {
		fullname := '${mod_id}.${id}'
		sa.set_future_import_flags(fullname)

		mut node := ?SymbolTableNode(none)
		if mod != none {
			node = (mod as MypyFile).names[id] or { none }
		}

		imported_id := if as_id != none { as_id } else { id }
		use_implicit_reexport := !sa.is_stub_file() && sa.options.implicit_reexport
		module_public := use_implicit_reexport || (as_id != none && id == as_id)

		if node != none {
			sa.add_imported_symbol(imported_id, node, imp, module_public, !module_public)
		} else if mod != none {
			sa.report_missing_module_attribute(mod_id, id, imported_id, imp)
		} else {
			sa.add_unknown_imported_symbol(imported_id, imp, fullname, module_public,
				!module_public)
		}
	}
}

// visit_assignment_stmt обрабатывает присваивание
pub fn (mut sa SemanticAnalyzer) visit_assignment_stmt(s AssignmentStmt) {
	sa.statement = s

	if sa.analyze_identity_global_assignment(s) {
		return
	}

	tag := sa.track_incomplete_refs()
	// TODO: анализ rvalue
	s.rvalue.accept(sa)

	if sa.found_incomplete_ref(tag) {
		for expr in sa.names_modified_by_assignment(s) {
			sa.mark_incomplete(expr.name, expr)
		}
		return
	}

	// TODO: проверка special forms (type alias, TypeVar, и т.д.)
	s.is_final_def = sa.unwrap_final(s)
	sa.analyze_lvalues(s)
	// TODO: дополнительные проверки
}

// visit_if_stmt обрабатывает if
pub fn (mut sa SemanticAnalyzer) visit_if_stmt(s IfStmt) {
	sa.statement = s
	// TODO: infer_reachability_of_if_statement
	for i in 0 .. s.expr.len {
		s.expr[i].accept(sa)
		sa.visit_block(s.body[i])
	}
	sa.visit_block_maybe(s.else_body)
}

// visit_block обрабатывает блок
pub fn (mut sa SemanticAnalyzer) visit_block(b Block) {
	if b.is_unreachable {
		return
	}
	sa.block_depth[sa.block_depth.len - 1]++
	for s in b.body {
		sa.accept(s)
	}
	sa.block_depth[sa.block_depth.len - 1]--
}

// visit_block_maybe обрабатывает опциональный блок
pub fn (mut sa SemanticAnalyzer) visit_block_maybe(b ?Block) {
	if b != none {
		sa.visit_block(b)
	}
}

// visit_while_stmt обрабатывает while
pub fn (mut sa SemanticAnalyzer) visit_while_stmt(s WhileStmt) {
	sa.statement = s
	s.expr.accept(sa)
	sa.loop_depth[sa.loop_depth.len - 1]++
	sa.visit_block(s.body)
	sa.loop_depth[sa.loop_depth.len - 1]--
	sa.visit_block_maybe(s.else_body)
}

// visit_for_stmt обрабатывает for
pub fn (mut sa SemanticAnalyzer) visit_for_stmt(s ForStmt) {
	if s.is_async {
		// TODO: проверка async
	}
	sa.statement = s
	s.expr.accept(sa)
	sa.analyze_lvalue(s.index, false, s.index_type != none)
	sa.loop_depth[sa.loop_depth.len - 1]++
	sa.visit_block(s.body)
	sa.loop_depth[sa.loop_depth.len - 1]--
	sa.visit_block_maybe(s.else_body)
}

// visit_return_stmt обрабатывает return
pub fn (mut sa SemanticAnalyzer) visit_return_stmt(s ReturnStmt) {
	if !sa.is_func_scope() {
		sa.fail('"return" outside function', s)
	}
	if s.expr != none {
		s.expr.accept(sa)
	}
}

// visit_break_stmt обрабатывает break
pub fn (mut sa SemanticAnalyzer) visit_break_stmt(s BreakStmt) {
	if sa.loop_depth.last() == 0 {
		sa.fail('"break" outside loop', s, serious: true, blocker: true)
	}
}

// visit_continue_stmt обрабатывает continue
pub fn (mut sa SemanticAnalyzer) visit_continue_stmt(s ContinueStmt) {
	if sa.loop_depth.last() == 0 {
		sa.fail('"continue" outside loop', s, serious: true, blocker: true)
	}
}

// visit_try_stmt обрабатывает try
pub fn (mut sa SemanticAnalyzer) visit_try_stmt(s TryStmt) {
	sa.statement = s
	s.body.accept(sa)
	for i in 0 .. s.types.len {
		if s.types[i] != none {
			s.types[i].accept(sa)
		}
		if s.vars[i] != none {
			sa.analyze_lvalue(s.vars[i], false, false)
		}
		s.handlers[i].accept(sa)
	}
	sa.visit_block_maybe(s.else_body)
	sa.visit_block_maybe(s.finally_body)
}

// visit_decorator обрабатывает декоратор
pub fn (mut sa SemanticAnalyzer) visit_decorator(dec Decorator) {
	sa.statement = dec
	dec.decorators = dec.original_decorators.clone()
	dec.func.is_conditional = sa.block_depth.last() > 0

	if !dec.is_overload {
		sa.add_symbol(dec.name, dec, dec)
	}

	dec.func._fullname = sa.qualified_name(dec.name)
	dec.var._fullname = sa.qualified_name(dec.name)

	for d in dec.decorators {
		d.accept(sa)
	}

	// TODO: обработка специальных декораторов (abstractmethod, staticmethod и т.д.)
}

// visit_expression_stmt обрабатывает expression statement
pub fn (mut sa SemanticAnalyzer) visit_expression_stmt(s ExpressionStmt) {
	sa.statement = s
	s.expr.accept(sa)
}

// visit_name_expr обрабатывает имя
pub fn (mut sa SemanticAnalyzer) visit_name_expr(expr NameExpr) {
	n := sa.lookup(expr.name, expr)
	if n != none {
		sa.bind_name_expr(expr, n)
	}
}

// visit_member_expr обрабатывает member access
pub fn (mut sa SemanticAnalyzer) visit_member_expr(expr MemberExpr) {
	expr.expr.accept(sa)
	// TODO: обработка member access
}

// visit_call_expr обрабатывает вызов
pub fn (mut sa SemanticAnalyzer) visit_call_expr(expr CallExpr) {
	expr.callee.accept(sa)
	// TODO: обработка специальных вызовов (cast, reveal_type и т.д.)
	for a in expr.args {
		a.accept(sa)
	}
}

// visit_int_expr обрабатывает int literal
pub fn (sa SemanticAnalyzer) visit_int_expr(expr IntExpr) {
	// Ничего не делаем
}

// visit_str_expr обрабатывает string literal
pub fn (sa SemanticAnalyzer) visit_str_expr(expr StrExpr) {
	// Ничего не делаем
}

// visit_pass_stmt обрабатывает pass
pub fn (sa SemanticAnalyzer) visit_pass_stmt(s PassStmt) {
	// Ничего не делаем
}

// accept принимает узел
pub fn (mut sa SemanticAnalyzer) accept(node Node) {
	// TODO: вызов node.accept(sa)
}

// lookup ищет имя
pub fn (sa SemanticAnalyzer) lookup(name string, ctx NodeBase) ?SymbolTableNode {
	// TODO: полная реализация поиска
	return none
}

// lookup_qualified ищет квалифицированное имя
pub fn (sa SemanticAnalyzer) lookup_qualified(name string, ctx NodeBase, suppress_errors bool) ?SymbolTableNode {
	if '.' !in name {
		return sa.lookup(name, ctx)
	}
	// TODO: полная реализация
	return none
}

// bind_name_expr привязывает имя
fn (mut sa SemanticAnalyzer) bind_name_expr(expr NameExpr, sym SymbolTableNode) {
	expr.kind = sym.kind
	expr.node = sym.node
	expr.fullname = sym.fullname or { '' }
}

// analyze_lvalue анализирует lvalue
pub fn (mut sa SemanticAnalyzer) analyze_lvalue(lval Lvalue, nested bool, explicit_type bool) {
	if lval is NameExpr {
		// TODO: анализ lvalue
	} else if lval is MemberExpr {
		lval.accept(sa)
	} else if lval is TupleExpr {
		for item in lval.items {
			sa.analyze_lvalue(item, true, explicit_type)
		}
	}
}

// names_modified_by_assignment возвращает имена, изменённые в присваивании
fn (sa SemanticAnalyzer) names_modified_by_assignment(s AssignmentStmt) []NameExpr {
	mut result := []NameExpr{}
	for lval in s.lvalues {
		result << sa.names_modified_in_lvalue(lval)
	}
	return result
}

// names_modified_in_lvalue возвращает NameExpr в lvalue
fn (sa SemanticAnalyzer) names_modified_in_lvalue(lval Lvalue) []NameExpr {
	if lval is NameExpr {
		return [lval]
	} else if lval is TupleExpr {
		mut result := []NameExpr{}
		for item in lval.items {
			result << sa.names_modified_in_lvalue(item)
		}
		return result
	}
	return []
}

// unwrap_final обрабатывает Final
fn (mut sa SemanticAnalyzer) unwrap_final(s AssignmentStmt) bool {
	// TODO: реализация
	return false
}

// analyze_identity_global_assignment проверяет X = X
fn (sa SemanticAnalyzer) analyze_identity_global_assignment(s AssignmentStmt) bool {
	// TODO: реализация
	return false
}

// qualified_name возвращает полное имя
fn (sa SemanticAnalyzer) qualified_name(name string) string {
	if sa._type != none {
		return (sa._type or { return '' })._fullname + '.' + name
	} else if sa.is_func_scope() {
		return name
	}
	return sa.cur_mod_id + '.' + name
}

// is_func_scope проверяет, находимся ли мы в функции
fn (sa SemanticAnalyzer) is_func_scope() bool {
	scope_type := sa.scope_stack.last()
	return scope_type in [scope_func, scope_comprehension]
}

// is_class_scope проверяет, находимся ли мы в классе
fn (sa SemanticAnalyzer) is_class_scope() bool {
	return sa._type != none && !sa.is_func_scope()
}

// is_module_scope проверяет, находимся ли мы в модуле
fn (sa SemanticAnalyzer) is_module_scope() bool {
	return !sa.is_class_scope() && !sa.is_func_scope()
}

// is_core_builtin_class проверяет, является ли класс базовым builtins
fn (sa SemanticAnalyzer) is_core_builtin_class(defn ClassDef) bool {
	return sa.cur_mod_id == 'builtins' && defn.name in core_builtin_classes
}

// recurse_into_functions проверяет, нужно ли рекурсивно обходить функции
fn (sa SemanticAnalyzer) recurse_into_functions() bool {
	return true // TODO: правильная реализация
}

// enter_class входит в класс
fn (mut sa SemanticAnalyzer) enter_class(info TypeInfo) {
	sa.type_stack << sa._type
	sa.locals << none
	sa.scope_stack << scope_class
	sa.block_depth << -1
	sa.loop_depth << 0
	sa._type = info
	sa.missing_names << map[string]bool{}
}

// leave_class выходит из класса
fn (mut sa SemanticAnalyzer) leave_class() {
	sa.block_depth.pop()
	sa.loop_depth.pop()
	sa.locals.pop()
	sa.scope_stack.pop()
	sa._type = sa.type_stack.pop()
	sa.missing_names.pop()
}

// add_function_to_symbol_table добавляет функцию в таблицу символов
fn (mut sa SemanticAnalyzer) add_function_to_symbol_table(func_def FuncDef) {
	if sa.is_class_scope() {
		func_def.info = sa._type
	}
	func_def._fullname = sa.qualified_name(func_def.name)
	sa.add_symbol(func_def.name, func_def, func_def)
}

// add_symbol добавляет символ
pub fn (mut sa SemanticAnalyzer) add_symbol(name string, node SymbolNode, context NodeBase) bool {
	// TODO: полная реализация
	return true
}

// add_imported_symbol добавляет импортированный символ
fn (mut sa SemanticAnalyzer) add_imported_symbol(name string, node SymbolTableNode, context ImportBase, module_public bool, module_hidden bool) {
	// TODO: реализация
}

// add_unknown_imported_symbol добавляет неизвестный импортированный символ
fn (mut sa SemanticAnalyzer) add_unknown_imported_symbol(name string, context NodeBase, target_name string, module_public bool, module_hidden bool) {
	// TODO: реализация
}

// report_missing_module_attribute сообщает об отсутствующем атрибуте модуля
fn (mut sa SemanticAnalyzer) report_missing_module_attribute(module_id string, source_id string, imported_id string, context NodeBase) {
	// TODO: реализация
}

// correct_relative_import исправляет относительный импорт
fn (sa SemanticAnalyzer) correct_relative_import(node ImportFrom) string {
	// TODO: реализация
	return node.id
}

// set_future_import_flags устанавливает флаги future import
fn (mut sa SemanticAnalyzer) set_future_import_flags(fullname string) {
	if fullname in future_imports {
		sa.cur_mod_node.future_import_flags << future_imports[fullname]
	}
}

// push_type_args добавляет type args
fn (mut sa SemanticAnalyzer) push_type_args(type_args []TypeParam, context NodeBase) ?[]string {
	// TODO: реализация
	return []string{}
}

// pop_type_args удаляет type args
fn (mut sa SemanticAnalyzer) pop_type_args(type_args []TypeParam) {
	// TODO: реализация
}

// update_function_type_variables обновляет типовые переменные функции
fn (mut sa SemanticAnalyzer) update_function_type_variables(fun_type CallableTypeNode, defn FuncItem) bool {
	// TODO: реализация
	return false
}

// analyze_function_body анализирует тело функции
fn (mut sa SemanticAnalyzer) analyze_function_body(defn FuncItem) {
	// TODO: реализация
	defn.body.accept(sa)
}

// prepare_class_def подготавливает определение класса
fn (mut sa SemanticAnalyzer) prepare_class_def(defn ClassDef) {
	// TODO: реализация
}

// setup_type_vars настраивает типовые переменные
fn (mut sa SemanticAnalyzer) setup_type_vars(defn ClassDef, tvar_defs []TypeVarLikeType) {
	// TODO: реализация
}

// mark_incomplete отмечает неполное определение
fn (mut sa SemanticAnalyzer) mark_incomplete(name string, node NodeBase) {
	sa.defer(node)
	sa.missing_names.last()[name] = true
}

// defer откладывает анализ
pub fn (mut sa SemanticAnalyzer) defer(debug_context NodeBase) {
	sa.deferred = true
}

// track_incomplete_refs отслеживает неполные ссылки
fn (mut sa SemanticAnalyzer) track_incomplete_refs() int {
	return 0 // TODO: реализация
}

// found_incomplete_ref проверяет наличие неполных ссылок
fn (sa SemanticAnalyzer) found_incomplete_ref(tag int) bool {
	return false // TODO: реализация
}

// fail сообщает об ошибке
pub fn (mut sa SemanticAnalyzer) fail(msg string, ctx NodeBase, serious bool, blocker bool) {
	// TODO: реализация
}

// Вспомогательные типы
type FuncItem = FuncDef | LambdaExpr | Decorator
type SymbolNode = FuncDef
	| Var
	| TypeInfo
	| Decorator
	| TypeAlias
	| PlaceholderNode
	| OverloadedFuncDef
type Lvalue = NameExpr | MemberExpr | TupleExpr | StarExpr | ListExpr
type Statement = FuncDef
	| ClassDef
	| AssignmentStmt
	| IfStmt
	| WhileStmt
	| ForStmt
	| ReturnStmt
	| Import
	| ImportFrom
	| Block
type Expression = NameExpr | MemberExpr | CallExpr | IntExpr | StrExpr | OpExpr
type NodeBase = Context | Statement | Expression | FuncDef | ClassDef
