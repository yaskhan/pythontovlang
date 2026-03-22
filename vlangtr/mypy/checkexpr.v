// РЇ Antigravity СЂР°Р±РѕС‚Р°СЋ РЅР°Рґ СЌС‚РёРј С„Р°Р№Р»РѕРј. РќР°С‡Р°Р»Рѕ: 2026-03-22 06:47
module mypy

// РџСЂРѕРІРµСЂРєР° С‚РёРїРѕРІ РІС‹СЂР°Р¶РµРЅРёР№ (ExpressionChecker).

pub struct ExpressionChecker {
pub mut:
	chk          &TypeChecker
	msg          &MessageBuilder
	type_context []?MypyTypeNode

	// strfrm_checker           &StringFormatterChecker
	// plugin                   &Plugin
	is_callee      bool
	in_expression  bool
	in_lambda_expr bool
	expr_cache     map[string]MypyTypeNode // СѓРїСЂРѕС‰РµРЅРЅС‹Р№ РєСЌС€
	type_overrides map[string]MypyTypeNode // РІСЂРµРјРµРЅРЅС‹Рµ РїРµСЂРµРѕРїСЂРµРґРµР»РµРЅРёСЏ С‚РёРїРѕРІ
}

pub fn new_expression_checker(mut chk &TypeChecker, mut msg &MessageBuilder) &ExpressionChecker {
	return &ExpressionChecker{

		chk:          chk
		msg:          msg
		type_context: [none]
	}
}

pub fn (mut e ExpressionChecker) reset() {
	e.expr_cache = map[string]MypyTypeNode{}
	e.type_overrides = map[string]MypyTypeNode{}
}

pub fn (mut e ExpressionChecker) accept(node Expression, type_context ?MypyTypeNode, allow_none_return bool, always_allow_any bool, is_callee bool) MypyTypeNode {
	// РЎРѕС…СЂР°РЅРµРЅРёРµ РїСЂРµРґС‹РґСѓС‰РµРіРѕ РєРѕРЅС‚РµРєСЃС‚Р°
	old_is_callee := e.is_callee
	e.is_callee = is_callee

	e.type_context << type_context

	// Р”РёСЃРїРµС‚С‡РµСЂРёР·Р°С†РёСЏ РїРѕ С‚РёРїСѓ СѓР·Р»Р°
	mut typ := MypyTypeNode(AnyType{
		type_of_any: .from_error
	})

	match node {
		NameExpr {
			typ = e.visit_name_expr(node)
		}
		CallExpr {
			typ = e.visit_call_expr(node, allow_none_return)
		}
		MemberExpr {
			typ = e.visit_member_expr(node, false)
		}
		OpExpr {
			typ = e.visit_op_expr(node)
		}
		UnaryExpr {
			typ = e.visit_unary_expr(node)
		}
		IntExpr {
			typ = e.visit_int_expr(node)
		}
		StrExpr {
			typ = e.visit_str_expr(node)
		}
		FloatExpr {
			typ = e.visit_float_expr(node)
		}
		BytesExpr {
			typ = e.visit_bytes_expr(node)
		}
		ListExpr {
			typ = e.visit_list_expr(node)
		}
		SetExpr {
			typ = e.visit_set_expr(node)
		}
		DictExpr {
			typ = e.visit_dict_expr(node)
		}
		TupleExpr {
			typ = e.visit_tuple_expr(node)
		}
		GeneratorExpr {
			typ = e.visit_generator_expr(node)
		}
		ListComprehension {
			typ = e.visit_list_comp_expr(node)
		}
		DictionaryComprehension {
			typ = e.visit_dict_comp_expr(&node)
		}
		SetComprehension {
			typ = e.visit_set_comp_expr(&node)
		}
		SliceExpr {
			typ = e.visit_slice_expr(&node)
		}
		LambdaExpr {
			typ = e.visit_lambda_expr(&node)
		}

		YieldExpr {
			typ = e.visit_yield_expr(node)
		}
		YieldFromExpr {
			typ = e.visit_yield_from_expr(node, allow_none_return)
		}
		IndexExpr {
			typ = e.visit_index_expr(node)
		}
		ComparisonExpr {
			typ = e.visit_comparison_expr(node)
		}
		ConditionalExpr {
			typ = e.visit_conditional_expr(node)
		}
		AssignmentExpr {
			typ = e.visit_assignment_expr(node)
		}
		RevealExpr {
			typ = e.visit_reveal_expr(node)
		}
		AwaitExpr {
			typ = e.visit_await_expr(node)
		}
		EllipsisExpr {
			typ = e.visit_ellipsis_expr(node)
		}
		else {
			// fallback
		}
	}

	e.type_context.delete_last()
	e.is_callee = old_is_callee

	return typ
}

// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// Р‘Р°Р·РѕРІС‹Рµ Р»РёС‚РµСЂР°Р»С‹
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) visit_int_expr(node &IntExpr) MypyTypeNode {
	return MypyTypeNode(*e.chk.named_type('builtins.int', []))
}

pub fn (mut e ExpressionChecker) visit_str_expr(node &StrExpr) MypyTypeNode {
	return MypyTypeNode(*e.chk.named_type('builtins.str', []))
}

pub fn (mut e ExpressionChecker) visit_float_expr(node &FloatExpr) MypyTypeNode {
	return MypyTypeNode(*e.chk.named_type('builtins.float', []))
}

pub fn (mut e ExpressionChecker) visit_bytes_expr(node &BytesExpr) MypyTypeNode {
	return MypyTypeNode(*e.chk.named_type('builtins.bytes', []))
}

pub fn (mut e ExpressionChecker) visit_ellipsis_expr(node &EllipsisExpr) MypyTypeNode {
	return MypyTypeNode(*e.chk.named_type('builtins.ellipsis', []))
}


// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// NameExpr / RefExpr
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) visit_name_expr(node &NameExpr) MypyTypeNode {
	result := e.analyze_ref_expr(node, false)
	// narrowed := e.narrow_type_from_binder(node, result)
	// e.chk.check_deprecated(node.node, node)
	return result
}

pub fn (mut e ExpressionChecker) analyze_ref_expr(node Expression, lvalue bool) MypyTypeNode {
	mut result := MypyTypeNode(AnyType{
		type_of_any: .from_error
	})

	if node is NameExpr {
		if node.is_special_form {
			return MypyTypeNode(AnyType{
				type_of_any: .special_form
			})
		}
		if target := node.node {
			if target is Var {
				result = e.analyze_var_ref(target, node)
			} else if target is Decorator {
				result = e.analyze_var_ref(target.var_, node)
			} else if target is OverloadedFuncDef {
				if ot := target.type_ {
					result = ot
				} else {
					result = MypyTypeNode(AnyType{
						type_of_any: .from_error
					})
				}
			} else if target is FuncDef {
				result = e.analyze_static_reference(target as Node, node, lvalue)
			} else if target is TypeInfo {
				result = e.analyze_static_reference(target as Node, node, lvalue)
			} else if target is TypeAlias {
				result = e.analyze_static_reference(target as Node, node, lvalue)
			} else {
				result = MypyTypeNode(AnyType{
					type_of_any: .from_error
				})
			}
		}
	} else if node is MemberExpr {
		// РѕР±С‰РёР№ РїСѓС‚СЊ РґР»СЏ MemberExpr.kind != ldef
		result = MypyTypeNode(AnyType{
			type_of_any: .from_error
		})
	}

	return result
}

pub fn (mut e ExpressionChecker) analyze_var_ref(target &Var, context Expression) MypyTypeNode {
	if typ := target.type_ {
		// РЎРїРµС†РёР°Р»СЊРЅС‹Р№ СЃР»СѓС‡Р°Р№: typing.Any в†’ _SpecialForm РІ runtime-РєРѕРЅС‚РµРєСЃС‚Рµ
		if target.fullname == 'typing.Any' {
			return MypyTypeNode(*e.chk.named_type('typing._SpecialForm', []))
		}
		// True / False в†’ LiteralType
		if target.name == 'True' {
			return e.infer_literal_bool_type(true)
		}
		if target.name == 'False' {
			return e.infer_literal_bool_type(false)
		}
		return typ
	}
	// РќРµС‚ С‚РёРїР° вЂ” РІРѕР·РјРѕР¶РЅР° РЅРµРіРѕС‚РѕРІРЅРѕСЃС‚СЊ РїРµСЂРµРјРµРЅРЅРѕР№
	if !target.is_ready {
		// e.chk.handle_cannot_determine_type(target.name, context)
	}
	return MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
}

pub fn (mut e ExpressionChecker) infer_literal_bool_type(value bool) MypyTypeNode {
	// Returns Instance builtins.bool
	return MypyTypeNode(*e.chk.named_type('builtins.bool', []))
}


pub fn (mut e ExpressionChecker) analyze_static_reference(node Node, ctx Expression, is_lvalue bool) MypyTypeNode {
	if node is FuncDef {
		// return function_type(node, e.chk.named_type))
		return MypyTypeNode(*e.chk.named_type('builtins.function', []))
	} else if node is TypeInfo {
		if node.fullname == 'types.NoneType' {
			return MypyTypeNode(TypeType{
				item: MypyTypeNode(NoneType{})
			})
		}
		// return type_object_type(node, e.chk.named_type)
		return MypyTypeNode(*e.chk.named_type('builtins.type', []))
	}
 else if node is TypeAlias {
		// return e.alias_type_in_runtime_context(node, ctx, is_lvalue)
		return MypyTypeNode(AnyType{
			type_of_any: .special_form
		})
	} else if node is TypeVarExpr {
		return MypyTypeNode(*e.chk.named_type('typing.TypeVar', []))
	} else if node is MypyFile {

		return e.module_type(node)
	}
	return MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
}

pub fn (mut e ExpressionChecker) module_type(node &MypyFile) MypyTypeNode {
	// Р’РѕР·РІСЂР°С‰Р°РµС‚ types.ModuleType СЃ extra_attrs РёР· РїСѓР±Р»РёС‡РЅС‹С… РёРјС‘РЅ РјРѕРґСѓР»СЏ
	mut result := e.chk.named_type('types.ModuleType', [])
	// РС‚РµСЂР°С†РёСЏ РїРѕ РёРјРµРЅР°Рј РјРѕРґСѓР»СЏ РїСЂРѕРїСѓС‰РµРЅР° (РЅРµС‚ ExtraAttrs РІ stub)
	return result
}

// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// CallExpr
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) visit_call_expr(node &CallExpr, allow_none_return bool) MypyTypeNode {
	// Р’ Mypy РµСЃС‚СЊ РєСЌС€/СЃРїРµС†РёР°Р»СЊРЅС‹Рµ РїСЂРѕРІРµСЂРєРё РґР»СЏ TypedDict Рё isinstance

	callee_type := e.accept(node.callee, none, false, true, true)

	mut callable_name := ?string(none)
	mut object_type := ?MypyTypeNode(none)

	if node.callee is NameExpr {
		callable_name = (node.callee as NameExpr).fullname
	} else if node.callee is MemberExpr {
		m_expr := node.callee as MemberExpr
		callable_name = m_expr.name
		object_type = e.chk.lookup_type(m_expr.expr)
	}


	ret_type := e.check_call_expr_with_callee_type(callee_type, node, callable_name, object_type,
		none)
	return ret_type
}

