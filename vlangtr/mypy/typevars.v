// Type variables utilities for mypy (typevars.py)

module mypy

// InstanceOrTupleType is a sum type for fill_typevars return type
pub type InstanceOrTupleType = Instance | TupleType

// fill_typevars creates an instance type for a non-generic type.
// For a generic G type with parameters T1, .., Tn, return G[T1, ..., Tn].
pub fn fill_typevars(typ &TypeInfo) InstanceOrTupleType {
	mut tvs := []MypyTypeNode{}
	if defn := typ.defn {
		for tv in defn.type_vars {
			tvs << tv
		}
	}
	inst := Instance{
		typ:   typ
		type_: typ
		args:  tvs
	}
	if tt := typ.tuple_type {
		return tt.copy_modified(tt.items.clone(), &inst)
	}
	return inst
}

// fill_typevars_with_any applies a correct number of Any's as type arguments to a type.
pub fn fill_typevars_with_any(typ &TypeInfo) InstanceOrTupleType {
	mut args := []MypyTypeNode{}
	if defn := typ.defn {
		for _ in defn.type_vars {
			args << MypyTypeNode(AnyType{
				type_of_any: .special_form
			})
		}
	}
	inst := Instance{
		typ:   typ
		type_: typ
		args:  args
	}
	if tt := typ.tuple_type {
		return tt.copy_modified(tt.items.clone(), &inst)
	}
	return inst
}

// has_no_typevars tests if a type contains type variables.
pub fn has_no_typevars(typ Type) bool {
	return typ == erase_typevars(typ)
}
