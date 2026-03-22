// Я Cline работаю над этим файлом. Начало: 2026-03-22 15:20
// subtypes.v — Subtype checking for mypy types
// Переведён из mypy/subtypes.py

module mypy

// Флаги для обнаруженных членов протокола
pub const is_settable = 1
pub const is_classvar = 2
pub const is_class_or_static = 3
pub const is_var = 4
pub const is_explicit_setter = 5

// SubtypeContext — контекст проверки подтипов
pub struct SubtypeContext {
pub:
	ignore_type_params       bool
	ignore_pos_arg_names     bool
	ignore_declared_variance bool
	always_covariant         bool
	ignore_promotions        bool
	erase_instances          bool
	keep_erased_types        bool
	options                  ?Options
}

// new_subtype_context создаёт новый SubtypeContext
pub fn new_subtype_context(ignore_type_params bool, ignore_pos_arg_names bool, ignore_declared_variance bool, always_covariant bool, ignore_promotions bool, erase_instances bool, keep_erased_types bool, options ?Options) SubtypeContext {
	return SubtypeContext{
		ignore_type_params:       ignore_type_params
		ignore_pos_arg_names:     ignore_pos_arg_names
		ignore_declared_variance: ignore_declared_variance
		always_covariant:         always_covariant
		ignore_promotions:        ignore_promotions
		erase_instances:          erase_instances
		keep_erased_types:        keep_erased_types
		options:                  options
	}
}

// is_subtype проверяет, является ли left подтипом right
// Также считает Any подтипом любого типа и наоборот
pub fn is_subtype(left MypyTypeNode, right MypyTypeNode, subtype_context SubtypeContext) bool {
	if left.str() == right.str() {
		return true
	}
	// TODO: полная реализация с SubtypeVisitor
	return is_subtype_internal(left, right, subtype_context)
}

// is_subtype_internal — внутренняя реализация проверки подтипов
fn is_subtype_internal(left MypyTypeNode, right MypyTypeNode, ctx SubtypeContext) bool {
	left_proper := get_proper_type(left)
	right_proper := get_proper_type(right)

	// AnyType подтип любого типа (для non-proper)
	if !ctx.erase_instances && !ctx.keep_erased_types {
		if right_proper is AnyType || right_proper is UnboundType
			|| right_proper is ErasedType {
			if left_proper !is UnpackType {
				return true
			}
		}
	}

	// UnionType проверка
	if right_proper is UnionType && left_proper !is UnionType {
		for item in right_proper.items {
			if is_subtype(left, item, ctx) {
				return true
			}
		}
		return false
	}

	// Instance -> Instance
	if left_proper is Instance && right_proper is Instance {
		return is_instance_subtype(left_proper, right_proper, ctx)
	}

	// NoneType
	if left_proper is NoneType {
		if right_proper is NoneType || is_named_instance(right_proper, 'builtins.object') {
			return true
		}
		return false
	}

	// AnyType
	if left_proper is AnyType {
		return !ctx.erase_instances
	}

	// UninhabitedType (Never) — подтип всего
	if left_proper is UninhabitedType {
		return true
	}

	// TypeVarType
	if left_proper is TypeVarType && right_proper is TypeVarType {
		if left_proper.id == right_proper.id {
			return true
		}
		return is_subtype(left_proper.upper_bound, right, ctx)
	}

	// CallableType
	if left_proper is CallableType && right_proper is CallableType {
		return is_callable_subtype(left_proper, right_proper, ctx)
	}

	// TupleType
	if left_proper is TupleType && right_proper is TupleType {
		if left_proper.items.len != right_proper.items.len {
			return false
		}
		for i in 0 .. left_proper.items.len {
			if !is_subtype(left_proper.items[i], right_proper.items[i], ctx) {
				return false
			}
		}
		return true
	}

	// TypedDictType
	if left_proper is TypedDictType && right_proper is TypedDictType {
		return is_typeddict_subtype(left_proper, right_proper, ctx)
	}

	return false
}

// is_instance_subtype проверяет подтип для Instance
fn is_instance_subtype(left Instance, right Instance, ctx SubtypeContext) bool {
	// Проверяем кэш
	if type_state.is_cached_subtype(left, right) {
		return true
	}
	if type_state.is_cached_negative_subtype(left, right) {
		return false
	}

	// Промоушны
	if !ctx.ignore_promotions && !right.typ.is_protocol {
		for base in left.typ.mro {
			if base._promote.len > 0 {
				for p in base._promote {
					if is_subtype(p, right, ctx) {
						type_state.record_subtype_cache(left, right)
						return true
					}
				}
			}
		}
	}

	// Номинальная проверка
	rname := (right.typ or { return "" }).fullname
	if (left.typ or { return false }).has_base(rname) || rname == 'builtins.object' {
		mapped := map_instance_to_supertype(left, right.typ)

		// Проверка аргументов типов
		if !ctx.ignore_type_params {
			for i, tvar in (right.typ or { return false }).defn.type_vars {
				if i >= mapped.args.len || i >= right.args.len {
					continue
				}
				left_arg := mapped.args[i]
				right_arg := right.args[i]

				if tvar is TypeVarType {
					variance := tvar.variance
					if ctx.always_covariant && variance == 0 {
						variance = 1 // COVARIANT
					}
					if !check_type_parameter(left_arg, right_arg, variance, ctx) {
						type_state.record_negative_subtype_cache(left, right)
						return false
					}
				}
			}
		}

		type_state.record_subtype_cache(left, right)
		return true
	}

	// Протоколы
	if right.typ.is_protocol {
		if is_protocol_implementation(left, right, ctx) {
			return true
		}
	}

	type_state.record_negative_subtype_cache(left, right)
	return false
}

