// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 10:55
module mypy

// expandtype.v — Замещение (expand) параметров типов (TypeVar) на конкретные аргументы (Type).

pub struct ExpandTypeVisitor {
	TypeTraverserVisitor
pub mut:
	env map[string]MypyTypeNode // TypeVarId (имя в упрощенном виде) -> Type
}

pub fn expand_type(typ MypyTypeNode, env map[string]MypyTypeNode) MypyTypeNode {
	if env.len == 0 {
		return typ
	}
	
	// Оптимизация: если тип не содержит переменных типов
	// if has_no_typevars(typ) { return typ } (from mypy.typevars)
	
	mut visitor := ExpandTypeVisitor{
		env: env
	}
	return typ.accept_synthetic(mut visitor) or { return typ }
}

pub fn expand_type_by_instance(typ MypyTypeNode, instance &Instance) MypyTypeNode {
	// Подставляет аргументы типов из инстанса
	if instance.args.len == 0 || instance.typ == none {
		return typ
	}
	// TODO: map variables
	mut env := map[string]MypyTypeNode{}
	/*
	info := instance.typ or { return typ }
	for i, tv in info.type_vars {
		env[tv] = instance.args[i]
	}
	*/
	return expand_type(typ, env)
}

pub fn (mut v ExpandTypeVisitor) visit_type_var_type(t &TypeVarType) !string {
	// В V мы не можем просто так "заменить" саму ссылку, так как `accept_synthetic` обычно возвращает строку
	// В Mypy `ExpandTypeVisitor` возвращает новый `Type` узел. Мы эмулируем это заглушкой.
	// Правильный подход в V: мы клонируем узел или возвращаем новый, если бы visitor возвращал TypeNode.
	if replacement := v.env[t.name] {
		// Мы модифицируем `t` на месте? Это опасно(надо клонировать всё).
		// Пока заглушка.
	}
	return v.TypeTraverserVisitor.visit_type_var_type(t)
}

// ... Остальные визиторы обходят структуру типа (Instance.args, Callable.arg_types и т.д.)
