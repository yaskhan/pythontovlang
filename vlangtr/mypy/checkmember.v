// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 07:12
module mypy

// Проверка доступа к атрибутам (MemberExpr).

pub fn analyze_member_access(name string, typ MypyTypeNode, context Context, is_lvalue bool, is_super bool, is_operator bool, original_type MypyTypeNode, chk &TypeChecker, in_literal_context bool) MypyTypeNode {
	// Основная логика: mypy/checkmember.py -> analyze_member_access
	
	mut result := MypyTypeNode(AnyType{type_of_any: .special_form})
	
	if typ is Instance {
		info := typ.typ
		if info != none {
			return analyze_instance_member_access(name, typ, context, is_lvalue, original_type, chk)
		}
	} else if typ is AnyType {
		return MypyTypeNode(AnyType{type_of_any: typ.type_of_any})
	} else if typ is UnionType {
		return analyze_union_member_access(name, typ, context, is_lvalue, original_type, chk)
	} else if typ is TupleType {
		// Tuple has methods like count, index. Map everything to Tuple's fallback Instance.
		return analyze_member_access(name, MypyTypeNode(typ.tuple_fallback()), context, is_lvalue, is_super, is_operator, original_type, chk, in_literal_context)
	}
	
	if result is AnyType {
		chk.msg.fail("Has no attribute '\${name}'", context, false, false, none)
		return MypyTypeNode(AnyType{type_of_any: .from_error})
	}
	
	return result
}

pub fn analyze_instance_member_access(name string, typ Instance, mx Context, is_lvalue bool, original_type MypyTypeNode, chk &TypeChecker) MypyTypeNode {
	info := typ.typ
	if info == none {
		return MypyTypeNode(AnyType{type_of_any: .from_error})
	}
	
	method := info.get_method(name)
	
	if name == '__init__' && !info.is_final {
		// Специальные проверки: нельзя обращаться к __init__ напрямую (только через super или если финал)
		// Для начала позволим обращаться.
	}
	
	if method != none {
		// Это метод. В питоне есть @property через OverloadedFuncDef, пропустим это пока.
		if is_lvalue {
			chk.msg.fail('Cannot assign to a method', mx, false, false, none)
		}
		
		// TODO: function_type, bind_self, expand_type_by_instance
		mut signature := MypyTypeNode(AnyType{type_of_any: .special_form})
		if method is FuncDef {
			// signature = bind_self(...) 
		}
		
		return signature
	} else {
		// Не метод. Поиск как переменной
		return analyze_member_var_access(name, typ, info, mx, is_lvalue, original_type, chk)
	}
}

pub fn analyze_member_var_access(name string, itype Instance, info &TypeInfo, mx Context, is_lvalue bool, original_type MypyTypeNode, chk &TypeChecker) MypyTypeNode {
	sym := info.get(name)
	
	if sym != none {
		node := sym.node
		if node is Var {
			if is_lvalue {
				// check_final_member
			}
			return node.typ
		} else if node is TypeInfo {
			// Вложенный класс
			return MypyTypeNode(TypeType{item: MypyTypeNode(Instance{typ: node, args: []})})
		}
	}
	
	// Если атрибут не найден, пробуем классFallback
	if info.fallback_to_any {
		return MypyTypeNode(AnyType{type_of_any: .special_form})
	}
	
	chk.msg.fail("Has no attribute '\${name}'", mx, false, false, none)
	return MypyTypeNode(AnyType{type_of_any: .from_error})
}

pub fn analyze_union_member_access(name string, typ UnionType, mx Context, is_lvalue bool, original_type MypyTypeNode, chk &TypeChecker) MypyTypeNode {
	mut results := []MypyTypeNode{}
	
	for subtype in typ.items {
		// Рекурсивно вызываем analyze_member_access для каждого элемента объединения
		res := analyze_member_access(name, subtype, mx, is_lvalue, false, false, subtype, chk, false)
		results << res
	}
	
	// Возвращаем склеенный (simplified) Union из результатов. Но в нашей реализации это пока просто UnionType
	return MypyTypeNode(UnionType{items: results})
}
