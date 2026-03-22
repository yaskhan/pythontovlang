// Work in progress by Codex. Started: 2026-03-22 21:40:00 +05:00
module mypy

pub fn get_target_type(tvar TypeVarLikeType, typ MypyTypeNode, callable CallableType, context Context, skip_unsatisfied bool) ?MypyTypeNode {
	_ = callable
	_ = context
	p_type := get_proper_type(typ)

	if p_type is UninhabitedType {
		if default_type := type_var_like_default(tvar) {
			return default_type
		}
	}

	match tvar {
		ParamSpecType, TypeVarTupleType {
			return typ
		}
		TypeVarType {
			if tvar.values.len > 0 {
				if p_type is AnyType {
					return typ
				}
				mut matching := []MypyTypeNode{}
				for value in tvar.values {
					if is_subtype(typ, value) {
						matching << value
					}
				}
				if matching.len > 0 {
					return matching[0]
				}
				if skip_unsatisfied {
					return none
				}
				return none
			}

			mut upper_bound := tvar.upper_bound
			if tvar.name == 'Self' {
				upper_bound = erase_typevars(upper_bound)
			}
			if !is_subtype(typ, upper_bound) {
				if skip_unsatisfied {
					return none
				}
				return none
			}
			return typ
		}
	}
}

pub fn apply_generic_arguments(callable CallableType, orig_types []?MypyTypeNode, context Context, skip_unsatisfied bool) CallableType {
	tvars := callable.variables
	assert orig_types.len <= tvars.len

	mut id_to_type := map[TypeVarId]MypyTypeNode{}
	for i, tvar_node in tvars {
		if i >= orig_types.len {
			break
		}
		maybe_typ := orig_types[i]
		typ := maybe_typ or { continue }
		tvar := type_var_like_from_node(tvar_node) or { continue }
		target_type := get_target_type(tvar, typ, callable, context, skip_unsatisfied) or {
			continue
		}
		id := extract_type_var_like_id(tvar) or { continue }
		id_to_type[id] = target_type
	}

	if param_spec := callable_param_spec(callable) {
		if param_spec.id in id_to_type {
			expanded := expand_type(MypyTypeNode(callable), id_to_type)
			if expanded is CallableType {
				return expanded.copy_modified(expanded.arg_types, expanded.ret_type, filter_remaining_type_vars(tvars,
					id_to_type))
			}
		}
	}

	mut new_arg_types := []MypyTypeNode{}
	for arg_typ in callable.arg_types {
		new_arg_types << expand_type(arg_typ, id_to_type)
	}

	ret_type := expand_type(callable.ret_type, id_to_type)
	remaining_tvars := filter_remaining_type_vars(tvars, id_to_type)
	return callable.copy_modified(new_arg_types, ret_type, remaining_tvars)
}

pub type PolyTranslationError = string

pub fn apply_poly(tp CallableType, poly_tvars []TypeVarLikeType) ?CallableType {
	mut translator := PolyTranslator{
		poly_tvars:   poly_tvars.clone()
		bound_tvars:  map[TypeVarId]bool{}
		seen_aliases: map[string]bool{}
	}

	mut new_arg_types := []MypyTypeNode{}
	for arg_typ in tp.arg_types {
		result := translator.visit(arg_typ)
		if result is PlaceholderType && result.fullname == poly_translation_error_sentinel {
			return none
		}
		new_arg_types << result
	}

	ret_type := translator.visit(tp.ret_type)
	if ret_type is PlaceholderType && ret_type.fullname == poly_translation_error_sentinel {
		return none
	}

	return tp.copy_modified(new_arg_types, ret_type, []MypyTypeNode{})
}

pub struct PolyTranslator {
pub mut:
	poly_tvars   []TypeVarLikeType
	bound_tvars  map[TypeVarId]bool
	seen_aliases map[string]bool
}

pub type CallableOrParameters = CallableType | ParametersType

pub fn (mut pt PolyTranslator) collect_vars(t CallableOrParameters) []TypeVarLikeType {
	mut found_vars := []TypeVarLikeType{}
	arg_types := match t {
		CallableType { t.arg_types }
		ParametersType { t.arg_types }
	}

	for arg in arg_types {
		for tv in get_all_type_vars(arg) {
			if pt.is_poly_tvar(tv) {
				found_vars << tv
			}
		}
	}
	return remove_dups_type_var_like(found_vars)
}

pub fn (mut pt PolyTranslator) visit(t MypyTypeNode) MypyTypeNode {
	match t {
		CallableType {
			return MypyTypeNode(pt.visit_callable_type(t))
		}
		TypeVarType {
			if pt.is_poly_tvar(t) {
				return poly_translation_error_type()
			}
			return t
		}
		ParamSpecType {
			if pt.is_poly_tvar(t) {
				return poly_translation_error_type()
			}
			return t
		}
		TypeVarTupleType {
			if pt.is_poly_tvar(t) {
				return poly_translation_error_type()
			}
			return t
		}
		Instance {
			return pt.visit_instance(t)
		}
		UnionType {
			mut items := []MypyTypeNode{}
			for item in t.items {
				items << pt.visit(item)
			}
			return UnionType{
				items:  items
				line:   t.line
				column: t.column
			}
		}
		TupleType {
			mut items := []MypyTypeNode{}
			for item in t.items {
				items << pt.visit(item)
			}
			return t.copy_modified(items, t.partial_fallback)
		}
		else {
			return t
		}
	}
}

