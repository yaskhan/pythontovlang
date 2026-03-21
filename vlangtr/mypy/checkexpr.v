// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 06:47
module mypy

// Проверка типов выражений (ExpressionChecker).

pub struct ExpressionChecker {
pub mut:
	chk                         &TypeChecker
	msg                         &MessageBuilder
	type_context                []?MypyTypeNode
	// strfrm_checker           &StringFormatterChecker
	// plugin                   &Plugin
	is_callee                   bool
	in_expression               bool
	in_lambda_expr              bool
	expr_cache                  map[string]MypyTypeNode // упрощенный кэш
}

pub fn new_expression_checker(chk &TypeChecker, msg &MessageBuilder) &ExpressionChecker {
	return &ExpressionChecker{
		chk: chk
		msg: msg
		type_context: [none]
	}
}

pub fn (mut e ExpressionChecker) accept(node Expression, type_context ?MypyTypeNode, allow_none_return bool, always_allow_any bool, is_callee bool) MypyTypeNode {
	// Сохранение предыдущего контекста
	old_is_callee := e.is_callee
	e.is_callee = is_callee
	
	e.type_context << type_context
	
	// Диспетчеризация по типу узла
	mut typ := MypyTypeNode(AnyType{type_of_any: .from_error})
	
	match node {
		NameExpr { typ = e.visit_name_expr(node) }
		CallExpr { typ = e.visit_call_expr(node, allow_none_return) }
		MemberExpr { typ = e.visit_member_expr(node, false) }
		OpExpr { typ = e.visit_op_expr(node) }
		UnaryExpr { typ = e.visit_unary_expr(node) }
		IntExpr { typ = e.visit_int_expr(node) }
		StrExpr { typ = e.visit_str_expr(node) }
		ListExpr { typ = e.visit_list_expr(node) }
		SetExpr { typ = e.visit_set_expr(node) }
		DictExpr { typ = e.visit_dict_expr(node) }
		TupleExpr { typ = e.visit_tuple_expr(node) }
		GeneratorExpr { typ = e.visit_generator_expr(node) }
		ListCompExpr { typ = e.visit_list_comp_expr(node) }
		DictCompExpr { typ = e.visit_dict_comp_expr(node) }
		SliceExpr { typ = e.visit_slice_expr(node) }
		LambdaExpr { typ = e.visit_lambda_expr(node) }
		YieldExpr { typ = e.visit_yield_expr(node) }
		YieldFromExpr { typ = e.visit_yield_from_expr(node, allow_none_return) }
		else {
			// fallback
		}
	}
	
	e.type_context.delete_last()
	e.is_callee = old_is_callee
	
	return typ
}

pub fn (mut e ExpressionChecker) visit_name_expr(node &NameExpr) MypyTypeNode {
	result := e.analyze_ref_expr(node, false)
	// narrowed := e.narrow_type_from_binder(node, result)
	// return narrowed
	return result
}

pub fn (mut e ExpressionChecker) analyze_ref_expr(node Expression, lvalue bool) MypyTypeNode {
	mut result := MypyTypeNode(AnyType{type_of_any: .from_error})
	
	if node is NameExpr {
		if target := node.node {
			if target is Var {
				result = e.analyze_var_ref(target, node)
			} else if target is FuncDef || target is TypeInfo {
				result = e.analyze_static_reference(target, node, lvalue)
			}
		}
	} else if node is RefExpr {
		// ...
	}
	
	return result
}

pub fn (mut e ExpressionChecker) analyze_var_ref(target &Var, context Expression) MypyTypeNode {
	if typ := target.typ {
		return typ
	}
	return MypyTypeNode(AnyType{type_of_any: .unannotated})
}

pub fn (mut e ExpressionChecker) analyze_static_reference(node MypyNode, ctx Expression, is_lvalue bool) MypyTypeNode {
	if node is FuncDef {
		// return function_type(...)
	} else if node is TypeInfo {
		// return type_object_type(...)
	}
	return MypyTypeNode(AnyType{type_of_any: .special_form})
}

pub fn (mut e ExpressionChecker) visit_call_expr(node &CallExpr, allow_none_return bool) MypyTypeNode {
	// В Mypy есть кэш/специальные проверки для TypedDict и isinstance
	
	callee_type := e.accept(node.callee, none, false, true, true)
	
	mut callable_name := ?string(none)
	mut object_type := ?MypyTypeNode(none)
	
	if node.callee is RefExpr {
		// Извлечение имени и объекта, если это метод
		callable_name = node.callee.fullname
	} else if node.callee is MemberExpr {
		callable_name = node.callee.name
		object_type = e.chk.lookup_type(node.callee.expr)
	}
	
	ret_type := e.check_call_expr_with_callee_type(callee_type, node, callable_name, object_type, none)
	return ret_type
}

