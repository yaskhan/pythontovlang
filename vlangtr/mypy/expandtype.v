// Я Cline работаю над этим файлом. Начало: 2026-03-22 15:48
// expandtype.v — Substitute type variables in types
// Переведён из mypy/expandtype.py

module mypy

// expand_type подставляет ссылки на типовые переменные в типе
// согласно окружению типов
pub fn expand_type(typ MypyTypeNode, env map[TypeVarId]MypyTypeNode) MypyTypeNode {
	return typ.accept(ExpandTypeVisitor{ variables: env })
}

// expand_type_by_instance подставляет типовые переменные в типе
// используя значения из Instance
pub fn expand_type_by_instance(typ MypyTypeNode, instance InstanceNode) MypyTypeNode {
	if instance.args.len == 0 && !instance.typ.has_type_var_tuple_type {
		return typ
	}

	mut variables := map[TypeVarId]MypyTypeNode{}

	if instance.typ.has_type_var_tuple_type {
		// TODO: обработка TypeVarTuple
		return typ
	} else {
		for i, binder in instance.typ.defn.type_vars {
			if i < instance.args.len {
				variables[binder.id] = instance.args[i]
			}
		}
	}

	return expand_type(typ, variables)
}

// freshen_function_type_vars подставляет свежие типовые переменные
// для обобщённых функций
pub fn freshen_function_type_vars(callee CallableTypeNode) CallableTypeNode {
	if !callee.is_generic() {
		return callee
	}
	mut tvs := []TypeVarLikeType{}
	mut tvmap := map[TypeVarId]MypyTypeNode{}

	for v in callee.variables {
		tv := v.new_unification_variable(v)
		tvs << tv
		tvmap[v.id] = tv
	}

	mut fresh := expand_type(callee, tvmap)
	if fresh is CallableTypeNode {
		return fresh.copy_modified(variables: tvs)
	}
	return callee
}

// freshen_all_functions_type_vars обновляет все обобщённые функции в типе
pub fn freshen_all_functions_type_vars(t MypyTypeNode) MypyTypeNode {
	if !has_generic_callable(t) {
		return t
	}
	return t.accept(FreshenCallableVisitor{})
}

// has_generic_callable проверяет, содержит ли тип обобщённый callable
pub fn has_generic_callable(t MypyTypeNode) bool {
	if t is CallableTypeNode {
		return t.is_generic()
	}
	// TODO: рекурсивная проверка для других типов
	return false
}

// ExpandTypeVisitor — посетитель для подстановки типовых переменных
pub struct ExpandTypeVisitor {
pub:
	variables map[TypeVarId]MypyTypeNode
}

// visit_unbound_type обрабатывает UnboundType
pub fn (v ExpandTypeVisitor) visit_unbound_type(t UnboundTypeNode) MypyTypeNode {
	return t
}

// visit_any обрабатывает AnyType
pub fn (v ExpandTypeVisitor) visit_any(t AnyTypeNode) MypyTypeNode {
	return t
}

// visit_none_type обрабатывает NoneType
pub fn (v ExpandTypeVisitor) visit_none_type(t NoneTypeNode) MypyTypeNode {
	return t
}

// visit_uninhabited_type обрабатывает UninhabitedType (Never)
pub fn (v ExpandTypeVisitor) visit_uninhabited_type(t UninhabitedTypeNode) MypyTypeNode {
	return t
}

// visit_deleted_type обрабатывает DeletedType
pub fn (v ExpandTypeVisitor) visit_deleted_type(t DeletedTypeNode) MypyTypeNode {
	return t
}

// visit_erased_type обрабатывает ErasedType
pub fn (v ExpandTypeVisitor) visit_erased_type(t ErasedTypeNode) MypyTypeNode {
	return t
}

// visit_instance обрабатывает Instance
pub fn (v ExpandTypeVisitor) visit_instance(t InstanceNode) MypyTypeNode {
	if t.args.len == 0 {
		return t
	}

	args := v.expand_types(t.args)
	return t.copy_modified(args: args)
}

// visit_type_var обрабатывает TypeVar
pub fn (v ExpandTypeVisitor) visit_type_var(t TypeVarTypeNode) MypyTypeNode {
	repl := v.variables[t.id] or { return t }
	if repl is InstanceNode {
		return repl.copy_modified(last_known_value: none)
	}
	return repl
}

// visit_param_spec обрабатывает ParamSpec
pub fn (v ExpandTypeVisitor) visit_param_spec(t ParamSpecTypeNode) MypyTypeNode {
	repl := v.variables[t.id] or { return t }
	return repl
}

