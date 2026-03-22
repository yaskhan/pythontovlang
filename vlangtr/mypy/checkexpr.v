// checkexpr.v — Expression type checker
// Translated from mypy/checkexpr.py
// Note: this is a very large file (~4000 lines), main structures and key functions are translated

module mypy

// Constants
pub const max_unions = 5

// TooManyUnions — exception for exceeding union math limit
pub struct TooManyUnions {
	Error
}

// Finished — exception for early termination of overload check
pub struct Finished {
	Error
}

// UseReverse — used in visit_op_expr for managing reverse method checks
pub enum UseReverse {
	standard
	always
	never
}

// ExpressionChecker — expression type checker
pub struct ExpressionChecker {
pub mut:
	chk                         &TypeChecker
	msg                         MessageBuilder
	type_context                []?MypyTypeNode
	strfrm_checker              StringFormatterChecker
	plugin                      Plugin
	type_overrides              map[Expression]MypyTypeNode
	is_callee                   bool
	in_expression               bool
	collect_line_checking_stats bool
	per_line_checking_time_ns   map[int]int
	expr_cache                  map[string]MypyTypeNode
	in_lambda_expr              bool
	_literal_true               ?InstanceNode
	_literal_false              ?InstanceNode
}

// new_expression_checker создаёт новый ExpressionChecker
pub fn new_expression_checker(chk &TypeChecker, msg MessageBuilder, plugin Plugin) ExpressionChecker {
	return ExpressionChecker{
		chk:                         chk
		msg:                         msg
		type_context:                [?MypyTypeNode(none)]
		strfrm_checker:              StringFormatterChecker{}
		plugin:                      plugin
		type_overrides:              map[Expression]MypyTypeNode{}
		is_callee:                   false
		in_expression:               false
		collect_line_checking_stats: false
		per_line_checking_time_ns:   map[int]int{}
		expr_cache:                  map[string]MypyTypeNode{}
		in_lambda_expr:              false
		_literal_true:               none
		_literal_false:              none
	}
}

// reset очищает кэш выражений
pub fn (mut ec ExpressionChecker) reset() {
	ec.expr_cache.clear()
}

// visit_name_expr проверяет имя
pub fn (mut ec ExpressionChecker) visit_name_expr(e NameExpr) MypyTypeNode {
	result := ec.analyze_ref_expr(e)
	narrowed := ec.narrow_type_from_binder(e, result)
	ec.chk.check_deprecated(e.node, e)
	return narrowed
}

// analyze_ref_expr анализирует ссылку
pub fn (mut ec ExpressionChecker) analyze_ref_expr(e RefExpr, lvalue bool) MypyTypeNode {
	mut result := ?MypyTypeNode(none)

	if e is NameExpr && e.is_special_form {
		return AnyType{
			type_of_any: TypeOfAny.special_form
		}
	}

	if mut node := e.node {
		if node is Var {
			result = ec.analyze_var_ref(node, e)
		} else if node is Decorator {
			result = ec.analyze_var_ref(node.var_, e)
		} else if node is OverloadedFuncDef {
			if mut t0 := node.type_ {
				result = t0
			} else {
				result = AnyType{
					type_of_any: TypeOfAny.from_error
				}
			}
		} else if node is FuncDef || node is TypeInfo || node is TypeAlias {
			result = ec.analyze_static_reference(node, e)
		} else {
			result = AnyType{
				type_of_any: TypeOfAny.from_error
			}
		}
	} else {
		result = AnyType{
			type_of_any: TypeOfAny.from_error
		}
	}

	return result or {
		AnyType{
			type_of_any: TypeOfAny.from_error
		}
	}
}