pub fn (mut e ExpressionChecker) check_call_expr_with_callee_type(callee_type MypyTypeNode, node &CallExpr, callable_name ?string, object_type ?MypyTypeNode, member ?string) MypyTypeNode {
	mut actual_callable_name := callable_name
	
	if actual_callable_name == none && member != none {
		if ot := object_type {
			actual_callable_name = e.method_fullname(ot, member or { panic("") })
		}
	}
	
	// В Mypy есть хуки плагинов (transform_callee_type), здесь мы их опускаем
	
	ret_type, _ := e.check_call(callee_type, node.args, node.arg_kinds, node, node.arg_names, node.callee, actual_callable_name, object_type, none)
	return ret_type
}

pub fn (mut e ExpressionChecker) check_call(callee MypyTypeNode, args []Expression, arg_kinds []int, context Context, arg_names []?string, callable_node ?Expression, callable_name ?string, object_type ?MypyTypeNode, original_type ?MypyTypeNode) (MypyTypeNode, MypyTypeNode) {
	if callee is CallableType {
		// check_callable_call
		return e.check_callable_call(callee, args, arg_kinds, context, arg_names, callable_node, callable_name, object_type)
	} else if callee is Overloaded {
		// check_overload_call
		return e.check_overload_call(callee, args, arg_kinds, arg_names, callable_name, object_type, context), callee
	} else if callee is AnyType {
		return e.check_any_type_call(args, arg_kinds, callee, context), callee
	} else if callee is UnionType {
		// check_union_call
		return MypyTypeNode(AnyType{type_of_any: .from_error}), callee
	}
	
	e.msg.fail("Not callable", context, false, false, none)
	return MypyTypeNode(AnyType{type_of_any: .from_error}), callee
}

pub fn (mut e ExpressionChecker) check_callable_call(callee &CallableType, args []Expression, arg_kinds []int, context Context, arg_names []?string, callable_node ?Expression, callable_name ?string, object_type ?MypyTypeNode) (MypyTypeNode, MypyTypeNode) {
	// Основная логика: map_actuals_to_formals, check_args, infer_function_type_arguments
	mut actual_callee := callee
	
	if actual_callee.is_type_obj() && actual_callee.type_object().is_abstract {
		e.msg.fail('Cannot instantiate abstract class', context, false, false, none)
	}
	
	// if actual_callee.is_generic() { ... freshen_function_type_vars ... }
	
	formal_to_actual := map_actuals_to_formals(arg_kinds, arg_names, actual_callee.arg_kinds, actual_callee.arg_names, fn (i int) MypyTypeNode {
		// e.accept(args[i], none, false, false, false) // требуется доступ к e, это можно решить позже через замыкание или передачу аргументов
		return MypyTypeNode(AnyType{type_of_any: .from_error}) // placeholder
	})
	
	// if callee.is_generic() { ... infer_function_type_arguments ... }
	
	arg_types := e.infer_arg_types_in_context(actual_callee, args, arg_kinds, formal_to_actual)
	
	e.check_argument_count(actual_callee, arg_types, arg_kinds, arg_names, formal_to_actual, context, object_type, callable_name)
	e.check_argument_types(arg_types, arg_kinds, args, actual_callee, formal_to_actual, context, object_type)
	
	if cl_node := callable_node {
		// e.chk.store_type(cl_node, actual_callee)
	}
	
	return actual_callee.ret_type, actual_callee
}

pub fn (mut e ExpressionChecker) visit_member_expr(node &MemberExpr, is_lvalue bool) MypyTypeNode {
	result := e.analyze_ordinary_member_access(node, is_lvalue, none)
	// narrowed := e.narrow_type_from_binder(node, result)
	return result
}

pub fn (mut e ExpressionChecker) analyze_ordinary_member_access(node &MemberExpr, is_lvalue bool, rvalue ?Expression) MypyTypeNode {
	if node.kind != none {
		return e.analyze_ref_expr(node, is_lvalue)
	}
	
	original_type := e.accept(node.expr, none, false, true, e.is_callee)
	base := node.expr
	
	mut is_self := false
	if base is RefExpr {
		if bn := base.node {
			if bn is Var {
				is_self = bn.is_self || bn.is_cls
			}
		}
	}
	
	member_type := analyze_member_access(node.name, original_type, node, is_lvalue, false, false, original_type, e.chk, e.is_literal_context())
	return member_type
}

pub fn (mut e ExpressionChecker) is_literal_context() bool {
	// dummy, проверить type_context
	return false
}

