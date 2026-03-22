// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 14:00
// evalexpr.v — Evaluate expression at runtime
// Translated from mypy/evalexpr.py to V 0.5.x
//
// ---------------------------------------------------------------------------

module mypy

// NodeEvaluator — посетитель для вычисления выражений
pub struct NodeEvaluator {
mut:
	line   int
	column int
}

// visit_int_expr вычисляет целочисленный литерал
pub fn (mut e NodeEvaluator) visit_int_expr(mut o &IntExpr) !string {
	return o.value.str()
}

// visit_str_expr вычисляет строковый литерал
pub fn (mut e NodeEvaluator) visit_str_expr(mut o &StrExpr) !string {
	return o.value
}

// visit_bytes_expr вычисляет байтовый литерал
pub fn (mut e NodeEvaluator) visit_bytes_expr(mut o &BytesExpr) !string {
	return o.value
}

// visit_float_expr вычисляет float литерал
pub fn (mut e NodeEvaluator) visit_float_expr(mut o &FloatExpr) !string {
	return o.value.str()
}

// visit_complex_expr вычисляет complex литерал
pub fn (mut e NodeEvaluator) visit_complex_expr(mut o &ComplexExpr) !string {
	return '${o.real} + ${o.imag}j'
}

// visit_ellipsis вычисляет Ellipsis
pub fn (mut e NodeEvaluator) visit_ellipsis(mut o &EllipsisExpr) !string {
	return '...'
}

// visit_star_expr вычисляет StarExpr
pub fn (mut e NodeEvaluator) visit_star_expr(mut o &StarExpr) !string {
	return '*' + o.expr.accept(mut e)!
}

// visit_name_expr вычисляет NameExpr
pub fn (mut e NodeEvaluator) visit_name_expr(mut o &NameExpr) !string {
	return o.name
}

// visit_member_expr вычисляет MemberExpr
pub fn (mut e NodeEvaluator) visit_member_expr(mut o &MemberExpr) !string {
	return o.expr.accept(mut e)! + '.' + o.name
}

// visit_yield_from_expr вычисляет YieldFromExpr
pub fn (mut e NodeEvaluator) visit_yield_from_expr(mut o &YieldFromExpr) !string {
	return 'yield from ' + o.expr.accept(mut e)!
}

// visit_yield_expr вычисляет YieldExpr
pub fn (mut e NodeEvaluator) visit_yield_expr(mut o &YieldExpr) !string {
	if expr := o.expr {
		return 'yield ' + expr.accept(mut e)!
	}
	return 'yield'
}

// visit_call_expr вычисляет CallExpr
pub fn (mut e NodeEvaluator) visit_call_expr(mut o &CallExpr) !string {
	return 'call'
}

// visit_op_expr вычисляет OpExpr
pub fn (mut e NodeEvaluator) visit_op_expr(mut o &OpExpr) !string {
	return o.left.accept(mut e)! + ' ' + o.op + ' ' + o.right.accept(mut e)!
}

// visit_comparison_expr вычисляет ComparisonExpr
pub fn (mut e NodeEvaluator) visit_comparison_expr(mut o &ComparisonExpr) !string {
	return 'comparison'
}

// visit_cast_expr вычисляет CastExpr
pub fn (mut e NodeEvaluator) visit_cast_expr(mut o &CastExpr) !string {
	return o.expr.accept(mut e)!
}

// visit_assert_type_expr вычисляет AssertTypeExpr
pub fn (mut e NodeEvaluator) visit_assert_type_expr(mut o &AssertTypeExpr) !string {
	return o.expr.accept(mut e)!
}

// visit_reveal_expr вычисляет RevealExpr
pub fn (mut e NodeEvaluator) visit_reveal_expr(mut o &RevealExpr) !string {
    if expr := o.expr {
	    return 'reveal_type(${expr.accept(mut e)!})'
    }
    return 'reveal_type()'
}

// visit_super_expr вычисляет SuperExpr
pub fn (mut e NodeEvaluator) visit_super_expr(mut o &SuperExpr) !string {
	return 'super()'
}

