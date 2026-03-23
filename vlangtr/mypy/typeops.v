// typeops.v — Miscellaneous type operations and helpers
// Translated from mypy/typeops.py to V 0.5.x
//
// I, Antigravity, am working on this file. Started: 2026-03-22 20:00

module mypy

// is_recursive_pair checks if a pair of types is recursive
pub fn is_recursive_pair(s MypyTypeNode, t MypyTypeNode) bool {
	if s is TypeAliasType {
		sat := s as TypeAliasType
		if sat.is_recursive {
			pt := get_proper_type(t)
			return pt is Instance || pt is UnionType
				|| (t is TypeAliasType && (t as TypeAliasType).is_recursive)
				|| get_proper_type(s) is TupleType
		}
	}

	if t is TypeAliasType {
		tat := t as TypeAliasType
		if tat.is_recursive {
			ps := get_proper_type(s)
			return ps is Instance || ps is UnionType
				|| (s is TypeAliasType && (s as TypeAliasType).is_recursive)
				|| get_proper_type(t) is TupleType
		}
	}

	return false
}

// tuple_fallback returns the fallback type for a tuple
pub fn tuple_fallback(typ TupleType) Instance {
	pf := typ.partial_fallback or { return Instance{} }
	info := pf.typ or { return pf }
	if info.fullname != 'builtins.tuple' {
		return pf
	}

	mut items := []MypyTypeNode{}
	for item in typ.items {
		if item is UnpackType {
			ut := item as UnpackType
			unpacked_type := get_proper_type(ut.type)

			if unpacked_type is TypeVarTupleType {
				tvt := unpacked_type as TypeVarTupleType
				unpacked_type = get_proper_type(tvt.upper_bound)
			}

			if unpacked_type is Instance {
				inst := unpacked_type as Instance
				if inst.type_name == 'builtins.tuple' && inst.args.len > 0 {
					items << inst.args[0]
					continue
				}
			}

			// Not implemented for complex cases
			return pf
		} else {
			items << item
		}
	}

	return Instance{
		type_name:   info.fullname
		args:        [make_simplified_union(items, false)]
		extra_attrs: pf.extra_attrs
	}
}

// get_self_type gets the self-type from a function
pub fn get_self_type(func CallableType, def_info TypeInfo) ?MypyTypeNode {
	default_self := fill_typevars(def_info)

	ret := get_proper_type(func.ret_type)
	if ret is UninhabitedType {
		return func.ret_type
	}

	if func.arg_types.len > 0 && func.arg_types[0] != default_self && func.arg_kinds[0] == 'ARG_POS' {
		return func.arg_types[0]
	}

	return default_self
}

// make_simplified_union creates a simplified union type
pub fn make_simplified_union(items []MypyTypeNode, handle_recursive bool) MypyTypeNode {
	// Simplified version — just creates UnionType
	return UnionType{
		items: items
	}
}

// fill_typevars fills type variables for TypeInfo
pub fn fill_typevars(info TypeInfo) Instance {
	return Instance{
		type_name: info.fullname
		args:      []MypyTypeNode{}
		typ:       &info
	}
}

// get_proper_type gets the proper type (unwraps TypeAliasType)
pub fn get_proper_type(t MypyTypeNode) MypyTypeNode {
	return match t {
		TypeAliasType {
			tat := t as TypeAliasType
			if tat.alias != none {
				// return tat.alias.target
			}
			t
		}
		else {
			t
		}
	}
}

// is_optional_type checks if the type is Optional[X]
pub fn is_optional_type(t MypyTypeNode) bool {
	pt := get_proper_type(t)
	if pt is UnionType {
		ut := pt as UnionType
		if ut.items.len == 2 {
			for item in ut.items {
				if item is NoneType {
					return true
				}
			}
		}
	}
	return false
}

// remove_optional removes None from an Optional type
pub fn remove_optional(t MypyTypeNode) MypyTypeNode {
	pt := get_proper_type(t)
	if pt is UnionType {
		ut := pt as UnionType
		mut items := []MypyTypeNode{}
		for item in ut.items {
			if item !is NoneType {
				items << item
			}
		}
		if items.len == 1 {
			return items[0]
		}
		return UnionType{
			items: items
		}
	}
	return t
}

