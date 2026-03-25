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
		return MypyTypeNode(CallableType{
			arg_types:   tp.arg_types.clone()
			arg_kinds:   tp.arg_kinds.clone()
			arg_names:   tp.arg_names.clone()
			ret_type:    tp.ret_type
			variables:   tp.variables.clone()
			line:        tp.line
			fallback:    tp.fallback
			name:        ''
			fullname:    tp.fullname
			is_var_arg:  tp.is_var_arg
			is_ellipsis: tp.is_ellipsis
			min_args:    tp.min_args
			is_type_obj: tp.is_type_obj
		})
	} else if tp is Overloaded {
		mut items := []&CallableType{}
		for item in tp.items {
			items << item
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
	if tp !is UnionType && tp !is TupleType {
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
				if is_invalid_recursive_alias(seen_nodes, (item as UnpackType).@type) {
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
		for typ in flatten_union_list(tp.items) {
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
pub fn is_union_with_any(tp_arg MypyTypeNode) bool {
	mut tp := get_proper_type(tp_arg)
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
pub fn is_generic_instance(tp_arg MypyTypeNode) bool {
	mut tp := get_proper_type(tp_arg)
	return tp is Instance && (tp as Instance).args.len > 0
}

// is_overlapping_none checks if a type can be None
pub fn is_overlapping_none(t MypyTypeNode) bool {
	tp := get_proper_type(t)
	if tp is NoneType {
		return true
	}
	if tp is UnionType {
		for e in (tp as UnionType).items {
			if get_proper_type(e) is NoneType {
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
		for t in (tp as UnionType).items {
			if get_proper_type(t) !is NoneType {
				items << t
			}
		}
		return make_union(items)
	} else if tp is NoneType {
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
	mut target_arg_type := typ.arg_types[i]
	if typ.arg_kinds[i] == ArgKind.arg_star {
		if target_arg_type is ParamSpecType {
			// Do nothing
		} else if target_arg_type is UnpackType {
			unpacked := get_proper_type((target_arg_type as UnpackType).@type)
			if unpacked is TupleType {
				target_arg_type = MypyTypeNode(unpacked)
			} else if unpacked is Instance && (unpacked as Instance).type_name == 'builtins.tuple' {
				target_arg_type = MypyTypeNode(unpacked)
			} else {
				fb := named_type('builtins.tuple', [
					MypyTypeNode(named_type('builtins.object', [])),
				])
				target_arg_type = MypyTypeNode(TupleType{
					items:            [target_arg_type]
					partial_fallback: &fb
				})
			}
		} else {
			target_arg_type = MypyTypeNode(named_type('builtins.tuple', [
				target_arg_type,
			]))
		}
	} else if typ.arg_kinds[i] == ArgKind.arg_star2 {
		if target_arg_type !is ParamSpecType {
			target_arg_type = MypyTypeNode(named_type('builtins.dict', [
				MypyTypeNode(named_type('builtins.str', [])),
				target_arg_type,
			]))
		}
	}
	if defn is FuncDef {
		mut d := defn as FuncDef
		d.arguments[i].variable.type_ = target_arg_type
	}
}

// Helper stub functions
fn get_proper_type(t MypyTypeNode) MypyTypeNode {
	// Delegate to types module
	return get_proper_type(t)
}

fn get_proper_types(types []MypyTypeNode) []MypyTypeNode {
	return types.map(get_proper_type(it))
}

fn flatten_union_list(items []MypyTypeNode) []MypyTypeNode {
	mut result := []MypyTypeNode{}
	for item in items {
		tp := get_proper_type(item)
		if tp is UnionType {
			result << flatten_union_list(tp.items)
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
