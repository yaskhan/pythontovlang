// Я Cline работаю над этим файлом. Начало: 2026-03-22 03:05
// copytype.v — Shallow copy of mypy types
// Переведён из mypy/copytype.py
//
// ---------------------------------------------------------------------------

module mypy

// copy_type — create a shallow copy of a type
pub fn copy_type(t MypyTypeNode) !MypyTypeNode {
	return type_shallow_copy(t)
}

// type_shallow_copy выполняет поверхностное копирование типа
pub fn type_shallow_copy(t MypyTypeNode) !MypyTypeNode {
	return match t {
		AnyType {
			MypyTypeNode(AnyType{
				type_of_any: t.type_of_any
				source_any:  t.source_any
				line:        t.line
				column:      t.column
			})
		}
		NoneType {
			MypyTypeNode(NoneType{
				line:   t.line
				column: t.column
			})
		}
		Instance {
			MypyTypeNode(Instance{
				type_:  t.type_
				args:   t.args.clone()
				line:   t.line
				column: t.column
			})
		}
		CallableType {
			MypyTypeNode(CallableType{
				arg_types: t.arg_types.clone()
				arg_kinds: t.arg_kinds.clone()
				arg_names: t.arg_names.clone()
				ret_type:  t.ret_type
				fallback:  t.fallback
				name:      t.name
				line:      t.line
				column:    t.column
			})
		}
		else {
			t
		}
	}
}
