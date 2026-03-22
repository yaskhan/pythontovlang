// visitor.v — Generic AST node visitor interfaces
// Translated from mypy/visitor.py to V 0.5.x

module mypy

// ---------------------------------------------------------------------------
// Forward declarations (resolve cross-module references)
// ---------------------------------------------------------------------------

// Nodes and patterns are declared in nodes.v / patterns.v.
// In V, interfaces don't need a generic type param the same way Python does —
// we use `any` as the return type to replicate Generic[T] visitor pattern.
// Concrete visitors can wrap results in their own sum-type or struct.

// ---------------------------------------------------------------------------
// ExpressionVisitor
// ---------------------------------------------------------------------------

pub interface ExpressionVisitor {
mut:

	visit_int_expr(o &IntExpr) !string
	visit_str_expr(o &StrExpr) !string
	visit_bytes_expr(o &BytesExpr) !string
	visit_float_expr(o &FloatExpr) !string
	visit_complex_expr(o &ComplexExpr) !string
	visit_ellipsis(o &EllipsisExpr) !string
	visit_star_expr(o &StarExpr) !string
	visit_name_expr(o &NameExpr) !string
	visit_member_expr(o &MemberExpr) !string
	visit_yield_from_expr(o &YieldFromExpr) !string
	visit_yield_expr(o &YieldExpr) !string
	visit_call_expr(o &CallExpr) !string
	visit_op_expr(o &OpExpr) !string
	visit_comparison_expr(o &ComparisonExpr) !string
	visit_cast_expr(o &CastExpr) !string
	visit_assert_type_expr(o &AssertTypeExpr) !string
	visit_reveal_expr(o &RevealExpr) !string
	visit_super_expr(o &SuperExpr) !string
	visit_unary_expr(o &UnaryExpr) !string
	visit_assignment_expr(o &AssignmentExpr) !string
	visit_list_expr(o &ListExpr) !string
	visit_dict_expr(o &DictExpr) !string
	visit_template_str_expr(o &TemplateStrExpr) !string
	visit_tuple_expr(o &TupleExpr) !string
	visit_set_expr(o &SetExpr) !string
	visit_index_expr(o &IndexExpr) !string
	visit_type_application(o &TypeApplication) !string
	visit_lambda_expr(o &LambdaExpr) !string
	visit_list_comprehension(o &ListComprehension) !string
	visit_set_comprehension(o &SetComprehension) !string
	visit_dictionary_comprehension(o &DictionaryComprehension) !string
	visit_generator_expr(o &GeneratorExpr) !string
	visit_slice_expr(o &SliceExpr) !string
	visit_conditional_expr(o &ConditionalExpr) !string
	visit_type_var_expr(o &TypeVarExpr) !string
	visit_paramspec_expr(o &ParamSpecExpr) !string
	visit_type_var_tuple_expr(o &TypeVarTupleExpr) !string
	visit_type_alias_expr(o &TypeAliasExpr) !string
	visit_namedtuple_expr(o &NamedTupleExpr) !string
	visit_enum_call_expr(o &EnumCallExpr) !string
	visit_typeddict_expr(o &TypedDictExpr) !string
	visit_newtype_expr(o &NewTypeExpr) !string
	visit_promote_expr(o &PromoteExpr) !string
	visit_await_expr(o &AwaitExpr) !string
	visit_temp_node(o &TempNode) !string
}

// ---------------------------------------------------------------------------
// StatementVisitor
// ---------------------------------------------------------------------------

pub interface StatementVisitor {
mut:

	// Definitions
	visit_assignment_stmt(o &AssignmentStmt) !string
	visit_for_stmt(o &ForStmt) !string
	visit_with_stmt(o &WithStmt) !string
	visit_del_stmt(o &DelStmt) !string
	visit_func_def(o &FuncDef) !string
	visit_overloaded_func_def(o &OverloadedFuncDef) !string
	visit_class_def(o &ClassDef) !string
	visit_global_decl(o &GlobalDecl) !string
	visit_nonlocal_decl(o &NonlocalDecl) !string
	visit_decorator(o &Decorator) !string
	// Module structure
	visit_import(o &Import) !string
	visit_import_from(o &ImportFrom) !string
	visit_import_all(o &ImportAll) !string
	// Statements
	visit_block(o &Block) !string
	visit_expression_stmt(o &ExpressionStmt) !string
	visit_operator_assignment_stmt(o &OperatorAssignmentStmt) !string
	visit_while_stmt(o &WhileStmt) !string
	visit_return_stmt(o &ReturnStmt) !string
	visit_assert_stmt(o &AssertStmt) !string
	visit_if_stmt(o &IfStmt) !string
	visit_break_stmt(o &BreakStmt) !string
	visit_continue_stmt(o &ContinueStmt) !string
	visit_pass_stmt(o &PassStmt) !string
	visit_raise_stmt(o &RaiseStmt) !string
	visit_try_stmt(o &TryStmt) !string
	visit_match_stmt(o &MatchStmt) !string
	visit_type_alias_stmt(o &TypeAliasStmt) !string
}

// ---------------------------------------------------------------------------
// PatternVisitor
// ---------------------------------------------------------------------------

pub interface PatternVisitor {
mut:

	visit_as_pattern(o &AsPattern) !string
	visit_or_pattern(o &OrPattern) !string
	visit_value_pattern(o &ValuePattern) !string
	visit_singleton_pattern(o &SingletonPattern) !string
	visit_sequence_pattern(o &SequencePattern) !string
	visit_starred_pattern(o &StarredPattern) !string
	visit_mapping_pattern(o &MappingPattern) !string
	visit_class_pattern(o &ClassPattern) !string
}

