// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 14:35
module mypy

// Семантический Анализатор (SemanticAnalyzer).
// Главный "Проход 2" (Pass 2) компилятора Mypy.
// Задача: обойти AST (узлы), разрешить все имена, собрать классы, функции в SymbolTables,
// выявить иерархическое наследование, загрузить плагины, создать TypeInfo для классов.

pub struct SemanticAnalyzer {
	NodeTraverser
pub mut:
	modules  map[string]&MypyFile
	options  &Options
	errors   &Errors
	
	// Состояние парсера модулей/прохода
	is_stub_file bool
	is_typeshed_file bool
	
	// Контексты текущего обхода (Scope)
	globals &SymbolTable = unsafe { nil }
	locals  []&SymbolTable
	
	current_class_node ?&ClassDef
	current_func_node  ?&FuncDef // FuncItem
	
	// Плагины и Анализатор типов
	plugin  &PluginInterface = unsafe { nil }
	// type_analyzer ?&TypeAnalyser
}


// -----------------------------------------------------
// Основные методы входа
// -----------------------------------------------------

pub fn (mut s SemanticAnalyzer) visit_file(file_node &MypyFile, fnam string, options &Options) {
	s.options = options
	s.is_stub_file = file_node.is_stub
	s.is_typeshed_file = file_node.is_stub // Упрощенно
	
	s.globals = &file_node.names

	s.locals = []
	
	// Предварительная инициализация модуля/__builtins__
	if '__builtins__' !in s.globals.symbols {
		s.globals.symbols['__builtins__'] = SymbolTableNode{
			kind: .module_ref
			// node: ... ссылка на модуль
		}
	} // Упрощенно
	
	// Для каждого выражения/оператора (Statement) в модуле
	for stmt in file_node.defs {
		s.accept(stmt)
	}
}

pub fn (mut s SemanticAnalyzer) accept(node Node) {
	node.accept(mut s) or {
		s.errors.add_error_info(&ErrorInfo{message: err.msg()}, none)
		return
	}
}


// -----------------------------------------------------
// Обработка Statements
// -----------------------------------------------------

pub fn (mut s SemanticAnalyzer) visit_class_def(defn &ClassDef) !string {
	// Подготовка TypeInfo для класса
	mut info := defn.info
	if info == none {
		info = &TypeInfo{
			fullname: defn.fullname
			names: SymbolTable{symbols: map[string]SymbolTableNode{}}

			module_name: defn.fullname // TODO: выделить module
		}
		defn.info = info
	}
	
	// Привязываем класс к текущей таблице символов
	s.add_symbol(defn.name, SymbolTableNode{
		kind: .type_info
		node: info
	})
	
	// Анализируем базовые классы (наследование)
	for i in 0 .. defn.base_type_exprs.len {
		// Тут мы анализируем expr через type_analyzer
		// Заглушка:
	}
	
	s.current_class_node = defn
	s.locals << &info.names

	
	// Рекурсивно перебираем методы и свойства класса
	for stmt in defn.defs.body {
		s.accept(stmt)
	}
	
	s.locals.pop()
	s.current_class_node = none
	
	return ''
}

pub fn (mut s SemanticAnalyzer) visit_func_def(defn &FuncDef) !string {
	// Заполняем имя функции в scope
	s.add_symbol(defn.name, SymbolTableNode{
		kind: .node
		node: defn
	})
	
	s.current_func_node = defn
	
	// Символы внутри функции
	func_locals := &SymbolTable{symbols: map[string]SymbolTableNode{}}

	s.locals << func_locals
	
	// Заносим аргументы в scope
	for arg in defn.arguments {
		arg_node := Var{
			name: arg.variable.name
			is_property: false
			is_classvar: false
		}
		s.add_symbol(arg.variable.name, SymbolTableNode{
			kind: .node
			node: arg_node
		})
	}
	
	// Обрабатываем тело
	for stmt in defn.body.body {
		s.accept(stmt)
	}
	
	s.locals.pop()
	s.current_func_node = none
	
	return ''
}

pub fn (mut s SemanticAnalyzer) visit_assignment_stmt(stmt &AssignmentStmt) !string {
	// Разбираем левую часть присваивания.
	// Если это новая переменная глобального/локального уровня (a = 5), создаем её в SymbolTable
	for lvalue in stmt.lvalues {
		if lvalue is NameExpr {
			// Если имя новое:
			if !s.is_defined_in_scope(lvalue.name) {
				var_node := Var{
					name: lvalue.name
					is_ready: false
				}
				s.add_symbol(lvalue.name, SymbolTableNode{
					kind: .node
					node: var_node
				})
			}
		} else if lvalue is MemberExpr {
			// class_val.field = 5 -> добавляем поле в TypeInfo (обычно это делает pass 3 или type analyzer)
		}
	}
	
	// Сканируем правую часть:
	s.accept(stmt.rvalue)
	
	return ''
}

pub fn (mut s SemanticAnalyzer) visit_import(stmt &Import) !string {
	// Добавляем импортированные модули в таблицу символов
	for id in stmt.ids {
		name := id.as_name or { id.name }
		s.add_symbol(name, SymbolTableNode{
			kind: .module_ref
			// node: модуль (ссылка через s.modules)
		})
	}
	return ''
}

// -----------------------------------------------------
// Хелперы Scope
// -----------------------------------------------------

pub fn (mut s SemanticAnalyzer) add_symbol(name string, node SymbolTableNode) {
	if s.locals.len > 0 {
		s.locals.last().symbols[name] = node
	} else {
		s.globals.symbols[name] = node
	}
}

pub fn (mut s SemanticAnalyzer) is_defined_in_scope(name string) bool {
	if s.locals.len > 0 {
		if name in s.locals.last().symbols { return true }
	} else {
		if name in s.globals.symbols { return true }
	}
	return false
}

// Реализация недостающих базовых Expression визиторов, чтобы не падало
pub fn (mut s SemanticAnalyzer) visit_name_expr(expr &NameExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_int_expr(expr &IntExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_str_expr(expr &StrExpr) !string { return '' }

// ... остальные expr
