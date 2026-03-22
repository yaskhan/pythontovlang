// Проверка доступа к атрибутам (MemberExpr).
module mypy

pub fn analyze_member_access(name string, typ MypyTypeNode, context Context, is_lvalue bool, is_super bool, is_operator bool, original_type MypyTypeNode, mut chk &TypeChecker, in_literal_context bool) MypyTypeNode {
	// Основная логика: mypy/checkmember.py -> analyze_member_access
	
	if typ is Instance {
		inst := typ as Instance
		if info := inst.typ {
			return analyze_instance_member_access(name, inst, context, is_lvalue, original_type, mut chk)
		}
	} else if typ is AnyType {
		return MypyTypeNode(AnyType{type_of_any: typ.type_of_any})
	} else if typ is UnionType {
		return analyze_union_member_access(name, typ, context, is_lvalue, original_type, mut chk)
	} else if typ is TupleType {
		// Tuple has methods like count, index. Map everything to Tuple's fallback Instance.
		return analyze_member_access(name, MypyTypeNode(typ.tuple_fallback()), context, is_lvalue, is_super, is_operator, original_type, mut chk, in_literal_context)
	}
	
	chk.msg.fail("Has no attribute '${name}'", context, none)
	return MypyTypeNode(AnyType{type_of_any: .from_error})
}

pub fn analyze_instance_member_access(name string, typ Instance, mx Context, is_lvalue bool, original_type MypyTypeNode, mut chk &TypeChecker) MypyTypeNode {
	info := typ.typ or { return MypyTypeNode(AnyType{type_of_any: .from_error}) }

	if sym := info.names[name] {
		node := sym.node or { return MypyTypeNode(AnyType{type_of_any: .from_error}) }
		
		if node is FuncDef {
			if is_lvalue {
				chk.msg.fail('Cannot assign to a method', mx, none)
			}
			// TODO: bind_self, etc.
			return MypyTypeNode(AnyType{type_of_any: .special_form})
		} else {
			return analyze_member_var_access(name, typ, info, mx, is_lvalue, original_type, mut chk)
		}
	} else {
		// Try MRO search would be here.
	}

	chk.msg.fail("Has no attribute '${name}'", mx, none)
	return MypyTypeNode(AnyType{type_of_any: .from_error})
}

pub fn analyze_member_var_access(name string, itype Instance, info &TypeInfo, mx Context, is_lvalue bool, original_type MypyTypeNode, mut chk &TypeChecker) MypyTypeNode {
	if sym := info.names[name] {
		node := sym.node or { return MypyTypeNode(AnyType{type_of_any: .from_error}) }
		if node is Var {
			v := node as Var
			if is_lvalue {
				// check_final_member
			}
			if t := v.type_ {
				return MypyTypeNode(t)
			}
			return MypyTypeNode(AnyType{type_of_any: .unannotated})
		} else if node is TypeInfo {
			ti := node as TypeInfo
			return MypyTypeNode(TypeType{item: MypyTypeNode(Instance{typ: &ti, args: [], type_name: ti.fullname})})
		}
	}
	
	chk.msg.fail("Has no attribute '${name}'", mx, none)
	return MypyTypeNode(AnyType{type_of_any: .from_error})
}

pub fn analyze_union_member_access(name string, typ UnionType, mx Context, is_lvalue bool, original_type MypyTypeNode, mut chk &TypeChecker) MypyTypeNode {
	mut results := []MypyTypeNode{}
	
	for subtype in typ.items {
		res := analyze_member_access(name, subtype, mx, is_lvalue, false, false, subtype, mut chk, false)
		results << res
	}
	
	return MypyTypeNode(UnionType{items: results})
}
