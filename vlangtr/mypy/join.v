// Work in progress by Cline. Started: 2026-03-22 16:00
// join.v — Calculation of the least upper bound types (joins)
// Translated from mypy/join.py

module mypy

// InstanceJoiner — computes join of two Instance types
pub struct InstanceJoiner {
pub mut:
	seen_instances [][]Instance
}

// new_instance_joiner creates a new InstanceJoiner
pub fn new_instance_joiner() InstanceJoiner {
	return InstanceJoiner{
		seen_instances: [][]Instance{}
	}
}

// join_instances computes join of two Instance types
pub fn (mut ij InstanceJoiner) join_instances(t Instance, s Instance) ProperType {
	// Check for cyclic dependencies
	for pair in ij.seen_instances {
		if (pair[0].str() == t.str() && pair[1].str() == s.str())
			|| (pair[0].str() == s.str() && pair[1].str() == t.str()) {
			return object_from_instance(t)
		}
	}

	ij.seen_instances << [t, s]

	// If base types are the same
	if t.typ == s.typ {
		mut args := []MypyTypeNode{}

		for i in 0 .. t.args.len {
			if i >= s.args.len {
				break
			}
			ta := t.args[i]
			sa := s.args[i]
			ta_proper := get_proper_type(ta)
			sa_proper := get_proper_type(sa)

			mut new_type := ?MypyTypeNode(none)
			if ta_proper is AnyType {
				new_type = AnyType{
					type_of_any: TypeOfAny.from_another_any
				}
			} else if sa_proper is AnyType {
				new_type = AnyType{
					type_of_any: TypeOfAny.from_another_any
				}
			} else {
				new_type = join_types(ta, sa, mut ij)
			}

			if nt := new_type {
				args << nt
			}
		}

		result := Instance{
			typ:  t.typ
			args: args
		}
		ij.seen_instances.pop()
		return result
	}

	// If t is subtype of s
	if is_subtype(t, s) {
		result := ij.join_instances_via_supertype(t, s)
		ij.seen_instances.pop()
		return result
	}

	// Otherwise find common supertype
	result := ij.join_instances_via_supertype(s, t)
	ij.seen_instances.pop()
	return result
}

// join_instances_via_supertype computes join via supertype
pub fn (ij InstanceJoiner) join_instances_via_supertype(t Instance, s Instance) ProperType {
	// Prefer join via duck typing (e.g., join(int, float) == float)
	for p in t.typ._promote {
		if p is Instance {
			if is_subtype(p, s) {
				return join_types(p, s, ij)
			}
		}
	}
	for p in s.typ._promote {
		if p is Instance {
			if is_subtype(p, t) {
				return join_types(t, p, ij)
			}
		}
	}

	// Compute "best" supertype of t when joining with s
	mut best := ?ProperType(none)
	for base in t.typ.bases {
		mapped := map_instance_to_supertype(t, base.typ)
		res := ij.join_instances(mapped, s)
		if best == none || is_better(res, best or { res }) {
			best = res
		}
	}

	return best or { object_from_instance(t) }
}

// join_types computes least upper bound of two types
pub fn join_types(s MypyTypeNode, t MypyTypeNode, instance_joiner InstanceJoiner) MypyTypeNode {
	s_proper := get_proper_type(s)
	t_proper := get_proper_type(t)

	if s_proper is AnyType {
		return s_proper
	}
	if s_proper is ErasedType {
		return t_proper
	}
	if s_proper is NoneType && t_proper !is NoneType {
		return join_types(t_proper, s_proper, instance_joiner)
	}
	if s_proper is UninhabitedType && t_proper !is UninhabitedType {
		return join_types(t_proper, s_proper, instance_joiner)
	}

	mut v := TypeJoinVisitor{
		s:               s_proper
		instance_joiner: instance_joiner
	}
	return t_proper.accept_translator(mut v)
}

