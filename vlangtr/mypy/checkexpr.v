// checkexpr.v — Expression type checker
// Translated from mypy/checkexpr.py
// Bridge implementation aligned with the current V AST/type layer.

module mypy

pub const max_unions = 5

pub struct TooManyUnions {
	Error
}

pub struct Finished {
	Error
}

pub enum UseReverse {
	standard
	always
	never
}

pub struct ExpressionChecker {
pub mut:
	chk                         &TypeChecker
	msg                         MessageBuilder
	type_context                []?MypyTypeNode
	strfrm_checker              StringFormatterChecker
	plugin                      Plugin
	type_overrides              map[string]MypyTypeNode
	is_callee                   bool
	in_expression               bool
	collect_line_checking_stats bool
	per_line_checking_time_ns   map[int]int
	expr_cache                  map[string]MypyTypeNode
	in_lambda_expr              bool
	literal_true_               ?Instance
	literal_false_              ?Instance
}

pub fn new_expression_checker(chk &TypeChecker, msg MessageBuilder, plugin Plugin) ExpressionChecker {
	return ExpressionChecker{
		chk:                         chk
		msg:                         msg
		type_context:                [?MypyTypeNode(none)]
		strfrm_checker:              StringFormatterChecker{
			chk: unsafe { nil }
			msg: unsafe { nil }
		}
		plugin:                      plugin
		type_overrides:              map[string]MypyTypeNode{}
		is_callee:                   false
		in_expression:               false
		collect_line_checking_stats: false
		per_line_checking_time_ns:   map[int]int{}
		expr_cache:                  map[string]MypyTypeNode{}
		in_lambda_expr:              false
		literal_true_:               none
		literal_false_:              none
	}
}

pub fn (mut ec ExpressionChecker) reset() {
	ec.expr_cache.clear()
}

pub fn (mut ec ExpressionChecker) accept(node Expression) MypyTypeNode {
	typ := match node {
		AssignmentExpr { ec.visit_assignment_expr(node) }
		AwaitExpr { ec.visit_await_expr(node) }
		BytesExpr { ec.visit_bytes_expr(node) }
		CallExpr { ec.visit_call_expr(node, false) }
		CastExpr { ec.visit_cast_expr(node) }
		ComparisonExpr { ec.visit_comparison_expr(node) }
		ComplexExpr { ec.visit_complex_expr(node) }
		ConditionalExpr { ec.visit_conditional_expr(node) }
		DictExpr { ec.visit_dict_expr(node) }
		DictionaryComprehension { ec.visit_dictionary_comprehension(node) }
		EllipsisExpr { ec.visit_ellipsis(node) }
		EnumCallExpr { ec.visit_enum_call_expr(node) }
		FloatExpr { ec.visit_float_expr(node) }
		GeneratorExpr { ec.visit_generator_expr(node) }
		IndexExpr { ec.visit_index_expr(node) }
		IntExpr { ec.visit_int_expr(node) }
		LambdaExpr { ec.visit_lambda_expr(node) }
		ListComprehension { ec.visit_list_comprehension(node) }
		ListExpr { ec.visit_list_expr(node) }
		MemberExpr { ec.visit_member_expr(node, false) }
		NameExpr { ec.visit_name_expr(node) }
		NamedTupleExpr { ec.visit_namedtuple_expr(node) }
		NewTypeExpr { ec.visit_newtype_expr(node) }
		OpExpr { ec.visit_op_expr(node) }
		ParamSpecExpr { ec.visit_paramspec_expr(node) }
		PromoteExpr { ec.visit_promote_expr(node) }
		RevealExpr { ec.visit_reveal_expr(node) }
		SetComprehension { ec.visit_set_comprehension(node) }
		SetExpr { ec.visit_set_expr(node) }
		SliceExpr { ec.visit_slice_expr(node) }
		StarExpr { ec.visit_star_expr(node) }
		StrExpr { ec.visit_str_expr(node) }
		SuperExpr { ec.visit_super_expr(node) }
		TempNode { ec.visit_temp_node(node) }
		TemplateStrExpr { ec.visit_template_str_expr(node) }
		TupleExpr { ec.visit_tuple_expr(node) }
		TypeAliasExpr { ec.visit_type_alias_expr(node) }
		TypeApplication {
			AnyType{
				type_of_any: .special_form
			}
		}
		TypeVarExpr {
			AnyType{
				type_of_any: .special_form
			}
		}
		TypeVarTupleExpr {
			AnyType{
				type_of_any: .special_form
			}
		}
		TypedDictExpr {
			AnyType{
				type_of_any: .special_form
			}
		}
		UnaryExpr { ec.visit_unary_expr(node) }
		AssertTypeExpr { ec.visit_assert_type_expr(node) }
		YieldExpr { ec.visit_yield_expr(node) }
		YieldFromExpr { ec.visit_yield_from_expr(node) }
		FormatStringExpr {
			AnyType{
				type_of_any: .special_form
			}
		}
	}
	return typ
}