// analyze_static_reference анализирует статическую ссылку
pub fn (ec ExpressionChecker) analyze_static_reference(node SymbolNodeRef, ctx NodeBase) MypyTypeNode {
	if node is Var || node is Decorator || node is OverloadedFuncDef {
		if node is Var {
			return node.type_ or { AnyType{ type_of_any: TypeOfAny.special_form } }
		} else if node is Decorator {
			return node.var_.type_ or { AnyType{ type_of_any: TypeOfAny.special_form } }
		} else if node is OverloadedFuncDef {
			return node.type_ or { AnyType{ type_of_any: TypeOfAny.special_form } }
		}
		return AnyType{ type_of_any: TypeOfAny.special_form }
	} else if node is FuncDef {
		// return function_type(node, ec.named_type('builtins.function'))
		return AnyType{ type_of_any: TypeOfAny.special_form }
	} else if node is TypeInfo {
		// if node.typeddict_type != none {
		// 	return ec.typeddict_callable(node)
		// }
		// return type_object_type(node, ec.named_type)
		return AnyType{ type_of_any: TypeOfAny.special_form }
	} else if node is TypeAlias {
		// return ec.alias_type_in_runtime_context(node, ctx)
		return AnyType{ type_of_any: TypeOfAny.special_form }
	}
	return AnyType{
		type_of_any: TypeOfAny.from_error
	}
}

// analyze_var_ref анализирует ссылку на переменную
pub fn (ec ExpressionChecker) analyze_var_ref(var Var, context NodeBase) MypyTypeNode {
	if t := var.type_ {
		return t
	}
	return AnyType{
		type_of_any: TypeOfAny.special_form
	}
}

// visit_call_expr проверяет вызов
pub fn (mut ec ExpressionChecker) visit_call_expr(e CallExpr, allow_none_return bool) MypyTypeNode {
	return ec.visit_call_expr_inner(e, allow_none_return)
}

// visit_call_expr_inner проверяет вызов (внутренняя реализация)
pub fn (mut ec ExpressionChecker) visit_call_expr_inner(e CallExpr, allow_none_return bool) MypyTypeNode {
	// callee_type := ec.accept(e.callee, always_allow_any: true, is_callee: true)
	callee_type := AnyType{ type_of_any: TypeOfAny.special_form }

	mut fullname := ?string(none)
	mut object_type := ?MypyTypeNode(none)
	mut member := ?string(none)

	match e.callee {
		NameExpr { fullname = e.callee.fullname }
		MemberExpr { fullname = e.callee.name }
		else {}
	}

	ret_type := ec.check_call_expr_with_callee_type(callee_type, e, fullname, object_type,
		member)

	return ret_type
}

// check_call_expr_with_callee_type проверяет вызов с типом callee
pub fn (mut ec ExpressionChecker) check_call_expr_with_callee_type(callee_type MypyTypeNode,
	e CallExpr,
	callable_name ?string,
	object_type ?MypyTypeNode,
	member ?string) MypyTypeNode {
	ret_type, _ := ec.check_call(callee_type, e.args, e.arg_kinds, e.base)

	p_ret_type := get_proper_type(ret_type)
	if p_ret_type is UninhabitedType {
		ec.chk.binder.unreachable()
	}

	return ret_type
}

// check_call проверяет вызов
pub fn (mut ec ExpressionChecker) check_call(callee MypyTypeNode,
	args []Expression,
	arg_kinds []ArgKind,
	context NodeBase) (MypyTypeNode, MypyTypeNode) {
	p_callee := get_proper_type(callee)

	if p_callee is CallableType {
		return ec.check_callable_call(p_callee, args, arg_kinds, context)
	} else if p_callee is AnyType {
		return ec.check_any_type_call(args, arg_kinds, p_callee, context)
	} else if p_callee is Instance {
		call_method := analyze_member_access('__call__', p_callee, context.ctx, true, false, false, AnyType{}, ec.chk, false)
		return ec.check_call(call_method, args, arg_kinds, context)
	}

	return AnyType{
		type_of_any: TypeOfAny.from_error
	}, callee
}

// check_callable_call проверяет вызов callable
pub fn (mut ec ExpressionChecker) check_callable_call(callee CallableType,
	args []Expression,
	arg_kinds []ArgKind,
	context NodeBase) (MypyTypeNode, MypyTypeNode) {
	// TODO: полная реализация с проверкой аргументов
	return callee.ret_type, callee
}

// check_any_type_call проверяет вызов Any
pub fn (ec ExpressionChecker) check_any_type_call(args []Expression,
	arg_kinds []ArgKind,
	callee MypyTypeNode,
	context NodeBase) (MypyTypeNode, MypyTypeNode) {
	return AnyType{
		type_of_any: TypeOfAny.from_another_any
	}, AnyType{
		type_of_any: TypeOfAny.from_another_any
	}
}

