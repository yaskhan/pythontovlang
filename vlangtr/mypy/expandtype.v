// Work in progress by Cline. Started: 2026-03-22 15:48
// Version: 5377
// expandtype.v — Substitute type variables in types
// Translated from mypy/expandtype.py

module mypy

// expand_type substitutes type variable references in type
// according to type environment
pub fn expand_type(typ MypyTypeNode, env map[TypeVarId]MypyTypeNode) MypyTypeNode {
	mut v := ExpandTypeVisitor{
		variables: env
	}
	proper := get_proper_type(typ)
	match proper {
		AnyType {
			return v.visit_any(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		CallableArgument {
			return v.visit_callable_argument(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		CallableType {
			return v.visit_callable_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		DeletedType {
			return v.visit_deleted_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		EllipsisType {
			return v.visit_ellipsis_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		ErasedType {
			return v.visit_erased_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		Instance {
			return v.visit_instance(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		LiteralType {
			return v.visit_literal_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		NoneType {
			return v.visit_none_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		Overloaded {
			return v.visit_overloaded(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		ParamSpecType {
			return v.visit_param_spec(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		ParametersType {
			return v.visit_parameters(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		PartialTypeT {
			return v.visit_partial_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		PlaceholderType {
			return v.visit_placeholder_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		RawExpressionType {
			return v.visit_raw_expression_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		TupleType {
			return v.visit_tuple_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		TypeAliasType {
			return v.visit_type_alias_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		TypeList {
			return v.visit_type_list(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		TypeType {
			return v.visit_type_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		TypeVarTupleType {
			return v.visit_type_var_tuple(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		TypeVarType {
			return v.visit_type_var(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		UnboundType {
			return v.visit_unbound_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		UninhabitedType {
			return v.visit_uninhabited_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		UnionType {
			return v.visit_union_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
        TypedDictType {
			return v.visit_typeddict_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
		UnpackType {
			return v.visit_unpack_type(&proper) or {
				MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
	}
}

pub fn expand_type_by_instance(typ MypyTypeNode, instance Instance) MypyTypeNode {
	if instance.args.len == 0 { // Simplification
		return typ
	}
	mut variables := map[TypeVarId]MypyTypeNode{}
	binders := (instance.type_.defn or { return typ }).type_vars
	for i, binder in binders {
		if i < instance.args.len {
			proper_binder := get_proper_type(binder)
			if id := extract_type_var_id(proper_binder) {
				variables[id] = instance.args[i]
			}
		}
	}
	return expand_type(typ, variables)
}

pub fn freshen_function_type_vars(callee &CallableType) CallableType {
	if !callee.is_generic() {
		return *callee
	}
	mut tvs := []MypyTypeNode{}
	mut tvmap := map[TypeVarId]MypyTypeNode{}
	for v in callee.variables {
		proper_v := get_proper_type(v)
		tv := new_unification_variable(proper_v)
		tvs << tv
		if id := extract_type_var_id(proper_v) {
			tvmap[id] = tv
		}
	}
	res := expand_type(MypyTypeNode(*callee), tvmap)
	proper_res := get_proper_type(res)
	if proper_res is CallableType {
		// redundant 'as' removal
		return proper_res.copy_modified([], AnyType{type_of_any: .unannotated}, tvs)
	}
	return *callee
}

pub fn freshen_all_functions_type_vars(t MypyTypeNode) MypyTypeNode {
	if !has_generic_callable(t) {
		return t
	}
	mut v := FreshenCallableVisitor{}
	proper := get_proper_type(t)
	match proper {
		AnyType { return v.visit_any(&proper) or { t } }
		CallableArgument { return v.visit_callable_argument(&proper) or { t } }
		CallableType { return v.visit_callable_type(&proper) or { t } }
		DeletedType { return v.visit_deleted_type(&proper) or { t } }
		EllipsisType { return v.visit_ellipsis_type(&proper) or { t } }
		ErasedType { return v.visit_erased_type(&proper) or { t } }
		Instance { return v.visit_instance(&proper) or { t } }
		LiteralType { return v.visit_literal_type(&proper) or { t } }
		NoneType { return v.visit_none_type(&proper) or { t } }
		Overloaded { return v.visit_overloaded(&proper) or { t } }
		ParamSpecType { return v.visit_param_spec(&proper) or { t } }
		ParametersType { return v.visit_parameters(&proper) or { t } }
		PartialTypeT { return v.visit_partial_type(&proper) or { t } }
		PlaceholderType { return v.visit_placeholder_type(&proper) or { t } }
		RawExpressionType { return v.visit_raw_expression_type(&proper) or { t } }
		TupleType { return v.visit_tuple_type(&proper) or { t } }
		TypeAliasType { return v.visit_type_alias_type(&proper) or { t } }
		TypeList { return v.visit_type_list(&proper) or { t } }
		TypeType { return v.visit_type_type(&proper) or { t } }
		TypeVarTupleType { return v.visit_type_var_tuple(&proper) or { t } }
		TypeVarType { return v.visit_type_var(&proper) or { t } }
		UnboundType { return v.visit_unbound_type(&proper) or { t } }
		UninhabitedType { return v.visit_uninhabited_type(&proper) or { t } }
		UnionType { return v.visit_union_type(&proper) or { t } }
        TypedDictType { return v.visit_typeddict_type(&proper) or { t } }
		else { return t }
	}
}

pub fn has_generic_callable(t MypyTypeNode) bool {
	proper := get_proper_type(t)
	if proper is CallableType {
		// redundant 'as' removal
		return proper.is_generic()
	}
	return false
}

// ---------------------------------------------------------------------------
// ExpandTypeVisitor
// ---------------------------------------------------------------------------

pub struct ExpandTypeVisitor {
mut:
	variables map[TypeVarId]MypyTypeNode
}

pub fn (mut v ExpandTypeVisitor) expand_types(types []MypyTypeNode) []MypyTypeNode {
	mut res := []MypyTypeNode{}
	for tv in types {
		res << expand_type(tv, v.variables)
	}
	return res
}

pub fn (mut v ExpandTypeVisitor) visit_unbound_type(t &UnboundType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_any(t &AnyType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_none_type(t &NoneType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_uninhabited_type(t &UninhabitedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_erased_type(t &ErasedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_deleted_type(t &DeletedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_instance(t &Instance) !MypyTypeNode {
	if t.args.len == 0 {
		return MypyTypeNode(*t)
	}
	args := v.expand_types(t.args)
	return MypyTypeNode(t.copy_modified(args, none))
}

pub fn (mut v ExpandTypeVisitor) visit_type_var(t &TypeVarType) !MypyTypeNode {
	repl := v.variables[t.id] or { return MypyTypeNode(*t) }
	proper_repl := get_proper_type(repl)
	if proper_repl is Instance {
		return MypyTypeNode(proper_repl.copy_modified(proper_repl.args, none))
	}
	return repl
}

pub fn (mut v ExpandTypeVisitor) visit_param_spec(t &ParamSpecType) !MypyTypeNode {
	repl := v.variables[t.id] or { return MypyTypeNode(*t) }
	return repl
}

pub fn (mut v ExpandTypeVisitor) visit_parameters(t &ParametersType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_type_var_tuple(t &TypeVarTupleType) !MypyTypeNode {
	repl := v.variables[t.id] or { return MypyTypeNode(*t) }
	return repl
}

pub fn (mut v ExpandTypeVisitor) visit_callable_type(t &CallableType) !MypyTypeNode {
	arg_types := v.expand_types(t.arg_types)
	res_typ := expand_type(t.ret_type, v.variables)
    return MypyTypeNode(t.copy_modified(arg_types, res_typ, t.variables))
}

pub fn (mut v ExpandTypeVisitor) visit_overloaded(t &Overloaded) !MypyTypeNode {
	mut items := []&CallableType{}
	for item in t.items {
		expanded := v.visit_callable_type(item)!
		proper := get_proper_type(expanded)
		if proper is CallableType {
			// redundant 'as' removal
			items << &proper
		}
	}
	return MypyTypeNode(Overloaded{
		items: items
		line:  t.line
	})
}

pub fn (mut v ExpandTypeVisitor) visit_tuple_type(t &TupleType) !MypyTypeNode {
	items := v.expand_types(t.items)
	mut partial_fallback := t.partial_fallback
	if pf := t.partial_fallback {
		expanded_pf := v.visit_instance(pf)!
		proper_pf := get_proper_type(expanded_pf)
		if proper_pf is Instance {
			// redundant 'as' removal
			res := proper_pf
			partial_fallback = &Instance{
				...res
			}
		}
	}
	return MypyTypeNode(t.copy_modified(items, partial_fallback))
}

pub fn (mut v ExpandTypeVisitor) visit_typeddict_type(t &TypedDictType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_literal_type(t &LiteralType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_union_type(t &UnionType) !MypyTypeNode {
	items := v.expand_types(t.items)
	return MypyTypeNode(UnionType{
		items:  items
		line:   t.line
		column: t.column
	})
}

pub fn (mut v ExpandTypeVisitor) visit_partial_type(t &PartialTypeT) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_type_type(t &TypeType) !MypyTypeNode {
	item_typ := expand_type(t.item, v.variables)
	return MypyTypeNode(TypeType{
		item:   item_typ
		line:   t.line
		column: t.column
	})
}

pub fn (mut v ExpandTypeVisitor) visit_type_alias_type(t &TypeAliasType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_unpack_type(t &UnpackType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_callable_argument(t &CallableArgument) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_ellipsis_type(t &EllipsisType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_placeholder_type(t &PlaceholderType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_raw_expression_type(t &RawExpressionType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v ExpandTypeVisitor) visit_type_list(t &TypeList) !MypyTypeNode {
	return MypyTypeNode(*t)
}

// ---------------------------------------------------------------------------
// FreshenCallableVisitor
// ---------------------------------------------------------------------------

pub struct FreshenCallableVisitor {}

pub fn (mut v FreshenCallableVisitor) visit_unbound_type(t &UnboundType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_any(t &AnyType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_none_type(t &NoneType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_uninhabited_type(t &UninhabitedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_erased_type(t &ErasedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_deleted_type(t &DeletedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_instance(t &Instance) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_type_var(t &TypeVarType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_param_spec(t &ParamSpecType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_parameters(t &ParametersType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_type_var_tuple(t &TypeVarTupleType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_callable_type(t &CallableType) !MypyTypeNode {
	if t.is_generic() {
		return MypyTypeNode(freshen_function_type_vars(t))
	}
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_overloaded(t &Overloaded) !MypyTypeNode {
	mut items := []&CallableType{}
	for item in t.items {
		expanded := v.visit_callable_type(item)!
		proper := get_proper_type(expanded)
		if proper is CallableType {
			items << &proper
		}
	}
	return MypyTypeNode(Overloaded{
		items: items
		line:  t.line
	})
}

pub fn (mut v FreshenCallableVisitor) visit_tuple_type(t &TupleType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_typeddict_type(t &TypedDictType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_literal_type(t &LiteralType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_union_type(t &UnionType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_partial_type(t &PartialTypeT) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_type_type(t &TypeType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_type_alias_type(t &TypeAliasType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_unpack_type(t &UnpackType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_callable_argument(t &CallableArgument) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_ellipsis_type(t &EllipsisType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_placeholder_type(t &PlaceholderType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_raw_expression_type(t &RawExpressionType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut v FreshenCallableVisitor) visit_type_list(t &TypeList) !MypyTypeNode {
	return MypyTypeNode(*t)
}
