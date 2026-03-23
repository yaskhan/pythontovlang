// visitor.v — Generic AST node visitor interfaces
module mypy

// ---------------------------------------------------------------------------
// ExpressionVisitor
// ---------------------------------------------------------------------------

pub interface ExpressionVisitor {
mut:
	visit_int_expr(mut o IntExpr) !string
	visit_str_expr(mut o StrExpr) !string
	visit_bytes_expr(mut o BytesExpr) !string
	visit_float_expr(mut o FloatExpr) !string
	visit_complex_expr(mut o ComplexExpr) !string
	visit_ellipsis(mut o EllipsisExpr) !string
	visit_star_expr(mut o StarExpr) !string
	visit_name_expr(mut o NameExpr) !string
	visit_member_expr(mut o MemberExpr) !string
	visit_yield_from_expr(mut o YieldFromExpr) !string
	visit_yield_expr(mut o YieldExpr) !string
	visit_call_expr(mut o CallExpr) !string
	visit_op_expr(mut o OpExpr) !string
	visit_comparison_expr(mut o ComparisonExpr) !string
	visit_cast_expr(mut o CastExpr) !string
	visit_assert_type_expr(mut o AssertTypeExpr) !string
	visit_reveal_expr(mut o RevealExpr) !string
	visit_super_expr(mut o SuperExpr) !string
	visit_unary_expr(mut o UnaryExpr) !string
	visit_assignment_expr(mut o AssignmentExpr) !string
	visit_list_expr(mut o ListExpr) !string
	visit_dict_expr(mut o DictExpr) !string
	visit_template_str_expr(mut o TemplateStrExpr) !string
	visit_tuple_expr(mut o TupleExpr) !string
	visit_set_expr(mut o SetExpr) !string
	visit_index_expr(mut o IndexExpr) !string
	visit_type_application(mut o TypeApplication) !string
	visit_lambda_expr(mut o LambdaExpr) !string
	visit_list_comprehension(mut o ListComprehension) !string
	visit_set_comprehension(mut o SetComprehension) !string
	visit_dictionary_comprehension(mut o DictionaryComprehension) !string
	visit_generator_expr(mut o GeneratorExpr) !string
	visit_slice_expr(mut o SliceExpr) !string
	visit_conditional_expr(mut o ConditionalExpr) !string
	visit_type_var_expr(mut o TypeVarExpr) !string
	visit_paramspec_expr(mut o ParamSpecExpr) !string
	visit_type_var_tuple_expr(mut o TypeVarTupleExpr) !string
	visit_type_alias_expr(mut o TypeAliasExpr) !string
	visit_namedtuple_expr(mut o NamedTupleExpr) !string
	visit_enum_call_expr(mut o EnumCallExpr) !string
	visit_typeddict_expr(mut o TypedDictExpr) !string
	visit_newtype_expr(mut o NewTypeExpr) !string
	visit_promote_expr(mut o PromoteExpr) !string
	visit_await_expr(mut o AwaitExpr) !string
	visit_temp_node(mut o TempNode) !string
}

// ---------------------------------------------------------------------------
// StatementVisitor
// ---------------------------------------------------------------------------

pub interface StatementVisitor {
mut:
	visit_assignment_stmt(mut o AssignmentStmt) !string
	visit_for_stmt(mut o ForStmt) !string
	visit_with_stmt(mut o WithStmt) !string
	visit_del_stmt(mut o DelStmt) !string
	visit_func_def(mut o FuncDef) !string
	visit_overloaded_func_def(mut o OverloadedFuncDef) !string
	visit_class_def(mut o ClassDef) !string
	visit_global_decl(mut o GlobalDecl) !string
	visit_nonlocal_decl(mut o NonlocalDecl) !string
	visit_decorator(mut o Decorator) !string
	visit_import(mut o Import) !string
	visit_import_from(mut o ImportFrom) !string
	visit_import_all(mut o ImportAll) !string
	visit_block(mut o Block) !string
	visit_expression_stmt(mut o ExpressionStmt) !string
	visit_operator_assignment_stmt(mut o OperatorAssignmentStmt) !string
	visit_while_stmt(mut o WhileStmt) !string
	visit_return_stmt(mut o ReturnStmt) !string
	visit_assert_stmt(mut o AssertStmt) !string
	visit_if_stmt(mut o IfStmt) !string
	visit_break_stmt(mut o BreakStmt) !string
	visit_continue_stmt(mut o ContinueStmt) !string
	visit_pass_stmt(mut o PassStmt) !string
	visit_raise_stmt(mut o RaiseStmt) !string
	visit_try_stmt(mut o TryStmt) !string
	visit_type_alias_stmt(mut o TypeAliasStmt) !string
	visit_match_stmt(mut o MatchStmt) !string
}

// ---------------------------------------------------------------------------
// PatternVisitor
// ---------------------------------------------------------------------------

pub interface PatternVisitor {
mut:
	visit_as_pattern(mut o AsPattern) !string
	visit_or_pattern(mut o OrPattern) !string
	visit_value_pattern(mut o ValuePattern) !string
	visit_singleton_pattern(mut o SingletonPattern) !string
	visit_sequence_pattern(mut o SequencePattern) !string
	visit_starred_pattern(mut o StarredPattern) !string
	visit_mapping_pattern(mut o MappingPattern) !string
	visit_class_pattern(mut o ClassPattern) !string
}