// visit_member_expr проверяет доступ к атрибуту
pub fn (mut ec ExpressionChecker) visit_member_expr(e MemberExpr, is_lvalue bool) MypyTypeNode {
	result := ec.analyze_ordinary_member_access(e, is_lvalue)
	narrowed := ec.narrow_type_from_binder(e, result)
	ec.chk.warn_deprecated(e.node, e.base)
	return narrowed
}

// analyze_ordinary_member_access анализирует доступ к атрибуту
pub fn (mut ec ExpressionChecker) analyze_ordinary_member_access(e MemberExpr, is_lvalue bool) MypyTypeNode {
	original_type := ec.accept(e.expr, none, false, ec.is_callee, false)

	member_type := analyze_member_access(e.name, original_type, e.base.ctx, false, is_lvalue, false, AnyType{}, ec.chk, false)
		is_lvalue:     is_lvalue
		is_super:      false
		is_operator:   false
		original_type: original_type
		chk:           ec.chk
	)

	return member_type
}

// visit_index_expr проверяет индексацию
pub fn (mut ec ExpressionChecker) visit_index_expr(e IndexExpr) MypyTypeNode {
	if e.analyzed != none {
		return ec.accept(e.analyzed)
	}

	left_type := ec.accept(e.base)
	return ec.visit_index_with_type(left_type, e)
}

// visit_index_with_type проверяет индексацию с типом
pub fn (mut ec ExpressionChecker) visit_index_with_type(left_type MypyTypeNode, e IndexExpr) MypyTypeNode {
	ec.accept(e.index)

	p_left := get_proper_type(left_type)

	if p_left is TupleTypeNode {
		// TODO: специальная обработка tuple indexing
	}

	if p_left is TypedDictTypeNode {
		result, _ := ec.visit_typeddict_index_expr(p_left, e.index)
		return result
	}

	result, _ := ec.check_method_call_by_name('__getitem__', left_type, [e.index], [
		arg_pos,
	], e)
	return result
}

// visit_typeddict_index_expr проверяет индекс TypedDict
pub fn (mut ec ExpressionChecker) visit_typeddict_index_expr(td TypedDictTypeNode, index Expression) (MypyTypeNode, []string) {
	if index is StrExpr {
		key_name := index.value
		if key_name in td.items {
			return td.items[key_name], [key_name]
		}
		ec.msg.typeddict_key_not_found(td, key_name, index)
		return AnyTypeNode{
			reason: TypeOfAny.from_error
		}, []
	}

	ec.msg.typeddict_key_must_be_string_literal(td, index)
	return AnyTypeNode{
		reason: TypeOfAny.from_error
	}, []
}

// visit_op_expr проверяет бинарный оператор
pub fn (mut ec ExpressionChecker) visit_op_expr(e OpExpr) MypyTypeNode {
	if e.analyzed != none {
		return ec.accept(e.analyzed)
	}

	if e.op == 'and' || e.op == 'or' {
		return ec.check_boolean_op(e)
	}

	if e.op in operators.op_methods {
		method := operators.op_methods[e.op]
		left_type := ec.accept(e.left)
		result, _ := ec.check_op(method, left_type, e.right, e)
		return result
	}

	panic('Unknown operator ${e.op}')
}

// check_boolean_op проверяет булев оператор
pub fn (mut ec ExpressionChecker) check_boolean_op(e OpExpr) MypyTypeNode {
	left_type := ec.accept(e.left)

	left_map, right_map := ec.chk.find_isinstance_check(e.left)

	right_type := ec.analyze_cond_branch(right_map, e.right)

	return make_simplified_union([left_type, right_type])
}

// check_op проверяет оператор
pub fn (mut ec ExpressionChecker) check_op(method string,
	base_type MypyTypeNode,
	arg Expression,
	context NodeBase) (MypyTypeNode, MypyTypeNode) {
	return ec.check_method_call_by_name(method, base_type, [arg], [arg_pos], context)
}

