// Я Antigravity работаю над этим файлом. Начало: 2026-02-22 05:00
// erasetype.v — Type erasure transformation
//
// ---------------------------------------------------------------------------

module mypy

pub fn erase_type(typ MypyTypeNode) MypyTypeNode {
	t := get_proper_type(typ)
	return t.accept_translator(mut EraseTypeVisitor{}) or { MypyTypeNode(AnyType{type_of_any: TypeOfAny.from_error}) }
}

pub struct EraseTypeVisitor {}

pub fn (mut v EraseTypeVisitor) visit_unbound_type(t &UnboundType) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: TypeOfAny.from_error
	})
}

pub fn (mut v EraseTypeVisitor) visit_any(t &AnyType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v EraseTypeVisitor) visit_none_type(t &NoneType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v EraseTypeVisitor) visit_uninhabited_type(t &UninhabitedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v EraseTypeVisitor) visit_erased_type(t &ErasedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v EraseTypeVisitor) visit_partial_type(t &PartialTypeT) !MypyTypeNode {
	return error('Cannot erase partial types')
}

pub fn (mut v EraseTypeVisitor) visit_deleted_type(t &DeletedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v EraseTypeVisitor) visit_instance(t &Instance) !MypyTypeNode {
	// В упрощенной схеме просто копируем с Any аргументами
	mut args := []MypyTypeNode{}
	for _ in 0 .. t.args.len {
		args << MypyTypeNode(AnyType{type_of_any: TypeOfAny.special_form})
	}
	return MypyTypeNode(Instance{
		type_:     t.type_
		args:      args
		line:      t.line
		column:    t.column
	})
}

pub fn (mut v EraseTypeVisitor) visit_type_var(t &TypeVarType) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: TypeOfAny.special_form
	})
}

pub fn (mut v EraseTypeVisitor) visit_param_spec(t &ParamSpecType) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: TypeOfAny.special_form
	})
}

pub fn (mut v EraseTypeVisitor) visit_parameters(t &ParametersType) !MypyTypeNode {
	return error('Parameters should have been bound to a class')
}

pub fn (mut v EraseTypeVisitor) visit_type_var_tuple(t &TypeVarTupleType) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: TypeOfAny.special_form
	})
}

pub fn (mut v EraseTypeVisitor) visit_unpack_type(t &UnpackType) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: TypeOfAny.special_form
	})
}

pub fn (mut v EraseTypeVisitor) visit_callable_type(t &CallableType) !MypyTypeNode {
	any_t := MypyTypeNode(AnyType{
		type_of_any: TypeOfAny.special_form
	})
	return MypyTypeNode(CallableType{
		arg_types:        [any_t, any_t]
		arg_kinds:        [ArgKind.arg_star, ArgKind.arg_star2]
		arg_names:        [?string(none), none]
		ret_type:         any_t
		fallback:         t.fallback
		name:             t.name
	})
}

pub fn (mut v EraseTypeVisitor) visit_overloaded(t &Overloaded) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: TypeOfAny.special_form
	})
}

pub fn (mut v EraseTypeVisitor) visit_tuple_type(t &TupleType) !MypyTypeNode {
    return t.fallback.accept_translator(mut v)!
}

pub fn (mut v EraseTypeVisitor) visit_typeddict_type(t &TypedDictType) !MypyTypeNode {
    return t.fallback.accept_translator(mut v)!
}

pub fn (mut v EraseTypeVisitor) visit_literal_type(t &LiteralType) !MypyTypeNode {
	return t.fallback.accept_translator(mut v)!
}

pub fn (mut v EraseTypeVisitor) visit_union_type(t &UnionType) !MypyTypeNode {
	mut items := []MypyTypeNode{}
	for item in t.items {
		items << item.accept_translator(mut v)!
	}
	// TODO: simplify union
	return MypyTypeNode(UnionType{items: items})
}

pub fn (mut v EraseTypeVisitor) visit_type_type(t &TypeType) !MypyTypeNode {
    item := t.item.accept_translator(mut v)!
    return MypyTypeNode(TypeType{item: item})
}

pub fn (mut v EraseTypeVisitor) visit_type_alias_type(t &TypeAliasType) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: TypeOfAny.special_form
	})
}

pub fn (mut v EraseTypeVisitor) visit_placeholder_type(t &PlaceholderType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v EraseTypeVisitor) visit_type_list(t &TypeList) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: TypeOfAny.special_form
	})
}

pub fn (mut v EraseTypeVisitor) visit_callable_argument(t &CallableArgument) !MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: TypeOfAny.special_form
	})
}

pub fn (mut v EraseTypeVisitor) visit_ellipsis_type(t &EllipsisType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v EraseTypeVisitor) visit_raw_expression_type(t &RawExpressionType) !MypyTypeNode {
	return MypyTypeNode(*t)
}