// ---------------------------------------------------------------------------
// NodeVisitor — combined visitor
// ---------------------------------------------------------------------------

pub interface NodeVisitor {
mut:
	visit_mypy_file(mut o MypyFile) !string
	visit_var(mut o Var) !string
	visit_type_alias(mut o TypeAlias) !string
	visit_placeholder_node(mut o PlaceholderNode) !string
	visit_argument(mut o Argument) !string
	visit_type_param(mut o TypeParam) !string
	visit_type_info(mut o TypeInfo) !string

	// From ExpressionVisitor
	visit_int_expr(mut o IntExpr) !string
	visit_str_expr(mut o StrExpr) !string
	visit_bytes_expr(mut o BytesExpr) !string
	visit_float_expr(mut o FloatExpr) !string
	visit_complex_expr(mut o ComplexExpr) !string
	visit_ellipsis(mut o EllipsisExpr) !string
	visit_star_expr(mut o StarExpr) !string
	visit_name_expr(mut o NameExpr) !string
	visit_member_expr(mut o MemberExpr) !string
	visit_yield_from_expr(mut o YieldFromExpr) !string
	visit_yield_expr(mut o YieldExpr) !string
	visit_call_expr(mut o CallExpr) !string
	visit_op_expr(mut o OpExpr) !string
	visit_comparison_expr(mut o ComparisonExpr) !string
	visit_cast_expr(mut o CastExpr) !string
	visit_assert_type_expr(mut o AssertTypeExpr) !string
	visit_reveal_expr(mut o RevealExpr) !string
	visit_super_expr(mut o SuperExpr) !string
	visit_unary_expr(mut o UnaryExpr) !string
	visit_assignment_expr(mut o AssignmentExpr) !string
	visit_list_expr(mut o ListExpr) !string
	visit_dict_expr(mut o DictExpr) !string
	visit_template_str_expr(mut o TemplateStrExpr) !string
	visit_tuple_expr(mut o TupleExpr) !string
	visit_set_expr(mut o SetExpr) !string
	visit_index_expr(mut o IndexExpr) !string
	visit_type_application(mut o TypeApplication) !string
	visit_lambda_expr(mut o LambdaExpr) !string
	visit_list_comprehension(mut o ListComprehension) !string
	visit_set_comprehension(mut o SetComprehension) !string
	visit_dictionary_comprehension(mut o DictionaryComprehension) !string
	visit_generator_expr(mut o GeneratorExpr) !string
	visit_slice_expr(mut o SliceExpr) !string
	visit_conditional_expr(mut o ConditionalExpr) !string
	visit_type_var_expr(mut o TypeVarExpr) !string
	visit_paramspec_expr(mut o ParamSpecExpr) !string
	visit_type_var_tuple_expr(mut o TypeVarTupleExpr) !string
	visit_type_alias_expr(mut o TypeAliasExpr) !string
	visit_namedtuple_expr(mut o NamedTupleExpr) !string
	visit_enum_call_expr(mut o EnumCallExpr) !string
	visit_typeddict_expr(mut o TypedDictExpr) !string
	visit_newtype_expr(mut o NewTypeExpr) !string
	visit_promote_expr(mut o PromoteExpr) !string
	visit_await_expr(mut o AwaitExpr) !string
	visit_temp_node(mut o TempNode) !string

	// From StatementVisitor
	visit_assignment_stmt(mut o AssignmentStmt) !string
	visit_for_stmt(mut o ForStmt) !string
	visit_with_stmt(mut o WithStmt) !string
	visit_del_stmt(mut o DelStmt) !string
	visit_func_def(mut o FuncDef) !string
	visit_overloaded_func_def(mut o OverloadedFuncDef) !string
	visit_class_def(mut o ClassDef) !string
	visit_global_decl(mut o GlobalDecl) !string
	visit_nonlocal_decl(mut o NonlocalDecl) !string
	visit_decorator(mut o Decorator) !string
	visit_import(mut o Import) !string
	visit_import_from(mut o ImportFrom) !string
	visit_import_all(mut o ImportAll) !string
	visit_block(mut o Block) !string
	visit_expression_stmt(mut o ExpressionStmt) !string
	visit_operator_assignment_stmt(mut o OperatorAssignmentStmt) !string
	visit_while_stmt(mut o WhileStmt) !string
	visit_return_stmt(mut o ReturnStmt) !string
	visit_assert_stmt(mut o AssertStmt) !string
	visit_if_stmt(mut o IfStmt) !string
	visit_break_stmt(mut o BreakStmt) !string
	visit_continue_stmt(mut o ContinueStmt) !string
	visit_pass_stmt(mut o PassStmt) !string
	visit_raise_stmt(mut o RaiseStmt) !string
	visit_try_stmt(mut o TryStmt) !string
	visit_type_alias_stmt(mut o TypeAliasStmt) !string
	visit_match_stmt(mut o MatchStmt) !string
	visit_type_info(mut o TypeInfo) !string

	// From PatternVisitor
	visit_as_pattern(mut o AsPattern) !string
	visit_or_pattern(mut o OrPattern) !string
	visit_value_pattern(mut o ValuePattern) !string
	visit_singleton_pattern(mut o SingletonPattern) !string
	visit_sequence_pattern(mut o SequencePattern) !string
	visit_starred_pattern(mut o StarredPattern) !string
	visit_mapping_pattern(mut o MappingPattern) !string
	visit_class_pattern(mut o ClassPattern) !string
}
