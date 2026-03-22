// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 13:30
module mypy

// typeops.v — Различные операции над типами: упрощение объединений (Union), 
// стирание типов, создание fallback-типов для кортежей и т.д.

pub fn make_simplified_union(items []MypyTypeNode) MypyTypeNode {
	// Упрощает список типов, убирая дубликаты и поглощаемые типы
	// Например: Union[int, int] -> int
	// Union[int, object] -> object (так как int <: object)
	
	if items.len == 0 {
		return MypyTypeNode(AnyType{type_of_any: .special_form})
	}
	if items.len == 1 {
		return items[0]
	}
	
	// В Mypy `make_simplified_union` использует `is_subtype` для фильтрации подтипов 
	// (оставляя только их супертипы).
	// Простая O(N^2) реализация для начала:
	mut result := []MypyTypeNode{}
	
	mut has_any := false
	for item in items {
		if item is AnyType {
			has_any = true
		}
	}
	
	if has_any {
		return MypyTypeNode(AnyType{type_of_any: .special_form})
	}
	
	// Фильтрация подтипов
	for i in 0 .. items.len {
		mut is_absorbed := false
		for j in 0 .. items.len {
			if i != j {
				// Учитываем контекст (по умолчанию)
				ctx := SubtypeContext{}
				// Если items[i] является подтипом items[j], то items[j] полностью поглощает items[i]
				if is_subtype(items[i], items[j], ctx) && !is_same_type(items[i], items[j]) {
					is_absorbed = true
					break
				} else if is_same_type(items[i], items[j]) && j < i {
					// Удаляем точные дубликаты (оставляем только первый)
					is_absorbed = true
					break
				}
			}
		}
		
		if !is_absorbed {
			result << items[i]
		}
	}
	
	if result.len == 0 {
		// Такого быть не должно, если только не было сложных Any или None
		return MypyTypeNode(AnyType{type_of_any: .special_form})
	} else if result.len == 1 {
		return result[0]
	}
	
	return MypyTypeNode(UnionType{items: result})
}

// Возвращает Instance, который используется как fallback для кортежа (Tuple)
pub fn (t &TupleType) tuple_fallback() Instance {
	// Истинная логика: если есть fallback в кортеже, то возвращаем его.
	// Здесь мы просто возвращаем то, что сохранили в fallback.
	return t.implicit_fallback
}

pub fn true_only() MypyTypeNode {
	// typeops.py: Возвращает LiteralType[True, bool]
	// Заглушка, пока LiteralType не доделан
	return MypyTypeNode(AnyType{type_of_any: .special_form})
}

pub fn false_only() MypyTypeNode {
	// typeops.py: Возвращает LiteralType[False, bool]
	return MypyTypeNode(AnyType{type_of_any: .special_form})
}

// Возвращает True, если есть рекурсивная зависимость между s и t (с защитой от циклов)
pub fn is_recursive_pair(s MypyTypeNode, t MypyTypeNode) bool {
	// Заглушка, полная требует отслеживания графа
	return false 
}
