// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 07:30
module mypy

// Основной модуль проверки типов (Type Checker).

pub struct DeferredNode {
pub:
	node            DeferredNodeType
	active_typeinfo ?&TypeInfo
}

pub type DeferredNodeType = FuncDef | OverloadedFuncDef | Decorator

pub struct TypeChecker {
	NodeTraverser
pub mut:
	is_stub                  bool

	errors                   &Errors
	msg                      &MessageBuilder
	type_maps                []map[Expression]MypyTypeNode
	binder                &ConditionalTypeBinder
	expr_checker_            &ExpressionCheckerSharedApi
	// pattern_checker       &PatternChecker
	
	// tscope                &Scope
	scope                    &CheckerScope
	type_                    ?&TypeInfo
	return_types             []MypyTypeNode
	dynamic_funcs            []bool
	// partial_types         []PartialTypeScope
	partial_reported         map[&Var]bool
	widened_vars             []string
	globals                  &SymbolTable
	modules                  map[string]&MypyFile
	deferred_nodes           []DeferredNode
	pass_num                 int
	last_pass                int
	current_node_deferred    bool
	is_typeshed_stub         bool
	options                  &Options
	inferred_attribute_types map[&Var]MypyTypeNode
	no_partial_types         bool
	module_refs              map[string]bool
	// var_decl_frames       map[&Var]map[int]bool
	
	recurse_into_functions   bool
	is_final_def             bool
}

pub fn (mut chk TypeChecker) expr_checker() &ExpressionCheckerSharedApi {
	return chk.expr_checker_
}

pub fn (mut chk TypeChecker) named_type(name string, args []MypyTypeNode) &Instance {
	return &Instance{
		typ: &TypeInfo{name: name}
		args: args
	}
}

pub fn (mut chk TypeChecker) lookup_type(node Expression) MypyTypeNode {
	for i := chk.type_maps.len - 1; i >= 0; i-- {
		if t := chk.type_maps[i][node] {
			return t
		}
	}
	return MypyTypeNode(AnyType{type_of_any: .from_error})
}

pub fn (mut chk TypeChecker) store_type(node Expression, typ MypyTypeNode) {
	if chk.type_maps.len > 0 {
		chk.type_maps[chk.type_maps.len - 1][node] = typ
	}
}

pub fn (mut chk TypeChecker) check_subtype(subtype MypyTypeNode, supertype MypyTypeNode, context Context, msg string, code ?string, expected ?MypyTypeNode, templates []string, expr ?Expression, options ?string) {
	// Stub for checking subtype
}

pub fn (mut chk TypeChecker) accept(node Node) {
	node.accept(mut chk) or {
		chk.errors.add_error_info(&ErrorInfo{message: err.msg()}, none)
	}
}

pub fn (mut chk TypeChecker) visit_block(b &Block) {
	for stmt in b.body {
		chk.accept(stmt)
	}
}

pub fn (mut chk TypeChecker) visit_while_stmt(s &WhileStmt) {
	// В Mypy while проверяется через фиктивный if внутри цикла
	mut if_node := &IfStmt{
		expr: [s.expr]
		body: [s.body]
	}
	chk.accept_loop(if_node, s.else_body, s.expr)
}

pub fn (mut chk TypeChecker) accept_loop(body Node, else_body ?&Block, exit_condition ?Expression) {
	chk.binder.push_frame(true) // conditional_frame
	
	mut iter := 0
	for {
		iter++
		chk.binder.push_frame(false)
		chk.accept(body)
		chk.binder.pop_frame(true, 1, false) // can_skip=true
		
		if !chk.binder.last_pop_changed || iter > 5 {
			break
		}
	}
	
	if eb := else_body {
		chk.accept(eb)
	}
	
	if cond := exit_condition {
		_, else_map := chk.find_isinstance_check(cond)
		chk.push_type_map(else_map)
	}
	
	chk.binder.pop_frame(false, 0, false)
}

pub fn (mut chk TypeChecker) visit_if_stmt(s &IfStmt) {
	chk.binder.push_frame(true)
	for i := 0; i < s.expr.len; i++ {
		e := s.expr[i]
		b := s.body[i]
		_ = chk.expr_checker_.accept(e, none, false, false, false)
		if_map, else_map := chk.find_isinstance_check(e)
		chk.binder.push_frame(false)
		chk.push_type_map(if_map)
		chk.accept(b)
		chk.binder.pop_frame(true, 2, false)
		chk.push_type_map(else_map)
	}
	if eb := s.else_body {
		chk.binder.push_frame(false)
		chk.accept(eb)
		chk.binder.pop_frame(true, 2, false)
	}
	chk.binder.pop_frame(false, 0, false)
}

