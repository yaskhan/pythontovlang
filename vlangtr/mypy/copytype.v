// copytype.v — Shallow copy of mypy types
// Translated from mypy/copytype.py to V 0.5.x
//
// Я Cline работаю над этим файлом. Начало: 2026-03-22 04:38
//
// Translation notes:
//   - Python's TypeVisitor[ProperType] → V's TypeVisitor interface
//   - copy_type function creates a shallow copy of a type
//   - TypeShallowCopier implements the visitor pattern
//   - Used to mutate copies with truthiness information

module mypy

// ---------------------------------------------------------------------------
// copy_type — create a shallow copy of a type
// ---------------------------------------------------------------------------

// copy_type creates a shallow copy of a type.
// This can be used to mutate the copy with truthiness information.
// Classes compiled with mypyc don't support copy.copy(), so we need
// a custom implementation.
pub fn copy_type(t MypyTypeNode) !MypyTypeNode {
	return type_shallow_copy(t)
}

// type_shallow_copy dispatches on the sum-type
pub fn type_shallow_copy(t MypyTypeNode) !MypyTypeNode {
	return match t {
		UnboundType {
			// UnboundType is returned as-is
			t
		}
		AnyType {
			mut dup := AnyType{
				type_of_any:         t.type_of_any
				source_any:          t.source_any
				missing_import_name: t.missing_import_name
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		NoneType {
			mut dup := NoneType{}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		UninhabitedType {
			mut dup := UninhabitedType{
				ambiguous: t.ambiguous
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		ErasedType {
			mut dup := ErasedType{}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		DeletedType {
			mut dup := DeletedType{
				source: t.source
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		Instance {
			mut dup := Instance{
				type_name:        t.type_name
				args:             t.args
				last_known_value: t.last_known_value
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		TypeVarType {
			mut dup := TypeVarType{
				name:        t.name
				fullname:    t.fullname
				id:          t.id
				values:      t.values
				upper_bound: t.upper_bound
				default_:    t.default_
				variance:    t.variance
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		ParamSpecType {
			mut dup := ParamSpecType{
				name:        t.name
				fullname:    t.fullname
				id:          t.id
				flavor:      t.flavor
				upper_bound: t.upper_bound
				default_:    t.default_
				prefix:      t.prefix
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		ParametersType {
			mut dup := ParametersType{
				arg_types: t.arg_types
				arg_kinds: t.arg_kinds
				arg_names: t.arg_names
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		TypeVarTupleType {
			mut dup := TypeVarTupleType{
				name:           t.name
				fullname:       t.fullname
				id:             t.id
				upper_bound:    t.upper_bound
				tuple_fallback: t.tuple_fallback
				default_:       t.default_
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		UnpackType {
			mut dup := UnpackType{
				type_: t.type_
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		PartialTypeT {
			mut dup := PartialTypeT{
				type_:      t.type_
				var_:       t.var_
				value_type: t.value_type
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		CallableType {
			mut dup := CallableType{
				arg_types:           t.arg_types
				arg_kinds:           t.arg_kinds
				arg_names:           t.arg_names
				ret_type:            t.ret_type
				name:                t.name
				definition:          t.definition
				variables:           t.variables
				is_ellipsis_args:    t.is_ellipsis_args
				is_classmethod:      t.is_classmethod
				is_staticmethod:     t.is_staticmethod
				is_protocol:         t.is_protocol
				implicit:            t.implicit
				special_sig:         t.special_sig
				from_concatenate:    t.from_concatenate
				imprecise_arg_kinds: t.imprecise_arg_kinds
				unpack_kwargs:       t.unpack_kwargs
				param_spec_id:       t.param_spec_id
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		TupleType {
			mut dup := TupleType{
				items:            t.items
				partial_fallback: t.partial_fallback
				implicit:         t.implicit
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		TypedDictType {
			mut dup := TypedDictType{
				items:         t.items
				required_keys: t.required_keys
				readonly_keys: t.readonly_keys
				fallback:      t.fallback
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		LiteralType {
			mut dup := LiteralType{
				value:    t.value
				fallback: t.fallback
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		UnionType {
			mut dup := UnionType{
				items:              t.items
				uses_pep604_syntax: t.uses_pep604_syntax
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		Overloaded {
			mut dup := Overloaded{
				items: t.items
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		TypeType {
			// Use explicit field assignment since the type annotations in TypeType are imprecise
			mut dup := TypeType{
				item:         t.item
				is_type_form: t.is_type_form
			}
			copy_common(&t.base, &mut dup.base)
			dup
		}
		TypeAliasType {
			panic('TypeShallowCopier: only ProperTypes supported, got TypeAliasType')
		}
		// Synthetic types - not supported
		EllipsisType {
			panic('TypeShallowCopier: only ProperTypes supported, got EllipsisType')
		}
		RawExpressionType {
			panic('TypeShallowCopier: only ProperTypes supported, got RawExpressionType')
		}
		PlaceholderType {
			panic('TypeShallowCopier: only ProperTypes supported, got PlaceholderType')
		}
		TypeList {
			panic('TypeShallowCopier: only ProperTypes supported, got TypeList')
		}
		CallableArgument {
			panic('TypeShallowCopier: only ProperTypes supported, got CallableArgument')
		}
	}
}

// copy_common copies common fields from source to destination
fn copy_common(src &TypeBase, mut dst TypeBase) {
	dst.ctx = src.ctx
	dst._can_be_true = src._can_be_true
	dst._can_be_false = src._can_be_false
}
