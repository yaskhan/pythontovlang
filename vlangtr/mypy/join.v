module mypy

pub struct InstanceJoiner {}

pub fn new_instance_joiner() InstanceJoiner {
	return InstanceJoiner{}
}

pub fn (mut ij InstanceJoiner) join_instances(t Instance, s Instance) MypyTypeNode {
	_ = ij
	if t.type_name == s.type_name && t.args.len == s.args.len {
		return t
	}
	return trivial_join(t, s)
}

pub fn (mut ij InstanceJoiner) join_instances_via_supertype(t Instance, s Instance) ProperType {
	_ = ij
	return ProperType(trivial_join(t, s))
}

pub fn join_types(s MypyTypeNode, t MypyTypeNode, instance_joiner InstanceJoiner) MypyTypeNode {
	_ = instance_joiner
	if s.type_str() == t.type_str() {
		return s
	}
	if s is AnyType || t is AnyType {
		return MypyTypeNode(AnyType{
			type_of_any: .special_form
		})
	}
	return make_simplified_union([s, t], false)
}

pub fn join_type_list(types []MypyTypeNode) MypyTypeNode {
	if types.len == 0 {
		return MypyTypeNode(AnyType{
			type_of_any: .special_form
		})
	}
	mut joined := types[0]
	for i in 1 .. types.len {
		joined = join_types(joined, types[i], new_instance_joiner())
	}
	return joined
}

pub fn trivial_join(s MypyTypeNode, t MypyTypeNode) MypyTypeNode {
	return make_simplified_union([s, t], false)
}

pub struct TypeJoinVisitor {
pub:
	s               MypyTypeNode
	instance_joiner InstanceJoiner
}

pub fn (v TypeJoinVisitor) visit_unbound_type(t &UnboundType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_union_type(t &UnionType) !MypyTypeNode { return make_simplified_union([v.s, MypyTypeNode(*t)], false) }
pub fn (v TypeJoinVisitor) visit_any(t &AnyType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_none_type(t &NoneType) !MypyTypeNode { return make_simplified_union([v.s, MypyTypeNode(*t)], false) }
pub fn (v TypeJoinVisitor) visit_uninhabited_type(t &UninhabitedType) !MypyTypeNode { return v.s }
pub fn (v TypeJoinVisitor) visit_deleted_type(t &DeletedType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_erased_type(t &ErasedType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_type_var(t &TypeVarType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_instance(t &Instance) !MypyTypeNode {
	mut ij := v.instance_joiner
	s_proper := get_proper_type(v.s)
	if s_proper is Instance {
		return ij.join_instances(*t, s_proper as Instance)
	}
	return MypyTypeNode(*t)
}
pub fn (v TypeJoinVisitor) visit_callable_type(t &CallableType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_tuple_type(t &TupleType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_typeddict_type(t &TypedDictType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_literal_type(t &LiteralType) !MypyTypeNode { return join_types(v.s, t.fallback, v.instance_joiner) }
pub fn (v TypeJoinVisitor) visit_type_type(t &TypeType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn is_better(t MypyTypeNode, s MypyTypeNode) bool { return t.type_str() == s.type_str() }
pub fn is_similar_callables(t CallableType, s CallableType) bool { return t.arg_types.len == s.arg_types.len }
pub fn combine_similar_callables(t CallableType, s CallableType) CallableType { _ = s return t }
pub fn object_from_instance(instance Instance) Instance { return instance }
pub fn object_or_any_from_type(typ ProperType) ProperType { return typ }
pub fn unpack_callback_protocol(t Instance) ?ProperType { _ = t return none }
pub fn (v TypeJoinVisitor) visit_param_spec(t &ParamSpecType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_parameters(t &ParametersType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_type_var_tuple(t &TypeVarTupleType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_overloaded(t &Overloaded) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_partial_type(t &PartialTypeT) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_type_group(t &TypeType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_type_alias_type(t &TypeAliasType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_unpack_type(t &UnpackType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_type_list(t &TypeList) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_callable_argument(t &CallableArgument) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_ellipsis_type(t &EllipsisType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_raw_expression_type(t &RawExpressionType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (v TypeJoinVisitor) visit_placeholder_type(t &PlaceholderType) !MypyTypeNode { return MypyTypeNode(*t) }
