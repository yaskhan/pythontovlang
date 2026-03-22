// Я Cline работаю над этим файлом. Начало: 2026-03-22 16:00
// join.v — Calculation of the least upper bound types (joins)
// Переведён из mypy/join.py

module mypy

// InstanceJoiner — вычисляет join двух Instance типов
pub struct InstanceJoiner {
pub mut:
	seen_instances [][]InstanceNode
}

// new_instance_joiner создаёт новый InstanceJoiner
pub fn new_instance_joiner() InstanceJoiner {
	return InstanceJoiner{
		seen_instances: [][]InstanceNode{}
	}
}

// join_instances вычисляет join двух Instance типов
pub fn (mut ij InstanceJoiner) join_instances(t InstanceNode, s InstanceNode) ProperTypeNode {
	// Проверяем на циклические зависимости
	for pair in ij.seen_instances {
		if (pair[0].str() == t.str() && pair[1].str() == s.str())
			|| (pair[0].str() == s.str() && pair[1].str() == t.str()) {
			return object_from_instance(t)
		}
	}

	ij.seen_instances << [t, s]

	// Если базовые типы одинаковые
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
			if ta_proper is AnyTypeNode {
				new_type = AnyTypeNode{
					reason: TypeOfAny.from_another_any
				}
			} else if sa_proper is AnyTypeNode {
				new_type = AnyTypeNode{
					reason: TypeOfAny.from_another_any
				}
			} else {
				new_type = join_types(ta, sa, mut ij)
			}

			if nt := new_type {
				args << nt
			}
		}

		result := InstanceNode{
			typ:  t.typ
			args: args
		}
		ij.seen_instances.pop()
		return result
	}

	// Если t является подтипом s
	if is_subtype(t, s) {
		result := ij.join_instances_via_supertype(t, s)
		ij.seen_instances.pop()
		return result
	}

	// Иначе ищем общий супертип
	result := ij.join_instances_via_supertype(s, t)
	ij.seen_instances.pop()
	return result
}

// join_instances_via_supertype вычисляет join через супертип
pub fn (ij InstanceJoiner) join_instances_via_supertype(t InstanceNode, s InstanceNode) ProperTypeNode {
	// Предпочитаем join через duck typing (например, join(int, float) == float)
	for p in t.typ._promote {
		if p is InstanceNode {
			if is_subtype(p, s) {
				return join_types(p, s, ij)
			}
		}
	}
	for p in s.typ._promote {
		if p is InstanceNode {
			if is_subtype(p, t) {
				return join_types(t, p, ij)
			}
		}
	}

	// Вычисляем "лучший" супертип t при join с s
	mut best := ?ProperTypeNode(none)
	for base in t.typ.bases {
		mapped := map_instance_to_supertype(t, base.typ)
		res := ij.join_instances(mapped, s)
		if best == none || is_better(res, best or { res }) {
			best = res
		}
	}

	return best or { object_from_instance(t) }
}

// join_types вычисляет least upper bound двух типов
pub fn join_types(s MypyTypeNode, t MypyTypeNode, instance_joiner InstanceJoiner) MypyTypeNode {
	s_proper := get_proper_type(s)
	t_proper := get_proper_type(t)

	if s_proper is AnyTypeNode {
		return s_proper
	}
	if s_proper is ErasedTypeNode {
		return t_proper
	}
	if s_proper is NoneTypeNode && t_proper !is NoneTypeNode {
		return join_types(t_proper, s_proper, instance_joiner)
	}
	if s_proper is UninhabitedTypeNode && t_proper !is UninhabitedTypeNode {
		return join_types(t_proper, s_proper, instance_joiner)
	}

	return t_proper.accept(TypeJoinVisitor{ s: s_proper, instance_joiner: instance_joiner })
}

// join_type_list вычисляет join списка типов
pub fn join_type_list(types []MypyTypeNode) MypyTypeNode {
	if types.len == 0 {
		return UninhabitedTypeNode{}
	}
	mut joined := types[0]
	for i := 1; i < types.len; i++ {
		joined = join_types(joined, types[i], new_instance_joiner())
	}
	return joined
}

// trivial_join возвращает один из типов если он является супертипом другого
pub fn trivial_join(s MypyTypeNode, t MypyTypeNode) MypyTypeNode {
	if is_subtype(s, t) {
		return t
	} else if is_subtype(t, s) {
		return s
	} else {
		return object_or_any_from_type(get_proper_type(t))
	}
}

// TypeJoinVisitor — посетитель для вычисления join
pub struct TypeJoinVisitor {
pub:
	s               ProperTypeNode
	instance_joiner InstanceJoiner
}

// visit_unbound_type обрабатывает UnboundType
pub fn (v TypeJoinVisitor) visit_unbound_type(t UnboundTypeNode) ProperTypeNode {
	return AnyTypeNode{
		reason: TypeOfAny.special_form
	}
}

// visit_union_type обрабатывает UnionType
pub fn (v TypeJoinVisitor) visit_union_type(t UnionTypeNode) ProperTypeNode {
	if is_proper_subtype(v.s, t) {
		return t
	}
	return make_simplified_union([v.s, t])
}

// visit_any обрабатывает AnyType
pub fn (v TypeJoinVisitor) visit_any(t AnyTypeNode) ProperTypeNode {
	return t
}

// visit_none_type обрабатывает NoneType
pub fn (v TypeJoinVisitor) visit_none_type(t NoneTypeNode) ProperTypeNode {
	if v.s is NoneTypeNode || v.s is UninhabitedTypeNode {
		return t
	}
	return make_simplified_union([v.s, t])
}

// visit_uninhabited_type обрабатывает UninhabitedType
pub fn (v TypeJoinVisitor) visit_uninhabited_type(t UninhabitedTypeNode) ProperTypeNode {
	return v.s
}

