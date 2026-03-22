// Member access checking (MemberExpr).
module mypy

pub fn analyze_member_access(name string, typ MypyTypeNode, context Context, is_lvalue bool, is_super bool, is_operator bool, original_type MypyTypeNode, mut chk TypeChecker, in_literal_context bool) MypyTypeNode {
	_ = is_lvalue
	_ = is_super
	_ = is_operator
	_ = in_literal_context
	proper_type := get_proper_type(typ)
	if proper_type is Instance {
		return analyze_instance_member_access(name, proper_type, context, original_type, mut
			chk)
	}
	if proper_type is AnyType {
		return MypyTypeNode(AnyType{
			type_of_any: proper_type.type_of_any
		})
	}
	if proper_type is UnionType {
		return analyze_union_member_access(name, proper_type, context, original_type, mut
			chk)
	}
	if proper_type is TupleType {
		if fb := proper_type.partial_fallback {
			return analyze_member_access(name, *fb, context, false, false, false, original_type, mut
				chk, false)
		}
		return MypyTypeNode(AnyType{
			type_of_any: .from_error
		})
	}
	return chk.msg.has_no_attr(original_type, typ, name, context)
}

pub fn analyze_instance_member_access(name string, inst Instance, context Context, original_type MypyTypeNode, mut chk TypeChecker) MypyTypeNode {
	if isnil(inst.type_) {
		return MypyTypeNode(AnyType{
			type_of_any: .from_error
		})
	}
	info := inst.type_
	if sym := lookup_typeinfo_member(name, info) {
		if node := sym.node {
			return match node {
				Var {
					node.type_ or { MypyTypeNode(AnyType{
						type_of_any: .from_error
					}) }
				}
				FuncDef {
					function_type(node, chk.named_type('builtins.function'))
				}
				Decorator {
					node.var_.type_ or {
						MypyTypeNode(AnyType{
							type_of_any: .from_error
						})
					}
				}
				OverloadedFuncDef {
					node.type_ or { MypyTypeNode(AnyType{
						type_of_any: .from_error
					}) }
				}
				TypeInfo {
					chk.type_type()
				}
				else {
					MypyTypeNode(AnyType{
						type_of_any: .special_form
					})
				}
			}
		}
	}
	return chk.msg.has_no_attr(original_type, inst, name, context)
}

pub fn analyze_union_member_access(name string, utype UnionType, context Context, original_type MypyTypeNode, mut chk TypeChecker) MypyTypeNode {
	mut item_types := []MypyTypeNode{}
	for item in utype.items {
		item_types << analyze_member_access(name, item, context, false, false, false,
			original_type, mut chk, false)
	}
	if item_types.len == 1 {
		return item_types[0]
	}
	return UnionType{
		items: item_types
	}
}

fn lookup_typeinfo_member(name string, info &TypeInfo) ?SymbolTableNode {
	if name in info.names.symbols {
		return info.names.symbols[name]
	}
	for base in info.mro {
		if name in base.names.symbols {
			return base.names.symbols[name]
		}
	}
	return none
}
