// Я Qwen Code работаю над этим файлом. Начало: 2026-03-22 17:30
// Type erasure utilities for mypy (erasetype.py)

module mypy

// erase_type erases any type variables from a type.
// Also replace tuple types with the corresponding concrete types.
// Examples:
//   A -> A
//   B[X] -> B[Any]
//   Tuple[A, B] -> tuple
//   Callable[[A1, A2, ...], R] -> Callable[..., Any]
//   Type[X] -> Type[Any]
pub fn erase_type(typ Type) ProperType {
	typ = get_proper_type(typ)
	return typ.accept(EraseTypeVisitor{})
}

// EraseTypeVisitor implements type erasure.
pub struct EraseTypeVisitor {}

pub fn (v EraseTypeVisitor) visit_unbound_type(t &UnboundType) !ProperType {
	// TODO: replace with an assert after UnboundType can't leak from semantic analysis.
	return AnyType{
		base:        TypeBase{}
		type_of_any: type_of_any_from_error
	}
}

pub fn (v EraseTypeVisitor) visit_any(t &AnyType) !ProperType {
	return t
}

pub fn (v EraseTypeVisitor) visit_none_type(t &NoneType) !ProperType {
	return t
}

pub fn (v EraseTypeVisitor) visit_uninhabited_type(t &UninhabitedType) !ProperType {
	return t
}

pub fn (v EraseTypeVisitor) visit_erased_type(t &ErasedType) !ProperType {
	return t
}

pub fn (v EraseTypeVisitor) visit_partial_type(t &PartialType) !ProperType {
	// Should not get here.
	panic('Cannot erase partial types')
}

pub fn (v EraseTypeVisitor) visit_deleted_type(t &DeletedType) !ProperType {
	return t
}

pub fn (v EraseTypeVisitor) visit_instance(t &Instance) !ProperType {
	args := erased_vars(t.type_info.defn.type_vars, type_of_any_special_form)
	return Instance{
		base:      TypeBase{}
		type_info: t.type_info
		args:      args
		line:      t.line
	}
}

pub fn (v EraseTypeVisitor) visit_type_var(t &TypeVarType) !ProperType {
	return AnyType{
		base:        TypeBase{}
		type_of_any: type_of_any_special_form
	}
}

pub fn (v EraseTypeVisitor) visit_param_spec(t &ParamSpecType) !ProperType {
	return AnyType{
		base:        TypeBase{}
		type_of_any: type_of_any_special_form
	}
}

pub fn (v EraseTypeVisitor) visit_parameters(t &ParametersType) !ProperType {
	panic('Parameters should have been bound to a class')
}

pub fn (v EraseTypeVisitor) visit_type_var_tuple(t &TypeVarTupleType) !ProperType {
	// Likely, we can never get here because of aggressive erasure of types that
	// can contain this, but better still return a valid replacement.
	return t.tuple_fallback.copy_modified(
		args: [AnyType{
			base:        TypeBase{}
			type_of_any: type_of_any_special_form
		}]
	)
}

pub fn (v EraseTypeVisitor) visit_unpack_type(t &UnpackType) !ProperType {
	return AnyType{
		base:        TypeBase{}
		type_of_any: type_of_any_special_form
	}
}

pub fn (v EraseTypeVisitor) visit_callable_type(t &CallableType) !ProperType {
	// We must preserve the fallback type for overload resolution to work.
	any_type := AnyType{
		base:        TypeBase{}
		type_of_any: type_of_any_special_form
	}
	return CallableType{
		base:             TypeBase{}
		arg_types:        [any_type, any_type]
		arg_kinds:        [arg_star, arg_star2]
		arg_names:        [none, none]
		ret_type:         any_type
		fallback:         t.fallback
		is_ellipsis_args: true
		implicit:         true
	}
}

pub fn (v EraseTypeVisitor) visit_overloaded(t &Overloaded) !ProperType {
	return t.fallback.accept(EraseTypeVisitor{})
}

pub fn (v EraseTypeVisitor) visit_tuple_type(t &TupleType) !ProperType {
	return t.partial_fallback.accept(EraseTypeVisitor{})
}

pub fn (v EraseTypeVisitor) visit_typeddict_type(t &TypedDictType) !ProperType {
	return t.fallback.accept(EraseTypeVisitor{})
}

