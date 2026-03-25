// visitor.v — Generic AST node visitor interfaces
module mypy

// AnyNode — sum type for visitor return values (analysis or transformation)
pub type AnyNode = MypyNode | PatternNode | string

pub fn (a AnyNode) as_mypy_node() ?MypyNode {
	if a is MypyNode {
		return a
	}
	return none
}

pub fn (a AnyNode) as_pattern() ?PatternNode {
	if a is PatternNode {
		return a
	}
	return none
}

// ---------------------------------------------------------------------------
// ExpressionVisitor
// ---------------------------------------------------------------------------

pub interface ExpressionVisitor {
mut:
	visit_int_expr(mut o IntExpr) !AnyNode
	visit_str_expr(mut o StrExpr) !AnyNode
	visit_bytes_expr(mut o BytesExpr) !AnyNode
	visit_float_expr(mut o FloatExpr) !AnyNode
	visit_complex_expr(mut o ComplexExpr) !AnyNode
	visit_ellipsis(mut o EllipsisExpr) !AnyNode
	visit_star_expr(mut o StarExpr) !AnyNode
	visit_name_expr(mut o NameExpr) !AnyNode
	visit_member_expr(mut o MemberExpr) !AnyNode
	visit_yield_from_expr(mut o YieldFromExpr) !AnyNode
	visit_yield_expr(mut o YieldExpr) !AnyNode
	visit_call_expr(mut o CallExpr) !AnyNode
	visit_op_expr(mut o OpExpr) !AnyNode
	visit_comparison_expr(mut o ComparisonExpr) !AnyNode
	visit_cast_expr(mut o CastExpr) !AnyNode
	visit_assert_type_expr(mut o AssertTypeExpr) !AnyNode
	visit_reveal_expr(mut o RevealExpr) !AnyNode
	visit_super_expr(mut o SuperExpr) !AnyNode
	visit_unary_expr(mut o UnaryExpr) !AnyNode
	visit_assignment_expr(mut o AssignmentExpr) !AnyNode
	visit_list_expr(mut o ListExpr) !AnyNode
	visit_dict_expr(mut o DictExpr) !AnyNode
	visit_template_str_expr(mut o TemplateStrExpr) !AnyNode
	visit_tuple_expr(mut o TupleExpr) !AnyNode
	visit_set_expr(mut o SetExpr) !AnyNode
	visit_index_expr(mut o IndexExpr) !AnyNode
	visit_type_application(mut o TypeApplication) !AnyNode
	visit_lambda_expr(mut o LambdaExpr) !AnyNode
	visit_list_comprehension(mut o ListComprehension) !AnyNode
	visit_set_comprehension(mut o SetComprehension) !AnyNode
	visit_dictionary_comprehension(mut o DictionaryComprehension) !AnyNode
	visit_generator_expr(mut o GeneratorExpr) !AnyNode
	visit_slice_expr(mut o SliceExpr) !AnyNode
	visit_conditional_expr(mut o ConditionalExpr) !AnyNode
	visit_type_var_expr(mut o TypeVarExpr) !AnyNode
	visit_paramspec_expr(mut o ParamSpecExpr) !AnyNode
	visit_type_var_tuple_expr(mut o TypeVarTupleExpr) !AnyNode
	visit_type_alias_expr(mut o TypeAliasExpr) !AnyNode
	visit_namedtuple_expr(mut o NamedTupleExpr) !AnyNode
	visit_enum_call_expr(mut o EnumCallExpr) !AnyNode
	visit_typeddict_expr(mut o TypedDictExpr) !AnyNode
	visit_newtype_expr(mut o NewTypeExpr) !AnyNode
	visit_promote_expr(mut o PromoteExpr) !AnyNode
	visit_await_expr(mut o AwaitExpr) !AnyNode
	visit_temp_node(mut o TempNode) !AnyNode
}

// ---------------------------------------------------------------------------
// StatementVisitor
// ---------------------------------------------------------------------------

