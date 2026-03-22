// Я Cline работаю над этим файлом. Начало: 2026-03-22 14:49
// renaming.v — Variable renaming for redefinition support
// Переведён из mypy/renaming.py

module mypy

// Константы для типов областей видимости
pub const file_scope = 0
pub const function_scope = 1
pub const class_scope = 2

// VariableRenameVisitor переименовывает переменные для поддержки переопределения
// Например, код:
//   x = 0
//   f(x)
//   x = "a"
//   g(x)
// Трансформируется в:
//   x' = 0
//   f(x')
//   x = "a"
//   g(x)
pub struct VariableRenameVisitor {
pub mut:
	// Счётчик для нумерации новых блоков
	block_id int
	// Количество окружающих операторов try, запрещающих переопределение переменных
	disallow_redef_depth int
	// Количество окружающих циклов
	loop_depth int
	// Маппинг block_id -> loop_depth
	block_loop_depth map[int]int
	// Стек обрабатываемых block_id
	blocks []int
	// Список областей видимости; каждая область маппит имя -> block_id
	var_blocks []map[string]int

	// Ссылки на переменные, которые могут потребовать переименования
	// Список областей; каждая область — маппинг name -> list of collections
	refs []map[string][][]NameExpr
	// Количество чтений последнего определения переменной (на область)
	num_reads []map[string]int
	// Типы вложенных областей (FILE, FUNCTION или CLASS)
	scope_kinds []int
}

// new_variable_rename_visitor создаёт новый VariableRenameVisitor
pub fn new_variable_rename_visitor() VariableRenameVisitor {
	return VariableRenameVisitor{
		block_id:             0
		disallow_redef_depth: 0
		loop_depth:           0
		block_loop_depth:     map[int]int{}
		blocks:               []int{}
		var_blocks:           []map[string]int{}
		refs:                 []map[string][][]NameExpr{}
		num_reads:            []map[string]int{}
		scope_kinds:          []int{}
	}
}

// clear очищает состояние
pub fn (mut v VariableRenameVisitor) clear() {
	v.blocks = []
	v.var_blocks = []
}

// enter_block входит в новый блок
pub fn (mut v VariableRenameVisitor) enter_block() BlockGuard {
	v.block_id++
	v.blocks << v.block_id
	v.block_loop_depth[v.block_id] = v.loop_depth
	return BlockGuard{
		v: v
	}
}

// BlockGuard для автоматического выхода из блока
pub struct BlockGuard {
mut:
	v &VariableRenameVisitor
}

// drop удаляет блок при выходе
pub fn (bg BlockGuard) drop() {
	bg.v.blocks.pop()
}

// enter_try входит в try-блок
pub fn (mut v VariableRenameVisitor) enter_try() TryGuard {
	v.disallow_redef_depth++
	return TryGuard{
		v: v
	}
}

// TryGuard для автоматического выхода из try
pub struct TryGuard {
mut:
	v &VariableRenameVisitor
}

// drop уменьшает глубину try
pub fn (tg TryGuard) drop() {
	tg.v.disallow_redef_depth--
}

// enter_loop входит в цикл
pub fn (mut v VariableRenameVisitor) enter_loop() LoopGuard {
	v.loop_depth++
	return LoopGuard{
		v: v
	}
}

// LoopGuard для автоматического выхода из цикла
pub struct LoopGuard {
mut:
	v &VariableRenameVisitor
}

// drop уменьшает глубину цикла
pub fn (lg LoopGuard) drop() {
	lg.v.loop_depth--
}

// enter_scope входит в новую область видимости
pub fn (mut v VariableRenameVisitor) enter_scope(kind int) ScopeGuard {
	v.var_blocks << map[string]int{}
	v.refs << map[string][][]NameExpr{}
	v.num_reads << map[string]int{}
	v.scope_kinds << kind
	return ScopeGuard{
		v: v
	}
}

// ScopeGuard для автоматического выхода из области видимости
pub struct ScopeGuard {
mut:
	v &VariableRenameVisitor
}

// drop выполняет flush_refs при выходе
pub fn (sg ScopeGuard) drop() {
	sg.v.flush_refs()
	sg.v.var_blocks.pop()
	sg.v.num_reads.pop()
	sg.v.scope_kinds.pop()
}

// current_block возвращает текущий block_id
fn (v VariableRenameVisitor) current_block() int {
	return v.blocks[v.blocks.len - 1]
}

// is_nested проверяет, вложены ли мы
fn (v VariableRenameVisitor) is_nested() bool {
	return v.var_blocks.len > 1
}

// flush_refs обрабатывает ссылки на переменные
fn (mut v VariableRenameVisitor) flush_refs() {
	if v.refs.len == 0 {
		return
	}
	
	last_refs := v.refs.pop()
	last_reads := v.num_reads.pop()
	
	for name, collections in last_refs {
		reads := last_reads[name] or { 0 }
		
		// Если было переопределение и мало чтений
		if collections.len > 1 && reads <= 1 {
			// Переименовываем первое определение
			for i, coll in collections {
				if i > 0 {
					for expr in coll {
						// Помечаем для переименования
						expr.is_special_form = true
					}
				}
			}
		}
	}
}

