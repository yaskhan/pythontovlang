// Work in progress by Cline. Started: 2026-03-22 16:10
// meet.v — Calculation of the greatest lower bound types (meets)
// Translated from mypy/meet.py

module mypy

// trivial_meet возвращает один из типов если он является подтипом другого
pub fn trivial_meet(s MypyTypeNode, t MypyTypeNode) ProperType {
	if is_subtype(s, t) {
		return get_proper_type(s)
	} else if is_subtype(t, s) {
		return get_proper_type(t)
	} else {
		return UninhabitedType{}
	}
}

// meet_types вычисляет greatest lower bound двух типов
pub fn meet_types(s MypyTypeNode, t MypyTypeNode) ProperType {
	s_proper := get_proper_type(s)
	t_proper := get_proper_type(t)

	// Check extra_attrs for Instance
	if s_proper is Instance && t_proper is Instance {
		if s_proper.typ == t_proper.typ {
			if is_same_type(s_proper, t_proper) {
				if s_proper.extra_attrs != none && t_proper.extra_attrs != none {
					if s_proper.extra_attrs.attrs.len > t_proper.extra_attrs.attrs.len {
						return s_proper
					}
					return t_proper
				}
				if s_proper.extra_attrs != none {
					return s_proper
				}
				return t_proper
			}
		}
	}

	if s_proper !is UnboundType && t_proper !is UnboundType {
		if is_proper_subtype(s_proper, t_proper) {
			return s_proper
		}
		if is_proper_subtype(t_proper, s_proper) {
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

	mut v := TypeMeetVisitor{ s: s_proper }
	return t_proper.accept_translator(mut v)
}

// narrow_declared_type narrows the declared type to another type
pub fn narrow_declared_type(declared MypyTypeNode, narrowed MypyTypeNode) MypyTypeNode {
	declared_proper := get_proper_type(declared)
	narrowed_proper := get_proper_type(narrowed)

	if declared_proper == narrowed_proper {
		return declared
	}

	if declared_proper is UnionType {
		mut items := []MypyTypeNode{}
		if narrowed_proper is UnionType {
			for d in declared_proper.items {
				for n in narrowed_proper.items {
					if is_overlapping_types(d, n) || is_subtype(n, d) {
						items << narrow_declared_type(d, n)
					}
				}
			}
		} else {
			for d in declared_proper.items {
				if is_overlapping_types(d, narrowed_proper) || is_subtype(narrowed_proper, d) {
					items << narrow_declared_type(d, narrowed_proper)
				}
			}
		}
		return make_simplified_union(items)
	}

	if !is_overlapping_types(declared_proper, narrowed_proper) {
		return UninhabitedType{}
	}

	if narrowed_proper is UnionType {
		mut items := []MypyTypeNode{}
		for n in narrowed_proper.items {
			items << narrow_declared_type(declared, n)
		}
		return make_simplified_union(items)
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

	if is_subtype(left_proper, right_proper) || is_subtype(right_proper, left_proper) {
		return true
	}

	// Handle Instance
	if left_proper is Instance && right_proper is Instance {
		if left_proper.typ.has_base(right_proper.typ.fullname) {
			return true
		}
		if right_proper.typ.has_base(left_proper.typ.fullname) {
			return true
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
		return is_callable_compatible(left_proper, right_proper)
	}

	return false
}

// TypeMeetVisitor — visitor for computing meet
pub struct TypeMeetVisitor {
pub:
	s ProperType
}

// visit_unbound_type handles UnboundType
pub fn (v TypeMeetVisitor) visit_unbound_type(t &UnboundType) ProperType {
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
pub fn (v TypeMeetVisitor) visit_any(t &AnyType) ProperType {
	return v.s
}

// visit_union_type handles UnionType
pub fn (v TypeMeetVisitor) visit_union_type(t &UnionType) ProperType {
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
	return make_simplified_union(meets)
}

// visit_none_type handles NoneType
pub fn (v TypeMeetVisitor) visit_none_type(t &NoneType) ProperType {
	if v.s is NoneType
		|| (v.s is Instance && (v.s as Instance).typ.fullname == 'builtins.object') {
		return t
	}
	return UninhabitedType{}
}

// visit_uninhabited_type handles UninhabitedType
pub fn (v TypeMeetVisitor) visit_uninhabited_type(t &UninhabitedType) ProperType {
	return t
}

// visit_deleted_type handles DeletedType
pub fn (v TypeMeetVisitor) visit_deleted_type(t &DeletedType) ProperType {
	if v.s is NoneType || v.s is UninhabitedType {
		return v.s
	}
	return t
}

// visit_erased_type handles ErasedType
pub fn (v TypeMeetVisitor) visit_erased_type(t &ErasedType) ProperType {
	return v.s
}

// visit_type_var handles TypeVar
pub fn (v TypeMeetVisitor) visit_type_var(t &TypeVarType) ProperType {
	if v.s is TypeVarType {
		s_tvar := v.s as TypeVarType
		if s_tvar.id == t.id {
			if s_tvar.upper_bound.str() == t.upper_bound.str() {
				return s_tvar
			}
			return s_tvar.copy_modified(
				upper_bound: meet_types(s_tvar.upper_bound, t.upper_bound)
			)
		}
	}
	return object_from_type(v.s)
}

// visit_instance handles Instance
pub fn (v TypeMeetVisitor) visit_instance(t &Instance) ProperType {
	if v.s is Instance {
		s_inst := v.s as Instance
		if t.typ == s_inst.typ {
			if is_subtype(t, s_inst) || is_subtype(s_inst, t) {
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
		} else {
			if is_subtype(t, s_inst) {
				return t
			} else if is_subtype(s_inst, t) {
				return s_inst
			}
			return UninhabitedType{}
		}
	}
	return object_from_type(v.s)
}

// visit_callable_type handles CallableType
pub fn (v TypeMeetVisitor) visit_callable_type(t &CallableType) ProperType {
	if v.s is CallableType {
		s_callable := v.s as CallableType
		if is_similar_callables(t, s_callable) {
			return meet_similar_callables(t, s_callable)
		}
	}
	return object_from_type(v.s)
}

// visit_tuple_type handles TupleType
pub fn (v TypeMeetVisitor) visit_tuple_type(t &TupleType) ProperType {
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
pub fn (v TypeMeetVisitor) visit_typeddict_type(t &TypedDictType) ProperType {
	if v.s is TypedDictType {
		// TODO: full implementation of meet for TypedDict
		if is_subtype(t, v.s) {
			return t
		}
	}
	return object_from_type(v.s)
}

// visit_literal_type handles LiteralType
pub fn (v TypeMeetVisitor) visit_literal_type(t &LiteralTypeNode) ProperType {
	if v.s is LiteralTypeNode && v.s as LiteralTypeNode == t {
		return t
	}
	return object_from_type(v.s)
}

// visit_type_type handles TypeType
pub fn (v TypeMeetVisitor) visit_type_type(t &TypeType) ProperType {
	if v.s is TypeType {
		typ := meet_types(t.item, (v.s as TypeType).item)
		if typ !is NoneType {
			return TypeType.make_normalized(typ)
		}
	}
	return object_from_type(v.s)
}

// Вспомогательные функции
pub fn meet_similar_callables(t CallableType, s CallableType) CallableType {
	mut arg_types := []MypyTypeNode{}
	for i in 0 .. t.arg_types.len {
		arg_types << join_types(t.arg_types[i], s.arg_types[i])
	}
	return t.copy_modified(
		arg_types: arg_types
		ret_type:  meet_types(t.ret_type, s.ret_type)
		name:      ''
	)
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

pub fn object_from_type(typ ProperType) ProperType {
	if typ is Instance {
		return Instance{
			typ:  typ.typ.mro.last()
			args: []
		}
	} else if typ is CallableType {
		return Instance{
			typ:  typ.fallback.typ.mro.last()
			args: []
		}
	} else if typ is TupleType {
		return Instance{
			typ:  typ.partial_fallback.typ.mro.last()
			args: []
		}
	}
	return AnyType{
		type_of_any: TypeOfAny.special_form
	}
}

// Helper stub functions


fn is_subtype(left MypyTypeNode, right MypyTypeNode) bool {
	// Delegate to subtypes module
	ctx := new_subtype_context(false, false, false, false, false, false, false, none)
	return is_subtype(left, right, ctx)
}

fn is_proper_subtype(left ProperType, right ProperType) bool {
	// Delegate to subtypes module
	ctx := new_subtype_context(false, false, false, false, false, false, false, none)
	return is_proper_subtype(left, right, ctx)
}

fn is_same_type(left ProperType, right ProperType) bool {
	return left.str() == right.str()
}

fn is_similar_callables(t CallableType, s CallableType) bool {
	return t.arg_types.len == s.arg_types.len && t.min_args == s.min_args
		&& t.is_var_arg == s.is_var_arg
}

fn is_callable_compatible(t CallableType, s CallableType) bool {
	// Check return type covariance
	if !is_subtype(t.ret_type, s.ret_type) {
		return false
	}
	
	// Check argument type contravariance
	if t.arg_types.len != s.arg_types.len {
		return false
	}
	
	for i in 0 .. t.arg_types.len {
		if !is_subtype(s.arg_types[i], t.arg_types[i]) {
			return false
		}
	}
	
	return true
}

fn make_simplified_union(items []MypyTypeNode) MypyTypeNode {
	if items.len == 0 {
		return UninhabitedType{}
	}
	if items.len == 1 {
		return items[0]
	}
	
	// Remove duplicates
	mut seen := map[string]bool{}
	mut unique := []MypyTypeNode{}
	
	for item in items {
		key := item.str()
		if key !in seen {
			seen[key] = true
			unique << item
		}
	}
	
	// Flatten nested unions
	mut flattened := []MypyTypeNode{}
	for item in unique {
		if item is UnionType {
			for sub_item in item.items {
				sub_key := sub_item.str()
				if sub_key !in seen {
					seen[sub_key] = true
					flattened << sub_item
				}
			}
		} else {
			flattened << item
		}
	}
	
	if flattened.len == 1 {
		return flattened[0]
	}
	
	return UnionType{
		items: flattened
	}
}

fn join_types(s MypyTypeNode, t MypyTypeNode) MypyTypeNode {
	// Delegate to join module
	return join_types(s, t, new_instance_joiner())
}

