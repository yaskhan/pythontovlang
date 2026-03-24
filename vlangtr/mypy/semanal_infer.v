// I, Codex, am working on this file. Started: 2026-03-22 15:18:07 +05:00
module mypy

// Simple type inference for decorated functions during semantic analysis.

pub fn infer_decorator_signature_if_simple(mut dec Decorator, analyzer SemanticAnalyzerInterface) {
	if dec.var_.is_property {
		if dec.func.type_ == none {
			fallback := analyzer.named_type('builtins.function', []MypyTypeNode{})
			dec.var_.type_ = CallableType{
				arg_types: [
					MypyTypeNode(AnyType{
						type_of_any: .special_form
					}),
				]
				arg_kinds: [.arg_pos]
				arg_names: [?string(none)]
				ret_type:  MypyTypeNode(AnyType{
					type_of_any: .special_form
				})
				fallback:  fallback
				name:      dec.var_.name
			}
		} else if fn_typ := dec.func.type_ {
			if fn_typ is CallableType {
				dec.var_.type_ = fn_typ
			}
		}
		return
	}

	if dec.decorators.len == 0 {
		return
	}
	if return_type := calculate_return_type(dec.decorators[0]) {
		if return_type is AnyType {
			dec.var_.type_ = AnyType{
				type_of_any: .from_another_any
			}
		}
	}
	if mut sig := find_fixed_callable_return(dec.decorators[0]) {
		if orig := function_type_of_func(dec.func, analyzer) {
			sig.name = orig.name
		}
		dec.var_.type_ = sig
	}
}

pub fn is_identity_signature(sig MypyTypeNode) bool {
	if sig is CallableType {
		if sig.arg_kinds.len == 1 && sig.arg_kinds[0] == .arg_pos && sig.arg_types.len == 1 {
			if sig.arg_types[0] is TypeVarType && sig.ret_type is TypeVarType {
				return (sig.arg_types[0] as TypeVarType).id == (sig.ret_type as TypeVarType).id
			}
		}
	}
	return false
}

pub fn calculate_return_type(expr Expression) ?MypyTypeNode {
	match expr {
		NameExpr {
			if ref_node := expr.node {
				if ref_node is FuncDef {
					if fn_typ := ref_node.type_ {
						if fn_typ is CallableType {
							return get_proper_type(fn_typ.ret_type)
						}
						return none
					}
					return MypyTypeNode(AnyType{
						type_of_any: .unannotated
					})
				}
				if ref_node is Var {
					if v_typ := ref_node.type_ {
						return get_proper_type(v_typ)
					}
				}
			}
		}
		MemberExpr {
			if ref_node := expr.node {
				if ref_node is FuncDef {
					if fn_typ := ref_node.type_ {
						if fn_typ is CallableType {
							return get_proper_type(fn_typ.ret_type)
						}
						return none
					}
					return MypyTypeNode(AnyType{
						type_of_any: .unannotated
					})
				}
				if ref_node is Var {
					if v_typ := ref_node.type_ {
						return get_proper_type(v_typ)
					}
				}
			}
		}
		CallExpr {
			return calculate_return_type(expr.callee)
		}
		else {}
	}
	return none
}

pub fn find_fixed_callable_return(expr Expression) ?CallableType {
	match expr {
		NameExpr {
			if ref_node := expr.node {
				if ref_node is FuncDef {
					if fn_typ := ref_node.type_ {
						if fn_typ is CallableType {
							ret_type := get_proper_type(fn_typ.ret_type)
							if ret_type is CallableType {
								return ret_type
							}
						}
					}
				}
			}
		}
		MemberExpr {
			if ref_node := expr.node {
				if ref_node is FuncDef {
					if fn_typ := ref_node.type_ {
						if fn_typ is CallableType {
							ret_type := get_proper_type(fn_typ.ret_type)
							if ret_type is CallableType {
								return ret_type
							}
						}
					}
				}
			}
		}
		CallExpr {
			if t := find_fixed_callable_return(expr.callee) {
				ret_type := get_proper_type(t.ret_type)
				if ret_type is CallableType {
					return ret_type
				}
			}
		}
		else {}
	}
	return none
}

fn function_type_of_func(f FuncDef, analyzer SemanticAnalyzerInterface) ?CallableType {
	if fn_typ := f.type_ {
		if fn_typ is CallableType {
			return fn_typ
		}
	}
	fallback := analyzer.named_type('builtins.function', []MypyTypeNode{})
	return CallableType{
		arg_types: []MypyTypeNode{}
		arg_kinds: []ArgKind{}
		arg_names: []?string{}
		ret_type:  MypyTypeNode(AnyType{
			type_of_any: .special_form
		})
		fallback:  fallback
		name:      f.name
	}
}