pub fn (mut chk TypeChecker) visit_for_stmt(s &ForStmt) {
	_ = chk.expr_checker_.accept(s.expr, none, false, false, false)
	chk.accept_loop(s.body, s.else_body, none)
}

pub fn (mut chk TypeChecker) visit_return_stmt(s &ReturnStmt) {
	if ex := s.expr {
		mut return_type := MypyTypeNode(AnyType{type_of_any: .from_error})
		if chk.return_types.len > 0 {
			return_type = chk.return_types.last()
		}
		
		_ = chk.expr_checker_.accept(ex, return_type, true, false, false)
	}
	chk.binder.unreachable()
}

pub fn (mut chk TypeChecker) visit_break_stmt(s &BreakStmt) {
	chk.binder.handle_break()
}

pub fn (mut chk TypeChecker) visit_continue_stmt(s &ContinueStmt) {
	chk.binder.handle_continue()
}

pub fn (mut chk TypeChecker) visit_pass_stmt(s &PassStmt) {
}

pub fn (mut chk TypeChecker) visit_expression_stmt(s &ExpressionStmt) {
	_ = chk.expr_checker_.accept(s.expr, none, true, false, false)
}

pub fn (mut chk TypeChecker) visit_try_stmt(s &TryStmt) {
	// Our enclosing frame will get the result if the try/except falls through.
	chk.binder.push_frame(false)
	
	chk.binder.push_frame(false) // frame with fall_through=2
	chk.binder.push_frame(true) // conditional_frame
	chk.binder.push_frame(false) // body
	chk.accept(s.body)
	chk.binder.pop_frame(true, 2, false)
	
	for h in s.handlers {
		chk.binder.push_frame(true) // fall_through=4
		chk.accept(h)
		chk.binder.pop_frame(true, 4, false)
	}
	chk.binder.pop_frame(true, 2, false)
	
	if eb := s.else_body {
		chk.accept(eb)
	}
	chk.binder.pop_frame(true, 2, false)
	
	if fb := s.finally_body {
		chk.accept(fb)
	}
	
	if fb2 := s.finally_body {
		if !chk.binder.frames.last().unreachable {
			chk.accept(fb2)
		}
	}
	
	chk.binder.pop_frame(false, 0, false)
}

pub fn (mut chk TypeChecker) visit_with_stmt(s &WithStmt) {
	for i := 0; i < s.expr.len; i++ {
		e := s.expr[i]
		t := s.target[i]
		
		_ = chk.expr_checker_.accept(e, none, false, false, false)
		if t != none {
			// analyze and assign to target
		}
	}
	chk.accept(s.body)
}

pub fn (mut chk TypeChecker) find_isinstance_check(e Expression) (map[Expression]MypyTypeNode, map[Expression]MypyTypeNode) {
	mut if_map := map[Expression]MypyTypeNode{}
	mut else_map := map[Expression]MypyTypeNode{}
	return if_map, else_map
}

pub fn (mut chk TypeChecker) push_type_map(type_map map[Expression]MypyTypeNode) {
	for expr, typ in type_map {
		chk.binder.put(expr, typ, false)
	}
}

pub fn (mut chk TypeChecker) visit_assignment_stmt(s &AssignmentStmt) {
	if s.is_alias_def && chk.is_stub { return }
	
	mut rvalue_type := chk.expr_checker_.accept(s.rvalue, none, false, false, false)
	rvalue_type = get_proper_type(rvalue_type)
	
	for lvalue in s.lvalues {
		chk.check_assignment(lvalue, s.rvalue, rvalue_type, s.type_annotation, false)
	}
}

pub fn (mut chk TypeChecker) check_assignment(lvalue Expression, rvalue Expression, rvalue_type MypyTypeNode, type_ ?MypyTypeNode, new_syntax bool) {
	if lvalue is TupleExpr || lvalue is ListExpr {
		// chk.check_unpacking(...) // Распаковка a, b = c
		return
	}
	
	if lvalue is NameExpr {
		// Простая переменная
		if t := type_ {
			// type annotation check
			chk.check_subtype(rvalue_type, t, lvalue.get_context(), "Incompatible types in assignment", none, none, [], none, none)
		} else {
			// type inference
			chk.store_type(lvalue, rvalue_type)
		}
	} else if lvalue is MemberExpr {
		// obj.field = value
	} else if lvalue is IndexExpr {
		// A[i] = ... -> call __setitem__
	}
}

pub fn (mut chk TypeChecker) visit_func_def(defn &FuncDef) {
	if !chk.recurse_into_functions {
		return
	}
	
	chk.check_func_item(defn, none)
}

