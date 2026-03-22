// Я Cline работаю над этим файлом. Начало: 2026-03-22 16:10
// meet.v — Calculation of the greatest lower bound types (meets)
// Переведён из mypy/meet.py

module mypy

// trivial_meet возвращает один из типов если он является подтипом другого
pub fn trivial_meet(s MypyTypeNode, t MypyTypeNode) ProperTypeNode {
	if is_subtype(s, t) {
		return get_proper_type(s)
	} else if is_subtype(t, s) {
		return get_proper_type(t)
	} else {
		return UninhabitedTypeNode{}
	}
}

// meet_types вычисляет greatest lower bound двух типов
pub fn meet_types(s MypyTypeNode, t MypyTypeNode) ProperTypeNode {
	s_proper := get_proper_type(s)
	t_proper := get_proper_type(t)

	// Проверяем extra_attrs для Instance
	if s_proper is InstanceNode && t_proper is InstanceNode {
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

	if s_proper !is UnboundTypeNode && t_proper !is UnboundTypeNode {
		if is_proper_subtype(s_proper, t_proper) {
			return s_proper
		}
		if is_proper_subtype(t_proper, s_proper) {
			return t_proper
		}
	}

	if s_proper is ErasedTypeNode {
		return s_proper
	}
	if s_proper is AnyTypeNode {
		return t_proper
	}
	if s_proper is UnionTypeNode && t_proper !is UnionTypeNode {
		return meet_types(t_proper, s_proper)
	}

	return t_proper.accept(TypeMeetVisitor{s: s_proper})
}

// narrow_declared_type сужает объявленный тип до другого типа
pub fn narrow_declared_type(declared MypyTypeNode, narrowed MypyTypeNode) MypyTypeNode {
	declared_proper := get_proper_type(declared)
	narrowed_proper := get_proper_type(narrowed)

	if declared_proper == narrowed_proper {
		return declared
	}

	if declared_proper is UnionTypeNode {
		mut items := []MypyTypeNode{}
		if narrowed_proper is UnionTypeNode {
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
		return UninhabitedTypeNode{}
	}

	if narrowed_proper is UnionTypeNode {
		mut items := []MypyTypeNode{}
		for n in narrowed_proper.items {
			items << narrow_declared_type(declared, n)
		}
		return make_simplified_union(items)
	}

	if narrowed_proper is AnyTypeNode {
		return narrowed
	}

	return meet_types(declared, narrowed)
}

// is_overlapping_types проверяет, могут ли два типа пересекаться
pub fn is_overlapping_types(left MypyTypeNode, right MypyTypeNode) bool {
	left_proper := get_proper_type(left)
	right_proper := get_proper_type(right)

	if left_proper is AnyTypeNode || right_proper is AnyTypeNode {
		return true
	}

	if is_subtype(left_proper, right_proper) || is_subtype(right_proper, left_proper) {
		return true
	}

	// Обработка Instance
	if left_proper is InstanceNode && right_proper is InstanceNode {
		if left_proper.typ.has_base(right_proper.typ.fullname) {
			return true
		}
		if right_proper.typ.has_base(left_proper.typ.fullname) {
			return true
		}
		return false
	}

	// Обработка Union
	if left_proper is UnionTypeNode {
		for item in left_proper.items {
			if is_overlapping_types(item, right_proper) {
				return true
			}
		}
		return false
	}
	if right_proper is UnionTypeNode {
		for item in right_proper.items {
			if is_overlapping_types(left_proper, item) {
				return true
			}
		}
		return false
	}

	// Обработка Callable
	if left_proper is CallableTypeNode && right_proper is CallableTypeNode {
		return is_callable_compatible(left_proper, right_proper)
	}

	return false
}

// TypeMeetVisitor — посетитель для вычисления meet
pub struct TypeMeetVisitor {
pub:
	s ProperTypeNode
}

// visit_unbound_type обрабатывает UnboundType
pub fn (v TypeMeetVisitor) visit_unbound_type(t UnboundTypeNode) ProperTypeNode {
	if v.s is NoneTypeNode {
		return UninhabitedTypeNode{}
	} else if v.s is UninhabitedTypeNode {
		return v.s
	}
	return AnyTypeNode{reason: TypeOfAny.special_form}
}

// visit_any обрабатывает AnyType
pub fn (v TypeMeetVisitor) visit_any(t AnyTypeNode) ProperTypeNode {
	return v.s
}

// visit_union_type обрабатывает UnionType
pub fn (v TypeMeetVisitor) visit_union_type(t UnionTypeNode) ProperTypeNode {
	mut meets := []MypyTypeNode{}
	if v.s is UnionTypeNode {
		for x in t.items {
			for y in (v.s as UnionTypeNode).items {
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

// visit_none_type обрабатывает NoneType
pub fn (v TypeMeetVisitor) visit_none_type(t NoneTypeNode) ProperTypeNode {
	if v.s is NoneTypeNode || (v.s is InstanceNode && (v.s as InstanceNode).typ.fullname == 'builtins.object') {
		return t
	}
	return UninhabitedTypeNode{}
}

// visit_uninhabited_type обрабатывает UninhabitedType
pub fn (v TypeMeetVisitor) visit_uninhabited_type(t UninhabitedTypeNode) ProperTypeNode {
	return t
}

// visit_deleted_type обрабатывает DeletedType
pub fn (v TypeMeetVisitor) visit_deleted_type(t DeletedTypeNode) ProperTypeNode {
	if v.s is NoneTypeNode || v.s is UninhabitedTypeNode {
		return v.s
	}
	return t
}

// visit_erased_type обрабатывает ErasedType
pub fn (v TypeMeetVisitor) visit_erased_type(t ErasedTypeNode) ProperTypeNode {
	return v.s
}

// visit_type_var обрабатывает TypeVar
pub fn (v TypeMeetVisitor) visit_type_var(t TypeVarTypeNode) ProperTypeNode {
	if v.s is TypeVarTypeNode {
		s_tvar := v.s as TypeVarTypeNode
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

// visit_instance обрабатывает Instance
pub fn (v TypeMeetVisitor) visit_instance(t InstanceNode) ProperTypeNode {
	if v.s is InstanceNode {
		s_inst := v.s as InstanceNode
		if t.typ == s_inst.typ {
			if is_subtype(t, s_inst) || is_subtype(s_inst, t) {
				mut args := []MypyTypeNode{}
				for i in 0 .. t.args.len {
					if i >= s_inst.args.len {
						break
					}
					args << meet_types(t.args[i], s_inst.args[i])
				}
				return InstanceNode{typ: t.typ, args: args}
			}
			return UninhabitedTypeNode{}
		} else {
			if is_subtype(t, s_inst) {
				return t
			} else if is_subtype(s_inst, t) {
				return s_inst
			}
			return UninhabitedTypeNode{}
		}
	}
	return object_from_type(v.s)
}

// visit_callable_type обрабатывает CallableType
pub fn (v TypeMeetVisitor) visit_callable_type(t CallableTypeNode) ProperTypeNode {
	if v.s is CallableTypeNode {
		s_callable := v.s as CallableTypeNode
		if is_similar_callables(t, s_callable) {
			return meet_similar_callables(t, s_callable)
		}
	}
	return object_from_type(v.s)
}

// visit_tuple_type обрабатывает TupleType
pub fn (v TypeMeetVisitor) visit_tuple_type(t TupleTypeNode) ProperTypeNode {
	if v.s is TupleTypeNode {
		s_tuple := v.s as TupleTypeNode
		if t.items.len == s_tuple.items.len {
			mut items := []MypyTypeNode{}
			for i in 0 .. t.items.len {
				items << meet_types(t.items[i], s_tuple.items[i])
			}
			return TupleTypeNode{items: items, partial_fallback: t.partial_fallback}
		}
	}
	return object_from_type(v.s)
}

// visit_typeddict_type обрабатывает TypedDictType
pub fn (v TypeMeetVisitor) visit_typeddict_type(t TypedDictTypeNode) ProperTypeNode {
	if v.s is TypedDictTypeNode {
		// TODO: полная реализация meet для TypedDict
		if is_subtype(t, v.s) {
			return t
		}
	}
	return object_from_type(v.s)
}

// visit_literal_type обрабатывает LiteralType
pub fn (v TypeMeetVisitor) visit_literal_type(t LiteralTypeNode) ProperTypeNode {
	if v.s is LiteralTypeNode && v.s as LiteralTypeNode == t {
		return t
	}
	return object_from_type(v.s)
}

// visit_type_type обрабатывает TypeType
pub fn (v TypeMeetVisitor) visit_type_type(t TypeTypeNode) ProperTypeNode {
	if v.s is TypeTypeNode {
		typ := meet_types(t.item, (v.s as TypeTypeNode).item)
		if typ !is NoneTypeNode {
			return TypeTypeNode.make_normalized(typ)
		}
	}
	return object_from_type(v.s)
}

// Вспомогательные функции
pub fn meet_similar_callables(t CallableTypeNode, s CallableTypeNode) CallableTypeNode {
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
		return AnyTypeNode{reason: TypeOfAny.implementation_artifact}
	}
	mut met := types[0]
	for i := 1; i < types.len; i++ {
		met = meet_types(met, types[i])
	}
	return met
}

pub fn object_from_type(typ ProperTypeNode) ProperTypeNode {
	if typ is InstanceNode {
		return InstanceNode{typ: typ.typ.mro.last(), args: []}
	} else if typ is CallableTypeNode {
		return InstanceNode{typ: typ.fallback.typ.mro.last(), args: []}
	} else if typ is TupleTypeNode {
		return InstanceNode{typ: typ.partial_fallback.typ.mro.last(), args: []}
	}
	return AnyTypeNode{reason: TypeOfAny.special_form}
}

// Вспомогательные функции-заглушки
fn get_proper_type(t MypyTypeNode) ProperTypeNode {
	return t as ProperTypeNode
}

fn is_subtype(left MypyTypeNode, right MypyTypeNode) bool {
	return true
}

fn is_proper_subtype(left ProperTypeNode, right ProperTypeNode) bool {
	return true
}

fn is_same_type(left ProperTypeNode, right ProperTypeNode) bool {
	return left.str() == right.str()
}

fn is_similar_callables(t CallableTypeNode, s CallableTypeNode) bool {
	return t.arg_types.len == s.arg_types.len
}

fn is_callable_compatible(t CallableTypeNode, s CallableTypeNode) bool {
	return true
}

fn make_simplified_union(items []MypyTypeNode) MypyTypeNode {
	if items.len == 1 {
		return items[0]
	}
	return UnionTypeNode{items: items}
}

fn join_types(s MypyTypeNode, t MypyTypeNode) MypyTypeNode {
	// TODO: вызов из join.v
	return s
}