// visit_type_var_tuple обрабатывает TypeVarTuple
pub fn (v ExpandTypeVisitor) visit_type_var_tuple(t TypeVarTupleTypeNode) MypyTypeNode {
	repl := v.variables[t.id] or { return t }
	if repl is TypeVarTupleTypeNode {
		return repl
	}
	return t
}

// visit_callable_type обрабатывает CallableType
pub fn (v ExpandTypeVisitor) visit_callable_type(t CallableTypeNode) MypyTypeNode {
	arg_types := v.expand_types(t.arg_types)
	ret_type := t.ret_type.accept(v)

	return t.copy_modified(
		arg_types: arg_types
		ret_type:  ret_type
	)
}

// visit_overloaded обрабатывает Overloaded
pub fn (v ExpandTypeVisitor) visit_overloaded(t OverloadedNode) MypyTypeNode {
	mut items := []CallableTypeNode{}
	for item in t.items {
		new_item := item.accept(v)
		if new_item is CallableTypeNode {
			items << new_item
		}
	}
	return OverloadedNode{
		items: items
	}
}

// visit_tuple_type обрабатывает TupleType
pub fn (v ExpandTypeVisitor) visit_tuple_type(t TupleTypeNode) MypyTypeNode {
	items := v.expand_types(t.items)
	fallback := t.partial_fallback.accept(v)
	if fallback is InstanceNode {
		return t.copy_modified(items: items, partial_fallback: fallback)
	}
	return t
}

// visit_typeddict_type обрабатывает TypedDictType
pub fn (v ExpandTypeVisitor) visit_typeddict_type(t TypedDictTypeNode) MypyTypeNode {
	mut item_types := []MypyTypeNode{}
	for item in t.items.values() {
		item_types << item.accept(v)
	}
	fallback := t.fallback.accept(v)
	if fallback is InstanceNode {
		return t.copy_modified(item_types: item_types, fallback: fallback)
	}
	return t
}

// visit_literal_type обрабатывает LiteralType
pub fn (v ExpandTypeVisitor) visit_literal_type(t LiteralTypeNode) MypyTypeNode {
	return t
}

// visit_union_type обрабатывает UnionType
pub fn (v ExpandTypeVisitor) visit_union_type(t UnionTypeNode) MypyTypeNode {
	expanded := v.expand_types(t.items)
	return make_union(expanded)
}

// visit_type_type обрабатывает TypeType
pub fn (v ExpandTypeVisitor) visit_type_type(t TypeTypeNode) MypyTypeNode {
	item := t.item.accept(v)
	return TypeTypeNode.make_normalized(item)
}

// visit_type_alias_type обрабатывает TypeAliasType
pub fn (v ExpandTypeVisitor) visit_type_alias_type(t TypeAliasTypeNode) MypyTypeNode {
	if t.args.len == 0 {
		return t
	}
	args := v.expand_types(t.args)
	return t.copy_modified(args: args)
}

// expand_types расширяет список типов
pub fn (v ExpandTypeVisitor) expand_types(types []MypyTypeNode) []MypyTypeNode {
	mut result := []MypyTypeNode{}
	for t in types {
		result << t.accept(v)
	}
	return result
}

// FreshenCallableVisitor — посетитель для обновления callable типов
pub struct FreshenCallableVisitor {}

// visit_callable_type обновляет типовые переменные в CallableType
pub fn (v FreshenCallableVisitor) visit_callable_type(t CallableTypeNode) MypyTypeNode {
	result := freshen_function_type_vars(t)
	return result
}

// expand_self_type раскрывает Self тип в типе переменной
pub fn expand_self_type(var VarNode, typ MypyTypeNode, replacement MypyTypeNode) MypyTypeNode {
	if var.info.self_type != none && !var.is_property {
		self_type := var.info.self_type or { return typ }
		return expand_type(typ, {
			self_type.id: replacement
		})
	}
	return typ
}

// remove_trivial упрощает список типов без вызова is_subtype
pub fn remove_trivial(types []MypyTypeNode) []MypyTypeNode {
	mut new_types := []MypyTypeNode{}
	mut all_types := map[string]bool{}

	for t in types {
		p_t := get_proper_type(t)
		if p_t is UninhabitedTypeNode {
			continue
		}
		if p_t is InstanceNode && p_t.typ.fullname == 'builtins.object' {
			return [p_t]
		}
		key := p_t.str()
		if key !in all_types {
			new_types << t
			all_types[key] = true
		}
	}

	if new_types.len > 0 {
		return new_types
	}
	return [UninhabitedTypeNode{}]
}

// Вспомогательные функции
fn get_proper_type(t MypyTypeNode) MypyTypeNode {
	// TODO: реализация из types.v
	return t
}

fn make_union(items []MypyTypeNode) MypyTypeNode {
	if items.len == 1 {
		return items[0]
	}
	return UnionTypeNode{
		items: items
	}
}
