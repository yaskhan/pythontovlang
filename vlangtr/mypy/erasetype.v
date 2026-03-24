// I, Codex, am working on this file. Started: 2026-03-22 22:35
// erasetype.v — Type erasure transformation

module mypy

pub fn erase_type(typ MypyTypeNode) MypyTypeNode {
	proper := get_proper_type(typ)
	return match proper {
		AnyType, NoneType, UninhabitedType, ErasedType, DeletedType, PlaceholderType, EllipsisType,
		RawExpressionType, CallableArgument, ParametersType, TypeList, TypedDictType {
			proper
		}
		UnboundType, TypeVarType, ParamSpecType, TypeVarTupleType, TypeAliasType, UnpackType {
			MypyTypeNode(AnyType{
				type_of_any: .special_form
			})
		}
		PartialTypeT {
			MypyTypeNode(AnyType{
				type_of_any: .from_error
			})
		}
		Instance {
			mut args := []MypyTypeNode{}
			for _ in 0 .. proper.args.len {
				args << MypyTypeNode(AnyType{
					type_of_any: .special_form
				})
			}
			mut info := ?&TypeInfo(none)
			if ti := proper.type_ {
				info = ti
			} else if ti := proper.typ {
				info = ti
			}
			MypyTypeNode(Instance{
				typ:              info
				type_:            info
				args:             args
				last_known_value: none
				line:             proper.line
				type_ref:         proper.type_ref
				type_name:        proper.type_name
			})
		}
		CallableType {
			any_t := MypyTypeNode(AnyType{
				type_of_any: .special_form
			})
			arg_types := [any_t, any_t]
			arg_kinds := [ArgKind.arg_star, ArgKind.arg_star2]
			arg_names := [?string(none), ?string(none)]
			MypyTypeNode(CallableType{
				arg_types: arg_types
				arg_kinds: arg_kinds
				arg_names: arg_names
				ret_type:  any_t
				variables: []MypyTypeNode{}
				line:      proper.line
				fallback:  proper.fallback
			})
		}
		Overloaded {
			MypyTypeNode(AnyType{
				type_of_any: .special_form
			})
		}
		TupleType {
			if fb := proper.partial_fallback {
				erase_type(*fb)
			} else {
				MypyTypeNode(AnyType{
					type_of_any: .special_form
				})
			}
		}
		LiteralType {
			erase_type(proper.fallback)
		}
		UnionType {
			mut items := []MypyTypeNode{}
			for item in proper.items {
				items << erase_type(item)
			}
			MypyTypeNode(UnionType{
				items: items
				line:  proper.line
			})
		}
		TypeType {
			MypyTypeNode(TypeType{
				item: erase_type(proper.item)
				line: proper.line
			})
		}
	}
}