pub fn (mut e ExpressionChecker) visit_op_expr(node &OpExpr) MypyTypeNode {
	if node.op == 'and' || node.op == 'or' {
		// return e.check_boolean_op(node)
	}
	
	left_type := e.accept(node.left, none, false, false, false)
	proper_left_type := get_proper_type(left_type)
	
	if proper_left_type is TupleType && node.op == '+' {
		// logic for Tuple addition...
	}
	
	// Маппинг операторов в магические методы
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
		else { }
	}
	
	if method != '' {
		result, _ := e.check_op(method, left_type, node.right, node, true)
		return result
	}
	
	e.msg.fail("Unknown operator \${node.op}", node, false, false, none)
	return MypyTypeNode(AnyType{type_of_any: .from_error})
}

pub fn (mut e ExpressionChecker) check_op(method string, base_type MypyTypeNode, arg Expression, context Context, allow_reverse bool) (MypyTypeNode, MypyTypeNode) {
	// check_method_call_by_name ...
	// Если метод не найден и allow_reverse == true, проверяем реверсивный метод у правого операнда (__radd__ и тд).
	return MypyTypeNode(AnyType{type_of_any: .from_error}), MypyTypeNode(AnyType{type_of_any: .from_error})
}

pub fn (mut e ExpressionChecker) visit_unary_expr(node &UnaryExpr) MypyTypeNode {
	operand_type := e.accept(node.expr, none, false, false, false)
	op := node.op
	if op == 'not' {
		return e.chk.named_type('builtins.bool', [])
	}
	
	mut method := ''
	match op {
		'-' { method = '__neg__' }
		'+' { method = '__pos__' }
		'~' { method = '__invert__' }
		else { }
	}
	
	if method != '' {
		// check_method_call_by_name
		return MypyTypeNode(AnyType{type_of_any: .from_error})
	}
	
	return MypyTypeNode(AnyType{type_of_any: .from_error})
}

pub fn (mut e ExpressionChecker) visit_list_expr(node &ListExpr) MypyTypeNode {
	return e.check_lst_expr(node.items, 'builtins.list', '<list>')
}

pub fn (mut e ExpressionChecker) visit_set_expr(node &SetExpr) MypyTypeNode {
	return e.check_lst_expr(node.items, 'builtins.set', '<set>')
}

pub fn (mut e ExpressionChecker) check_lst_expr(items []Expression, fullname string, tag string) MypyTypeNode {
	// В Mypy это преобразуется в вызов обобщенной функции вида:
	// def [T] (*args: T) -> list[T]
	// И дальше вызывается метод check_callable_call
	
	// Упрощенная заглушка: просто обходим элементы и объединяем их типы
	mut types := []MypyTypeNode{}
	for item in items {
		types << e.accept(item, none, false, false, false)
	}
	
	fallback := e.chk.named_type(fullname, [])
	// В идеале мы должны создать Instance type с параметрами типов, 
	// вычисленными через объединение (Join) types.
	// Пока возвращаем Instance с первым типом или Any
	
	if types.len > 0 {
		mut inst := fallback
		inst.args = [types[0]]
		return MypyTypeNode(inst)
	} else {
		mut inst := fallback
		inst.args = [MypyTypeNode(AnyType{type_of_any: .special_form})]
		return MypyTypeNode(inst)
	}
}

pub fn (mut e ExpressionChecker) visit_dict_expr(node &DictExpr) MypyTypeNode {
	// Упрощенная логика проверки словаря, в Mypy преобразуется в dict_check(key_types, value_types)
	// И также проверка на TypedDictType из type_context
	for item in node.items {
		if item.0 != none {
			e.accept(item.0 or { panic('') }, none, false, false, false)
		}
		e.accept(item.1, none, false, false, false)
	}
	return MypyTypeNode(e.chk.named_type('builtins.dict', []))
}

pub fn (mut e ExpressionChecker) visit_tuple_expr(node &TupleExpr) MypyTypeNode {
	mut items := []MypyTypeNode{}
	for item in node.items {
		// Мы пока игнорируем распаковку (*item) для простоты
		items << e.accept(item, none, false, false, false)
	}
	
	fallback := e.chk.named_type('builtins.tuple', [MypyTypeNode(AnyType{type_of_any: .special_form})])
	return MypyTypeNode(TupleType{items: items, partial_fallback: fallback})
}

pub fn (mut e ExpressionChecker) visit_generator_expr(node &GeneratorExpr) MypyTypeNode {
	// analyze_iterable_item_type -> visit_generator_expr logic
	// e.chk.binder.push_frame() ...
	// Для заглушки мы просто обходим выражение
	e.accept(node.left_expr, none, false, false, false)
	for seq in node.sequences {
		e.accept(seq, none, false, false, false)
	}
	
	return MypyTypeNode(e.chk.named_type('typing.Generator', [
		MypyTypeNode(AnyType{type_of_any: .special_form}),
		MypyTypeNode(AnyType{type_of_any: .special_form}),
		MypyTypeNode(AnyType{type_of_any: .special_form})
	]))
}

