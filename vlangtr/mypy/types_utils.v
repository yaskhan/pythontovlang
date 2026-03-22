// Я Cline работаю над этим файлом. Начало: 2026-03-22 14:56
// types_utils.v — Basic type operations utilities
// Переведён из mypy/types_utils.py
// Этот модуль содержит базовые операции с типами, не зависящие от is_subtype, meet_types, join_types

module mypy

// flatten_types разворачивает вложенные Union типы
pub fn flatten_types(types []MypyTypeNode) []MypyTypeNode {
	mut result := []MypyTypeNode{}
	for t in types {
		tp := get_proper_type(t)
		if tp is UnionTypeNode {
			result << flatten_types(tp.items)
		} else {
			result << t
		}
	}
	return result
}

// strip_type создаёт копию типа без отладочной информации (имени функции)
pub fn strip_type(typ MypyTypeNode) MypyTypeNode {
	orig_typ := typ
	tp := get_proper_type(typ)
	if tp is CallableTypeNode {
		return tp.copy_modified(name: '')
	} else if tp is OverloadedNode {
		mut items := []CallableTypeNode{}
		for item in tp.items {
			items << strip_type(item) as CallableTypeNode
		}
		return OverloadedNode{
			items: items
		}
	} else {
		return orig_typ
	}
}

// is_invalid_recursive_alias проверяет рекурсивные алиасы типа A = Union[int, A]
pub fn is_invalid_recursive_alias(seen_nodes map[string]bool, target MypyTypeNode) bool {
	if target is TypeAliasTypeNode {
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
	tp := target as ProperTypeNode
	if tp !in [UnionTypeNode, TupleTypeNode] {
		return false
	}
	if tp is UnionTypeNode {
		for item in tp.items {
			if is_invalid_recursive_alias(seen_nodes, item) {
				return true
			}
		}
		return false
	}
	if tp is TupleTypeNode {
		for item in tp.items {
			if item is UnpackTypeNode {
				if is_invalid_recursive_alias(seen_nodes, item.typ) {
					return true
				}
			}
		}
	}
	return false
}

// get_bad_type_type_item проверяет запрещённые типы вида Type[Type[...]]
pub fn get_bad_type_type_item(item MypyTypeNode) ?string {
	tp := get_proper_type(item)
	if tp is TypeTypeNode {
		return 'Type[...]'
	}
	if tp is LiteralTypeNode {
		return 'Literal[...]'
	}
	if tp is UnionTypeNode {
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

// is_union_with_any проверяет, является ли тип объединением с Any или просто Any
pub fn is_union_with_any(tp MypyTypeNode) bool {
	tp = get_proper_type(tp)
	if tp is AnyTypeNode {
		return true
	}
	if tp !is UnionTypeNode {
		return false
	}
	for t in get_proper_types((tp as UnionTypeNode).items) {
		if is_union_with_any(t) {
			return true
		}
	}
	return false
}

// is_generic_instance проверяет, является ли тип обобщённым экземпляром
pub fn is_generic_instance(tp MypyTypeNode) bool {
	tp = get_proper_type(tp)
	return tp is InstanceNode && tp.args.len > 0
}

// is_overlapping_none проверяет, может ли тип быть None
pub fn is_overlapping_none(t MypyTypeNode) bool {
	tp := get_proper_type(t)
	if tp is NoneTypeNode {
		return true
	}
	if tp is UnionTypeNode {
		for e in tp.items {
			if get_proper_type(e) is NoneTypeNode {
				return true
			}
		}
	}
	return false
}

// remove_optional удаляет None из типа
pub fn remove_optional(typ MypyTypeNode) MypyTypeNode {
	tp := get_proper_type(typ)
	if tp is UnionTypeNode {
		mut items := []MypyTypeNode{}
		for t in tp.items {
			if get_proper_type(t) !is NoneTypeNode {
				items << t
			}
		}
		return make_union(items)
	} else if tp is NoneTypeNode {
		return UninhabitedTypeNode{}
	} else {
		return typ
	}
}

// is_self_type_like проверяет, похож ли тип на аннотацию self-type
pub fn is_self_type_like(typ MypyTypeNode, is_classmethod bool) bool {
	tp := get_proper_type(typ)
	if !is_classmethod {
		return tp is TypeVarTypeNode
	}
	if tp !is TypeTypeNode {
		return false
	}
	return (tp as TypeTypeNode).item is TypeVarTypeNode
}

// store_argument_type сохраняет тип аргумента в определении функции
pub fn store_argument_type(defn FuncItem, i int, typ CallableTypeNode, named_type fn (string, []MypyTypeNode) InstanceNode) {
	mut arg_type := typ.arg_types[i]
	if typ.arg_kinds[i] == ArgKind.star {
		if arg_type is ParamSpecTypeNode {
			// Ничего не делаем
		} else if arg_type is UnpackTypeNode {
			unpacked := get_proper_type(arg_type.typ)
			if unpacked is TupleTypeNode {
				arg_type = unpacked
			} else if unpacked is InstanceNode && unpacked.typ.fullname == 'builtins.tuple' {
				arg_type = unpacked
			} else {
				arg_type = TupleTypeNode{
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
		if arg_type !is ParamSpecTypeNode && !typ.unpack_kwargs {
			arg_type = named_type('builtins.dict', [named_type('builtins.str', []), arg_type])
		}
	}
	defn.arguments[i].variable.typ = arg_type
}

// Вспомогательные функции-заглушки
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
		if tp is UnionTypeNode {
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
	return UnionTypeNode{
		items: items
	}
}