// join_type_list computes join of list of types
pub fn join_type_list(types []MypyTypeNode) MypyTypeNode {
	if types.len == 0 {
		return UninhabitedType{}
	}
	mut joined := types[0]
	for i := 1; i < types.len; i++ {
		joined = join_types(joined, types[i], new_instance_joiner())
	}
	return joined
}

// trivial_join returns one of the types if it is supertype of the other
pub fn trivial_join(s MypyTypeNode, t MypyTypeNode) MypyTypeNode {
	if is_subtype(s, t) {
		return t
	} else if is_subtype(t, s) {
		return s
	} else {
		return object_or_any_from_type(get_proper_type(t))
	}
}

// TypeJoinVisitor — visitor for computing join
pub struct TypeJoinVisitor {
pub:
	s               ProperType
	instance_joiner InstanceJoiner
}

// visit_unbound_type handles UnboundType
pub fn (v TypeJoinVisitor) visit_unbound_type(t &UnboundType) ProperType {
	return AnyType{
		type_of_any: TypeOfAny.special_form
	}
}

// visit_union_type handles UnionType
pub fn (v TypeJoinVisitor) visit_union_type(t &UnionType) ProperType {
	if is_proper_subtype(v.s, t) {
		return t
	}
	return make_simplified_union([v.s, t])
}

// visit_any handles AnyType
pub fn (v TypeJoinVisitor) visit_any(t &AnyType) ProperType {
	return t
}

// visit_none_type handles NoneType
pub fn (v TypeJoinVisitor) visit_none_type(t &NoneType) ProperType {
	if v.s is NoneType || v.s is UninhabitedType {
		return t
	}
	return make_simplified_union([v.s, t])
}

// visit_uninhabited_type handles UninhabitedType
pub fn (v TypeJoinVisitor) visit_uninhabited_type(t &UninhabitedType) ProperType {
	return v.s
}

// visit_deleted_type handles DeletedType
pub fn (v TypeJoinVisitor) visit_deleted_type(t &DeletedType) ProperType {
	return v.s
}

// visit_erased_type handles ErasedType
pub fn (v TypeJoinVisitor) visit_erased_type(t &ErasedType) ProperType {
	return v.s
}

// visit_type_var handles TypeVar
pub fn (v TypeJoinVisitor) visit_type_var(t &TypeVarType) ProperType {
	if v.s is TypeVarType {
		s_tvar := v.s as TypeVarType
		if s_tvar.id == t.id {
			if s_tvar.upper_bound.str() == t.upper_bound.str() {
				return s_tvar
			}
			return s_tvar.copy_modified(
				upper_bound: join_types(s_tvar.upper_bound, t.upper_bound, v.instance_joiner)
			)
		}
		return get_proper_type(join_types(s_tvar.upper_bound, t.upper_bound, v.instance_joiner))
	}
	return object_from_type(v.s)
}

// visit_instance handles Instance
pub fn (v TypeJoinVisitor) visit_instance(t &Instance) ProperType {
	if v.s is Instance {
		mut ij := v.instance_joiner
		return ij.join_instances(t, v.s as Instance)
	}
	return object_from_instance(t)
}

// visit_callable_type handles CallableType
pub fn (v TypeJoinVisitor) visit_callable_type(t &CallableType) ProperType {
	if v.s is CallableType {
		if is_similar_callables(t, v.s as CallableType) {
			return combine_similar_callables(t, v.s as CallableType)
		}
		return join_types(t.fallback, (v.s as CallableType).fallback, v.instance_joiner)
	}
	return join_types(t.fallback, v.s, v.instance_joiner)
}

// visit_tuple_type handles TupleType
pub fn (v TypeJoinVisitor) visit_tuple_type(t &TupleType) ProperType {
	if v.s is TupleType {
		s_tuple := v.s as TupleType
		if t.items.len == s_tuple.items.len {
			mut items := []MypyTypeNode{}
			for i in 0 .. t.items.len {
				items << join_types(t.items[i], s_tuple.items[i], v.instance_joiner)
			}
			return TupleType{
				items:            items
				partial_fallback: t.partial_fallback
			}
		}
	}
	return object_from_instance(t.partial_fallback)
}

