// Work in progress by Cline. Started: 2026-03-22 03:05
// copytype.v — Shallow copy of mypy types
// Translated from mypy/copytype.py
//
// ---------------------------------------------------------------------------

module mypy

// copy_type — create a shallow copy of a type
pub fn copy_type(t MypyTypeNode) !MypyTypeNode {
	return type_shallow_copy(t)
}

// type_shallow_copy performs a shallow copy of a type
pub fn type_shallow_copy(t MypyTypeNode) !MypyTypeNode {
	return match t {
		AnyType {
			MypyTypeNode(AnyType{
				type_of_any: t.type_of_any
				line:        t.line
			})
		}
		NoneType {
			MypyTypeNode(NoneType{
				line:   t.line
			})
		}
		Instance {
			info := if ti := t.type_ { ?&TypeInfo(ti) } else if ti := t.typ { ?&TypeInfo(ti) } else { none }
			MypyTypeNode(Instance{
				typ:       info
				type_:     info
				args:      t.args.clone()
				line:      t.line
				type_name: t.type_name
			})
		}
		CallableType {
			MypyTypeNode(CallableType{
				arg_types: t.arg_types.clone()
				arg_kinds: t.arg_kinds.clone()
				arg_names: t.arg_names.clone()
				ret_type:  t.ret_type
				fallback:  t.fallback
				variables: t.variables.clone()
				line:      t.line
			})
		}
		else {
			t
		}
	}
}