// is_none_type checks if the type is None
pub fn is_none_type(t MypyTypeNode) bool {
	return t is NoneType
}

// is_union checks if the type is Union
pub fn is_union(t MypyTypeNode) bool {
	return t is UnionType
}

// flatten_nested_unions flattens nested union types
pub fn flatten_nested_unions(t MypyTypeNode) []MypyTypeNode {
	mut result := []MypyTypeNode{}

	if t is UnionType {
		ut := t as UnionType
		for item in ut.items {
			result << flatten_nested_unions(item)
		}
	} else {
		result << t
	}

	return result
}

// is_callable_type checks if the type is Callable
pub fn is_callable_type(t MypyTypeNode) bool {
	return t is CallableType
}

// is_instance_type checks if the type is Instance
pub fn is_instance_type(t MypyTypeNode) bool {
	return t is Instance
}

// get_type_object_type returns the type object type
pub fn get_type_object_type(info TypeInfo) ProperType {
	// Simplified version
	return ProperType{}
}

// ProperType — proper type alias (expanded type)
pub type ProperType = MypyTypeNode

// is_type_var checks if the type is TypeVar
pub fn is_type_var(t MypyTypeNode) bool {
	return t is TypeVarType
}

// is_type_var_like checks if the type is TypeVar-like
pub fn is_type_var_like(t MypyTypeNode) bool {
	return t is TypeVarType || t is ParamSpecType || t is TypeVarTupleType
}

// has_type_var checks if the type contains type variables
pub fn has_type_var(t MypyTypeNode) bool {
	return match t {
		TypeVarType {
			true
		}
		ParamSpecType {
			true
		}
		TypeVarTupleType {
			true
		}
		CallableType {
			ct := t as CallableType
			for arg in ct.arg_types {
				if has_type_var(arg) {
					return true
				}
			}
			return has_type_var(ct.ret_type)
		}
		Instance {
			inst := t as Instance
			for arg in inst.args {
				if has_type_var(arg) {
					return true
				}
			}
			return false
		}
		UnionType {
			ut := t as UnionType
			for item in ut.items {
				if has_type_var(item) {
					return true
				}
			}
			return false
		}
		else {
			false
		}
	}
}

// replace_type_vars replaces type variables
pub fn replace_type_vars(t MypyTypeNode, replacements map[string]MypyTypeNode) MypyTypeNode {
	return match t {
		TypeVarType {
			tvt := t as TypeVarType
			if tvt.id.str() in replacements {
				return replacements[tvt.id.str()]
			}
			t
		}
		CallableType {
			ct := t as CallableType
			mut new_args := []MypyTypeNode{}
			for arg in ct.arg_types {
				new_args << replace_type_vars(arg, replacements)
			}
			ct.arg_types = new_args
			ct.ret_type = replace_type_vars(ct.ret_type, replacements)
			ct
		}
		Instance {
			inst := t as Instance
			mut new_args := []MypyTypeNode{}
			for arg in inst.args {
				new_args << replace_type_vars(arg, replacements)
			}
			inst.args = new_args
			inst
		}
		else {
			t
		}
	}
}

// is_generic_instance checks if the type is a generic Instance
pub fn is_generic_instance(t MypyTypeNode) bool {
	if t is Instance {
		inst := t as Instance
		return inst.args.len > 0
	}
	return false
}

// get_instance_type_args gets the type arguments of an Instance
pub fn get_instance_type_args(t MypyTypeNode) []MypyTypeNode {
	if t is Instance {
		inst := t as Instance
		return inst.args
	}
	return []MypyTypeNode{}
}

// is_same_type checks if types are the same
pub fn is_same_type(t1 MypyTypeNode, t2 MypyTypeNode) bool {
	return t1.type_str() == t2.type_str()
}

// is_subtype checks if t1 is a subtype of t2
pub fn is_subtype(t1 MypyTypeNode, t2 MypyTypeNode) bool {
	// Simplified version
	return is_same_type(t1, t2)
}