// check_method_call_by_name проверяет вызов метода по имени
pub fn (mut ec ExpressionChecker) check_method_call_by_name(method string,
	base_type MypyTypeNode,
	args []Expression,
	arg_kinds []ArgKind,
	context NodeBase) (MypyTypeNode, MypyTypeNode) {
	method_type := analyze_member_access(method, base_type, context,
		is_lvalue:     false
		is_super:      false
		is_operator:   true
		original_type: base_type
		chk:           ec.chk
	)

	return ec.check_call(method_type, args, arg_kinds, context)
}

// visit_unary_expr проверяет унарный оператор
pub fn (mut ec ExpressionChecker) visit_unary_expr(e UnaryExpr) MypyTypeNode {
	operand_type := ec.accept(e.expr)

	if e.op == 'not' {
		return ec.bool_type()
	}

	method := operators.unary_op_methods[e.op]
	result, _ := ec.check_method_call_by_name(method, operand_type, [], [], e)
	return result
}

// visit_comparison_expr проверяет сравнение
pub fn (mut ec ExpressionChecker) visit_comparison_expr(e ComparisonExpr) MypyTypeNode {
	mut result := ?MypyTypeNode(none)

	for i in 0 .. e.operators.len {
		left_type := ec.accept(e.operands[i])
		right := e.operands[i + 1]
		op := e.operators[i]

		if op in operators.op_methods {
			method := operators.op_methods[op]
			sub_result, _ := ec.check_op(method, left_type, right, e)

			if result == none {
				result = sub_result
			} else {
				result = join.join_types(result or { sub_result }, sub_result)
			}
		} else if op == 'is' || op == 'is not' {
			ec.accept(right)
			if result == none {
				result = ec.bool_type()
			}
		}
	}

	return result or { ec.bool_type() }
}

// visit_assignment_expr проверает walrus operator
pub fn (mut ec ExpressionChecker) visit_assignment_expr(e AssignmentExpr) MypyTypeNode {
	value := ec.accept(e.value)
	ec.chk.check_assignment(e.target, e.value)
	ec.chk.check_final(e)
	ec.chk.store_type(e.target, value)
	return value
}

// visit_list_expr проверает список
pub fn (mut ec ExpressionChecker) visit_list_expr(e ListExpr) MypyTypeNode {
	return ec.check_lst_expr(e, 'builtins.list', '<list>')
}

// visit_set_expr проверяет set
pub fn (mut ec ExpressionChecker) visit_set_expr(e SetExpr) MypyTypeNode {
	return ec.check_lst_expr(e, 'builtins.set', '<set>')
}

// ListSetExpr — тип для list/set expression
pub type ListSetExpr = ListExpr | SetExpr

// check_lst_expr проверяет list/set/tuple expression
pub fn (mut ec ExpressionChecker) check_lst_expr(e ListSetExpr, fullname string, tag string) MypyTypeNode {
	tv := TypeVarTypeNode{
		name:        'T'
		fullname:    'T'
		id:          TypeVarId{
			raw_id:    -1
			namespace: '<lst>'
		}
		values:      []
		upper_bound: ec.object_type()
		default:     AnyTypeNode{
			reason: TypeOfAny.from_omitted_generics
		}
	}

	constructor := CallableTypeNode{
		arg_types: [MypyTypeNode(tv)]
		arg_kinds: [arg_star]
		arg_names: [?string(none)]
		ret_type:  ec.chk.named_generic_type(fullname, [tv])
		fallback:  ec.named_type('builtins.function')
		name:      tag
		variables: [TypeVarLikeType(tv)]
	}

	mut exprs := []Expression{}
	mut kinds := []ArgKind{}
	for item in e.items {
		if item is StarExprNode {
			exprs << item.expr
			kinds << arg_star
		} else {
			exprs << item
			kinds << arg_pos
		}
	}

	result, _ := ec.check_call(constructor, exprs, kinds, e)
	return result
}