// visit_unary_expr вычисляет UnaryExpr
pub fn (mut e NodeEvaluator) visit_unary_expr(mut o &UnaryExpr) !string {
	return o.op + o.expr.accept(mut e)!
}

// visit_assignment_expr вычисляет AssignmentExpr (:=)
pub fn (mut e NodeEvaluator) visit_assignment_expr(mut o &AssignmentExpr) !string {
	return o.target.accept(mut e)! + ' := ' + o.value.accept(mut e)!
}

// visit_list_expr вычисляет ListExpr
pub fn (mut e NodeEvaluator) visit_list_expr(mut o &ListExpr) !string {
	return 'list'
}

// visit_dict_expr вычисляет DictExpr
pub fn (mut e NodeEvaluator) visit_dict_expr(mut o &DictExpr) !string {
	return 'dict'
}

// visit_tuple_expr вычисляет TupleExpr
pub fn (mut e NodeEvaluator) visit_tuple_expr(mut o &TupleExpr) !string {
	return 'tuple'
}

// visit_set_expr вычисляет SetExpr
pub fn (mut e NodeEvaluator) visit_set_expr(mut o &SetExpr) !string {
	return 'set'
}

// visit_index_expr вычисляет IndexExpr
pub fn (mut e NodeEvaluator) visit_index_expr(mut o &IndexExpr) !string {
	return o.base.accept(mut e)! + '[' + o.index.accept(mut e)! + ']'
}

// visit_type_application вычисляет TypeApplication
pub fn (mut e NodeEvaluator) visit_type_application(mut o &TypeApplication) !string {
	return o.expr.accept(mut e)! + '[...]'
}

// visit_lambda_expr вычисляет LambdaExpr
pub fn (mut e NodeEvaluator) visit_lambda_expr(mut o &LambdaExpr) !string {
	return 'lambda'
}

// visit_list_comprehension вычисляет ListComprehension
pub fn (mut e NodeEvaluator) visit_list_comprehension(mut o &ListComprehension) !string {
	return 'list_comp'
}

// visit_set_comprehension вычисляет SetComprehension
pub fn (mut e NodeEvaluator) visit_set_comprehension(mut o &SetComprehension) !string {
	return 'set_comp'
}

// visit_dictionary_comprehension вычисляет DictionaryComprehension
pub fn (mut e NodeEvaluator) visit_dictionary_comprehension(mut o &DictionaryComprehension) !string {
	return 'dict_comp'
}

// visit_generator_expr вычисляет GeneratorExpr
pub fn (mut e NodeEvaluator) visit_generator_expr(mut o &GeneratorExpr) !string {
	return 'gen_expr'
}

// visit_slice_expr вычисляет SliceExpr
pub fn (mut e NodeEvaluator) visit_slice_expr(mut o &SliceExpr) !string {
	return 'slice'
}

// visit_conditional_expr вычисляет ConditionalExpr
pub fn (mut e NodeEvaluator) visit_conditional_expr(mut o &ConditionalExpr) !string {
	return 'cond_expr'
}

// visit_type_var_expr вычисляет TypeVarExpr
pub fn (mut e NodeEvaluator) visit_type_var_expr(mut o &TypeVarExpr) !string {
	return 'TypeVar'
}

// visit_paramspec_expr вычисляет ParamSpecExpr
pub fn (mut e NodeEvaluator) visit_paramspec_expr(mut o &ParamSpecExpr) !string {
	return 'ParamSpec'
}

// visit_type_var_tuple_expr вычисляет TypeVarTupleExpr
pub fn (mut e NodeEvaluator) visit_type_var_tuple_expr(mut o &TypeVarTupleExpr) !string {
	return 'TypeVarTuple'
}

// visit_type_alias_expr вычисляет TypeAliasExpr
pub fn (mut e NodeEvaluator) visit_type_alias_expr(mut o &TypeAliasExpr) !string {
	return 'TypeAlias'
}

// visit_namedtuple_expr вычисляет NamedTupleExpr
pub fn (mut e NodeEvaluator) visit_namedtuple_expr(mut o &NamedTupleExpr) !string {
	return 'NamedTuple'
}

