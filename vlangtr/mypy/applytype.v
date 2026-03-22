// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 14:50
module mypy

// Подстановка аргументов типов (например, [int, str]) в обобщённый тип (Generic Callable).

pub fn apply_generic_arguments(
	callable &CallableType,
	orig_types []?MypyTypeNode,
	error_message string,
	context Context,
	skip_unsatisfied bool
) CallableType {
	// Создаёт новый CallableType, заменяя переменные типов на переданные аргументы.
	
	mut types := []?MypyTypeNode{}
	
	// Если аргументы не переданы, или их кол-во не сходится, возвращаем Callable fallback с Any
	tvars := callable.variables
	if orig_types.len != tvars.len {
		// Обычно выдается ошибка: "Type argument count mismatch..."
		// fallback to Any
		for _ in tvars {
			types << MypyTypeNode(AnyType{type_of_any: .from_error})
		}
	} else {
		for t in orig_types {
			if cur_t := t {
				types << cur_t
			} else {
				types << MypyTypeNode(AnyType{type_of_any: .from_error})
			}
		}

	}
	
	mut id_to_type := map[string]MypyTypeNode{}
	for i, tv in tvars {
		typ := types[i] or { MypyTypeNode(AnyType{type_of_any: .special_form}) }
		id_to_type[tv.type_str()] = typ
	}

	
	// Подстановка TypeVar через expand_type (который мы написали в expandtype.v)
	// В V придется написать/вызвать копировальщик для CallableType, так как expand_type 
	// возвращает MypyTypeNode (Интерфейс), а нам нужен CallableType.
	
	expanded := expand_type(MypyTypeNode(*callable), id_to_type)
	if expanded is CallableType {
		mut new_callable := expanded as CallableType
		new_callable.variables = []MypyTypeNode{}
		return new_callable
	}

	
	// Fallback
	return *callable
}

// Применяет полиморфные переменные к Callable (например, для методов с self)
pub fn apply_poly(tp &CallableType, poly_tvars []MypyTypeNode) ?CallableType {
	if poly_tvars.len == 0 {
		return *tp
	}

	
	// В Mypy эта функция "навешивает" свободные tvars на сигнатуру метода
	mut new_tp := *tp
	mut vars := new_tp.variables.clone()
	for tv in poly_tvars {
		vars << tv
	}
	new_tp.variables = vars
	return new_tp
}

// Извлечь poly/generics из класса (TypeInfo) для конструктора __init__ и т.д.
pub fn get_method_type_vars(info &TypeInfo) []MypyTypeNode {
	mut vars := []MypyTypeNode{}
	// info.type_vars already contains []MypyTypeNode
	for tv in info.type_vars {
		vars << tv
	}
	return vars
}

