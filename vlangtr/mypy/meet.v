// Work in progress by Cline. Started: 2026-03-22 16:10
// meet.v — Calculation of the greatest lower bound types (meets)
// Translated from mypy/meet.py

module mypy

// trivial_meet returns one of the types if it is a subtype of the other
pub fn trivial_meet(s MypyTypeNode, t MypyTypeNode) MypyTypeNode {
	if is_subtype_simple(s, t) {
		return get_proper_type(s)
	} else if is_subtype_simple(t, s) {
		return get_proper_type(t)
	} else {
		return UninhabitedType{}
	}
}

// meet_types computes the greatest lower bound of two types
pub fn meet_types(s MypyTypeNode, t MypyTypeNode) MypyTypeNode {
	s_proper := get_proper_type(s)
	t_proper := get_proper_type(t)

	// Check extra_attrs for Instance
	if s_proper is Instance && t_proper is Instance {
		if li := s_proper.typ {
			if ri := t_proper.typ {
				if li.fullname == ri.fullname && s_proper.str() == t_proper.str() {
					if s_proper.extra_attrs != none {
						return s_proper
					}
					if t_proper.extra_attrs != none {
						return t_proper
					}
					return s_proper
				}
			}
		}
	}

	if s_proper !is UnboundType && t_proper !is UnboundType {
		ctx := new_subtype_context(false, false, false, false, false, false, false, none)
		if is_proper_subtype(s_proper, t_proper, ctx) {
			return s_proper
		}
		if is_proper_subtype(t_proper, s_proper, ctx) {
			return t_proper
		}
	}

	if s_proper is ErasedType {
		return s_proper
	}
	if s_proper is AnyType {
		return t_proper
	}
	if s_proper is UnionType && t_proper !is UnionType {
		return meet_types(t_proper, s_proper)
	}

	mut v := TypeMeetVisitor{
		s: s_proper
	}
	return t_proper.accept_translator(mut v) or { t_proper }
}

// narrow_declared_type narrows the declared type to another type
pub fn narrow_declared_type(declared MypyTypeNode, narrowed MypyTypeNode) MypyTypeNode {
	declared_proper := get_proper_type(declared)
	narrowed_proper := get_proper_type(narrowed)

	if declared_proper.str() == narrowed_proper.str() {
		return declared
	}

	if declared_proper is UnionType {
		mut items := []MypyTypeNode{}
		if narrowed_proper is UnionType {
			for d in declared_proper.items {
				for n in narrowed_proper.items {
					if is_overlapping_types(d, n) || is_subtype_simple(n, d) {
						items << narrow_declared_type(d, n)
					}
				}
			}
		} else {
			for d in declared_proper.items {
				if is_overlapping_types(d, narrowed_proper) || is_subtype_simple(narrowed_proper, d) {
					items << narrow_declared_type(d, narrowed_proper)
				}
			}
		}
		return make_simplified_union(items, false)
	}

	if !is_overlapping_types(declared_proper, narrowed_proper) {
		return UninhabitedType{}
	}

	if narrowed_proper is UnionType {
		mut items := []MypyTypeNode{}
		for n in narrowed_proper.items {
			items << narrow_declared_type(declared, n)
		}
		return make_simplified_union(items, false)
	}

	if narrowed_proper is AnyType {
		return narrowed
	}

	return meet_types(declared, narrowed)
}

// is_overlapping_types checks if two types can overlap
pub fn is_overlapping_types(left MypyTypeNode, right MypyTypeNode) bool {
	left_proper := get_proper_type(left)
	right_proper := get_proper_type(right)

	if left_proper is AnyType || right_proper is AnyType {
		return true
	}

	if is_subtype_simple(left_proper, right_proper) || is_subtype_simple(right_proper, left_proper) {
		return true
	}

	// Handle Instance
	if left_proper is Instance && right_proper is Instance {
		if li := left_proper.typ {
			if ri := right_proper.typ {
				if li.has_base(ri.fullname) {
					return true
				}
				if ri.has_base(li.fullname) {
					return true
				}
			}
		}
		return false
	}

	// Handle Union
	if left_proper is UnionType {
		for item in left_proper.items {
			if is_overlapping_types(item, right_proper) {
				return true
			}
		}
		return false
	}
	if right_proper is UnionType {
		for item in right_proper.items {
			if is_overlapping_types(left_proper, item) {
				return true
			}
		}
		return false
	}

	// Handle Callable
	if left_proper is CallableType && right_proper is CallableType {
		return is_similar_callables(left_proper, right_proper)
	}

	return false
}