pub fn (mut ec ExpressionChecker) visit_name_expr(e NameExpr) MypyTypeNode {
	result := ec.analyze_ref_expr(e)
	return ec.narrow_type_from_binder(e, result)
}

pub fn (mut ec ExpressionChecker) analyze_ref_expr(e RefExpr) MypyTypeNode {
	if e is NameExpr && e.is_special_form {
		return AnyType{
			type_of_any: .special_form
		}
	}
	if node := e.node {
		return match node {
			Var {
				ec.analyze_var_ref(node)
			}
			Decorator {
				ec.analyze_var_ref(node.var_)
			}
			OverloadedFuncDef {
				node.type_ or {
					AnyType{
						type_of_any: .from_error
					}
				}
			}
			FuncDef, TypeInfo, TypeAlias {
				ec.analyze_static_reference(node)
			}
			else {
				AnyType{
					type_of_any: .from_error
				}
			}
		}
	}
	return AnyType{
		type_of_any: .from_error
	}
}

pub fn (ec ExpressionChecker) analyze_static_reference(node SymbolNodeRef) MypyTypeNode {
	return match node {
		Var {
			node.type_ or {
				AnyType{
					type_of_any: .special_form
				}
			}
		}
		Decorator {
			node.var_.type_ or {
				AnyType{
					type_of_any: .special_form
				}
			}
		}
		OverloadedFuncDef {
			node.type_ or {
				AnyType{
					type_of_any: .special_form
				}
			}
		}
		FuncDef {
			function_type(node, ec.named_type('builtins.function'))
		}
		TypeInfo {
			ec.chk.type_type()
		}
		TypeAlias {
			AnyType{
				type_of_any: .special_form
			}
		}
		ClassDef, MypyFile {
			AnyType{
				type_of_any: .special_form
			}
		}
		PlaceholderNode {
			AnyType{
				type_of_any: .special_form
			}
		}
		else {
			AnyType{
				type_of_any: .special_form
			}
		}
	}
}

pub fn (ec ExpressionChecker) analyze_var_ref(v Var) MypyTypeNode {
	if t := v.type_ {
		return t
	}
	return AnyType{
		type_of_any: .special_form
	}
}

pub fn (mut ec ExpressionChecker) visit_call_expr(e CallExpr, allow_none_return bool) MypyTypeNode {
	return ec.visit_call_expr_inner(e, allow_none_return)
}

pub fn (mut ec ExpressionChecker) visit_call_expr_inner(e CallExpr, allow_none_return bool) MypyTypeNode {
	_ = allow_none_return
	old_is_callee := ec.is_callee
	ec.is_callee = true
	callee_type := ec.accept(e.callee)
	ec.is_callee = old_is_callee
	return ec.check_call_expr_with_callee_type(callee_type, e)
}

pub fn (mut ec ExpressionChecker) check_call_expr_with_callee_type(callee_type MypyTypeNode, e CallExpr) MypyTypeNode {
	ret_type, _ := ec.check_call(callee_type, e.args, e.arg_kinds, e.base)
	if get_proper_type(ret_type) is UninhabitedType {
		ec.chk.binder.unreachable()
	}
	return ret_type
}

