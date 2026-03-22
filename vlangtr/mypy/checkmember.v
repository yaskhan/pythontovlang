// Проверка доступа к атрибутам (MemberExpr).
module mypy

pub fn analyze_member_access(name string, typ MypyTypeNode, context Context, is_lvalue bool, is_super bool, is_operator bool, original_type MypyTypeNode, mut chk TypeChecker, in_literal_context bool) MypyTypeNode {
	// Основная логика: mypy/checkmember.py -> analyze_member_access
	
	if typ is Instance {
		return analyze_instance_member_access(name, typ, context, is_lvalue, original_type, mut chk)
	} else if typ is AnyType {
		return MypyTypeNode(AnyType{type_of_any: typ.type_of_any})
	} else if typ is UnionType {
		return analyze_union_member_access(name, typ, context, is_lvalue, original_type, mut chk)
	} else if typ is TupleType {
		// Tuple has methods like count, index.
		return analyze_member_access(name, MypyTypeNode(typ.fallback), context, is_lvalue, is_super, is_operator, original_type, mut chk, in_literal_context)
	}
	
	return MypyTypeNode(AnyType{type_of_any: TypeOfAny.from_error})
}

pub fn analyze_instance_member_access(name string, inst &Instance, context Context, is_lvalue bool, original_type MypyTypeNode, mut chk TypeChecker) MypyTypeNode {
    // TODO: реализация
    return MypyTypeNode(AnyType{type_of_any: TypeOfAny.from_error})
}

pub fn analyze_union_member_access(name string, union &UnionType, context Context, is_lvalue bool, original_type MypyTypeNode, mut chk TypeChecker) MypyTypeNode {
    // TODO: реализация
    return MypyTypeNode(AnyType{type_of_any: TypeOfAny.from_error})
}