// TypeMeetVisitor — visitor for computing meet
pub struct TypeMeetVisitor {
pub:
	s MypyTypeNode
}

// visit_unbound_type handles UnboundType
pub fn (v TypeMeetVisitor) visit_unbound_type(t &UnboundType) !MypyTypeNode {
	if v.s is NoneType {
		return UninhabitedType{}
	} else if v.s is UninhabitedType {
		return v.s
	}
	return AnyType{
		type_of_any: TypeOfAny.special_form
	}
}

// visit_any handles AnyType
pub fn (v TypeMeetVisitor) visit_any(t &AnyType) !MypyTypeNode {
	return v.s
}

// visit_union_type handles UnionType
pub fn (v TypeMeetVisitor) visit_union_type(t &UnionType) !MypyTypeNode {
	mut meets := []MypyTypeNode{}
	if v.s is UnionType {
		for x in t.items {
			for y in (v.s as UnionType).items {
				meets << meet_types(x, y)
			}
		}
	} else {
		for x in t.items {
			meets << meet_types(x, v.s)
		}
	}
	return make_simplified_union(meets, false)
}

// visit_none_type handles NoneType
pub fn (v TypeMeetVisitor) visit_none_type(t &NoneType) !MypyTypeNode {
	if v.s is NoneType {
		return *t
	}
	if v.s is Instance {
		if ti := (v.s as Instance).typ {
			if ti.fullname == 'builtins.object' {
				return *t
			}
		}
	}
	return UninhabitedType{}
}

// visit_uninhabited_type handles UninhabitedType
pub fn (v TypeMeetVisitor) visit_uninhabited_type(t &UninhabitedType) !MypyTypeNode {
	return *t
}

// visit_deleted_type handles DeletedType
pub fn (v TypeMeetVisitor) visit_deleted_type(t &DeletedType) !MypyTypeNode {
	if v.s is NoneType || v.s is UninhabitedType {
		return v.s
	}
	return *t
}

// visit_erased_type handles ErasedType
pub fn (v TypeMeetVisitor) visit_erased_type(t &ErasedType) !MypyTypeNode {
	return v.s
}

// visit_type_var handles TypeVar
pub fn (v TypeMeetVisitor) visit_type_var(t &TypeVarType) !MypyTypeNode {
	if v.s is TypeVarType {
		s_tvar := v.s as TypeVarType
		if s_tvar.id == t.id {
			return s_tvar
		}
	}
	return object_from_type(v.s)
}

// visit_instance handles Instance
pub fn (v TypeMeetVisitor) visit_instance(t &Instance) !MypyTypeNode {
	if v.s is Instance {
		s_inst := v.s as Instance
		if ti := t.typ {
			if si := s_inst.typ {
				if ti.fullname == si.fullname {
					if is_subtype_simple(t, s_inst) || is_subtype_simple(s_inst, t) {
						mut args := []MypyTypeNode{}
						for i in 0 .. t.args.len {
							if i >= s_inst.args.len {
								break
							}
							args << meet_types(t.args[i], s_inst.args[i])
						}
						return Instance{
							typ:  t.typ
							args: args
						}
					}
					return UninhabitedType{}
				}
			}
		}
		if is_subtype_simple(t, s_inst) {
			return *t
		} else if is_subtype_simple(s_inst, t) {
			return s_inst
		}
		return UninhabitedType{}
	}
	return object_from_type(v.s)
}

// visit_callable_type handles CallableType
pub fn (v TypeMeetVisitor) visit_callable_type(t &CallableType) !MypyTypeNode {
	if v.s is CallableType {
		s_callable := v.s as CallableType
		if is_similar_callables(t, s_callable) {
			return meet_similar_callables(t, s_callable)
		}
	}
	return object_from_type(v.s)
}