pub fn (mut ec ExpressionChecker) check_call(callee MypyTypeNode, args []Expression, arg_kinds []ArgKind, context NodeBase) (MypyTypeNode, MypyTypeNode) {
	proper_callee := get_proper_type(callee)
	if proper_callee is CallableType {
		return ec.check_callable_call(proper_callee, args, arg_kinds, context)
	}
	if proper_callee is AnyType {
		return ec.check_any_type_call(args, arg_kinds, proper_callee, context)
	}
	if proper_callee is Overloaded {
		if proper_callee.items.len > 0 {
			return ec.check_callable_call(*proper_callee.items[0], args, arg_kinds, context)
		}
		return ec.check_any_type_call(args, arg_kinds, AnyType{
			type_of_any: .from_error
		}, context)
	}
	if proper_callee is Instance {
		call_method := analyze_member_access('__call__', callee, context.ctx, false, false,
			false, callee, mut ec.chk, false)
		return ec.check_call(call_method, args, arg_kinds, context)
	}
	return ec.msg.not_callable(callee, context.ctx), callee
}

pub fn (mut ec ExpressionChecker) check_callable_call(callee CallableType, args []Expression, arg_kinds []ArgKind, context NodeBase) (MypyTypeNode, MypyTypeNode) {
	_ = arg_kinds
	for arg in args {
		ec.accept(arg)
	}
	return callee.ret_type, callee
}

pub fn (ec ExpressionChecker) check_any_type_call(args []Expression, arg_kinds []ArgKind, callee MypyTypeNode, context NodeBase) (MypyTypeNode, MypyTypeNode) {
	_ = args
	_ = arg_kinds
	_ = callee
	_ = context
	typ := AnyType{
		type_of_any: .from_untyped_call
	}
	return typ, typ
}

pub fn (mut ec ExpressionChecker) visit_member_expr(e MemberExpr, is_lvalue bool) MypyTypeNode {
	result := ec.analyze_ordinary_member_access(e, is_lvalue)
	return ec.narrow_type_from_binder(e, result)
}

pub fn (mut ec ExpressionChecker) analyze_ordinary_member_access(e MemberExpr, is_lvalue bool) MypyTypeNode {
	original_type := ec.accept(e.expr)
	return analyze_member_access(e.name, original_type, e.base.ctx, is_lvalue, false,
		false, original_type, mut ec.chk, false)
}

pub fn (mut ec ExpressionChecker) visit_index_expr(e IndexExpr) MypyTypeNode {
	left_type := ec.accept(e.base_)
	return ec.visit_index_with_type(left_type, e)
}

pub fn (mut ec ExpressionChecker) visit_index_with_type(left_type MypyTypeNode, e IndexExpr) MypyTypeNode {
	index_type := ec.accept(e.index)
	left_proper := get_proper_type(left_type)
	if left_proper is TupleType {
		tuple_type := left_proper
		if e.index is IntExpr {
			idx := e.index.value
			if idx >= 0 && idx < tuple_type.items.len {
				return tuple_type.items[idx]
			}
		}
	}
	result, _ := ec.check_method_call_by_name('__getitem__', left_type, [e.index], [
		.arg_pos,
	], e.base)
	if get_proper_type(result) is AnyType {
		_ = index_type
	}
	return result
}

pub fn (mut ec ExpressionChecker) visit_typeddict_index_expr(td TypedDictType, index Expression) MypyTypeNode {
	if index is StrExpr {
		if index.value in td.items {
			return td.items[index.value]
		}
	}
	ec.msg.fail('Invalid TypedDict key access', index.get_context(), false, false, none)
	return AnyType{
		type_of_any: .from_error
	}
}

pub fn (mut ec ExpressionChecker) visit_op_expr(e OpExpr) MypyTypeNode {
	if e.op == 'and' || e.op == 'or' {
		return ec.check_boolean_op(e)
	}
	if e.op in op_methods {
		left_type := ec.accept(e.left)
		result, _ := ec.check_op(op_methods[e.op], left_type, e.right, e.base)
		return result
	}
	ec.accept(e.left)
	ec.accept(e.right)
	return AnyType{
		type_of_any: .from_error
	}
}