// ---------------------------------------------------------------------------
// NodeVisitor — combined visitor (Python: NodeVisitor(Generic[T], ExpressionVisitor[T], ...))
//
// V doesn't support interface embedding directly in the same way,
// so NodeVisitor declares all methods inline. A concrete struct that
// implements NodeVisitor automatically satisfies the narrower interfaces.
// ---------------------------------------------------------------------------

pub interface NodeVisitor {
mut:

	// --- top-level file ---
	visit_mypy_file(o &MypyFile) !string
	visit_var(o &Var) !string
	visit_type_alias(o &TypeAlias) !string
	visit_placeholder_node(o &PlaceholderNode) !string

	// --- inherited from StatementVisitor ---
	visit_assignment_stmt(o &AssignmentStmt) !string
	visit_for_stmt(o &ForStmt) !string
	visit_with_stmt(o &WithStmt) !string
	visit_del_stmt(o &DelStmt) !string
	visit_func_def(o &FuncDef) !string
	visit_overloaded_func_def(o &OverloadedFuncDef) !string
	visit_class_def(o &ClassDef) !string
	visit_global_decl(o &GlobalDecl) !string
	visit_nonlocal_decl(o &NonlocalDecl) !string
	visit_decorator(o &Decorator) !string
	visit_import(o &Import) !string
	visit_import_from(o &ImportFrom) !string
	visit_import_all(o &ImportAll) !string
	visit_block(o &Block) !string
	visit_expression_stmt(o &ExpressionStmt) !string
	visit_operator_assignment_stmt(o &OperatorAssignmentStmt) !string
	visit_while_stmt(o &WhileStmt) !string
	visit_return_stmt(o &ReturnStmt) !string
	visit_assert_stmt(o &AssertStmt) !string
	visit_if_stmt(o &IfStmt) !string
	visit_break_stmt(o &BreakStmt) !string
	visit_continue_stmt(o &ContinueStmt) !string
	visit_pass_stmt(o &PassStmt) !string
	visit_raise_stmt(o &RaiseStmt) !string
	visit_try_stmt(o &TryStmt) !string
	visit_match_stmt(o &MatchStmt) !string
	visit_type_alias_stmt(o &TypeAliasStmt) !string

	// --- inherited from ExpressionVisitor ---
	visit_int_expr(o &IntExpr) !string
	visit_str_expr(o &StrExpr) !string
	visit_bytes_expr(o &BytesExpr) !string
	visit_float_expr(o &FloatExpr) !string
	visit_complex_expr(o &ComplexExpr) !string
	visit_ellipsis(o &EllipsisExpr) !string
	visit_star_expr(o &StarExpr) !string
	visit_name_expr(o &NameExpr) !string
	visit_member_expr(o &MemberExpr) !string
	visit_yield_from_expr(o &YieldFromExpr) !string
	visit_yield_expr(o &YieldExpr) !string
	visit_call_expr(o &CallExpr) !string
	visit_op_expr(o &OpExpr) !string
	visit_comparison_expr(o &ComparisonExpr) !string
	visit_cast_expr(o &CastExpr) !string
	visit_assert_type_expr(o &AssertTypeExpr) !string
	visit_reveal_expr(o &RevealExpr) !string
	visit_super_expr(o &SuperExpr) !string
	visit_unary_expr(o &UnaryExpr) !string
	visit_assignment_expr(o &AssignmentExpr) !string
	visit_list_expr(o &ListExpr) !string
	visit_dict_expr(o &DictExpr) !string
	visit_template_str_expr(o &TemplateStrExpr) !string
	visit_tuple_expr(o &TupleExpr) !string
	visit_set_expr(o &SetExpr) !string
	visit_index_expr(o &IndexExpr) !string
	visit_type_application(o &TypeApplication) !string
	visit_lambda_expr(o &LambdaExpr) !string
	visit_list_comprehension(o &ListComprehension) !string
	visit_set_comprehension(o &SetComprehension) !string
	visit_dictionary_comprehension(o &DictionaryComprehension) !string
	visit_generator_expr(o &GeneratorExpr) !string
	visit_slice_expr(o &SliceExpr) !string
	visit_conditional_expr(o &ConditionalExpr) !string
	visit_type_var_expr(o &TypeVarExpr) !string
	visit_paramspec_expr(o &ParamSpecExpr) !string
	visit_type_var_tuple_expr(o &TypeVarTupleExpr) !string
	visit_type_alias_expr(o &TypeAliasExpr) !string
	visit_namedtuple_expr(o &NamedTupleExpr) !string
	visit_enum_call_expr(o &EnumCallExpr) !string
	visit_typeddict_expr(o &TypedDictExpr) !string
	visit_newtype_expr(o &NewTypeExpr) !string
	visit_promote_expr(o &PromoteExpr) !string
	visit_await_expr(o &AwaitExpr) !string
	visit_temp_node(o &TempNode) !string

	// --- inherited from PatternVisitor ---
	visit_as_pattern(o &AsPattern) !string
	visit_or_pattern(o &OrPattern) !string
	visit_value_pattern(o &ValuePattern) !string
	visit_singleton_pattern(o &SingletonPattern) !string
	visit_sequence_pattern(o &SequencePattern) !string
	visit_starred_pattern(o &StarredPattern) !string
	visit_mapping_pattern(o &MappingPattern) !string
	visit_class_pattern(o &ClassPattern) !string
}
