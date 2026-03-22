// EraseTypeVisitor implements type erasure.
module mypy

pub fn erase_type(typ MypyTypeNode) MypyTypeNode {
	t := get_proper_type(typ)
	return t.accept_res(mut EraseTypeVisitor{}) or { MypyTypeNode(AnyType{type_of_any: .from_error}) }
}

pub struct EraseTypeVisitor {}

pub fn (v EraseTypeVisitor) visit_unbound_type(t &UnboundType) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: .from_error
	})
}

pub fn (v EraseTypeVisitor) visit_any(t &AnyType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (v EraseTypeVisitor) visit_none_type(t &NoneType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (v EraseTypeVisitor) visit_uninhabited_type(t &UninhabitedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (v EraseTypeVisitor) visit_erased_type(t &ErasedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (v EraseTypeVisitor) visit_partial_type(t &PartialTypeT) !MypyTypeNode {
	panic('Cannot erase partial types')
}

pub fn (v EraseTypeVisitor) visit_deleted_type(t &DeletedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (v EraseTypeVisitor) visit_instance(t &Instance) !MypyTypeNode {
	info := t.typ or { return MypyTypeNode(AnyType{type_of_any: .from_error}) }
	args := erased_vars(info.defn.type_vars, .special_form)
	return MypyTypeNode(Instance{
		typ:  info
		args: args
		type_name: t.type_name
	})
}

pub fn (v EraseTypeVisitor) visit_type_var(t &TypeVarType) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
}

pub fn (v EraseTypeVisitor) visit_param_spec(t &ParamSpecType) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
}

pub fn (v EraseTypeVisitor) visit_parameters(t &ParametersType) !MypyTypeNode {
	panic('Parameters should have been bound to a class')
}

pub fn (v EraseTypeVisitor) visit_type_var_tuple(t &TypeVarTupleType) !MypyTypeNode {
	fb := t.tuple_fallback
	return MypyTypeNode(Instance{
		typ:  fb.typ
		args: [MypyTypeNode(AnyType{type_of_any: .special_form})]
		type_name: fb.type_name
	})
}

pub fn (v EraseTypeVisitor) visit_unpack_type(t &UnpackType) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
}

pub fn (v EraseTypeVisitor) visit_callable_type(t &CallableType) !MypyTypeNode {
	any_t := MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
	return MypyTypeNode(CallableType{
		arg_types:        [any_t, any_t]
		arg_kinds:        [ArgKind.arg_star, ArgKind.arg_star2]
		arg_names:        [?string(none), none]
		ret_type:         any_t
		fallback:         t.fallback
		is_ellipsis_args: true
		implicit:         true
	})
}

pub fn (v EraseTypeVisitor) visit_overloaded(t &Overloaded) !MypyTypeNode {
	if fb := t.fallback {
		return MypyTypeNode(fb).accept_res(mut EraseTypeVisitor{})
	}

	return MypyTypeNode(AnyType{
		type_of_any: .from_error
	})
}


pub fn (v EraseTypeVisitor) visit_tuple_type(t &TupleType) !MypyTypeNode {
	return MypyTypeNode(t.partial_fallback).accept_res(mut EraseTypeVisitor{})
}



pub fn (v EraseTypeVisitor) visit_typeddict_type(t &TypedDictType) !MypyTypeNode {
	return MypyTypeNode(t.fallback).accept_res(mut EraseTypeVisitor{})
}



pub fn (v EraseTypeVisitor) visit_literal_type(t &LiteralType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (v EraseTypeVisitor) visit_union_type(t &UnionType) !MypyTypeNode {
	mut erased_items := []MypyTypeNode{}
	for item in t.items {
		erased_items << erase_type(item)
	}
	return MypyTypeNode(UnionType{items: erased_items})
}

pub fn (v EraseTypeVisitor) visit_type_type(t &TypeType) !MypyTypeNode {
	item := t.item.accept_res(mut EraseTypeVisitor{})!

	return MypyTypeNode(TypeType{
		item:         item
		is_type_form: t.is_type_form
	})
}

pub fn (v EraseTypeVisitor) visit_type_alias_type(t &TypeAliasType) !MypyTypeNode {
	panic('Type aliases should be expanded before accepting this visitor')
}

// erased_vars - helper
fn erased_vars(vars []MypyTypeNode, kind TypeOfAny) []MypyTypeNode {
	mut res := []MypyTypeNode{}
	for _ in vars {
		res << MypyTypeNode(AnyType{type_of_any: kind})
	}
	return res
}