// visit_deleted_type обрабатывает DeletedType
pub fn (v TypeJoinVisitor) visit_deleted_type(t DeletedTypeNode) ProperTypeNode {
	return v.s
}

// visit_erased_type обрабатывает ErasedType
pub fn (v TypeJoinVisitor) visit_erased_type(t ErasedTypeNode) ProperTypeNode {
	return v.s
}

// visit_type_var обрабатывает TypeVar
pub fn (v TypeJoinVisitor) visit_type_var(t TypeVarTypeNode) ProperTypeNode {
	if v.s is TypeVarTypeNode {
		s_tvar := v.s as TypeVarTypeNode
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

// visit_instance обрабатывает Instance
pub fn (v TypeJoinVisitor) visit_instance(t InstanceNode) ProperTypeNode {
	if v.s is InstanceNode {
		mut ij := v.instance_joiner
		return ij.join_instances(t, v.s as InstanceNode)
	}
	return object_from_instance(t)
}

// visit_callable_type обрабатывает CallableType
pub fn (v TypeJoinVisitor) visit_callable_type(t CallableTypeNode) ProperTypeNode {
	if v.s is CallableTypeNode {
		if is_similar_callables(t, v.s as CallableTypeNode) {
			return combine_similar_callables(t, v.s as CallableTypeNode)
		}
		return join_types(t.fallback, (v.s as CallableTypeNode).fallback, v.instance_joiner)
	}
	return join_types(t.fallback, v.s, v.instance_joiner)
}

// visit_tuple_type обрабатывает TupleType
pub fn (v TypeJoinVisitor) visit_tuple_type(t TupleTypeNode) ProperTypeNode {
	if v.s is TupleTypeNode {
		s_tuple := v.s as TupleTypeNode
		if t.items.len == s_tuple.items.len {
			mut items := []MypyTypeNode{}
			for i in 0 .. t.items.len {
				items << join_types(t.items[i], s_tuple.items[i], v.instance_joiner)
			}
			return TupleTypeNode{
				items:            items
				partial_fallback: t.partial_fallback
			}
		}
	}
	return object_from_instance(t.partial_fallback)
}

// visit_typeddict_type обрабатывает TypedDictType
pub fn (v TypeJoinVisitor) visit_typeddict_type(t TypedDictTypeNode) ProperTypeNode {
	return object_from_instance(t.fallback)
}

// visit_literal_type обрабатывает LiteralType
pub fn (v TypeJoinVisitor) visit_literal_type(t LiteralTypeNode) ProperTypeNode {
	if v.s is LiteralTypeNode {
		s_lit := v.s as LiteralTypeNode
		if t == s_lit {
			return t
		}
		return join_types(s_lit.fallback, t.fallback, v.instance_joiner)
	}
	return join_types(v.s, t.fallback, v.instance_joiner)
}

// visit_type_type обрабатывает TypeType
pub fn (v TypeJoinVisitor) visit_type_type(t TypeTypeNode) ProperTypeNode {
	if v.s is TypeTypeNode {
		return TypeTypeNode.make_normalized(join_types(t.item, (v.s as TypeTypeNode).item,
			v.instance_joiner))
	}
	return object_from_type(v.s)
}

// Вспомогательные функции
pub fn is_better(t ProperTypeNode, s ProperTypeNode) bool {
	if t is InstanceNode {
		if s !is InstanceNode {
			return true
		}
		return t.typ.mro.len > (s as InstanceNode).typ.mro.len
	}
	return false
}

pub fn is_similar_callables(t CallableTypeNode, s CallableTypeNode) bool {
	return t.arg_types.len == s.arg_types.len && t.min_args == s.min_args
		&& t.is_var_arg == s.is_var_arg
}

pub fn combine_similar_callables(t CallableTypeNode, s CallableTypeNode) CallableTypeNode {
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

pub fn object_from_instance(instance InstanceNode) InstanceNode {
	return InstanceNode{
		typ:  instance.typ.mro.last()
		args: []
	}
}

pub fn object_or_any_from_type(typ ProperTypeNode) ProperTypeNode {
	if typ is InstanceNode {
		return object_from_instance(typ)
	} else if typ is CallableTypeNode {
		return object_from_instance(typ.fallback)
	} else if typ is TupleTypeNode {
		return object_from_instance(typ.partial_fallback)
	} else if typ is TypedDictTypeNode {
		return object_from_instance(typ.fallback)
	} else if typ is TypeVarTypeNode {
		return object_or_any_from_type(get_proper_type(typ.upper_bound))
	}
	return AnyTypeNode{
		reason: TypeOfAny.implementation_artifact
	}
}

pub fn unpack_callback_protocol(t InstanceNode) ?ProperTypeNode {
	// TODO: реализация проверки protocol_members == ["__call__"]
	return none
}

// Вспомогательные функции-заглушки
fn get_proper_type(t MypyTypeNode) ProperTypeNode {
	// TODO: реализация из types.v
	return t as ProperTypeNode
}

fn is_subtype(left MypyTypeNode, right MypyTypeNode) bool {
	// TODO: реализация из subtypes.v
	return true
}

fn is_proper_subtype(left MypyTypeNode, right MypyTypeNode) bool {
	// TODO: реализация из subtypes.v
	return true
}

fn map_instance_to_supertype(inst InstanceNode, supertype TypeInfoNode) InstanceNode {
	// TODO: реализация из maptype.v
	return inst
}

fn make_simplified_union(items []MypyTypeNode) MypyTypeNode {
	// TODO: реализация из typeops.v
	if items.len == 1 {
		return items[0]
	}
	return UnionTypeNode{
		items: items
	}
}