pub fn (mut e ExpressionChecker) check_call_expr_with_callee_type(callee_type MypyTypeNode, node &CallExpr, callable_name ?string, object_type ?MypyTypeNode, member ?string) MypyTypeNode {
	mut actual_callable_name := callable_name

	if actual_callable_name == none && member != none {
		if ot := object_type {
			actual_callable_name = e.method_fullname(ot, member or { panic('') })
		}
	}

	ret_type, _ := e.check_call(callee_type, node.args, node.arg_kinds, node.base.ctx, node.arg_names,
		node.callee, actual_callable_name, object_type, none)
	return ret_type
}

pub fn (mut e ExpressionChecker) check_call(callee MypyTypeNode, args []Expression, arg_kinds []ArgKind, context Context, arg_names []?string, callable_node ?Expression, callable_name ?string, object_type ?MypyTypeNode, original_type ?MypyTypeNode) (MypyTypeNode, MypyTypeNode) {

	if callee is CallableType {
		return e.check_callable_call(callee, args, arg_kinds, context, arg_names, callable_node,
			callable_name, object_type)
	} else if callee is Overloaded {
		return e.check_overload_call(callee, args, arg_kinds, arg_names, callable_name,
			object_type, context), callee
	} else if callee is AnyType {
		return e.check_any_type_call(args, arg_kinds, callee, context), callee
	} else if callee is UnionType {
		// Р’С‹Р·РѕРІ union-С‚РёРїР°: РїСЂРѕРІРµСЂСЏРµРј РєР°Р¶РґС‹Р№ РІР°СЂРёР°РЅС‚ Рё РѕР±СЉРµРґРёРЅСЏРµРј СЂРµР·СѓР»СЊС‚Р°С‚С‹
		mut ret_types := []MypyTypeNode{}
		for item in callee.items {
			r, _ := e.check_call(item, args, arg_kinds, context, arg_names, callable_node,
				callable_name, object_type, original_type)
			ret_types << r
		}
		if ret_types.len == 0 {
			return MypyTypeNode(AnyType{
				type_of_any: .from_error
			}), callee
		}
		return ret_types[0], callee // TODO: make_simplified_union(ret_types)
	} else if callee is Instance {
		// РџРѕРїС‹С‚РєР° РЅР°Р№С‚Рё __call__
		call_type := e.analyze_member_access_type('__call__', callee, context)
		return e.check_call(call_type, args, arg_kinds, context, arg_names, callable_node,
			callable_name, object_type, original_type)
	}

	e.msg.fail('Object is not callable', context, false, false, none)
	return MypyTypeNode(AnyType{
		type_of_any: .from_error
	}), callee
}

pub fn (mut e ExpressionChecker) check_callable_call(callee &CallableType, args []Expression, arg_kinds []ArgKind, context Context, arg_names []?string, callable_node ?Expression, callable_name ?string, object_type ?MypyTypeNode) (MypyTypeNode, MypyTypeNode) {

	mut actual_callee := callee

	if callee.is_type_obj {
		if ret := get_proper_type(callee.ret_type) as Instance {
			if info := ret.typ {
				if info.is_abstract {
					e.msg.fail('Cannot instantiate abstract class', context, none)
				}
			}
		}
	}

	formal_to_actual := map_actuals_to_formals(arg_kinds, arg_names, callee.arg_kinds,

		actual_callee.arg_names, fn (i int) MypyTypeNode {
		return MypyTypeNode(AnyType{ type_of_any: .from_error }) // placeholder
	})

	arg_types := e.infer_arg_types_in_context(actual_callee, args, arg_kinds, formal_to_actual)

	e.check_argument_count(callee, arg_types, arg_kinds, arg_names, formal_to_actual,
		context, object_type, callable_name)
	e.check_argument_types(arg_types, arg_kinds, args, callee, formal_to_actual,
		context, object_type)

	return callee.ret_type, MypyTypeNode(*callee)

}

pub fn (mut e ExpressionChecker) check_overload_call(callee &Overloaded, args []Expression, arg_kinds []int, arg_names []?string, callable_name ?string, object_type ?MypyTypeNode, context Context) MypyTypeNode {
	// РџРµСЂРµР±РёСЂР°РµРј РїРµСЂРµРіСЂСѓР·РєРё РІ РїРѕСЂСЏРґРєРµ РѕР±СЉСЏРІР»РµРЅРёСЏ, РІРѕР·РІСЂР°С‰Р°РµРј РїРµСЂРІСѓСЋ РїРѕРґС…РѕРґСЏС‰СѓСЋ
	for item in callee.items {
		// РџСЂРѕР±СѓРµРј Р±РµР· СЃРѕРѕР±С‰РµРЅРёР№ РѕР± РѕС€РёР±РєР°С…
		// Р’ РїРѕР»РЅРѕР№ СЂРµР°Р»РёР·Р°С†РёРё Р·РґРµСЃСЊ РёСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ С„РёР»СЊС‚СЂР°С†РёСЏ СЃ arg_approximate_similarity
		_, _ = e.check_callable_call(item, args, arg_kinds, context, arg_names, none,
			callable_name, object_type)
		return item.ret_type // Р—Р°РіР»СѓС€РєР°: РїРµСЂРІР°СЏ РїРµСЂРµРіСЂСѓР·РєР°
	}
	return MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
}

pub fn (mut e ExpressionChecker) check_any_type_call(args []Expression, arg_kinds []int, callee AnyType, context Context) MypyTypeNode {
	for arg in args {
		e.accept(arg, none, false, false, false)
	}
	return MypyTypeNode(AnyType{
		type_of_any: callee.type_of_any
	})
}