// check_type_parameter проверяет параметр типа с учётом variance
fn check_type_parameter(left MypyTypeNode, right MypyTypeNode, variance int, ctx SubtypeContext) bool {
	// INVARIANT = 0, COVARIANT = 1, CONTRAVARIANT = -1
	if variance == 1 { // COVARIANT
		return is_subtype(left, right, ctx)
	} else if variance == -1 { // CONTRAVARIANT
		return is_subtype(right, left, ctx)
	} else { // INVARIANT
		return is_subtype(left, right, ctx) && is_subtype(right, left, ctx)
	}
}

// is_callable_subtype проверяет подтип для CallableType
fn is_callable_subtype(left CallableType, right CallableType, ctx SubtypeContext) bool {
	// Проверка возвращаемого типа (ковариантно)
	if !is_subtype(left.ret_type, right.ret_type, ctx) {
		return false
	}

	// Проверка аргументов (контравариантно)
	if left.arg_types.len != right.arg_types.len {
		return false
	}
	for i in 0 .. left.arg_types.len {
		if !is_subtype(right.arg_types[i], left.arg_types[i], ctx) {
			return false
		}
	}

	return true
}

// is_typeddict_subtype проверяет подтип для TypedDictType
fn is_typeddict_subtype(left TypedDictType, right TypedDictType, ctx SubtypeContext) bool {
	// Проверяем что left содержит все ключи right
	for key in right.items.keys() {
		if key !in left.items {
			return false
		}
		left_type := left.items[key]
		right_type := right.items[key]

		// Required vs NotRequired проверка
		left_required := key in left.required_keys
		right_required := key in right.required_keys
		if !right_required && left_required {
			return false
		}

		// Readonly проверка
		left_readonly := key in left.readonly_keys
		right_readonly := key in right.readonly_keys
		if !right_readonly && left_readonly {
			return false
		}

		// Типы должны быть совместимы
		if right_readonly {
			if !is_subtype(left_type, right_type, ctx) {
				return false
			}
		} else {
			if !is_subtype(left_type, right_type, ctx) || !is_subtype(right_type, left_type, ctx) {
				return false
			}
		}
	}
	return true
}

pub fn is_protocol_implementation(left Instance, right Instance, ctx SubtypeContext) bool {
	right_info := right.typ or { return false }
	left_info := left.typ or { return false }
	
	for name, sym in right_info.names.symbols {
		if name.starts_with('__') && name.ends_with('__') && name !in ['__call__', '__iter__'] {
			continue
		}
		
		left_sym := left_info.names.symbols[name] or {
			return false
		}
		
		// TODO: Проверка совместимости типов членов протокола.
		// Пока только проверка наличия.
	}
	
	return true
}

// is_proper_subtype проверяет proper subtype
pub fn is_proper_subtype(left MypyTypeNode, right MypyTypeNode, ctx SubtypeContext) bool {
	// TODO: реализация proper subtype проверки
	return is_subtype(left, right, ctx)
}

// is_equivalent проверяет эквивалентность типов
pub fn is_equivalent(a MypyTypeNode, b MypyTypeNode, ctx SubtypeContext) bool {
	return is_subtype(a, b, ctx) && is_subtype(b, a, ctx)
}

// is_same_type проверяет, являются ли типы одинаковыми
pub fn is_same_type(a MypyTypeNode, b MypyTypeNode, ctx SubtypeContext) bool {
	return is_proper_subtype(a, b, ctx) && is_proper_subtype(b, a, ctx)
}

// is_named_instance проверяет, является ли тип именованным экземпляром
fn is_named_instance(typ MypyTypeNode, fullname string) bool {
	if typ is Instance {
		return typ.typ.fullname == fullname
	}
	return false
}

// get_proper_type возвращает proper type


// map_instance_to_supertype маппит Instance к супертипу
fn map_instance_to_supertype(inst Instance, supertype TypeInfo) Instance {
	// TODO: реализация из maptype.v
	return inst
}

// Вспомогательные функции для работы с типами
fn erase_type(t MypyTypeNode) MypyTypeNode {
	// TODO: реализация из erasetype.v
	return t
}

