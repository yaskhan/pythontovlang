// I, Codex, am working on this file. Started: 2026-03-22 21:34:00
module mypy

pub const any_strategy = 0
pub const all_strategy = 1

pub struct TypeTranslator {
pub mut:
	cache map[string]MypyTypeNode
}

pub fn new_type_translator() TypeTranslator {
	return TypeTranslator{
		cache: map[string]MypyTypeNode{}
	}
}

pub fn (tt &TypeTranslator) get_cached(key string) ?MypyTypeNode {
	if key in tt.cache {
		return tt.cache[key]
	}
	return none
}

pub fn (mut tt TypeTranslator) set_cached(key string, value MypyTypeNode) {
	tt.cache[key] = value
}

pub fn (mut tt TypeTranslator) translate_type(t MypyTypeNode) MypyTypeNode {
	return match t {
		UnboundType {
			MypyTypeNode(t)
		}
		AnyType {
			MypyTypeNode(t)
		}
		NoneType {
			MypyTypeNode(t)
		}
		UninhabitedType {
			MypyTypeNode(t)
		}
		ErasedType {
			MypyTypeNode(t)
		}
		DeletedType {
			MypyTypeNode(t)
		}
		TypeVarType {
			MypyTypeNode(t)
		}
		ParamSpecType {
			MypyTypeNode(t)
		}
		ParametersType {
			MypyTypeNode(tt.visit_parameters(t))
		}
		TypeVarTupleType {
			MypyTypeNode(t)
		}
		Instance {
			MypyTypeNode(tt.visit_instance(t))
		}
		CallableType {
			MypyTypeNode(tt.visit_callable_type(t))
		}
		Overloaded {
			MypyTypeNode(tt.visit_overloaded(t))
		}
		TupleType {
			MypyTypeNode(tt.visit_tuple_type(t))
		}
		TypedDictType {
			MypyTypeNode(tt.visit_typeddict_type(t))
		}
		LiteralType {
			MypyTypeNode(tt.visit_literal_type(t))
		}
		UnionType {
			MypyTypeNode(tt.visit_union_type(t))
		}
		PartialTypeT {
			MypyTypeNode(t)
		}
		TypeType {
			MypyTypeNode(tt.visit_type_type(t))
		}
		TypeAliasType {
			MypyTypeNode(tt.visit_type_alias_type(t))
		}
		UnpackType {
			MypyTypeNode(tt.visit_unpack_type(t))
		}
		TypeList {
			MypyTypeNode(TypeList{
				items: tt.translate_type_list(t.items)
			})
		}
		CallableArgument {
			MypyTypeNode(t)
		}
		EllipsisType {
			MypyTypeNode(t)
		}
		RawExpressionType {
			MypyTypeNode(t)
		}
		PlaceholderType {
			MypyTypeNode(t)
		}
	}
}

pub fn (mut tt TypeTranslator) translate_type_list(types []MypyTypeNode) []MypyTypeNode {
	mut out := []MypyTypeNode{}
	for typ in types {
		out << tt.translate_type(typ)
	}
	return out
}

pub fn (mut tt TypeTranslator) visit_instance(t Instance) Instance {
	mut last_known_value := t.last_known_value
	if value := t.last_known_value {
		translated := tt.translate_type(MypyTypeNode(value))
		last_known_value = match translated {
			LiteralType { &translated }
			else { value }
		}
	}
	return Instance{
		type_:            t.type_
		args:             tt.translate_type_list(t.args)
		last_known_value: last_known_value
		line:             t.line
		type_ref:         t.type_ref
	}
}

pub fn (mut tt TypeTranslator) visit_parameters(t ParametersType) ParametersType {
	return ParametersType{
		arg_types: tt.translate_type_list(t.arg_types)
		arg_kinds: t.arg_kinds.clone()
		arg_names: t.arg_names.clone()
	}
}

pub fn (mut tt TypeTranslator) visit_unpack_type(t UnpackType) UnpackType {
	return UnpackType{
		type: tt.translate_type(t.type)
	}
}

pub fn (mut tt TypeTranslator) visit_callable_type(t CallableType) CallableType {
	return t.copy_modified(tt.translate_type_list(t.arg_types), tt.translate_type(t.ret_type),
		tt.translate_type_list(t.variables))
}

pub fn (mut tt TypeTranslator) visit_tuple_type(t TupleType) TupleType {
	return t.copy_modified(tt.translate_type_list(t.items), t.partial_fallback)
}

pub fn (mut tt TypeTranslator) visit_typeddict_type(t TypedDictType) TypedDictType {
	key := 'typeddict:${t.items.len}:${t.line}'
	if cached := tt.get_cached(key) {
		if typed := cached {
			match typed {
				TypedDictType { return typed }
				else {}
			}
		}
	}
	mut items := map[string]MypyTypeNode{}
	for name, item_type in t.items {
		items[name] = tt.translate_type(item_type)
	}
	result := TypedDictType{
		items:    items
		line:     t.line
		fallback: t.fallback
	}
	tt.set_cached(key, MypyTypeNode(result))
	return result
}