pub fn (mut e ExpressionChecker) infer_arg_types_in_context(callee &CallableType, args []Expression, arg_kinds []int, formal_to_actual [][]int) []MypyTypeNode {
	mut arg_types := []MypyTypeNode{}
	for i, arg in args {
		// Р’С‹Р±РёСЂР°РµРј РєРѕРЅС‚РµРєСЃС‚ С‚РёРїР° РёР· СЃРѕРѕС‚РІРµС‚СЃС‚РІСѓСЋС‰РµРіРѕ С„РѕСЂРјР°Р»СЊРЅРѕРіРѕ РїР°СЂР°РјРµС‚СЂР°
		mut ctx := ?MypyTypeNode(none)
		for fi, actuals in formal_to_actual {
			if i in actuals && fi < callee.arg_types.len {
				ctx = callee.arg_types[fi]
				break
			}
		}
		arg_types << e.accept(arg, ctx, false, false, false)
	}
	return arg_types
}

pub fn (mut e ExpressionChecker) check_argument_count(callee &CallableType, arg_types []MypyTypeNode, arg_kinds []ArgKind, arg_names []?string, formal_to_actual [][]int, context Context, object_type ?MypyTypeNode, callable_name ?string) {
	// 
	mut required_pos := 0
	for ak in callee.arg_kinds {
		if ak == ArgKind.arg_pos {
			required_pos++
		}
	}
	actual_pos := arg_types.len
	if actual_pos < required_pos {
		name := callable_name or { '<unknown>' }
		e.msg.fail('Too few arguments for "${name}"', context, false, false, none)
	}
}

pub fn (mut e ExpressionChecker) check_argument_types(arg_types []MypyTypeNode, arg_kinds []ArgKind, args []Expression, callee &CallableType, formal_to_actual [][]int, context Context, object_type ?MypyTypeNode) {

	for i, at_i in arg_types {
		if i < callee.arg_types.len {
			e.chk.check_subtype(at_i, callee.arg_types[i], context, 'Argument ${i + 1} has incompatible type',
				none, none, [], none, none)
		}
	}

}

pub fn (mut e ExpressionChecker) always_returns_none(node Expression) bool {
	if node is NameExpr {
		if nn := (node as NameExpr).node {
			return e.defn_returns_none(nn)
		}
	} else if node is MemberExpr {
		m_node := node as MemberExpr

		typ := get_proper_type(e.chk.lookup_type(m_node.expr))
		if typ is Instance {
			inst := typ as Instance
			if info := inst.typ {
				if sym := info.names[m_node.name] {
					if sn := sym.node {
						return e.defn_returns_none(sn)
					}
				}
			}
		}

	}
	return false
}

pub fn (mut e ExpressionChecker) defn_returns_none(defn SymbolNodeRef) bool {
	if defn is FuncDef {
		if ft := defn.type_ {
			if ft is CallableType {
				return get_proper_type(ft.ret_type) is NoneType
			}
		}
		return false
	}
	if defn is OverloadedFuncDef {
		return defn.items.all(e.defn_returns_none(it))
	}
	if defn is Var {
		if vt := defn.type_ {
			pt := get_proper_type(vt)
			if pt is CallableType {
				return get_proper_type(pt.ret_type) is NoneType
			}
		}
	}
	return false
}

// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// MemberExpr
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) visit_member_expr(node &MemberExpr, is_lvalue bool) MypyTypeNode {
	result := e.analyze_ordinary_member_access(node, is_lvalue, none)
	// narrowed := e.narrow_type_from_binder(node, result)
	return result
}

pub fn (mut e ExpressionChecker) analyze_ordinary_member_access(node &MemberExpr, is_lvalue bool, rvalue ?Expression) MypyTypeNode {
	if node.kind != ldef {
		return e.analyze_ref_expr(node, is_lvalue)
	}

	original_type := e.accept(node.expr, none, false, true, e.is_callee)

	mut is_self := false
	if node.expr is NameExpr {
		n_expr := node.expr as NameExpr
		if bn := n_expr.node {
			if bn is Var {
				is_self = (bn as Var).is_self || (bn as Var).is_cls
			}
		}
	} else if node.expr is MemberExpr {
		m_expr := node.expr as MemberExpr
		if bn := m_expr.node {
			if bn is Var {
				is_self = (bn as Var).is_self || (bn as Var).is_cls
			}
		}
	}

	_ = is_self
	member_type := analyze_member_access(node.name, original_type, node.base.ctx, is_lvalue, false,
		false, original_type, mut *e.chk, e.is_literal_context())

	return member_type
}

pub fn (mut e ExpressionChecker) analyze_member_access_type(name string, typ MypyTypeNode, context Context) MypyTypeNode {
	return analyze_member_access(name, typ, context, false, false, false, typ, mut *e.chk,
		false)
}



pub fn (mut e ExpressionChecker) is_literal_context() bool {
	if e.type_context.len == 0 {
		return false
	}
	if ctx := e.type_context.last() {
		return ctx is LiteralType
	}
	return false
}

// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// OpExpr / UnaryExpr / ComparisonExpr
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub enum UseReverse {
	default_mode
	always
	never
}

