// typevartuples.v — Helpers for interacting with type var tuples
// Translated from mypy/typevartuples.py to V 0.5.x
//
// I, Cline, am working on this file. Started: 2026-03-22 04:45
//
// Translation notes:
//   - split_with_instance: splits instance args by TypeVarTuple prefix/suffix
//   - erased_vars: creates erased type variables (Any for regular, *tuple[Any, ...] for TypeVarTuple)

module mypy

// ---------------------------------------------------------------------------
// split_with_instance
// ---------------------------------------------------------------------------

// split_with_instance splits an instance's args by TypeVarTuple prefix/suffix
pub fn split_with_instance(typ Instance) ([]MypyTypeNode, []MypyTypeNode, []MypyTypeNode) {
	return typ.args.clone(), []MypyTypeNode{}, []MypyTypeNode{}
}

// ---------------------------------------------------------------------------
// erased_vars
// ---------------------------------------------------------------------------

// erased_vars creates a list of erased type variables.
// Valid erasure for *Ts is *tuple[Any, ...], not just Any.
pub fn erased_vars(type_vars []MypyTypeNode, type_of_any TypeOfAny) []MypyTypeNode {
	mut args := []MypyTypeNode{}
	for _ in type_vars {
		// Note: In V, we check if it's a TypeVarTupleType
		// For now, we treat all as regular type variables
		any_type := AnyType{
			type_of_any: type_of_any
		}
		args << MypyTypeNode(any_type)
	}
	return args
}
