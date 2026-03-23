// I, Qwen Code, am working on this file. Started: 2026-03-22 17:00
// Type variables utilities for mypy (typevars.py)

module mypy

// InstanceOrTupleType is a sum type for fill_typevars return type
pub type InstanceOrTupleType = Instance | TupleType

// fill_typevars creates an instance type for a non-generic type.
// For a generic G type with parameters T1, .., Tn, return G[T1, ..., Tn].
pub fn fill_typevars(typ &TypeInfo) InstanceOrTupleType {
	mut tvs := []Type{}
	// TODO: why do we need to keep both typ.type_vars and typ.defn.type_vars?
	for i in 0 .. typ.defn.type_vars.len {
		tv := typ.defn.type_vars[i]
		// Change the line number
		match tv {
			TypeVarType {
				tv = tv.copy_modified(line: -1, column: -1)
				tvs << tv
			}
			TypeVarTupleType {
				unpack := UnpackType(TypeVarTupleType{
					base:           TypeBase{}
					name:           tv.name
					fullname:       tv.fullname
					id:             tv.id
					upper_bound:    tv.upper_bound
					default_:       tv.default
					tuple_fallback: tv.tuple_fallback
					min_len:        tv.min_len
				})
				tvs << unpack
			}
			ParamSpecType {
				ps := ParamSpecType{
					base:        TypeBase{}
					name:        tv.name
					fullname:    tv.fullname
					id:          tv.id
					flavor:      tv.flavor
					upper_bound: tv.upper_bound
					default_:    tv.default
					prefix:      tv.prefix
				}
				tvs << ps
			}
			else {
				panic('Unexpected type var kind')
			}
		}
	}
	inst := Instance{
		base: TypeBase{}
		type: typ
		args: tvs
	}
	// TODO: do we need to also handle typeddict_type here and below?
	if typ.tuple_type == none {
		return inst
	}
	return typ.tuple_type.copy_modified(fallback: inst)
}

// fill_typevars_with_any applies a correct number of Any's as type arguments to a type.
pub fn fill_typevars_with_any(typ &TypeInfo) InstanceOrTupleType {
	inst := Instance{
		base: TypeBase{}
		type: typ
		args: erased_vars(typ.defn.type_vars, type_of_any_special_form)
	}
	if typ.tuple_type == none {
		return inst
	}
	// TODO: implement erase_typevars for TupleType
	return typ.tuple_type.copy_modified(fallback: inst)
}

// has_no_typevars tests if a type contains type variables.
// We test if a type contains type variables by erasing all type variables
// and comparing the result to the original type. We use comparison by equality that
// in turn uses `__eq__` defined for types. Note: we can't use `is_same_type` because
// it is not safe with unresolved forward references, while this function may be called
// before forward references resolution patch pass. Note also that it is not safe to use
// `is` comparison because `erase_typevars` doesn't preserve type identity.
pub fn has_no_typevars(typ Type) bool {
	return typ == erase_typevars(typ)
}