pub fn (mut e ExpressionChecker) visit_op_expr(node &OpExpr) MypyTypeNode {
	if node.op == 'and' || node.op == 'or' {
		return e.check_boolean_op(node)
	}

	left_type := e.accept(node.left, none, false, false, false)

	// РњР°РїРїРёРЅРі РѕРїРµСЂР°С‚РѕСЂРѕРІ РІ РјР°РіРёС‡РµСЃРєРёРµ РјРµС‚РѕРґС‹
	mut method := ''
	match node.op {
		'+' { method = '__add__' }
		'-' { method = '__sub__' }
		'*' { method = '__mul__' }
		'/' { method = '__truediv__' }
		'//' { method = '__floordiv__' }
		'%' { method = '__mod__' }
		'**' { method = '__pow__' }
		'<<' { method = '__lshift__' }
		'>>' { method = '__rshift__' }
		'&' { method = '__and__' }
		'|' { method = '__or__' }
		'^' { method = '__xor__' }
		'@' { method = '__matmul__' }
		'in' { method = '__contains__' }
		'not in' { method = '__contains__' }
		else {}
	}

	if method != '' {
		result, _ := e.check_op(method, left_type, node.right, node.base.ctx, true)
		return result
	}


	e.msg.fail('Unknown operator ${node.op}', node.base.ctx, false, false, none)
	return MypyTypeNode(AnyType{
		type_of_any: .from_error
	})
}


pub fn (mut e ExpressionChecker) check_op(method string, base_type MypyTypeNode, arg Expression, context Context, allow_reverse bool) (MypyTypeNode, MypyTypeNode) {
	// РС‰РµРј РјРµС‚РѕРґ Сѓ Р»РµРІРѕРіРѕ РѕРїРµСЂР°РЅРґР°
	method_type := e.analyze_member_access_type(method, base_type, context)
	if method_type is CallableType {
		argument_type := e.accept(arg, none, false, false, false)
		ret, _ := e.check_callable_call(method_type as CallableType, [arg], [ArgKind.arg_pos], context, [

			?string(none),
		], none, method, none)
		return ret, method_type
	}
	// Р•СЃР»Рё РјРµС‚РѕРґ РЅРµ РЅР°Р№РґРµРЅ Рё allow_reverse == true, РїСЂРѕРІРµСЂСЏРµРј СЂРµРІРµСЂСЃРёРІРЅС‹Р№ РјРµС‚РѕРґ Сѓ РїСЂР°РІРѕРіРѕ РѕРїРµСЂР°РЅРґР° (__radd__ Рё С‚.Рґ.)
	if allow_reverse {
		reverse_method := get_reverse_op_method(method)
		if reverse_method != '' {
			right_type := e.accept(arg, none, false, false, false)
			rmethod_type := e.analyze_member_access_type(reverse_method, right_type, context)
			ret, _ := e.check_callable_call(rmethod_type as CallableType, [Expression(NameExpr{})],
				[ArgKind.arg_pos], context, [?string(none)], none, reverse_method, none)
			return ret, rmethod_type
		}
	}
	return MypyTypeNode(AnyType{
		type_of_any: .from_error
	}), MypyTypeNode(AnyType{
		type_of_any: .from_error
	})
}

// get_reverse_op_method РІРѕР·РІСЂР°С‰Р°РµС‚ СЂРµРІРµСЂСЃРёРІРЅС‹Р№ РјРµС‚РѕРґ РґР»СЏ Р±РёРЅР°СЂРЅРѕРіРѕ РѕРїРµСЂР°С‚РѕСЂР°
fn get_reverse_op_method(method string) string {
	return match method {
		'__add__' { '__radd__' }
		'__sub__' { '__rsub__' }
		'__mul__' { '__rmul__' }
		'__truediv__' { '__rtruediv__' }
		'__floordiv__' { '__rfloordiv__' }
		'__mod__' { '__rmod__' }
		'__pow__' { '__rpow__' }
		'__lshift__' { '__rlshift__' }
		'__rshift__' { '__rrshift__' }
		'__and__' { '__rand__' }
		'__or__' { '__ror__' }
		'__xor__' { '__rxor__' }
		'__matmul__' { '__rmatmul__' }
		else { '' }
	}
}

pub fn (mut e ExpressionChecker) check_boolean_op(node &OpExpr) MypyTypeNode {
	// `and` / `or` вЂ” РІС‹С‡РёСЃР»СЏРµРј РѕР±Р° РѕРїРµСЂР°РЅРґР°, РІРѕР·РІСЂР°С‰Р°РµРј union
	left_type := e.accept(node.left, none, false, false, false)
	right_type := e.accept(node.right, none, false, false, false)
	// Р’ РїРѕР»РЅРѕР№ СЂРµР°Р»РёР·Р°С†РёРё Р·РґРµСЃСЊ РёСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ join_types / make_simplified_union
	// РЈРїСЂРѕС‰С‘РЅРЅРѕ: РІРѕР·РІСЂР°С‰Р°РµРј РїСЂР°РІС‹Р№ РѕРїРµСЂР°РЅРґ (РїРѕРІРµРґРµРЅРёРµ `or` РїСЂРё РёСЃС‚РёРЅРЅРѕРј Р»РµРІРѕРј)
	if node.op == 'or' {
		return right_type
	}
	// `and` РїСЂРё Р»РѕР¶РЅРѕРј Р»РµРІРѕРј РІРѕР·РІСЂР°С‰Р°РµС‚ Р»РµРІС‹Р№
	return left_type
}

pub fn (mut e ExpressionChecker) visit_unary_expr(node &UnaryExpr) MypyTypeNode {
	operand_type := e.accept(node.expr, none, false, false, false)
	op := node.op
	if op == 'not' {
		return MypyTypeNode(*e.chk.named_type('builtins.bool', []))
	}


	mut method := ''
	match op {
		'-' { method = '__neg__' }
		'+' { method = '__pos__' }
		'~' { method = '__invert__' }
		else {}
	}

	if method != '' {
		method_type := e.analyze_member_access_type(method, operand_type, node.base.ctx)
		if method_type is CallableType {
			ret, _ := e.check_callable_call(method_type as CallableType, [], [], node.base.ctx, [], none, method,
				none)
			return ret
		}
	}

	return MypyTypeNode(AnyType{
		type_of_any: .from_error
	})
}

