// maptype.v — Mapping instance types to supertypes
module mypy

// map_instance_to_supertype produces a supertype of `instance` that is an Instance
// of `superclass`, mapping type arguments up the chain of bases.
pub fn map_instance_to_supertype(instance Instance, superclass TypeInfo) Instance {
	// Fast path: `instance` already belongs to `superclass`.
	if instance.type_name == superclass.fullname {
		return instance
	}

	// Fast path: `superclass` has no type variables to map to.
	if superclass.type_vars.len == 0 {
		return Instance{
			type_name: superclass.fullname
			args:      []
		}
	}

	res := map_instance_to_supertypes(instance, superclass)
	if res.len > 0 {
		return res[0]
	}
	return Instance{
		type_name: superclass.fullname
		args:      []
	}
}

// map_instance_to_supertypes maps an instance to all possible supertypes
pub fn map_instance_to_supertypes(instance Instance, supertype TypeInfo) []Instance {
	mut result := []Instance{}

	if info := instance.typ {
		paths := class_derivation_paths(*info, supertype)
		for path in paths {
			mut types := [instance]
			for sup in path {
				mut a := []Instance{}
				for t in types {
					a << map_instance_to_direct_supertypes(t, sup)
				}
				types = a.clone()
			}
			result << types
		}
	}

	if result.len > 0 {
		return result
	} else {
		// Nothing. Presumably due to an error. Construct a dummy using Any.
		any_type := AnyType{
			type_of_any: TypeOfAny.from_error
		}
		mut args := []MypyTypeNode{}
		for _ in supertype.type_vars {
			args << MypyTypeNode(any_type)
		}
		return [Instance{
			type_name:  supertype.fullname
			args:       args
			typ:        supertype
		}]
	}
}

pub fn class_derivation_paths(typ TypeInfo, supertype TypeInfo) [][]TypeInfo {
	mut result := [][]TypeInfo{}

	for b in typ.bases {
		if b.type_name == supertype.fullname {
			result << [supertype]
		} else {
			if b_info := b.typ {
				for path in class_derivation_paths(*b_info, supertype) {
					mut new_path := [supertype] // Simplified for now
					new_path << path
					result << new_path
				}
			}
		}
	}

	return result
}

pub fn map_instance_to_direct_supertypes(instance Instance, supertype TypeInfo) []Instance {
	mut result := []Instance{}

	if typ := instance.typ {
		for b in typ.bases {
			if b.type_name == supertype.fullname {
				result << Instance{
					type_name: supertype.fullname
					args:      b.args
					typ:       &supertype
				}
			}
		}
	}

	if result.len > 0 {
		return result
	} else {
		any_type := AnyType{
			type_of_any: TypeOfAny.unannotated
		}
		mut args := []MypyTypeNode{}
		for _ in supertype.type_vars {
			args << MypyTypeNode(any_type)
		}
		return [Instance{
			type_name: supertype.fullname
			args:      args
			typ:       &supertype
		}]
	}
}