// visit_typeddict_type handles TypedDictType
pub fn (v TypeJoinVisitor) visit_typeddict_type(t &TypedDictType) ProperType {
	return object_from_instance(t.fallback)
}

// visit_literal_type handles LiteralType
pub fn (v TypeJoinVisitor) visit_literal_type(t &LiteralTypeNode) ProperType {
	if v.s is LiteralTypeNode {
		s_lit := v.s as LiteralTypeNode
		if t == s_lit {
			return t
		}
		return join_types(s_lit.fallback, t.fallback, v.instance_joiner)
	}
	return join_types(v.s, t.fallback, v.instance_joiner)
}

// visit_type_type handles TypeType
pub fn (v TypeJoinVisitor) visit_type_type(t &TypeType) ProperType {
	if v.s is TypeType {
		return TypeType.make_normalized(join_types(t.item, (v.s as TypeType).item, v.instance_joiner))
	}
	return object_from_type(v.s)
}

// Helper functions
pub fn is_better(t ProperType, s ProperType) bool {
	if t is Instance {
		if s !is Instance {
			return true
		}
		return t.typ.mro.len > (s as Instance).typ.mro.len
	}
	return false
}

pub fn is_similar_callables(t CallableType, s CallableType) bool {
	return t.arg_types.len == s.arg_types.len && t.min_args == s.min_args
		&& t.is_var_arg == s.is_var_arg
}

pub fn combine_similar_callables(t CallableType, s CallableType) CallableType {
	mut arg_types := []MypyTypeNode{}
	for i in 0 .. t.arg_types.len {
		arg_types << join_types(t.arg_types[i], s.arg_types[i], new_instance_joiner())
	}
	return t.copy_modified(
		arg_types: arg_types
		ret_type:  join_types(t.ret_type, s.ret_type, new_instance_joiner())
		name:      ''
	)
}

pub fn object_from_instance(instance Instance) Instance {
	return Instance{
		typ:  instance.typ.mro.last()
		args: []
	}
}

pub fn object_or_any_from_type(typ ProperType) ProperType {
	if typ is Instance {
		return object_from_instance(typ)
	} else if typ is CallableType {
		return object_from_instance(typ.fallback)
	} else if typ is TupleType {
		return object_from_instance(typ.partial_fallback)
	} else if typ is TypedDictType {
		return object_from_instance(typ.fallback)
	} else if typ is TypeVarType {
		return object_or_any_from_type(get_proper_type(typ.upper_bound))
	}
	return AnyType{
		type_of_any: TypeOfAny.implementation_artifact
	}
}

pub fn unpack_callback_protocol(t Instance) ?ProperType {
	// Check if protocol has only __call__ member
	if !t.typ.is_protocol {
		return none
	}

	mut has_call := false
	mut other_members := false

	for name in t.typ.names.symbols.keys() {
		if name == '__call__' {
			has_call = true
		} else if !name.starts_with('_')
			|| name in ['__iter__', '__next__', '__getitem__', '__setitem__'] {
			other_members = true
		}
	}

	if has_call && !other_members {
		// Return the __call__ type
		sym := t.typ.names.symbols['__call__'] or { return none }
		if sym.node != none {
			return sym.node.typ
		}
	}

	return none
}

// Helper stub functions

fn is_subtype(left MypyTypeNode, right MypyTypeNode) bool {
	// Delegate to subtypes module
	ctx := new_subtype_context(false, false, false, false, false, false, false, none)
	return is_subtype(left, right, ctx)
}

fn is_proper_subtype(left MypyTypeNode, right MypyTypeNode) bool {
	// Delegate to subtypes module
	ctx := new_subtype_context(false, false, false, false, false, false, false, none)
	return is_proper_subtype(left, right, ctx)
}

fn map_instance_to_supertype(inst Instance, supertype TypeInfo) Instance {
	// Delegate to subtypes module
	return map_instance_to_supertype(inst, supertype)
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