pub fn (mut ec ExpressionChecker) check_boolean_op(e OpExpr) MypyTypeNode {
	left_type := ec.accept(e.left)
	right_type := ec.accept(e.right)
	return expr_union([left_type, right_type])
}

pub fn (mut ec ExpressionChecker) check_op(method string, base_type MypyTypeNode, arg Expression, context NodeBase) (MypyTypeNode, MypyTypeNode) {
	return ec.check_method_call_by_name(method, base_type, [arg], [.arg_pos], context)
}

pub fn (mut ec ExpressionChecker) check_method_call_by_name(method string, base_type MypyTypeNode, args []Expression, arg_kinds []ArgKind, context NodeBase) (MypyTypeNode, MypyTypeNode) {
	method_type := analyze_member_access(method, base_type, context.ctx, false, false,
		true, base_type, mut ec.chk, false)
	return ec.check_call(method_type, args, arg_kinds, context)
}

pub fn (mut ec ExpressionChecker) visit_unary_expr(e UnaryExpr) MypyTypeNode {
	operand_type := ec.accept(e.expr)
	if e.op == 'not' {
		return ec.bool_type()
	}
	if e.op in unary_op_methods {
		result, _ := ec.check_method_call_by_name(unary_op_methods[e.op], operand_type,
			[]Expression{}, []ArgKind{}, e.base)
		return result
	}
	return AnyType{
		type_of_any: .from_error
	}
}

pub fn (mut ec ExpressionChecker) visit_comparison_expr(e ComparisonExpr) MypyTypeNode {
	for operand in e.operands {
		ec.accept(operand)
	}
	return ec.bool_type()
}

pub fn (mut ec ExpressionChecker) visit_assignment_expr(e AssignmentExpr) MypyTypeNode {
	value := ec.accept(e.value)
	if lval := e.target.as_lvalue() {
		ec.chk.check_assignment(lval, e.value)
	}
	ec.chk.store_type(e.target, value)
	return value
}

pub fn (mut ec ExpressionChecker) visit_list_expr(e ListExpr) MypyTypeNode {
	return ec.check_lst_expr(e.items, 'builtins.list')
}

pub fn (mut ec ExpressionChecker) visit_set_expr(e SetExpr) MypyTypeNode {
	return ec.check_lst_expr(e.items, 'builtins.set')
}

fn (mut ec ExpressionChecker) check_lst_expr(items []Expression, fullname string) MypyTypeNode {
	mut item_types := []MypyTypeNode{}
	for item in items {
		if item is StarExpr {
			item_types << ec.accept(item.expr)
		} else {
			item_types << ec.accept(item)
		}
	}
	item_type := if item_types.len > 0 {
		expr_union(item_types)
	} else {
		MypyTypeNode(AnyType{
			type_of_any: .special_form
		})
	}
	return ec.chk.named_generic_type(fullname, [item_type])
}

pub fn (mut ec ExpressionChecker) visit_dict_expr(e DictExpr) MypyTypeNode {
	mut key_types := []MypyTypeNode{}
	mut value_types := []MypyTypeNode{}
	for item in e.items {
		if k := item.key {
			key_types << ec.accept(k)
		}
		value_types << ec.accept(item.value)
	}
	key_type := if key_types.len > 0 {
		expr_union(key_types)
	} else {
		MypyTypeNode(AnyType{
			type_of_any: .special_form
		})
	}
	value_type := if value_types.len > 0 {
		expr_union(value_types)
	} else {
		MypyTypeNode(AnyType{
			type_of_any: .special_form
		})
	}
	return ec.chk.named_generic_type('builtins.dict', [key_type, value_type])
}

pub fn (mut ec ExpressionChecker) visit_tuple_expr(e TupleExpr) MypyTypeNode {
	mut items := []MypyTypeNode{}
	for item in e.items {
		items << ec.accept(item)
	}
	return TupleType{
		items: items
	}
}

pub fn (mut ec ExpressionChecker) visit_conditional_expr(e ConditionalExpr) MypyTypeNode {
	ec.accept(e.cond)
	return expr_union([ec.accept(e.if_expr), ec.accept(e.else_expr)])
}