pub interface StatementVisitor {
mut:
	visit_assignment_stmt(mut o AssignmentStmt) !AnyNode
	visit_for_stmt(mut o ForStmt) !AnyNode
	visit_with_stmt(mut o WithStmt) !AnyNode
	visit_del_stmt(mut o DelStmt) !AnyNode
	visit_func_def(mut o FuncDef) !AnyNode
	visit_overloaded_func_def(mut o OverloadedFuncDef) !AnyNode
	visit_class_def(mut o ClassDef) !AnyNode
	visit_global_decl(mut o GlobalDecl) !AnyNode
	visit_nonlocal_decl(mut o NonlocalDecl) !AnyNode
	visit_decorator(mut o Decorator) !AnyNode
	visit_import(mut o Import) !AnyNode
	visit_import_from(mut o ImportFrom) !AnyNode
	visit_import_all(mut o ImportAll) !AnyNode
	visit_block(mut o Block) !AnyNode
	visit_expression_stmt(mut o ExpressionStmt) !AnyNode
	visit_operator_assignment_stmt(mut o OperatorAssignmentStmt) !AnyNode
	visit_while_stmt(mut o WhileStmt) !AnyNode
	visit_return_stmt(mut o ReturnStmt) !AnyNode
	visit_assert_stmt(mut o AssertStmt) !AnyNode
	visit_if_stmt(mut o IfStmt) !AnyNode
	visit_break_stmt(mut o BreakStmt) !AnyNode
	visit_continue_stmt(mut o ContinueStmt) !AnyNode
	visit_pass_stmt(mut o PassStmt) !AnyNode
	visit_raise_stmt(mut o RaiseStmt) !AnyNode
	visit_try_stmt(mut o TryStmt) !AnyNode
	visit_type_alias_stmt(mut o TypeAliasStmt) !AnyNode
	visit_match_stmt(mut o MatchStmt) !AnyNode
}

// ---------------------------------------------------------------------------
// PatternVisitor
// ---------------------------------------------------------------------------

pub interface PatternVisitor {
mut:
	visit_as_pattern(mut o AsPattern) !AnyNode
	visit_or_pattern(mut o OrPattern) !AnyNode
	visit_value_pattern(mut o ValuePattern) !AnyNode
	visit_singleton_pattern(mut o SingletonPattern) !AnyNode
	visit_sequence_pattern(mut o SequencePattern) !AnyNode
	visit_starred_pattern(mut o StarredPattern) !AnyNode
	visit_mapping_pattern(mut o MappingPattern) !AnyNode
	visit_class_pattern(mut o ClassPattern) !AnyNode
}

// ---------------------------------------------------------------------------
// NodeVisitor — combined visitor
// ---------------------------------------------------------------------------

pub interface NodeVisitor {
mut:
	visit_mypy_file(mut o MypyFile) !AnyNode
	visit_var(mut o Var) !AnyNode
	visit_type_alias(mut o TypeAlias) !AnyNode
	visit_placeholder_node(mut o PlaceholderNode) !AnyNode
	visit_argument(mut o Argument) !AnyNode
	visit_type_param(mut o TypeParam) !AnyNode
	visit_type_info(mut o TypeInfo) !AnyNode