pub fn (mut e ExpressionChecker) visit_comparison_expr(node &ComparisonExpr) MypyTypeNode {
	for op_node in node.operands {
		e.accept(op_node, none, false, false, false)
	}
	return MypyTypeNode(*e.chk.named_type('builtins.bool', []))
}


// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// РљРѕР»Р»РµРєС†РёРё
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) visit_list_expr(node &ListExpr) MypyTypeNode {
	return e.check_lst_expr(node.items, 'builtins.list', '<list>')
}

pub fn (mut e ExpressionChecker) visit_set_expr(node &SetExpr) MypyTypeNode {
	return e.check_lst_expr(node.items, 'builtins.set', '<set>')
}

pub fn (mut e ExpressionChecker) check_lst_expr(items []Expression, fullname string, tag string) MypyTypeNode {
	// РћР±С…РѕРґРёРј СЌР»РµРјРµРЅС‚С‹ Рё РѕР±СЉРµРґРёРЅСЏРµРј С‚РёРїС‹
	mut types := []MypyTypeNode{}
	for item in items {
		types << e.accept(item, none, false, false, false)
	}

	fallback := e.chk.named_type(fullname, [])
	if types.len > 0 {
		mut inst := *fallback
		inst.args = [types[0]] // TODO: join РІСЃРµС… С‚РёРїРѕРІ
		return MypyTypeNode(inst)
	} else {
		mut inst := *fallback
		inst.args = [MypyTypeNode(AnyType{
			type_of_any: .special_form
		})]
		return MypyTypeNode(inst)
	}

}

pub fn (mut e ExpressionChecker) visit_dict_expr(node &DictExpr) MypyTypeNode {
	mut key_types := []MypyTypeNode{}
	mut value_types := []MypyTypeNode{}
	for item in node.items {
		if k := item.key {
			key_types << e.accept(k, none, false, false, false)
		}
		value_types << e.accept(item.value, none, false, false, false)
	}

	mut inst := *e.chk.named_type('builtins.dict', [])
	if key_types.len > 0 && value_types.len > 0 {
		inst.args = [key_types[0], value_types[0]] // TODO: join
	} else {
		inst.args = [
			MypyTypeNode(AnyType{
				type_of_any: .special_form
			}),
			MypyTypeNode(AnyType{
				type_of_any: .special_form
			}),
		]
	}
	return MypyTypeNode(inst)

}

pub fn (mut e ExpressionChecker) visit_tuple_expr(node &TupleExpr) MypyTypeNode {
	mut items := []MypyTypeNode{}
	for item in node.items {
		items << e.accept(item, none, false, false, false)
	}

	fallback := e.chk.named_type('builtins.tuple', [
		MypyTypeNode(AnyType{ type_of_any: .special_form }),
	])
	return MypyTypeNode(TupleType{
		items:            items
		partial_fallback: *fallback
	})

}

// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// Comprehensions
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) visit_generator_expr(node &GeneratorExpr) MypyTypeNode {
	e.accept(node.left_expr, none, false, false, false)
	for seq in node.sequences {
		e.accept(seq, none, false, false, false)
	}
	for cond_list in node.condlists {
		for cond in cond_list {
			e.accept(cond, none, false, false, false)
		}
	}
	return MypyTypeNode(*e.chk.named_type('typing.Generator', [
		MypyTypeNode(AnyType{ type_of_any: .special_form }),
		MypyTypeNode(AnyType{
			type_of_any: .special_form
		}),
		MypyTypeNode(AnyType{
			type_of_any: .special_form
		}),
	]))

}

pub fn (mut e ExpressionChecker) visit_list_comp_expr(node &ListComprehension) MypyTypeNode {
	e.accept(node.generator.left_expr, none, false, false, false)
	for seq in node.generator.sequences {
		e.accept(seq, none, false, false, false)
	}
	for cond_list in node.generator.condlists {
		for cond in cond_list {
			e.accept(cond, none, false, false, false)
		}
	}
	mut inst := *e.chk.named_type('builtins.list', [])
	inst.args = [MypyTypeNode(AnyType{
		type_of_any: .special_form
	})]
	return MypyTypeNode(inst)

}

pub fn (mut e ExpressionChecker) visit_dict_comp_expr(node &DictionaryComprehension) MypyTypeNode {
	e.accept(node.key, none, false, false, false)
	e.accept(node.value, none, false, false, false)
	for seq in node.sequences {
		e.accept(seq, none, false, false, false)
	}
	for cond_list in node.condlists {
		for cond in cond_list {
			e.accept(cond, none, false, false, false)
		}
	}
	mut inst := *e.chk.named_type('builtins.dict', [])
	inst.args = [
		MypyTypeNode(AnyType{
			type_of_any: .special_form
		}),
		MypyTypeNode(AnyType{
			type_of_any: .special_form
		}),
	]
	return MypyTypeNode(inst)

}

pub fn (mut e ExpressionChecker) visit_set_comp_expr(node &SetComprehension) MypyTypeNode {
	e.accept(node.generator.left_expr, none, false, false, false)
	for seq in node.generator.sequences {
		e.accept(seq, none, false, false, false)
	}
	for cond_list in node.generator.condlists {
		for cond in cond_list {
			e.accept(cond, none, false, false, false)
		}
	}
	mut inst := *e.chk.named_type('builtins.set', [])
	inst.args = [MypyTypeNode(AnyType{
		type_of_any: .special_form
	})]
	return MypyTypeNode(inst)

}

// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// SliceExpr / IndexExpr
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) visit_slice_expr(node &SliceExpr) MypyTypeNode {
	if begin := node.begin_index {
		e.accept(begin, none, false, false, false)
	}
	if end := node.end_index {
		e.accept(end, none, false, false, false)
	}
	if stride := node.stride {
		e.accept(stride, none, false, false, false)
	}
	return MypyTypeNode(*e.chk.named_type('builtins.slice', []))
}

pub fn (mut e ExpressionChecker) visit_index_expr(node &IndexExpr) MypyTypeNode {
	// Р•СЃР»Рё СЌС‚Рѕ СѓР¶Рµ РїСЂРѕР°РЅР°Р»РёР·РёСЂРѕРІР°РЅРЅРѕРµ СЃРїРµС†РёР°Р»СЊРЅРѕРµ РІС‹СЂР°Р¶РµРЅРёРµ (TypeApplication Рё С‚.Рґ.)
	if a := node.analyzed {
		return e.accept(a, none, false, false, false)
	}

	base_type := e.accept(node.base_, none, false, false, false)
	index_type := e.accept(node.index, none, false, false, false)

	getitem := e.analyze_member_access_type('__getitem__', base_type, node.base.ctx)
	if getitem is CallableType {
		ret, _ := e.check_callable_call(getitem as CallableType, [node.index], [ArgKind.arg_pos], node.base.ctx, [
			?string(none),
		], none, '__getitem__', none)
		return ret
	}

	// РЎРїРµС†РёР°Р»СЊРЅС‹Р№ СЃР»СѓС‡Р°Р№ РґР»СЏ СЃР»РѕРІР°СЂРµР№ Рё СЃРїРёСЃРєРѕРІ вЂ” РІРѕР·РІСЂР°С‰Р°РµРј РїР°СЂР°РјРµС‚СЂ С‚РёРїР°
	if base_type is Instance {
		inst := base_type as Instance
		if inst.args.len > 0 {
			// list[T][int] в†’ T; dict[K, V][K] в†’ V
			if inst.type_name in ['builtins.list', 'builtins.tuple', 'builtins.set'] {
				return inst.args[0]
			}
			if inst.type_name == 'builtins.dict' && inst.args.len >= 2 {
				return inst.args[1]
			}
		}
	}

	_ = index_type
	return MypyTypeNode(AnyType{
		type_of_any: .from_error
	})
}

// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// LambdaExpr / YieldExpr / YieldFromExpr / AwaitExpr
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) visit_lambda_expr(node &LambdaExpr) MypyTypeNode {
	// РђРЅР°Р»РёР·РёСЂСѓРµРј С‚РµР»Рѕ, РёРіРЅРѕСЂРёСЂСѓСЏ С‚РёРї РІРѕР·РІСЂР°С‚Р°
	old_in_lambda := e.in_lambda_expr
	e.in_lambda_expr = true
	body_type := e.accept(node.body, none, false, false, false)
	e.in_lambda_expr = old_in_lambda

	// РђСЂРіСѓРјРµРЅС‚С‹ вЂ” All Any (РЅРµС‚ Р°РЅРЅРѕС‚Р°С†РёР№ Сѓ lambda)
	mut arg_types := []MypyTypeNode{}
	mut arg_kinds := []ArgKind{}
	mut arg_names := []?string{}
	for arg in node.arg_names {
		arg_types << MypyTypeNode(AnyType{
			type_of_any: .unannotated
		})
		arg_kinds << ArgKind.arg_pos
		arg_names << ?string(arg)
	}

	return MypyTypeNode(CallableType{
		arg_types:   arg_types
		arg_kinds:   arg_kinds
		arg_names:   arg_names
		ret_type:    body_type
		fallback:    *e.chk.named_type('builtins.function', [])
		is_type_obj: false
	})
}


pub fn (mut e ExpressionChecker) visit_yield_expr(node &YieldExpr) MypyTypeNode {
	if expr := node.expr {
		e.accept(expr, none, false, false, false)
	}
	// Р—РЅР°С‡РµРЅРёРµ, РєРѕС‚РѕСЂРѕРµ РіРµРЅРµСЂР°С‚РѕСЂ РїРѕР»СѓС‡Р°РµС‚ РїРѕСЃР»Рµ yield (С‚РёРї send)
	return MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
}

pub fn (mut e ExpressionChecker) visit_yield_from_expr(node &YieldFromExpr, allow_none_return bool) MypyTypeNode {
	e.accept(node.expr, none, allow_none_return, false, false)

	// Р—РЅР°С‡РµРЅРёРµ СЂРµР·СѓР»СЊС‚Р°С‚Р° yield from (return РёР· РґРµР»РµРіРёСЂРѕРІР°РЅРЅРѕРіРѕ РіРµРЅРµСЂР°С‚РѕСЂР°)
	return MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
}

pub fn (mut e ExpressionChecker) visit_await_expr(node &AwaitExpr) MypyTypeNode {
	// await expr в†’ С‚РёРї __await__ в†’ С‚РёРї СЂРµР·СѓР»СЊС‚Р°С‚Р° coroutine
	expr_type := e.accept(node.expr, none, false, false, false)
	// РС‰РµРј __await__
	await_type := e.analyze_member_access_type('__await__', expr_type, node.base.ctx)
	if await_type is CallableType {
		// __await__() в†’ Generator[Any, None, T]; РЅР°СЃ РёРЅС‚РµСЂРµСЃСѓРµС‚ T
		ret, _ := e.check_callable_call(await_type as CallableType, [], [], node.base.ctx, [], none, '__await__',
			none)
		if ret is Instance {
			inst := ret as Instance
			if inst.type_name == 'typing.Generator' && inst.args.len >= 3 {
				return inst.args[2]
			}
		}
	}
	return MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
}

// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// ConditionalExpr / AssignmentExpr / RevealExpr
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) visit_conditional_expr(node &ConditionalExpr) MypyTypeNode {
	// cond if test else alt
	e.accept(node.cond, MypyTypeNode(*e.chk.named_type('builtins.bool', [])), false, false, false)

	if_type := e.accept(node.if_expr, e.type_context.last() or { MypyTypeNode(AnyType{type_of_any: .from_error}) }, false, false,
		false)
	else_type := e.accept(node.else_expr, e.type_context.last() or { MypyTypeNode(AnyType{type_of_any: .from_error}) }, false, false,
		false)
	// TODO: return make_simplified_union([if_type, else_type])
	return if_type
}

pub fn (mut e ExpressionChecker) visit_assignment_expr(node &AssignmentExpr) MypyTypeNode {
	// Walrus-РѕРїРµСЂР°С‚РѕСЂ: target := value
	value_type := e.accept(node.value, none, false, false, false)
	// РЎРѕС…СЂР°РЅСЏРµРј С‚РёРї С†РµР»Рё РІ checker
	// e.chk.store_type(node.target, value_type)
	return value_type
}

pub fn (mut e ExpressionChecker) visit_reveal_expr(node &RevealExpr) MypyTypeNode {
	// reveal_type(expr) / reveal_locals()
	if node.kind == reveal_type {
		// reveal_type(node.expr)
		if inner := node.expr {
			typ := e.accept(inner, none, false, false, false)
			// e.msg.reveal_type(typ, node.base.ctx)
			return typ
		}
	}
	return MypyTypeNode(NoneType{})
}

// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// method_fullname / named_type helpers
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) method_fullname(object_type MypyTypeNode, method_name string) ?string {
	proper := get_proper_type(object_type)

	mut type_name := ?string(none)
	if proper is Instance {
		inst := proper as Instance
		type_name = inst.type_name
	} else if proper is CallableType {
		c := proper as CallableType
		if c.is_type_obj {
			ret := get_proper_type(c.ret_type)
			if ret is Instance {
				r_inst := ret as Instance
				type_name = r_inst.type_name
			}
		}
	} else if proper is TupleType {
		fb := (proper as TupleType).partial_fallback
		type_name = fb.type_name
	} else if proper is TypeType {
		inner := get_proper_type((proper as TypeType).item)
		if inner is Instance {
			inst := inner as Instance
			type_name = inst.type_name
		}
	}

	if tn := type_name {
		return '${tn}.${method_name}'
	}
	return none
}


pub fn (mut e ExpressionChecker) named_type(fullname string) MypyTypeNode {
	return MypyTypeNode(e.chk.named_type(fullname, []))
}

pub fn (mut e ExpressionChecker) object_type() MypyTypeNode {
	return MypyTypeNode(*e.chk.named_type('builtins.object', []))
}


// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// TypedDict helpers (Р·Р°РіР»СѓС€РєРё)
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) refers_to_typeddict(base Expression) bool {
	match base {
		NameExpr {
			if nn := base.node {
				if nn is TypeInfo {
					ti := nn as TypeInfo
					return ti.is_protocol // placeholder
				}
			}
		}
		MemberExpr {
			if nn := base.node {
				if nn is TypeInfo {
					ti := nn as TypeInfo
					return ti.is_protocol 
				}
			}
		}
		else {}
	}
	return false
}

pub fn (mut e ExpressionChecker) typeddict_callable(info &TypeInfo) MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
}

pub fn (mut e ExpressionChecker) typeddict_callable_from_context(callee &TypedDictType, variables []MypyTypeNode) MypyTypeNode {
	mut arg_types := []MypyTypeNode{}
	mut arg_kinds := []ArgKind{}
	mut arg_names := []?string{}
	for name, typ in callee.items {
		arg_types << typ
		if name in callee.required_keys {
			arg_kinds << ArgKind.arg_named
		} else {
			arg_kinds << ArgKind.arg_named_opt
		}
		arg_names << ?string(name)
	}
	return MypyTypeNode(CallableType{
		arg_types:   arg_types
		arg_kinds:   arg_kinds
		arg_names:   arg_names
		ret_type:    MypyTypeNode(callee)
		fallback:    *e.chk.named_type('builtins.type', [])
		is_type_obj: true
	})
}


// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// try_infer_partial_type / get_partial_var (Р·Р°РіР»СѓС€РєРё)
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) try_infer_partial_type(node &CallExpr) {
	if node.callee !is MemberExpr {
		return
	}
	callee := node.callee as MemberExpr
	match callee.expr {
		NameExpr {
			// placeholder
		}
		else {}
	}
}

pub fn (mut e ExpressionChecker) get_partial_var(node Expression) ?(&Var, map[string]Context) {
	match node {
		NameExpr {
			if nn := node.node {
				if nn is Var {
					v := nn as Var
					return &v, map[string]Context{}
				}
			}
		}
		else {}
	}
	return none
}

// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// РџСЂРѕРІРµСЂРєР° runtime-РїСЂРѕС‚РѕРєРѕР»Р° / issubclass
// в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

pub fn (mut e ExpressionChecker) check_runtime_protocol_test(node &CallExpr) {
	if node.args.len < 2 {
		return
	}
	tp := get_proper_type(e.chk.lookup_type(node.args[1]))
	if tp is Instance {
		// inst := tp as Instance
		// placeholder
	}
}

pub fn (mut e ExpressionChecker) check_protocol_issubclass(node &CallExpr) {
	if node.args.len < 2 {
		return
	}
	tp := get_proper_type(e.chk.lookup_type(node.args[1]))
	if tp is Instance {
		// placeholder
	}
}