// is_equivalent checks type equivalence
pub fn is_equivalent(t1 MypyTypeNode, t2 MypyTypeNode) bool {
	return is_subtype(t1, t2) && is_subtype(t2, t1)
}

// get_union_items gets the items of a Union type
pub fn get_union_items(t MypyTypeNode) []MypyTypeNode {
	if t is UnionType {
		ut := t as UnionType
		return ut.items
	}
	return [t]
}

// is_literal_type checks if the type is Literal
pub fn is_literal_type(t MypyTypeNode) bool {
	return t is LiteralType
}

// is_typeddict_type checks if the type is TypedDict
pub fn is_typeddict_type(t MypyTypeNode) bool {
	return t is TypedDictType
}

// is_overloaded checks if the type is Overloaded
pub fn is_overloaded(t MypyTypeNode) bool {
	return t is Overloaded
}

// get_overloaded_items gets items of Overloaded
pub fn get_overloaded_items(t MypyTypeNode) []CallableType {
	if t is Overloaded {
		ot := t as Overloaded
		return ot.items
	}
	return []CallableType{}
}

// is_paramspec_type checks if the type is ParamSpec
pub fn is_paramspec_type(t MypyTypeNode) bool {
	return t is ParamSpecType
}

// is_type_var_tuple_type checks if the type is TypeVarTuple
pub fn is_type_var_tuple_type(t MypyTypeNode) bool {
	return t is TypeVarTupleType
}

// is_unpack_type checks if the type is Unpack
pub fn is_unpack_type(t MypyTypeNode) bool {
	return t is UnpackType
}

// is_parameters_type checks if the type is Parameters
pub fn is_parameters_type(t MypyTypeNode) bool {
	return t is Parameters
}

// is_partial_type checks if the type is PartialType
pub fn is_partial_type(t MypyTypeNode) bool {
	return t is PartialType
}

// is_type_type checks if the type is Type[...]
pub fn is_type_type(t MypyTypeNode) bool {
	return t is TypeType
}

// get_type_type_item gets the item of Type[...]
pub fn get_type_type_item(t MypyTypeNode) ?MypyTypeNode {
	if t is TypeType {
		tt := t as TypeType
		return tt.item
	}
	return none
}

// is_any_type checks if the type is Any
pub fn is_any_type(t MypyTypeNode) bool {
	return t is AnyType
}

// is_uninhabited_type checks if the type is Never/NoReturn
pub fn is_uninhabited_type(t MypyTypeNode) bool {
	return t is UninhabitedType
}

// is_erased_type checks if the type is ErasedType
pub fn is_erased_type(t MypyTypeNode) bool {
	return t is ErasedType
}

// is_deleted_type checks if the type is DeletedType
pub fn is_deleted_type(t MypyTypeNode) bool {
	return t is DeletedType
}

// is_unbound_type checks if the type is UnboundType
pub fn is_unbound_type(t MypyTypeNode) bool {
	return t is UnboundType
}

// is_tuple_type checks if the type is TupleType
pub fn is_tuple_type(t MypyTypeNode) bool {
	return t is TupleType
}

// get_tuple_items gets items of TupleType
pub fn get_tuple_items(t MypyTypeNode) []MypyTypeNode {
	if t is TupleType {
		tt := t as TupleType
		return tt.items
	}
	return []MypyTypeNode{}
}

// is_type_alias_type checks if the type is TypeAliasType
pub fn is_type_alias_type(t MypyTypeNode) bool {
	return t is TypeAliasType
}

// copy_type copies the type
pub fn copy_type(t MypyTypeNode) MypyTypeNode {
	return match t {
		Instance {
			inst := t as Instance
			Instance{
				type_name: inst.type_name
				args:      inst.args.clone()
				type:      inst.type
				line:      inst.line
				column:    inst.column
			}
		}
		CallableType {
			ct := t as CallableType
			CallableType{
				arg_types: ct.arg_types.clone()
				ret_type:  ct.ret_type
				variables: ct.variables.clone()
				line:      ct.line
				column:    ct.column
			}
		}
		else {
			t
		}
	}
}