// visit_name_expr обрабатывает имя переменной
pub fn (mut v VariableRenameVisitor) visit_name_expr(expr NameExpr) {
	if v.var_blocks.len == 0 {
		return
	}
	
	mut current := v.var_blocks.last()
	name := expr.name
	
	if name !in current {
		current[name] = v.current_block()
	} else {
		// Проверяем, в том же ли блоке определение
		def_block := current[name]
		if def_block != v.current_block() {
			// Переопределение в другом блоке
			if name !in v.refs.last() {
				v.refs.last()[name] = [][]NameExpr{}
			}
			v.refs.last()[name] << [expr]
		}
	}
}

// visit_assignment_stmt обрабатывает присваивание
pub fn (mut v VariableRenameVisitor) visit_assignment_stmt(stmt AssignmentStmt) {
	for lval in stmt.lvalues {
		v.visit_lvalue(lval)
	}
	if stmt.rvalue != none {
		v.visit_expression(stmt.rvalue)
	}
}

// visit_lvalue обрабатывает lvalue
fn (mut v VariableRenameVisitor) visit_lvalue(lval Lvalue) {
	if lval is NameExpr {
		if v.var_blocks.len > 0 {
			mut current := v.var_blocks.last()
			name := lval.name
			
			if name in current {
				// Переопределение
				if v.disallow_redef_depth == 0 {
					current[name] = v.current_block()
				}
			} else {
				current[name] = v.current_block()
			}
			
			// Сбрасываем счётчик чтений
			if v.num_reads.len > 0 {
				v.num_reads.last()[name] = 0
			}
		}
	} else if lval is TupleExpr || lval is ListExpr {
		for item in lval.items {
			v.visit_lvalue(item)
		}
	} else if lval is MemberExpr {
		v.visit_expression(lval.expr)
	}
}

// visit_expression обрабатывает выражение
fn (mut v VariableRenameVisitor) visit_expression(expr Expression) {
	if expr is NameExpr {
		v.visit_name_expr(expr)
		// Увеличиваем счётчик чтений
		if v.num_reads.len > 0 && v.var_blocks.len > 0 {
			name := expr.name
			if name in v.var_blocks.last() {
				mut reads := v.num_reads.last()[name] or { 0 }
				reads++
				v.num_reads.last()[name] = reads
			}
		}
	} else if expr is MemberExpr {
		v.visit_expression(expr.expr)
	} else if expr is CallExpr {
		v.visit_expression(expr.callee)
		for arg in expr.args {
			v.visit_expression(arg)
		}
	} else if expr is TupleExpr || expr is ListExpr {
		for item in expr.items {
			v.visit_expression(item)
		}
	} else if expr is DictExpr {
		for kv in expr.items {
			v.visit_expression(kv[0])
			v.visit_expression(kv[1])
		}
	}
}

// visit_func_def обрабатывает определение функции
pub fn (mut v VariableRenameVisitor) visit_func_def(defn FuncDef) {
	_ = v.enter_scope(function_scope)
	defer { ScopeGuard{v: v}.drop() }
	
	for arg in defn.arguments {
		v.visit_lvalue(arg.variable)
	}
	
	if defn.body != none {
		v.visit_block(defn.body)
	}
}

// visit_class_def обрабатывает определение класса
pub fn (mut v VariableRenameVisitor) visit_class_def(defn ClassDef) {
	_ = v.enter_scope(class_scope)
	defer { ScopeGuard{v: v}.drop() }
	
	if defn.defs != none {
		v.visit_block(defn.defs)
	}
}

// visit_block обрабатывает блок
pub fn (mut v VariableRenameVisitor) visit_block(block Block) {
	_ = v.enter_block()
	defer { BlockGuard{v: v}.drop() }
	
	for stmt in block.body {
		v.visit_statement(stmt)
	}
}

// visit_statement обрабатывает утверждение
fn (mut v VariableRenameVisitor) visit_statement(stmt Statement) {
	if stmt is AssignmentStmt {
		v.visit_assignment_stmt(stmt)
	} else if stmt is ExpressionStmt {
		v.visit_expression(stmt.expr)
	} else if stmt is ReturnStmt {
		if stmt.expr != none {
			v.visit_expression(stmt.expr)
		}
	} else if stmt is IfStmt {
		for expr in stmt.expr {
			v.visit_expression(expr)
		}
		for body in stmt.body {
			v.visit_block(body)
		}
		if stmt.else_body != none {
			v.visit_block(stmt.else_body)
		}
	} else if stmt is WhileStmt {
		v.visit_expression(stmt.expr)
		_ = v.enter_loop()
		defer { LoopGuard{v: v}.drop() }
		v.visit_block(stmt.body)
	} else if stmt is ForStmt {
		v.visit_expression(stmt.iter)
		v.visit_lvalue(stmt.index)
		_ = v.enter_loop()
		defer { LoopGuard{v: v}.drop() }
		v.visit_block(stmt.body)
	} else if stmt is TryStmt {
		_ = v.enter_try()
		defer { TryGuard{v: v}.drop() }
		v.visit_block(stmt.body)
		for handler in stmt.handlers {
			v.visit_block(handler)
		}
	} else if stmt is FuncDef {
		v.visit_func_def(stmt)
	} else if stmt is ClassDef {
		v.visit_class_def(stmt)
	} else if stmt is Block {
		v.visit_block(stmt)
	}
}