pub fn (mut tt TypeTranslator) visit_literal_type(t LiteralType) LiteralType {
	return LiteralType{
		fallback: tt.translate_type(t.fallback)
		line:     t.line
	}
}

pub fn (mut tt TypeTranslator) visit_union_type(t UnionType) UnionType {
	return UnionType{
		items:  tt.translate_type_list(t.items)
		line:   t.line
		column: t.column
	}
}

pub fn (mut tt TypeTranslator) visit_overloaded(t Overloaded) Overloaded {
	mut items := []&CallableType{}
	for item in t.items {
		translated := tt.translate_type(MypyTypeNode(*item))
		match translated {
			CallableType {
				copy := translated
				items << &copy
			}
			else {}
		}
	}
	return Overloaded{
		items: items
		line:  t.line
	}
}

pub fn (mut tt TypeTranslator) visit_type_type(t TypeType) TypeType {
	return TypeType{
		item:   tt.translate_type(t.item)
		line:   t.line
		column: t.column
	}
}

pub fn (mut tt TypeTranslator) visit_type_alias_type(t TypeAliasType) TypeAliasType {
	return TypeAliasType{
		alias:    t.alias
		args:     tt.translate_type_list(t.args)
		line:     t.line
		type_ref: t.type_ref
	}
}

pub struct TypeQuery {
pub mut:
	skip_alias_target bool
}

pub fn new_type_query() TypeQuery {
	return TypeQuery{}
}

pub fn (q &TypeQuery) strategy(_items []bool) bool {
	return false
}

pub fn (mut q TypeQuery) query_types(types []MypyTypeNode) bool {
	mut items := []bool{}
	for typ in types {
		items << q.query_type(typ)
	}
	return q.strategy(items)
}

pub fn (mut q TypeQuery) query_type(t MypyTypeNode) bool {
	return match t {
		UnboundType {
			q.query_types([]MypyTypeNode{})
		}
		ParametersType {
			q.query_types(t.arg_types)
		}
		Instance {
			q.query_types(t.args)
		}
		CallableType {
			q.query_types(t.arg_types) || q.query_type(t.ret_type)
		}
		TupleType {
			q.query_types(t.items)
		}
		TypedDictType {
			q.query_types(t.items.values())
		}
		UnionType {
			q.query_types(t.items)
		}
		TypeType {
			q.query_type(t.item)
		}
		TypeAliasType {
			if q.skip_alias_target {
				q.query_types(t.args)
			} else {
				q.query_type(get_proper_type(MypyTypeNode(t)))
			}
		}
		UnpackType {
			q.query_type(t.type)
		}
		TypeList {
			q.query_types(t.items)
		}
		else {
			q.strategy([]bool{})
		}
	}
}

pub struct BoolTypeQuery {
pub mut:
	strategy          int
	default           bool
	skip_alias_target bool
}

pub fn new_bool_type_query(strategy int) BoolTypeQuery {
	return BoolTypeQuery{
		strategy: strategy
		default:  strategy != any_strategy
	}
}

pub fn (mut q BoolTypeQuery) reset() {}

pub fn (q &BoolTypeQuery) combine(items []bool) bool {
	if q.strategy == any_strategy {
		for item in items {
			if item {
				return true
			}
		}
		return false
	}
	for item in items {
		if !item {
			return false
		}
	}
	return true
}

pub fn (mut q BoolTypeQuery) query_types(types []MypyTypeNode) bool {
	mut items := []bool{}
	for typ in types {
		items << q.query_type(typ)
	}
	return q.combine(items)
}

pub fn (mut q BoolTypeQuery) query_type(t MypyTypeNode) bool {
	return match t {
		UnboundType {
			q.query_types([]MypyTypeNode{})
		}
		TypeVarType {
			q.query_types(t.values) || q.query_type(t.upper_bound)
		}
		ParamSpecType {
			q.query_type(t.upper_bound) || q.query_type(t.default)
		}
		TypeVarTupleType {
			q.query_type(t.upper_bound) || q.query_type(t.default)
		}
		ParametersType {
			q.query_types(t.arg_types)
		}
		Instance {
			q.query_types(t.args)
		}
		CallableType {
			q.query_types(t.arg_types) || q.query_type(t.ret_type)
		}
		TupleType {
			q.query_types(t.items)
		}
		TypedDictType {
			q.query_types(t.items.values())
		}
		UnionType {
			q.query_types(t.items)
		}
		Overloaded {
			mut items := []MypyTypeNode{}
			for item in t.items {
				items << MypyTypeNode(*item)
			}
			q.query_types(items)
		}
		TypeType {
			q.query_type(t.item)
		}
		TypeAliasType {
			if q.skip_alias_target {
				q.query_types(t.args)
			} else {
				q.query_type(get_proper_type(MypyTypeNode(t)))
			}
		}
		UnpackType {
			q.query_type(t.type)
		}
		TypeList {
			q.query_types(t.items)
		}
		else {
			q.default
		}
	}
}