pub fn (v EraseTypeVisitor) visit_literal_type(t &LiteralType) !ProperType {
	// The fallback for literal types should always be either
	// something like int or str, or an enum class -- types that
	// don't contain any TypeVars. So there's no need to visit it.
	return t
}

pub fn (v EraseTypeVisitor) visit_union_type(t &UnionType) !ProperType {
	mut erased_items := []Type{}
	for item in t.items {
		erased_items << erase_type(item)
	}
	return make_simplified_union(erased_items)
}

pub fn (v EraseTypeVisitor) visit_type_type(t &TypeType) !ProperType {
	return TypeType.make_normalized(t.item.accept(EraseTypeVisitor{})!,
		line:         t.line
		is_type_form: t.is_type_form
	)
}

pub fn (v EraseTypeVisitor) visit_type_alias_type(t &TypeAliasType) !ProperType {
	panic('Type aliases should be expanded before accepting this visitor')
}

// erase_typevars replaces all type variables in a type with any,
// or just the ones in the provided collection.
pub fn erase_typevars(t Type, ids_to_erase ?[]TypeVarId) Type {
	if ids_to_erase == none {
		return t.accept(TypeVarEraser{
			erase_id:    none
			replacement: AnyType{
				base:        TypeBase{}
				type_of_any: type_of_any_special_form
			}
		})!
	}
	return t.accept(TypeVarEraser{
		erase_id:    ids_to_erase
		replacement: AnyType{
			base:        TypeBase{}
			type_of_any: type_of_any_special_form
		}
	})!
}

// erase_meta_id returns true if the id is a meta variable.
pub fn erase_meta_id(id TypeVarId) bool {
	return id.is_meta_var()
}

// replace_meta_vars replaces unification variables in a type with the target type.
pub fn replace_meta_vars(t Type, target_type Type) Type {
	return t.accept(TypeVarEraser{ erase_id: none, replacement: target_type })!
}

// TypeVarEraser implements type erasure for type variables.
pub struct TypeVarEraser {
pub mut:
	erase_id    ?[]TypeVarId
	replacement Type
}

pub fn (mut e TypeVarEraser) visit_type_var(t &TypeVarType) !Type {
	if e.erase_id == none || e.erase_id!.any(it == t.id) {
		return e.replacement
	}
	return t
}

pub fn (mut e TypeVarEraser) visit_instance(t &Instance) !Type {
	mut args := []Type{}
	for arg in t.args {
		args << arg.accept(e)!
	}
	result := t.copy_modified(args: args)
	if t.type_info.fullname == 'builtins.tuple' {
		// Normalize Tuple[*Tuple[X, ...], ...] -> Tuple[X, ...]
		arg := result.args[0]
		if arg is UnpackType {
			unpacked := get_proper_type((arg as UnpackType).type)
			if unpacked is Instance {
				inst := unpacked as Instance
				if inst.type_info.fullname == 'builtins.tuple' {
					return inst
				}
			}
		}
	}
	return result
}

pub fn (mut e TypeVarEraser) visit_tuple_type(t &TupleType) !Type {
	mut items := []Type{}
	for item in t.items {
		items << item.accept(e)!
	}
	result := t.copy_modified(items: items)
	if result.items.len == 1 {
		// Normalize Tuple[*Tuple[X, ...]] -> Tuple[X, ...]
		item := result.items[0]
		if item is UnpackType {
			unpacked := get_proper_type((item as UnpackType).type)
			if unpacked is Instance {
				inst := unpacked as Instance
				if inst.type_info.fullname == 'builtins.tuple' {
					if result.partial_fallback.type_info.fullname != 'builtins.tuple' {
						// If it is a subtype (like named tuple) we need to preserve it,
						// this essentially mimics the logic in tuple_fallback().
						return result.partial_fallback.accept(e)!
					}
					return inst
				}
			}
		}
	}
	return result
}

pub fn (mut e TypeVarEraser) visit_callable_type(t &CallableType) !Type {
	mut arg_types := []Type{}
	for arg in t.arg_types {
		arg_types << arg.accept(e)!
	}
	result := t.copy_modified(arg_types: arg_types)
	// Usually this is done in semanal_typeargs.py, but erasure can create
	// a non-normal callable from normal one.
	result.normalize_trivial_unpack()
	return result
}

