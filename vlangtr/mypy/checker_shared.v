// checker_shared.v — Shared definitions used by different parts of type checker
// Translated from mypy/checker_shared.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 17:30

module mypy

// TypeRange — объект, представляющий точный тип или тип с верхней границей
pub struct TypeRange {
pub mut:
	item           MypyTypeNode
	is_upper_bound bool // false => точный тип
}

// new_type_range создаёт новый TypeRange
pub fn new_type_range(item MypyTypeNode, is_upper_bound bool) TypeRange {
	return TypeRange{
		item:           item
		is_upper_bound: is_upper_bound
	}
}

// TypeAndType — кортеж двух типов
pub struct TypeAndType {
pub mut:
	first  MypyTypeNode
	second MypyTypeNode
}

// TypeAndStringList — кортеж типа и списка строк
pub struct TypeAndStringList {
pub mut:
	typ  MypyTypeNode
	strs []string
}

// TypeAndTypeOpt — кортеж двух опциональных типов
pub struct TypeAndTypeOpt {
pub mut:
	first  ?MypyTypeNode
	second ?MypyTypeNode
}

// OptionalTypeMap — опциональная map[string]Type
pub type OptionalTypeMap = ?map[string]MypyTypeNode

// TypeMapPair — пара опциональных map
pub struct TypeMapPair {
pub mut:
	first  OptionalTypeMap
	second OptionalTypeMap
}

// CheckerScope — область видимости для type checker
pub struct CheckerScope {
pub mut:
	stack []TypeInfoOrFuncItemOrMypyFile
}

// TypeInfoOrFuncItemOrMypyFile — sum-type для стека
pub type TypeInfoOrFuncItemOrMypyFile = TypeInfo | FuncItem | MypyFile

// new_checker_scope создаёт новый CheckerScope
pub fn new_checker_scope(mod MypyFile) CheckerScope {
	return CheckerScope{
		stack: [TypeInfoOrFuncItemOrMypyFile(mod)]
	}
}

// current_function возвращает текущую функцию
pub fn (mut cs CheckerScope) current_function() ?FuncItem {
	for i := cs.stack.len - 1; i >= 0; i-- {
		if cs.stack[i] is FuncItem {
			return cs.stack[i]
		}
	}
	return none
}

// top_level_function возвращает функцию верхнего уровня (не lambda)
pub fn (mut cs CheckerScope) top_level_function() ?FuncItem {
	for e in cs.stack {
		if e is FuncItem && e !is LambdaExpr {
			return e
		}
	}
	return none
}

// active_class возвращает активный класс (если мы внутри класса)
pub fn (mut cs CheckerScope) active_class() ?&TypeInfo {
	if cs.stack.len > 0 {
		last := cs.stack[cs.stack.len - 1]
		if last is TypeInfo {
			return last
		}
	}
	return none
}

// enclosing_class возвращает класс, непосредственно окружающий функцию
pub fn (mut cs CheckerScope) enclosing_class(func ?FuncItem) ?&TypeInfo {
	f := func or { cs.current_function() or { return none } }

	mut index := -1
	for i, item in cs.stack {
		if TypeInfoOrFuncItemOrMypyFile(item) == TypeInfoOrFuncItemOrMypyFile(f) {
			index = i
			break
		}
	}

	if index <= 0 {
		return none
	}

	enclosing := cs.stack[index - 1]
	if enclosing is TypeInfo {
		return enclosing
	}
	return none
}

// active_self_type возвращает тип self для текущего класса
pub fn (mut cs CheckerScope) active_self_type() ?Instance {
	info := cs.active_class()
	if info == none && cs.current_function() != none {
		info = cs.enclosing_class(none)
	}
	if info != none {
		ti := info or { return none }
		return fill_typevars(ti)
	}
	return none
}

// current_self_type возвращает тип self (обрабатывает вложенные функции)
pub fn (mut cs CheckerScope) current_self_type() ?Instance {
	for i := cs.stack.len - 1; i >= 0; i-- {
		if cs.stack[i] is TypeInfo {
			ti := cs.stack[i]
			return fill_typevars(ti)
		}
	}
	return none
}

// is_top_level проверяет, находимся ли мы на верхнем уровне
pub fn (cs CheckerScope) is_top_level() bool {
	return cs.stack.len == 1
}

// push_function добавляет функцию в стек
pub fn (mut cs CheckerScope) push_function(item FuncItem) {
	cs.stack << TypeInfoOrFuncItemOrMypyFile(item)
}

// pop_function удаляет функцию из стека
pub fn (mut cs CheckerScope) pop_function() {
	if cs.stack.len > 0 {
		cs.stack.pop()
	}
}

// push_class добавляет класс в стек
pub fn (mut cs CheckerScope) push_class(info TypeInfo) {
	cs.stack << TypeInfoOrFuncItemOrMypyFile(info)
}

// pop_class удаляет класс из стека
pub fn (mut cs CheckerScope) pop_class() {
	if cs.stack.len > 0 {
		cs.stack.pop()
	}
}

// fill_typevars заполняет переменные типа для TypeInfo
pub fn fill_typevars(info &TypeInfo) Instance {
	// Упрощённая версия — создаёт Instance с пустыми аргументами
	return Instance{
		type_name: info.fullname
		args:      []MypyTypeNode{}
		type:      info
	}
}