pub fn (mut chk TypeChecker) check_func_item(defn &FuncDef, type_override ?&CallableType) {
	// 1. Узнаем тип функции
	mut typ_node := MypyTypeNode(AnyType{type_of_any: .special_form})
	if t := defn.type_ {
		typ_node = t
	} else if override := type_override {
		typ_node = MypyTypeNode(*override)
	}
	
	if typ_node is CallableType {
		typ := typ_node as CallableType
		// 2. Создаем новый фрейм для функции
		old_binder := chk.binder
		chk.binder = &ConditionalTypeBinder{ /* options: chk.options */ }
		
		chk.binder.push_frame(true) // Top frame for function
		
		chk.return_types << typ.ret_type
		
		// 3. Инициализация типов аргументов в binder
		for i, arg in defn.arguments {
			argument_type := if i < typ.arg_types.len { typ.arg_types[i] } else { MypyTypeNode(AnyType{type_of_any: .unannotated}) }
			chk.binder.put(arg.variable, argument_type, false)
		}
		
		// 4. Обход тела!
		chk.accept(defn.body)
		
		// 5. Проверка Missing return
		is_unreachable := chk.binder.frames.last().unreachable
		
		// Убираем контекст функции
		chk.return_types.pop()
		chk.binder.pop_frame(true, 0, false)
		chk.binder = old_binder
		
		if !is_unreachable && !(typ.ret_type is NoneType) && !(typ.ret_type is AnyType) {
			// Missing return statement
			chk.msg.fail("Missing return statement", defn.base.ctx, false, false, none)
		}
	} else {
		// Динамическая функция (без аннотаций)
		old_binder := chk.binder
		chk.binder = &ConditionalTypeBinder{}
		chk.binder.push_frame(true)
		chk.return_types << MypyTypeNode(AnyType{type_of_any: .unannotated})
		
		chk.accept(defn.body)
		
		chk.return_types.pop()
		chk.binder.pop_frame(true, 0, false)
		chk.binder = old_binder
	}
}

pub fn (mut chk TypeChecker) visit_class_def(defn &ClassDef) {
	// 1. Проверки мета-информации базовых классов (Final, disjoint bases)
	typ := defn.info
	if info := typ {
		_ = info
		// TODO: validate final inheritances
	}
	
	// 2. Входим в область видимости класса, подменяя scope
	
	// 3. Создаем новый фрейм (Scope) для переменных, определяемых внутри класса
	old_binder := chk.binder
	chk.binder = &ConditionalTypeBinder{}
	chk.binder.push_frame(true) // Top frame for class body
	
	// 4. Обходим само определение класса (переменные, методы, вложенные классы)
	chk.accept(defn.defs)
	
	// 5. Восстанавливаем статус-кво
	chk.binder.pop_frame(true, 0, false)
	chk.binder = old_binder
	
	// 6. Проверка множественного наследования и метаклассов
	
	// 7. Проверка декораторов класса
	if defn.decorators.len > 0 {
		for dec in defn.decorators {
			_ = chk.expr_checker_.accept(dec, none, false, false, false)
		}
	}
}

pub fn (mut chk TypeChecker) visit_global_decl(node &GlobalDecl) {
	// В Mypy глобальные объявления часто просто пробрасывают имена в глобальный scope
	for name in node.names {
		_ = name
	}
}

pub fn (mut chk TypeChecker) visit_nonlocal_decl(node &NonlocalDecl) {
	// Ищет переменную в ближайшем внешнем scope (кроме глобального)
	for name in node.names {
		_ = name
	}
}

pub fn (mut chk TypeChecker) visit_del_stmt(node &DelStmt) {
	// Тип проверка del_stmt: можно удалять NameExpr, IndexExpr, MemberExpr
	_ = chk.expr_checker_.accept(node.expr, none, false, false, false)
}

pub fn (mut chk TypeChecker) visit_import(node &Import) {
}

pub fn (mut chk TypeChecker) visit_import_from(node &ImportFrom) {
}

pub fn (mut chk TypeChecker) visit_import_all(node &ImportAll) {
}

pub fn (mut chk TypeChecker) visit_match_stmt(node &MatchStmt) {
	// 1. Вычисляем тип subject
	subject_type := chk.expr_checker_.accept(node.subject, none, false, false, false)
	
	// 2. Идем по всем паттернам (case)
	mut pc := PatternChecker{
		chk: chk
	}
	
	for i, pattern in node.patterns {
		// 3. Получаем какие переменные захватил паттерн, и их типы
		res := pc.accept(pattern, subject_type)
		chk.binder.push_frame(true)
		
		for _, _ in res.captures {
			// Привязываем переменные к scope
		}
		
		// 4. Если есть guard (if case), тоже проверяем
		if guard := node.guards[i] {
			_ = chk.expr_checker_.accept(guard, none, false, false, false)
		}
		
		// 5. Обрабатываем тело
		chk.accept(node.bodies[i])
		chk.binder.pop_frame(true, 0, false)
	}
}