pub fn (mut ec ExpressionChecker) visit_lambda_expr(e LambdaExpr) MypyTypeNode {
	ret_type := ec.accept(e.body)
	return callable_type_from_lambda(e, ec.named_type('builtins.function'), ret_type)
}

pub fn (ec ExpressionChecker) visit_int_expr(e IntExpr) MypyTypeNode {
	return ec.infer_literal_expr_type(e.value.str(), 'builtins.int')
}

pub fn (ec ExpressionChecker) visit_str_expr(e StrExpr) MypyTypeNode {
	return ec.infer_literal_expr_type(e.value, 'builtins.str')
}

pub fn (ec ExpressionChecker) visit_bytes_expr(e BytesExpr) MypyTypeNode {
	return ec.named_type('builtins.bytes')
}

pub fn (ec ExpressionChecker) visit_float_expr(e FloatExpr) MypyTypeNode {
	return ec.named_type('builtins.float')
}

pub fn (ec ExpressionChecker) visit_complex_expr(e ComplexExpr) MypyTypeNode {
	return ec.named_type('builtins.complex')
}

pub fn (ec ExpressionChecker) visit_ellipsis(e EllipsisExpr) MypyTypeNode {
	return ec.named_type('builtins.ellipsis')
}

pub fn (ec ExpressionChecker) infer_literal_expr_type(value string, fallback_name string) MypyTypeNode {
	_ = value
	return ec.named_type(fallback_name)
}

pub fn (mut ec ExpressionChecker) visit_list_comprehension(e ListComprehension) MypyTypeNode {
	return ec.chk.named_generic_type('builtins.list', [
		ec.visit_generator_expr(e.generator),
	])
}

pub fn (mut ec ExpressionChecker) visit_generator_expr(e GeneratorExpr) MypyTypeNode {
	ec.accept(e.left_expr)
	for seq in e.sequences {
		ec.accept(seq)
	}
	for conds in e.condlists {
		for cond in conds {
			ec.accept(cond)
		}
	}
	return AnyType{
		type_of_any: .special_form
	}
}

pub fn (mut ec ExpressionChecker) visit_set_comprehension(e SetComprehension) MypyTypeNode {
	return ec.chk.named_generic_type('builtins.set', [
		ec.visit_generator_expr(e.generator),
	])
}

pub fn (mut ec ExpressionChecker) visit_dictionary_comprehension(e DictionaryComprehension) MypyTypeNode {
	key_type := ec.accept(e.key)
	value_type := ec.accept(e.value)
	for seq in e.sequences {
		ec.accept(seq)
	}
	for conds in e.condlists {
		for cond in conds {
			ec.accept(cond)
		}
	}
	return ec.chk.named_generic_type('builtins.dict', [key_type, value_type])
}

pub fn (mut ec ExpressionChecker) visit_cast_expr(e CastExpr) MypyTypeNode {
	ec.accept(e.expr)
	if t := e.type {
		return t
	}
	return AnyType{
		type_of_any: .from_error
	}
}

pub fn (mut ec ExpressionChecker) visit_assert_type_expr(e AssertTypeExpr) MypyTypeNode {
	return ec.accept(e.expr)
}

pub fn (mut ec ExpressionChecker) visit_reveal_expr(e RevealExpr) MypyTypeNode {
	return ec.accept(e.expr)
}

pub fn (mut ec ExpressionChecker) visit_yield_expr(e YieldExpr) MypyTypeNode {
	if expr := e.expr {
		ec.accept(expr)
	}
	return NoneType{}
}

pub fn (mut ec ExpressionChecker) visit_yield_from_expr(e YieldFromExpr) MypyTypeNode {
	return ec.accept(e.expr)
}

pub fn (mut ec ExpressionChecker) visit_await_expr(e AwaitExpr) MypyTypeNode {
	actual_type := ec.accept(e.expr)
	return ec.check_awaitable_expr(actual_type, e.base)
}

pub fn (mut ec ExpressionChecker) check_awaitable_expr(t MypyTypeNode, ctx NodeBase) MypyTypeNode {
	result, _ := ec.check_method_call_by_name('__await__', t, []Expression{}, []ArgKind{},
		ctx)
	return result
}

