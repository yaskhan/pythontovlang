// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 12:15
module mypy

// typeanal.v — Семантический анализатор для типов.
// Преобразует неразрешённые (Unbound) типы, полученные из парсинга AST (например, тип "List[int]"),
// в семантически корректные MypyTypeNode (например, Instance(list) с аргументом Instance(int)).

pub struct TypeAnalyser {
pub mut:
	options           &Options
	errors            &Errors
	is_typeshed_file  bool
	// lookup_node    fn(name string) ?SymbolTableNode
	allow_any         bool
	allow_tuple_literal bool
	allow_unbound_tvars bool
}

pub fn (mut t TypeAnalyser) accept(typ MypyTypeNode) MypyTypeNode {
	// Основная точка входа.
	return typ.accept_synthetic(mut t) or {
		// Ошибка преобразования — возвращаем Any
		return MypyTypeNode(AnyType{type_of_any: .from_error})
	}
}

pub fn (mut t TypeAnalyser) visit_unbound_type(typ &UnboundType) !string {
	// 1. Поиск символа
	// sym := t.lookup_node(typ.name)
	
	// 2. Если символ найден и это класс (TypeInfo), то собираем аргументы
	// if sym.node is TypeInfo ...
	
	// Заглушка, если ничего не найдено или мы еще не реализовали lookup:
	// t.fail("Name '\${typ.name}' is not defined", typ)
	// В V мы не можем изменить саму ссылку typ. Нужно возвращать новый MypyTypeNode.
	// Для совместимости с accept_synthetic, мы пока просто ничего не меняем.
	return ''
}

pub fn (mut t TypeAnalyser) visit_any(typ &AnyType) !string {
	return ''
}

pub fn (mut t TypeAnalyser) visit_none_type(typ &NoneType) !string {
	return ''
}

pub fn (mut t TypeAnalyser) visit_instance(typ &Instance) !string {
	// Анализируем аргументы типов
	/*
	for i in 0 .. typ.args.len {
		typ.args[i] = t.accept(typ.args[i])
	}
	*/
	return ''
}

pub fn (mut t TypeAnalyser) visit_callable_type(typ &CallableType) !string {
	// Анализируем типы аргументов и возвращаемое значение
	/*
	for i in 0 .. typ.arg_types.len {
		if arg := typ.arg_types[i] {
			typ.arg_types[i] = t.accept(arg)
		}
	}
	typ.ret_type = t.accept(typ.ret_type)
	*/
	return ''
}

pub fn (mut t TypeAnalyser) visit_tuple_type(typ &TupleType) !string {
	// Анализируем элементы кортежа
	/*
	for i in 0 .. typ.items.len {
		typ.items[i] = t.accept(typ.items[i])
	}
	*/
	return ''
}

pub fn (mut t TypeAnalyser) visit_union_type(typ &UnionType) !string {
	// Анализируем элементы объединения
	/*
	for i in 0 .. typ.items.len {
		typ.items[i] = t.accept(typ.items[i])
	}
	*/
	return ''
}

// TODO: методы для AnalyzeTypeAlias, ClassDef