// visit_enum_call_expr вычисляет EnumCallExpr
pub fn (mut e NodeEvaluator) visit_enum_call_expr(mut o &EnumCallExpr) !string {
	return 'Enum'
}

// visit_typeddict_expr вычисляет TypedDictExpr
pub fn (mut e NodeEvaluator) visit_typeddict_expr(mut o &TypedDictExpr) !string {
	return 'TypedDict'
}

// visit_newtype_expr вычисляет NewTypeExpr
pub fn (mut e NodeEvaluator) visit_newtype_expr(mut o &NewTypeExpr) !string {
	return 'NewType'
}

// visit_promote_expr вычисляет PromoteExpr
pub fn (mut e NodeEvaluator) visit_promote_expr(mut o &PromoteExpr) !string {
	return 'promote'
}

// visit_await_expr вычисляет AwaitExpr
pub fn (mut e NodeEvaluator) visit_await_expr(mut o &AwaitExpr) !string {
	return 'await ' + o.expr.accept(mut e)!
}

// visit_template_str_expr вычисляет TemplateStrExpr
pub fn (mut e NodeEvaluator) visit_template_str_expr(mut o &TemplateStrExpr) !string {
	return 'f-string'
}

// visit_temp_node вычисляет TempNode
pub fn (mut e NodeEvaluator) visit_temp_node(mut o &TempNode) !string {
	return 'temp'
}

// --- Placeholder nodes ---
pub fn (mut e NodeEvaluator) visit_placeholder_node(mut o &PlaceholderNode) !string {
    return 'placeholder'
}

// --- Statement Visitor Stubs ---
pub fn (mut e NodeEvaluator) visit_mypy_file(mut o &MypyFile) !string { return '' }
pub fn (mut e NodeEvaluator) visit_var(mut o &Var) !string { return '' }
pub fn (mut e NodeEvaluator) visit_type_alias(mut o &TypeAlias) !string { return '' }
pub fn (mut e NodeEvaluator) visit_import(mut o &Import) !string { return '' }
pub fn (mut e NodeEvaluator) visit_import_from(mut o &ImportFrom) !string { return '' }
pub fn (mut e NodeEvaluator) visit_import_all(mut o &ImportAll) !string { return '' }
pub fn (mut e NodeEvaluator) visit_func_def(mut o &FuncDef) !string { return '' }
pub fn (mut e NodeEvaluator) visit_overloaded_func_def(mut o &OverloadedFuncDef) !string { return '' }
pub fn (mut e NodeEvaluator) visit_class_def(mut o &ClassDef) !string { return '' }
pub fn (mut e NodeEvaluator) visit_global_decl(mut o &GlobalDecl) !string { return '' }
pub fn (mut e NodeEvaluator) visit_nonlocal_decl(mut o &NonlocalDecl) !string { return '' }
pub fn (mut e NodeEvaluator) visit_decorator(mut o &Decorator) !string { return '' }
pub fn (mut e NodeEvaluator) visit_block(mut o &Block) !string { return '' }
pub fn (mut e NodeEvaluator) visit_expression_stmt(mut o &ExpressionStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_assignment_stmt(mut o &AssignmentStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_operator_assignment_stmt(mut o &OperatorAssignmentStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_while_stmt(mut o &WhileStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_for_stmt(mut o &ForStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_return_stmt(mut o &ReturnStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_assert_stmt(mut o &AssertStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_if_stmt(mut o &IfStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_break_stmt(mut o &BreakStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_continue_stmt(mut o &ContinueStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_pass_stmt(mut o &PassStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_raise_stmt(mut o &RaiseStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_try_stmt(mut o &TryStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_with_stmt(mut o &WithStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_del_stmt(mut o &DelStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_type_alias_stmt(mut o &TypeAliasStmt) !string { return '' }
pub fn (mut e NodeEvaluator) visit_match_stmt(mut o &MatchStmt) !string { return '' }

// evaluate_expression вычисляет выражение в runtime (упрощенно до string для отладки)
pub fn evaluate_expression(mut expr Expression) !string {
	mut evaluator := NodeEvaluator{}
	return expr.accept(mut evaluator)
}