pub fn (pt PolyTranslator) is_poly_tvar(t TypeVarLikeType) bool {
	id := extract_type_var_like_id(t) or { return false }
	if pt.bound_tvars[id] {
		return false
	}
	for pv in pt.poly_tvars {
		pv_id := extract_type_var_like_id(pv) or { continue }
		if pv_id == id {
			return true
		}
	}
	return false
}

pub fn (mut pt PolyTranslator) visit_callable_type(t CallableType) CallableType {
	found_vars := pt.collect_vars(t)
	for fv in found_vars {
		if id := extract_type_var_like_id(fv) {
			pt.bound_tvars[id] = true
		}
	}

	mut new_arg_types := []MypyTypeNode{}
	for arg in t.arg_types {
		new_arg_types << pt.visit(arg)
	}
	ret := pt.visit(t.ret_type)

	for fv in found_vars {
		if id := extract_type_var_like_id(fv) {
			pt.bound_tvars.delete(id)
		}
	}

	mut new_variables := t.variables.clone()
	for fv in found_vars {
		new_variables << type_var_like_to_node(fv)
	}
	return t.copy_modified(new_arg_types, ret, new_variables)
}

pub fn (mut pt PolyTranslator) visit_instance(t Instance) MypyTypeNode {
	if t.args.len == 0 {
		return t
	}
	mut args := []MypyTypeNode{}
	for arg in t.args {
		args << pt.visit(arg)
	}
	return MypyTypeNode(t.copy_modified(args, t.last_known_value))
}

pub fn get_all_type_vars(typ MypyTypeNode) []TypeVarLikeType {
	mut result := []TypeVarLikeType{}
	match typ {
		TypeVarType {
			result << typ
		}
		ParamSpecType {
			result << typ
		}
		TypeVarTupleType {
			result << typ
		}
		CallableType {
			for arg in typ.arg_types {
				result << get_all_type_vars(arg)
			}
			result << get_all_type_vars(typ.ret_type)
			for variable in typ.variables {
				if tv := type_var_like_from_node(variable) {
					result << tv
				}
			}
		}
		ParametersType {
			for arg in typ.arg_types {
				result << get_all_type_vars(arg)
			}
		}
		Instance {
			for arg in typ.args {
				result << get_all_type_vars(arg)
			}
		}
		UnionType {
			for item in typ.items {
				result << get_all_type_vars(item)
			}
		}
		TupleType {
			for item in typ.items {
				result << get_all_type_vars(item)
			}
		}
		TypeType {
			result << get_all_type_vars(typ.item)
		}
		TypeAliasType {
			for arg in typ.args {
				result << get_all_type_vars(arg)
			}
		}
		UnpackType {
			result << get_all_type_vars(typ.type)
		}
		else {}
	}
	return result
}

pub fn erase_typevars(typ MypyTypeNode) MypyTypeNode {
	return typ
}

fn type_var_like_default(tvar TypeVarLikeType) ?MypyTypeNode {
	match tvar {
		TypeVarType { return none }
		ParamSpecType { return tvar.default }
		TypeVarTupleType { return tvar.default }
	}
}

fn extract_type_var_like_id(tvar TypeVarLikeType) ?TypeVarId {
	match tvar {
		TypeVarType { return tvar.id }
		ParamSpecType { return tvar.id }
		TypeVarTupleType { return tvar.id }
	}
}

fn type_var_like_from_node(node MypyTypeNode) ?TypeVarLikeType {
	match node {
		TypeVarType { return node }
		ParamSpecType { return node }
		TypeVarTupleType { return node }
		else { return none }
	}
}

fn type_var_like_to_node(tvar TypeVarLikeType) MypyTypeNode {
	return match tvar {
		TypeVarType { MypyTypeNode(tvar) }
		ParamSpecType { MypyTypeNode(tvar) }
		TypeVarTupleType { MypyTypeNode(tvar) }
	}
}

fn callable_param_spec(callable CallableType) ?ParamSpecType {
	for variable in callable.variables {
		if variable is ParamSpecType {
			return variable
		}
	}
	return none
}

fn filter_remaining_type_vars(tvars []MypyTypeNode, id_to_type map[TypeVarId]MypyTypeNode) []MypyTypeNode {
	mut remaining := []MypyTypeNode{}
	for variable in tvars {
		tv := type_var_like_from_node(variable) or {
			remaining << variable
			continue
		}
		id := extract_type_var_like_id(tv) or {
			remaining << variable
			continue
		}
		if id !in id_to_type {
			remaining << variable
		}
	}
	return remaining
}

fn remove_dups_type_var_like(items []TypeVarLikeType) []TypeVarLikeType {
	mut seen := map[TypeVarId]bool{}
	mut result := []TypeVarLikeType{}
	for item in items {
		id := extract_type_var_like_id(item) or { continue }
		if id in seen {
			continue
		}
		seen[id] = true
		result << item
	}
	return result
}

const poly_translation_error_sentinel = '__mypy_poly_translation_error__'

fn poly_translation_error_type() MypyTypeNode {
	return PlaceholderType{
		fullname: poly_translation_error_sentinel
	}
}