pub fn (mut e ExpressionChecker) visit_list_comp_expr(node &ListCompExpr) MypyTypeNode {
	// Аналогично generator, но возвращаем List
	e.accept(node.left_expr, none, false, false, false)
	for seq in node.sequences {
		e.accept(seq, none, false, false, false)
	}
	return MypyTypeNode(e.chk.named_type('builtins.list', [MypyTypeNode(AnyType{type_of_any: .special_form})]))
}

pub fn (mut e ExpressionChecker) visit_dict_comp_expr(node &DictCompExpr) MypyTypeNode {
	e.accept(node.key_expr, none, false, false, false)
	e.accept(node.value_expr, none, false, false, false)
	for seq in node.sequences {
		e.accept(seq, none, false, false, false)
	}
	return MypyTypeNode(e.chk.named_type('builtins.dict', [
		MypyTypeNode(AnyType{type_of_any: .special_form}),
		MypyTypeNode(AnyType{type_of_any: .special_form})
	]))
}

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
	return MypyTypeNode(e.chk.named_type('builtins.slice', []))
}

pub fn (mut e ExpressionChecker) visit_lambda_expr(node &LambdaExpr) MypyTypeNode {
	// В настоящем Mypy: проверка аргументов, тела с созданием фрейма в type_checker
	// У нас: просто обход и возврат CallableType (заглушка)
	e.accept(node.expr, none, false, false, false)
	
	// TODO: infer arguments type and return type
	return MypyTypeNode(CallableType{
		arg_types: []
		arg_kinds: []
		arg_names: []
		ret_type: MypyTypeNode(AnyType{type_of_any: .special_form})
		fallback: e.chk.named_type('builtins.function', [])
		is_type_obj: false
	})
}

pub fn (mut e ExpressionChecker) visit_yield_expr(node &YieldExpr) MypyTypeNode {
	if expr := node.expr {
		e.accept(expr, none, false, false, false)
	}
	// Значение, которое генератор получает после yield
	return MypyTypeNode(AnyType{type_of_any: .special_form})
}

pub fn (mut e ExpressionChecker) visit_yield_from_expr(node &YieldFromExpr, allow_none_return bool) MypyTypeNode {
	if expr := node.expr {
		e.accept(expr, none, false, false, false)
	}
	// Значение результата yield from (return из делегированного генератора)
	return MypyTypeNode(AnyType{type_of_any: .special_form})
}

pub fn (mut e ExpressionChecker) infer_arg_types_in_context(callee &CallableType, args []Expression, arg_kinds []int, formal_to_actual [][]int) []MypyTypeNode {
	mut arg_types := []MypyTypeNode{}
	for arg in args {
		arg_types << e.accept(arg, none, false, false, false)
	}
	return arg_types
}

pub fn (mut e ExpressionChecker) check_argument_count(callee &CallableType, arg_types []MypyTypeNode, arg_kinds []int, arg_names []?string, formal_to_actual [][]int, context Context, object_type ?MypyTypeNode, callable_name ?string) {
	// Проверка кол-ва аргументов
}

pub fn (mut e ExpressionChecker) check_argument_types(arg_types []MypyTypeNode, arg_kinds []int, args []Expression, callee &CallableType, formal_to_actual [][]int, context Context, object_type ?MypyTypeNode) {
	// Проверка типов аргументов
	for i, arg_type in arg_types {
		if i < callee.arg_types.len {
			e.chk.check_subtype(arg_type, callee.arg_types[i], context, 'Argument \${i+1} has incompatible type', none, none, [], none, none)
		}
	}
}

pub fn (mut e ExpressionChecker) check_overload_call(callee &Overloaded, args []Expression, arg_kinds []int, arg_names []?string, callable_name ?string, object_type ?MypyTypeNode, context Context) MypyTypeNode {
	// Stub
	return MypyTypeNode(AnyType{type_of_any: .special_form})
}

pub fn (mut e ExpressionChecker) check_any_type_call(args []Expression, arg_kinds []int, callee AnyType, context Context) MypyTypeNode {
	for arg in args {
		e.accept(arg, none, false, false, false)
	}
	return MypyTypeNode(AnyType{type_of_any: callee.type_of_any})
}

pub fn (mut e ExpressionChecker) visit_int_expr(node &IntExpr) MypyTypeNode {
	return e.chk.named_type('builtins.int', [])
}

pub fn (mut e ExpressionChecker) visit_str_expr(node &StrExpr) MypyTypeNode {
	return e.chk.named_type('builtins.str', [])
}

// Реализация интерфейса ExpressionCheckerSharedApi не требует повторного объявления check_call, т.к. метод уже определен выше


pub fn (mut e ExpressionChecker) method_fullname(object_type MypyTypeNode, method_name string) ?string {
	return none
}

// ... Оставшиеся методы из интерфейса можно добавить позже