// visit_dict_expr проверяет dict
pub fn (mut ec ExpressionChecker) visit_dict_expr(e DictExpr) MypyTypeNode {
	kt := TypeVarTypeNode{
		name:        'KT'
		fullname:    'KT'
		id:          TypeVarId{
			raw_id:    -1
			namespace: '<dict>'
		}
		values:      []
		upper_bound: ec.object_type()
		default:     AnyTypeNode{
			reason: TypeOfAny.from_omitted_generics
		}
	}
	vt := TypeVarTypeNode{
		name:        'VT'
		fullname:    'VT'
		id:          TypeVarId{
			raw_id:    -2
			namespace: '<dict>'
		}
		values:      []
		upper_bound: ec.object_type()
		default:     AnyTypeNode{
			reason: TypeOfAny.from_omitted_generics
		}
	}

	constructor := CallableTypeNode{
		arg_types: [MypyTypeNode(kt), MypyTypeNode(vt)]
		arg_kinds: [arg_pos, arg_pos]
		arg_names: [?string(none), ?string(none)]
		ret_type:  ec.chk.named_generic_type('builtins.dict', [kt, vt])
		fallback:  ec.named_type('builtins.function')
		name:      '<dict>'
		variables: [TypeVarLikeType(kt), TypeVarLikeType(vt)]
	}

	result, _ := ec.check_call(constructor, [], [], e)
	return result
}

// visit_tuple_expr проверяет tuple
pub fn (mut ec ExpressionChecker) visit_tuple_expr(e TupleExpr) MypyTypeNode {
	mut items := []MypyTypeNode{}
	for item in e.items {
		items << ec.accept(item)
	}

	fallback_item := AnyTypeNode{
		reason: TypeOfAny.special_form
	}
	fallback := ec.chk.named_generic_type('builtins.tuple', [fallback_item])

	return TupleTypeNode{
		items:            items
		partial_fallback: fallback
	}
}

// visit_conditional_expr проверяет conditional expression
pub fn (mut ec ExpressionChecker) visit_conditional_expr(e ConditionalExpr) MypyTypeNode {
	ec.accept(e.cond)

	if_type := ec.analyze_cond_branch(ec.chk.find_isinstance_check(e.cond)[0], e.if_expr)
	else_type := ec.analyze_cond_branch(ec.chk.find_isinstance_check(e.cond)[1], e.else_expr)

	return make_simplified_union([if_type, else_type])
}

// analyze_cond_branch анализирует ветку условия
pub fn (mut ec ExpressionChecker) analyze_cond_branch(map TypeMap, node Expression) MypyTypeNode {
	if is_unreachable_map(map) {
		return UninhabitedTypeNode{}
	}
	ec.chk.push_type_map(map)
	return ec.accept(node)
}

// visit_lambda_expr проверяет lambda
pub fn (mut ec ExpressionChecker) visit_lambda_expr(e LambdaExpr) MypyTypeNode {
	ec.chk.check_default_params(e, body_is_trivial: false)

	inferred_type, _ := ec.infer_lambda_type_using_context(e)
	if inferred_type != none {
		return inferred_type or {
			AnyTypeNode{
				reason: TypeOfAny.special_form
			}
		}
	}

	fallback := ec.named_type('builtins.function')
	ret_type := ec.accept(e.expr())
	return callable_type(e, fallback, ret_type)
}

// infer_lambda_type_using_context выводит тип lambda из контекста
pub fn (ec ExpressionChecker) infer_lambda_type_using_context(e LambdaExpr) (?MypyTypeNode, ?MypyTypeNode) {
	ctx := get_proper_type(ec.type_context.last())
	if ctx is CallableTypeNode {
		return ctx, ctx
	}
	return none, none
}

// visit_int_expr проверяет int literal
pub fn (ec ExpressionChecker) visit_int_expr(e IntExpr) MypyTypeNode {
	return ec.infer_literal_expr_type(e.value, 'builtins.int')
}

// visit_str_expr проверяет string literal
pub fn (ec ExpressionChecker) visit_str_expr(e StrExpr) MypyTypeNode {
	return ec.infer_literal_expr_type(e.value, 'builtins.str')
}

// visit_bytes_expr проверяет bytes literal
pub fn (ec ExpressionChecker) visit_bytes_expr(e BytesExpr) MypyTypeNode {
	return ec.infer_literal_expr_type(e.value, 'builtins.bytes')
}

