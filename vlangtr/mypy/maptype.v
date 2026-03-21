// maptype.v — Mapping instance types to supertypes
// Translated from mypy/maptype.py to V 0.5.x
//
// Я Cline работаю над этим файлом. Начало: 2026-03-22 04:43
//
// Translation notes:
//   - map_instance_to_supertype: maps instance to its supertype
//   - map_instance_to_supertypes: maps to multiple supertypes
//   - class_derivation_paths: finds inheritance paths
//   - map_instance_to_direct_supertypes: maps to direct supertypes

module mypy

// ---------------------------------------------------------------------------
// map_instance_to_supertype
// ---------------------------------------------------------------------------

// map_instance_to_supertype produces a supertype of `instance` that is an Instance
// of `superclass`, mapping type arguments up the chain of bases.
//
// If `superclass` is not a nominal superclass of `instance.type`,
// then all type arguments are mapped to 'Any'.
pub fn map_instance_to_supertype(instance Instance, superclass TypeInfo) Instance {
	// Fast path: `instance` already belongs to `superclass`.
	if instance.type_name == superclass.fullname {
		return instance
	}

	// Special case for tuple types
	if superclass.fullname == 'builtins.tuple' {
		// Note: tuple_type handling would require additional logic
		// For now, we skip this special case
	}

	// Fast path: `superclass` has no type variables to map to.
	if superclass.type_vars.len == 0 {
		return Instance{
			type_name: superclass.fullname
			args: []
		}
	}

	return map_instance_to_supertypes(instance, superclass)[0]
}

// ---------------------------------------------------------------------------
// map_instance_to_supertypes
// ---------------------------------------------------------------------------

// map_instance_to_supertypes maps an instance to all possible supertypes
pub fn map_instance_to_supertypes(instance Instance, supertype TypeInfo) []Instance {
	mut result := []Instance{}

	paths := class_derivation_paths(instance.type, supertype)
	for path in paths {
		mut types := [instance]
		for sup in path {
			mut a := []Instance{}
			for t in types {
				a << map_instance_to_direct_supertypes(t, sup)
			}
			types = a
		}
		result << types
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
			type_name: supertype.fullname
			args: args
		}]
	}
}

// ---------------------------------------------------------------------------
// class_derivation_paths
// ---------------------------------------------------------------------------

// class_derivation_paths returns an array of non-empty paths of direct base classes from
// type to supertype. Returns [] if no such path could be found.
//
// Example:
//   InterfaceImplementationPaths(A, B) == [[B]] if A inherits B
//   InterfaceImplementationPaths(A, C) == [[B, C]] if A inherits B and B inherits C
pub fn class_derivation_paths(typ TypeInfo, supertype TypeInfo) [][]TypeInfo {
	mut result := [][]TypeInfo{}

	for base in typ.bases {
		if base.fullname == supertype.fullname {
			result << [TypeInfo{fullname: base.fullname}]
		} else {
			// Try constructing a longer path via the base class.
			for path in class_derivation_paths(TypeInfo{fullname: base.fullname}, supertype) {
				mut new_path := [TypeInfo{fullname: base.fullname}]
				new_path << path
				result << new_path
			}
		}
	}

	return result
}

// ---------------------------------------------------------------------------
// map_instance_to_direct_supertypes
// ---------------------------------------------------------------------------

// map_instance_to_direct_supertypes maps an instance to its direct supertypes
pub fn map_instance_to_direct_supertypes(instance Instance, supertype TypeInfo) []Instance {
	typ := instance.type
	mut result := []Instance{}

	for b in typ.bases {
		if b.fullname == supertype.fullname {
			// In V, we simulate expand_type_by_instance by creating a new instance
			// with the type arguments from the base
			result << Instance{
				type_name: supertype.fullname
				args: b.args
			}
		}
	}

	if result.len > 0 {
		return result
	} else {
		// Relationship with the supertype not specified explicitly. Use dynamic
		// type arguments implicitly.
		any_type := AnyType{
			type_of_any: TypeOfAny.unannotated
		}
		mut args := []MypyTypeNode{}
		for _ in supertype.type_vars {
			args << MypyTypeNode(any_type)
		}
		return [Instance{
			type_name: supertype.fullname
			args: args
		}]
	}
}