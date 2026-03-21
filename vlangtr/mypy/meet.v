// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 09:12
module mypy

// Вычисление нижней границы (Greatest Lower Bound / Meet) для двух типов.
// Операция, обратная Join. Например, meet(int, float) может быть UninhabitedType, а meet(int, Any) = int.

pub fn meet_types(s MypyTypeNode, t MypyTypeNode) MypyTypeNode {
	// Основная логика: если s подтип t, то возвращаем s. (И наоборот, если t подтип s, возвращаем t).
	
	p_s := get_proper_type(s)
	p_t := get_proper_type(t)
	
	if is_same_type(p_s, p_t) {
		return s
	}
	
	if p_s is AnyType {
		return t
	}
	if p_t is AnyType {
		return s
	}
	
	if p_s is UninhabitedType {
		return s
	}
	if p_t is UninhabitedType {
		return t
	}
	
	// В Mypy дальше идет сложная механика разрешения Union-ов, Instance (интерсекция), и Tuple.
	// Как заглушка:
	return MypyTypeNode(AnyType{type_of_any: .special_form})
}

pub fn meet_type_list(types []MypyTypeNode) MypyTypeNode {
	if types.len == 0 {
		return MypyTypeNode(AnyType{type_of_any: .special_form})
	}
	mut res := types[0]
	for i in 1 .. types.len {
		res = meet_types(res, types[i])
	}
	return res
}

pub fn is_overlapping_types(left MypyTypeNode, right MypyTypeNode) bool {
	// Упрощенная проверка перекрытия типов
	p_left := get_proper_type(left)
	p_right := get_proper_type(right)
	
	if p_left is AnyType || p_right is AnyType { return true }
	if p_left is UninhabitedType || p_right is UninhabitedType { return false }
	
	return true // assume overlapping by default safely unless proven Uninhabited
}