// visit_float_expr проверяет float literal
pub fn (ec ExpressionChecker) visit_float_expr(e FloatExpr) MypyTypeNode {
	return ec.named_type('builtins.float')
}

// visit_complex_expr проверяет complex literal
pub fn (ec ExpressionChecker) visit_complex_expr(e ComplexExpr) MypyTypeNode {
	return ec.named_type('builtins.complex')
}

// visit_ellipsis проверяет ...
pub fn (ec ExpressionChecker) visit_ellipsis(e EllipsisExpr) MypyTypeNode {
	return ec.named_type('builtins.ellipsis')
}

// infer_literal_expr_type выводит тип literal
pub fn (ec ExpressionChecker) infer_literal_expr_type(value LiteralValue, fallback_name string) MypyTypeNode {
	typ := ec.named_type(fallback_name)
	if ec.is_literal_context() {
		return LiteralTypeNode{
			value:    value
			fallback: typ
		}
	}
	return typ
}

// visit_list_comprehension проверяет list comprehension
pub fn (mut ec ExpressionChecker) visit_list_comprehension(e ListComprehension) MypyTypeNode {
	return ec.check_generator_or_comprehension(e.generator, 'builtins.list', '<list-comprehension>')
}

// check_generator_or_comprehension проверяет generator/comprehension
pub fn (mut ec ExpressionChecker) check_generator_or_comprehension(gen GeneratorExpr, type_name string, id_for_messages string) MypyTypeNode {
	tv := TypeVarTypeNode{
		name:        'T'
		fullname:    'T'
		id:          TypeVarId{
			raw_id:    -1
			namespace: '<genexp>'
		}
		values:      []
		upper_bound: ec.object_type()
		default:     AnyTypeNode{
			reason: TypeOfAny.from_omitted_generics
		}
	}

	constructor := CallableTypeNode{
		arg_types: [MypyTypeNode(tv)]
		arg_kinds: [arg_pos]
		arg_names: [?string(none)]
		ret_type:  ec.chk.named_generic_type(type_name, [tv])
		fallback:  ec.named_type('builtins.function')
		name:      id_for_messages
		variables: [TypeVarLikeType(tv)]
	}

	result, _ := ec.check_call(constructor, [gen.left_expr], [arg_pos], gen)
	return result
}

// visit_cast_expr проверяет cast
pub fn (mut ec ExpressionChecker) visit_cast_expr(e CastExpr) MypyTypeNode {
	ec.accept(e.expr)
	return e.type
}

// visit_assert_type_expr проверяет assert_type
pub fn (mut ec ExpressionChecker) visit_assert_type_expr(e AssertTypeExpr) MypyTypeNode {
	source_type := ec.accept(e.expr, type_context: ec.type_context.last())
	return source_type
}

// visit_reveal_expr проверяет reveal_type
pub fn (mut ec ExpressionChecker) visit_reveal_expr(e RevealExpr) MypyTypeNode {
	if e.expr != none {
		revealed_type := ec.accept(e.expr or { return NoneTypeNode{} },
			type_context: ec.type_context.last()
		)
		ec.msg.reveal_type(revealed_type, e.expr or { return revealed_type })
		return revealed_type
	}
	return NoneTypeNode{}
}

// visit_yield_expr проверяет yield
pub fn (mut ec ExpressionChecker) visit_yield_expr(e YieldExpr) MypyTypeNode {
	return_type := ec.chk.return_types.last()
	expected_item_type := ec.chk.get_generator_yield_type(return_type, false)

	if e.expr != none {
		ec.accept(e.expr or { return expected_item_type }, expected_item_type)
	}

	return ec.chk.get_generator_receive_type(return_type, false)
}

// visit_await_expr проверяет await
pub fn (mut ec ExpressionChecker) visit_await_expr(e AwaitExpr) MypyTypeNode {
	actual_type := ec.accept(e.expr)
	return ec.check_awaitable_expr(actual_type, e)
}

// check_awaitable_expr проверяет awaitable
pub fn (ec ExpressionChecker) check_awaitable_expr(t MypyTypeNode, ctx NodeBase) MypyTypeNode {
	generator := ec.check_method_call_by_name('__await__', t, [], [], ctx)[0]
	return ec.chk.get_generator_return_type(generator, false)
}

