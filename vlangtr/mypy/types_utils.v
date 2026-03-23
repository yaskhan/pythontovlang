// I, Cline, am working on this file. Started: 2026-03-22 14:56
// types_utils.v — Basic type operations utilities
// Translated from mypy/types_utils.py
// This module contains basic type operations that don't depend on is_subtype, meet_types, join_types

module mypy

// flatten_types unrolls nested Union types
pub fn flatten_types(types []MypyTypeNode) []MypyTypeNode {
	mut result := []MypyTypeNode{}
	for t in types {
		tp := get_proper_type(t)
		if tp is UnionType {
			result << flatten_types(tp.items)
		} else {
			result << t
		}
	}
	return result
}

// strip_type creates a type copy without debug information (function name)
pub fn strip_type(typ MypyTypeNode) MypyTypeNode {
	orig_typ := typ
	tp := get_proper_type(typ)
	if tp is CallableType {
		return tp.copy_modified(name: '')
	} else if tp is Overloaded {
		mut items := []CallableType{}
		for item in tp.items {
			items << strip_type(item) as CallableType
		}
		return Overloaded{
			items: items
		}
	} else {
		return orig_typ
	}
}

// is_invalid_recursive_alias checks for recursive type aliases like A = Union[int, A]
pub fn is_invalid_recursive_alias(seen_nodes map[string]bool, target MypyTypeNode) bool {
	if target is TypeAliasType {
		alias_key := '${target.alias}'
		if alias_key in seen_nodes {
			return true
		}
		if target.alias == none {
			return false
		}
		mut new_seen := seen_nodes.clone()
		new_seen[alias_key] = true
		return is_invalid_recursive_alias(new_seen, get_proper_type(target))
	}
	tp := target as ProperType
	if tp !in [UnionType, TupleType] {
		return false
	}
	if tp is UnionType {
		for item in tp.items {
			if is_invalid_recursive_alias(seen_nodes, item) {
				return true
			}
		}
		return false
	}
	if tp is TupleType {
		for item in tp.items {
			if item is UnpackType {
				if is_invalid_recursive_alias(seen_nodes, item.typ) {
					return true
				}
			}
		}
	}
	return false
}

// get_bad_type_type_item checks for forbidden types like Type[Type[...]]
pub fn get_bad_type_type_item(item MypyTypeNode) ?string {
	tp := get_proper_type(item)
	if tp is TypeType {
		return 'Type[...]'
	}
	if tp is LiteralType {
		return 'Literal[...]'
	}
	if tp is UnionType {
		mut bad_items := []string{}
		for typ in flatten_nested_unions(tp.items) {
			if bad := get_bad_type_type_item(typ) {
				bad_items << bad
			}
		}
		if bad_items.len == 0 {
			return none
		}
		if bad_items.len == 1 {
			return bad_items[0]
		}
		return 'Union[${bad_items.join(', ')}]'
	}
	return none
}

// is_union_with_any checks if a type is a union with Any or just Any
pub fn is_union_with_any(tp MypyTypeNode) bool {
	tp = get_proper_type(tp)
	if tp is AnyType {
		return true
	}
	if tp !is UnionType {
		return false
	}
	for t in get_proper_types((tp as UnionType).items) {
		if is_union_with_any(t) {
			return true
		}
	}
	return false
}

// is_generic_instance checks if a type is a generic instance
pub fn is_generic_instance(tp MypyTypeNode) bool {
	tp = get_proper_type(tp)
	return tp is Instance && tp.args.len > 0
}

// is_overlapping_none checks if a type can be None
pub fn is_overlapping_none(t MypyTypeNode) bool {
	tp := get_proper_type(t)
	if tp is NoneTypeNode {
		return true
	}
	if tp is UnionType {
		for e in tp.items {
			if get_proper_type(e) is NoneTypeNode {
				return true
			}
		}
	}
	return false
}

// remove_optional removes None from a type
pub fn remove_optional(typ MypyTypeNode) MypyTypeNode {
	tp := get_proper_type(typ)
	if tp is UnionType {
		mut items := []MypyTypeNode{}
		for t in tp.items {
			if get_proper_type(t) !is NoneTypeNode {
				items << t
			}
		}
		return make_union(items)
	} else if tp is NoneTypeNode {
		return UninhabitedType{}
	} else {
		return typ
	}
}

// is_self_type_like checks if a type looks like a self-type annotation
pub fn is_self_type_like(typ MypyTypeNode, is_classmethod bool) bool {
	tp := get_proper_type(typ)
	if !is_classmethod {
		return tp is TypeVarType
	}
	if tp !is TypeType {
		return false
	}
	return (tp as TypeType).item is TypeVarType
}

// store_argument_type stores an argument type in a function definition
pub fn store_argument_type(defn FuncItem, i int, typ CallableType, named_type fn (string, []MypyTypeNode) Instance) {
	mut arg_type := typ.arg_types[i]
	if typ.arg_kinds[i] == ArgKind.star {
		if arg_type is ParamSpecType {
			// Do nothing
		} else if arg_type is UnpackType {
			unpacked := get_proper_type(arg_type.typ)
			if unpacked is TupleType {
				arg_type = unpacked
			} else if unpacked is Instance && unpacked.typ.fullname == 'builtins.tuple' {
				arg_type = unpacked
			} else {
				arg_type = TupleType{
					items:    [arg_type]
					fallback: named_type('builtins.tuple', [
						named_type('builtins.object', []),
					])
				}
			}
		} else {
			arg_type = named_type('builtins.tuple', [arg_type])
		}
	} else if typ.arg_kinds[i] == ArgKind.star2 {
		if arg_type !is ParamSpecType && !typ.unpack_kwargs {
			arg_type = named_type('builtins.dict', [named_type('builtins.str', []), arg_type])
		}
	}
	defn.arguments[i].variable.typ = arg_type
}

// Helper stub functions
fn get_proper_type(t MypyTypeNode) MypyTypeNode {
	// Delegate to types module
	return get_proper_type(t)
}

fn get_proper_types(types []MypyTypeNode) []MypyTypeNode {
	return types.map(get_proper_type(it))
}

fn flatten_nested_unions(items []MypyTypeNode) []MypyTypeNode {
	mut result := []MypyTypeNode{}
	for item in items {
		tp := get_proper_type(item)
		if tp is UnionType {
			result << flatten_nested_unions(tp.items)
		} else {
			result << item
		}
	}
	return result
}

fn make_union(items []MypyTypeNode) MypyTypeNode {
	if items.len == 1 {
		return items[0]
	}
	return UnionType{
		items: items
	}
}
