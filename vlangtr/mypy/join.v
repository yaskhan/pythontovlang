// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 09:10
module mypy

// Вычисление верхней границы (Least Upper Bound / Join) для двух типов.
// Например, join(int, object) = object.

pub fn join_types(s MypyTypeNode, t MypyTypeNode) MypyTypeNode {
	// Основная логика: если s подтип t, то возвращаем t. (И наоборот).
	// Если это не так, мы должны найти общую базу.
	
	p_s := get_proper_type(s)
	p_t := get_proper_type(t)
	
	if is_same_type(p_s, p_t) {
		return s
	}
	
	if p_s is AnyType {
		return s
	}
	if p_t is AnyType {
		return t
	}
	
	if p_s is UninhabitedType {
		return t
	}
	if p_t is UninhabitedType {
		return s
	}
	
	// Упрощенная логика: возвращаем AnyType, так как полная реализация требует MRO
	return MypyTypeNode(AnyType{type_of_any: .special_form})
}

pub fn join_type_list(types []MypyTypeNode) MypyTypeNode {
	if types.len == 0 {
		return MypyTypeNode(UninhabitedType{})
	}
	mut res := types[0]
	for i in 1 .. types.len {
		res = join_types(res, types[i])
	}
	return res
}