pub fn (ec ExpressionChecker) visit_temp_node(e TempNode) MypyTypeNode {
	return e.type_
}

pub fn (mut ec ExpressionChecker) visit_star_expr(e StarExpr) MypyTypeNode {
	return ec.accept(e.expr)
}

pub fn (mut ec ExpressionChecker) visit_slice_expr(e SliceExpr) MypyTypeNode {
	if b := e.begin {
		ec.accept(b)
	}
	if end := e.end {
		ec.accept(end)
	}
	if stride := e.step {
		ec.accept(stride)
	}
	return ec.named_type('builtins.slice')
}

pub fn (mut ec ExpressionChecker) visit_super_expr(e SuperExpr) MypyTypeNode {
	_ = e
	return ec.object_type()
}

pub fn (mut ec ExpressionChecker) visit_template_str_expr(e TemplateStrExpr) MypyTypeNode {
	return ec.named_type('builtins.str')
}

pub fn (mut ec ExpressionChecker) visit_type_alias_expr(e TypeAliasExpr) MypyTypeNode {
	_ = e
	return ec.named_type('builtins.type')
}

pub fn (mut ec ExpressionChecker) visit_namedtuple_expr(e NamedTupleExpr) MypyTypeNode {
	_ = e
	return ec.named_type('builtins.tuple')
}

pub fn (mut ec ExpressionChecker) visit_newtype_expr(e NewTypeExpr) MypyTypeNode {
	_ = e
	return ec.named_type('builtins.type')
}

pub fn (mut ec ExpressionChecker) visit_paramspec_expr(e ParamSpecExpr) MypyTypeNode {
	_ = e
	return AnyType{
		type_of_any: .special_form
	}
}

pub fn (mut ec ExpressionChecker) visit_promote_expr(e PromoteExpr) MypyTypeNode {
	return e.type_
}

pub fn (mut ec ExpressionChecker) visit_enum_call_expr(e EnumCallExpr) MypyTypeNode {
	_ = e
	return ec.named_type('builtins.object')
}

pub fn (ec ExpressionChecker) named_type(name string) Instance {
	return ec.chk.named_type(name)
}

pub fn (ec ExpressionChecker) object_type() Instance {
	return ec.named_type('builtins.object')
}

pub fn (ec ExpressionChecker) bool_type() Instance {
	return ec.named_type('builtins.bool')
}

pub fn (ec ExpressionChecker) narrow_type_from_binder(e Expression, known_type MypyTypeNode) MypyTypeNode {
	if literal(e) >= literal_type {
		if restriction := ec.chk.binder.get(e.str()) {
			return restriction
		}
	}
	return known_type
}

pub fn (ec ExpressionChecker) typeddict_callable(info TypeInfo, td TypedDictType) MypyTypeNode {
	return CallableType{
		arg_types: []MypyTypeNode{}
		arg_kinds: []ArgKind{}
		arg_names: []string{}
		ret_type:  ec.named_type(info.fullname)
		variables: []MypyTypeNode{}
		fallback:  td.fallback
	}
}

fn callable_type_from_lambda(e LambdaExpr, fallback Instance, ret_type MypyTypeNode) CallableType {
	mut arg_types := []MypyTypeNode{}
	mut arg_names := []string{}
	for arg in e.arguments {
		arg_types << (arg.variable.type_ or {
			MypyTypeNode(AnyType{
				type_of_any: .special_form
			})
		})
		arg_names << arg.variable.name
	}
	fallback_ptr := &Instance{
		typ:       fallback.typ
		type_:     fallback.type_
		args:      fallback.args.clone()
		type_name: fallback.type_name
	}
	return CallableType{
		arg_types: arg_types
		arg_kinds: e.arg_kinds
		arg_names: arg_names
		ret_type:  ret_type
		variables: []MypyTypeNode{}
		fallback:  fallback_ptr
	}
}

fn expr_union(items []MypyTypeNode) MypyTypeNode {
	if items.len == 0 {
		return AnyType{
			type_of_any: .special_form
		}
	}
	if items.len == 1 {
		return items[0]
	}
	return UnionType{
		items: items
	}
}