pub fn (mut e TypeVarEraser) visit_type_var_tuple(t &TypeVarTupleType) !Type {
	if e.erase_id == none || e.erase_id!.any(it == t.id) {
		return t.tuple_fallback.copy_modified(args: [e.replacement])
	}
	return t
}

pub fn (mut e TypeVarEraser) visit_param_spec(t &ParamSpecType) !Type {
	// TODO: we should probably preserve prefix here.
	if e.erase_id == none || e.erase_id!.any(it == t.id) {
		return e.replacement
	}
	return t
}

pub fn (mut e TypeVarEraser) visit_type_alias_type(t &TypeAliasType) !Type {
	// Type alias target can't contain bound type variables (not bound by the type
	// alias itself), so it is safe to just erase the arguments.
	mut args := []Type{}
	for a in t.args {
		args << a.accept(e)!
	}
	return t.copy_modified(args: args)
}

// remove_instance_last_known_values removes Literal[...] types from Instance types.
pub fn remove_instance_last_known_values(t Type) Type {
	return t.accept(LastKnownValueEraser{})!
}

// LastKnownValueEraser removes Literal[...] types from Instance types.
pub struct LastKnownValueEraser {}

pub fn (e LastKnownValueEraser) visit_instance(t &Instance) !Type {
	if t.last_known_value == none && t.args.len == 0 {
		return t
	}
	mut args := []Type{}
	for a in t.args {
		args << a.accept(e)!
	}
	return t.copy_modified(args: args, last_known_value: none)
}

pub fn (e LastKnownValueEraser) visit_type_alias_type(t &TypeAliasType) !Type {
	// Type aliases can't contain literal values, because they are
	// always constructed as explicit types.
	return t
}

pub fn (e LastKnownValueEraser) visit_union_type(t &UnionType) !Type {
	mut new_items := []Type{}
	for item in t.items {
		new_items << item.accept(e)!
	}
	// Erasure can result in many duplicate items; merge them.
	// Call make_simplified_union only on lists of instance types
	// that all have the same fullname, to avoid simplifying too much.
	mut instances := []Instance{}
	for item in new_items {
		p_item := get_proper_type(item)
		if p_item is Instance {
			instances << (p_item as Instance)
		}
	}
	// Avoid merge in simple cases such as optional types.
	if instances.len > 1 {
		mut instances_by_name := map[string][]Instance{}
		p_new_items := get_proper_types(new_items)
		for p_item in p_new_items {
			if p_item is Instance {
				inst := p_item as Instance
				if inst.args.len == 0 {
					if inst.type_info.fullname !in instances_by_name {
						instances_by_name[inst.type_info.fullname] = []Instance{}
					}
					instances_by_name[inst.type_info.fullname] << inst
				}
			}
		}
		mut merged := []Type{}
		for item in new_items {
			orig_item := item
			p_item := get_proper_type(item)
			if p_item is Instance {
				inst := p_item as Instance
				if inst.args.len == 0 {
					types := instances_by_name[inst.type_info.fullname]
					if types.len == 1 {
						merged << inst
					} else if types.len > 1 {
						merged << make_simplified_union(types)
						instances_by_name.delete(inst.type_info.fullname)
					}
				} else {
					merged << orig_item
				}
			} else {
				merged << orig_item
			}
		}
		return UnionType.make_union(merged)
	}
	return UnionType(new_items)
}

// shallow_erase_type_for_equality erases type variables from Instance's for equality comparison.
pub fn shallow_erase_type_for_equality(typ Type) ProperType {
	p_typ := get_proper_type(typ)
	if p_typ is Instance {
		inst := p_typ as Instance
		if inst.args.len == 0 {
			return inst
		}
		args := erased_vars(inst.type_info.defn.type_vars, type_of_any_special_form)
		return Instance{
			base:      TypeBase{}
			type_info: inst.type_info
			args:      args
			line:      inst.line
		}
	}
	if p_typ is UnionType {
		mut items := []Type{}
		for item in p_typ.items {
			items << shallow_erase_type_for_equality(item)
		}
		return UnionType.make_union(items)
	}
	return p_typ
}