// visit_temp_node проверяет temp node
pub fn (ec ExpressionChecker) visit_temp_node(e TempNode) MypyTypeNode {
	return e.typ
}

// accept принимает выражение
pub fn (mut ec ExpressionChecker) accept(node NodeBase,
	type_context ?MypyTypeNode,
	allow_none_return bool,
	always_allow_any bool,
	is_callee bool) MypyTypeNode {
	ec.type_context << type_context
	old_is_callee := ec.is_callee
	ec.is_callee = is_callee

	mut typ := MypyTypeNode(AnyTypeNode{
		reason: TypeOfAny.special_form
	})

	// TODO: полная реализация с вызовом node.accept(ec)

	ec.is_callee = old_is_callee
	ec.type_context.pop()

	ec.chk.store_type(node as Expression, typ)
	return typ
}

// named_type возвращает Instance с заданным именем
pub fn (ec ExpressionChecker) named_type(name string) InstanceNode {
	return ec.chk.named_type(name)
}

// object_type возвращает тип object
pub fn (ec ExpressionChecker) object_type() InstanceNode {
	return ec.named_type('builtins.object')
}

// bool_type возвращает тип bool
pub fn (ec ExpressionChecker) bool_type() InstanceNode {
	return ec.named_type('builtins.bool')
}

// narrow_type_from_binder сужает тип из binder
pub fn (ec ExpressionChecker) narrow_type_from_binder(e Expression, known_type MypyTypeNode) MypyTypeNode {
	if literal(e) >= literal_type {
		restriction := ec.chk.binder.get(e)
		if restriction != none {
			return narrow_declared_type(known_type, restriction or { return known_type })
		}
	}
	return known_type
}

// typeddict_callable создаёт callable для TypedDict
pub fn (ec ExpressionChecker) typeddict_callable(info TypeInfoNode) MypyTypeNode {
	return CallableTypeNode{
		arg_types: []
		arg_kinds: []
		arg_names: []
		ret_type:  InstanceNode{
			typ:  info
			args: []
		}
		fallback:  ec.named_type('builtins.type')
		name:      info.fullname
	}
}

// alias_type_in_runtime_context возвращает тип type alias в runtime контексте
pub fn (ec ExpressionChecker) alias_type_in_runtime_context(alias TypeAliasNode, ctx NodeBase) MypyTypeNode {
	return AnyTypeNode{
		reason: TypeOfAny.special_form
	}
}

// Вспомогательные функции-заглушки
fn analyze_member_access(name string,
	typ MypyTypeNode,
	context NodeBase,
	is_lvalue bool,
	is_super bool,
	is_operator bool,
	original_type MypyTypeNode,
	chk TypeChecker) MypyTypeNode {
	// TODO: реализация из checkmember.v
	return AnyTypeNode{
		reason: TypeOfAny.special_form
	}
}

fn callable_type(e LambdaExpr, fallback InstanceNode, ret_type MypyTypeNode) CallableTypeNode {
	// TODO: реализация
	return CallableTypeNode{
		fallback: fallback
		ret_type: ret_type
	}
}

fn get_proper_type(t MypyTypeNode) MypyTypeNode {
	return t
}

fn make_simplified_union(items []MypyTypeNode) MypyTypeNode {
	if items.len == 1 {
		return items[0]
	}
	return UnionTypeNode{
		items: items
	}
}

fn narrow_declared_type(declared MypyTypeNode, narrowed MypyTypeNode) MypyTypeNode {
	return narrowed
}

fn is_unreachable_map(type_map TypeMap) bool {
	for v in type_map.values {
		if v is UninhabitedTypeNode {
			return true
		}
	}
	return false
}

fn type_object_type(info TypeInfoNode, named_type_fn fn (string) InstanceNode) MypyTypeNode {
	return CallableTypeNode{
		arg_types: []
		arg_kinds: []
		arg_names: []
		ret_type:  InstanceNode{
			typ:  info
			args: []
		}
		fallback:  named_type_fn('builtins.function')
		name:      info.fullname
	}
}