// visit_tuple_type handles TupleType
pub fn (v TypeMeetVisitor) visit_tuple_type(t &TupleType) !MypyTypeNode {
	if v.s is TupleType {
		s_tuple := v.s as TupleType
		if t.items.len == s_tuple.items.len {
			mut items := []MypyTypeNode{}
			for i in 0 .. t.items.len {
				items << meet_types(t.items[i], s_tuple.items[i])
			}
			return TupleType{
				items:            items
				partial_fallback: t.partial_fallback
			}
		}
	}
	return object_from_type(v.s)
}

// visit_typeddict_type handles TypedDictType
pub fn (v TypeMeetVisitor) visit_typeddict_type(t &TypedDictType) !MypyTypeNode {
	if v.s is TypedDictType {
		if is_subtype_simple(t, v.s) {
			return *t
		}
	}
	return object_from_type(v.s)
}

// visit_literal_type handles LiteralType
pub fn (v TypeMeetVisitor) visit_literal_type(t &LiteralType) !MypyTypeNode {
	if v.s is LiteralType {
		vs := v.s as LiteralType
		if vs.str() == t.str() {
			return *t
		}
	}
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_param_spec(t &ParamSpecType) !MypyTypeNode {
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_parameters(t &ParametersType) !MypyTypeNode {
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_type_var_tuple(t &TypeVarTupleType) !MypyTypeNode {
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_overloaded(t &Overloaded) !MypyTypeNode {
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_partial_type(t &PartialTypeT) !MypyTypeNode {
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_type_alias_type(t &TypeAliasType) !MypyTypeNode {
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_unpack_type(t &UnpackType) !MypyTypeNode {
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_type_list(t &TypeList) !MypyTypeNode {
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_callable_argument(t &CallableArgument) !MypyTypeNode {
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_ellipsis_type(t &EllipsisType) !MypyTypeNode {
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_raw_expression_type(t &RawExpressionType) !MypyTypeNode {
	return object_from_type(v.s)
}

pub fn (v TypeMeetVisitor) visit_placeholder_type(t &PlaceholderType) !MypyTypeNode {
	return object_from_type(v.s)
}

// visit_type_type handles TypeType
pub fn (v TypeMeetVisitor) visit_type_type(t &TypeType) !MypyTypeNode {
	return object_from_type(v.s)
}

// Helper functions
pub fn meet_similar_callables(t CallableType, s CallableType) CallableType {
	mut arg_types := []MypyTypeNode{}
	for i in 0 .. t.arg_types.len {
		arg_types << join_types(t.arg_types[i], s.arg_types[i], new_instance_joiner())
	}
	return t.copy_modified(arg_types, meet_types(t.ret_type, s.ret_type), t.variables)
}

pub fn meet_type_list(types []MypyTypeNode) MypyTypeNode {
	if types.len == 0 {
		return AnyType{
			type_of_any: TypeOfAny.implementation_artifact
		}
	}
	mut met := types[0]
	for i := 1; i < types.len; i++ {
		met = meet_types(met, types[i])
	}
	return met
}

pub fn object_from_type(typ MypyTypeNode) MypyTypeNode {
	if typ is Instance {
		if ti := typ.typ {
			return Instance{
				typ:  ti.mro.last()
				args: []
			}
		}
	} else if typ is CallableType {
		if fb := typ.fallback {
			if fbti := fb.typ {
				return Instance{
					typ:  fbti.mro.last()
					args: []
				}
			}
		}
	} else if typ is TupleType {
		if pf := typ.partial_fallback {
			if pfti := pf.typ {
				return Instance{
					typ:  pfti.mro.last()
					args: []
				}
			}
		}
	}
	return AnyType{
		type_of_any: TypeOfAny.special_form
	}
}

fn is_subtype_simple(left MypyTypeNode, right MypyTypeNode) bool {
	ctx := new_subtype_context(false, false, false, false, false, false, false, none)
	return is_subtype_ctx(left, right, ctx)
}