	visit_int_expr(mut o IntExpr) !AnyNode
	visit_str_expr(mut o StrExpr) !AnyNode
	visit_bytes_expr(mut o BytesExpr) !AnyNode
	visit_float_expr(mut o FloatExpr) !AnyNode
	visit_complex_expr(mut o ComplexExpr) !AnyNode
	visit_ellipsis(mut o EllipsisExpr) !AnyNode
	visit_star_expr(mut o StarExpr) !AnyNode
	visit_name_expr(mut o NameExpr) !AnyNode
	visit_member_expr(mut o MemberExpr) !AnyNode
	visit_yield_from_expr(mut o YieldFromExpr) !AnyNode
	visit_yield_expr(mut o YieldExpr) !AnyNode
	visit_call_expr(mut o CallExpr) !AnyNode
	visit_op_expr(mut o OpExpr) !AnyNode
	visit_comparison_expr(mut o ComparisonExpr) !AnyNode
	visit_cast_expr(mut o CastExpr) !AnyNode
	visit_assert_type_expr(mut o AssertTypeExpr) !AnyNode
	visit_reveal_expr(mut o RevealExpr) !AnyNode
	visit_super_expr(mut o SuperExpr) !AnyNode
	visit_unary_expr(mut o UnaryExpr) !AnyNode
	visit_assignment_expr(mut o AssignmentExpr) !AnyNode
	visit_list_expr(mut o ListExpr) !AnyNode
	visit_dict_expr(mut o DictExpr) !AnyNode
	visit_template_str_expr(mut o TemplateStrExpr) !AnyNode
	visit_tuple_expr(mut o TupleExpr) !AnyNode
	visit_set_expr(mut o SetExpr) !AnyNode
	visit_index_expr(mut o IndexExpr) !AnyNode
	visit_type_application(mut o TypeApplication) !AnyNode
	visit_lambda_expr(mut o LambdaExpr) !AnyNode
	visit_list_comprehension(mut o ListComprehension) !AnyNode
	visit_set_comprehension(mut o SetComprehension) !AnyNode
	visit_dictionary_comprehension(mut o DictionaryComprehension) !AnyNode
	visit_generator_expr(mut o GeneratorExpr) !AnyNode
	visit_slice_expr(mut o SliceExpr) !AnyNode
	visit_conditional_expr(mut o ConditionalExpr) !AnyNode
	visit_type_var_expr(mut o TypeVarExpr) !AnyNode
	visit_paramspec_expr(mut o ParamSpecExpr) !AnyNode
	visit_type_var_tuple_expr(mut o TypeVarTupleExpr) !AnyNode
	visit_type_alias_expr(mut o TypeAliasExpr) !AnyNode
	visit_namedtuple_expr(mut o NamedTupleExpr) !AnyNode
	visit_enum_call_expr(mut o EnumCallExpr) !AnyNode
	visit_typeddict_expr(mut o TypedDictExpr) !AnyNode
	visit_newtype_expr(mut o NewTypeExpr) !AnyNode
	visit_promote_expr(mut o PromoteExpr) !AnyNode
	visit_await_expr(mut o AwaitExpr) !AnyNode
	visit_temp_node(mut o TempNode) !AnyNode

	visit_assignment_stmt(mut o AssignmentStmt) !AnyNode
	visit_for_stmt(mut o ForStmt) !AnyNode
	visit_with_stmt(mut o WithStmt) !AnyNode
	visit_del_stmt(mut o DelStmt) !AnyNode
	visit_func_def(mut o FuncDef) !AnyNode
	visit_overloaded_func_def(mut o OverloadedFuncDef) !AnyNode
	visit_class_def(mut o ClassDef) !AnyNode
	visit_global_decl(mut o GlobalDecl) !AnyNode
	visit_nonlocal_decl(mut o NonlocalDecl) !AnyNode
	visit_decorator(mut o Decorator) !AnyNode
	visit_import(mut o Import) !AnyNode
	visit_import_from(mut o ImportFrom) !AnyNode
	visit_import_all(mut o ImportAll) !AnyNode
	visit_block(mut o Block) !AnyNode
	visit_expression_stmt(mut o ExpressionStmt) !AnyNode
	visit_operator_assignment_stmt(mut o OperatorAssignmentStmt) !AnyNode
	visit_while_stmt(mut o WhileStmt) !AnyNode
	visit_return_stmt(mut o ReturnStmt) !AnyNode
	visit_assert_stmt(mut o AssertStmt) !AnyNode
	visit_if_stmt(mut o IfStmt) !AnyNode
	visit_break_stmt(mut o BreakStmt) !AnyNode
	visit_continue_stmt(mut o ContinueStmt) !AnyNode
	visit_pass_stmt(mut o PassStmt) !AnyNode
	visit_raise_stmt(mut o RaiseStmt) !AnyNode
	visit_try_stmt(mut o TryStmt) !AnyNode
	visit_type_alias_stmt(mut o TypeAliasStmt) !AnyNode
	visit_match_stmt(mut o MatchStmt) !AnyNode

	visit_as_pattern(mut o AsPattern) !AnyNode
	visit_or_pattern(mut o OrPattern) !AnyNode
	visit_value_pattern(mut o ValuePattern) !AnyNode
	visit_singleton_pattern(mut o SingletonPattern) !AnyNode
	visit_sequence_pattern(mut o SequencePattern) !AnyNode
	visit_starred_pattern(mut o StarredPattern) !AnyNode
	visit_mapping_pattern(mut o MappingPattern) !AnyNode
	visit_class_pattern(mut o ClassPattern) !AnyNode
	visit_lvalue(mut o Lvalue) !AnyNode
}



