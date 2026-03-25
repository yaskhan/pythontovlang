// traverser.v — Concrete no-op NodeVisitor traverser
// Translated from mypy/traverser.py to V 0.5.x
//
// NodeTraverser visits every node in the tree, calling accept() on children.
// Override specific visit_* methods to add custom logic.
// All default implementations traverse children without returning a value.

module mypy

// ---------------------------------------------------------------------------
// NodeTraverser — walks the full AST recursively.
// Satisfies NodeVisitor interface with empty string returns.
// ---------------------------------------------------------------------------

pub struct NodeTraverser {}

// --- top-level ---
pub fn (mut t NodeTraverser) visit_mypy_file(mut o MypyFile) !AnyNode {
	for mut stmt in o.defs {
		stmt_accept(mut stmt, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_var(mut o Var) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_type_alias(mut o TypeAlias) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_placeholder_node(mut o PlaceholderNode) !AnyNode {
	return AnyNode(MypyNode(o))
}

// --- imports ---
pub fn (mut t NodeTraverser) visit_import(mut o Import) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_import_from(mut o ImportFrom) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_import_all(mut o ImportAll) !AnyNode {
	return AnyNode(MypyNode(o))
}

// --- block & simple statements ---
pub fn (mut t NodeTraverser) visit_block(mut o Block) !AnyNode {
	for mut stmt in o.body {
		stmt_accept(mut stmt, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_expression_stmt(mut o ExpressionStmt) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_assignment_stmt(mut o AssignmentStmt) !AnyNode {
	for mut lv in o.lvalues {
		expr_accept(mut lv, mut t)!
	}
	expr_accept(mut o.rvalue, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_operator_assignment_stmt(mut o OperatorAssignmentStmt) !AnyNode {
	t.visit_lvalue(mut o.lvalue)!
	expr_accept(mut o.rvalue, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_while_stmt(mut o WhileStmt) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	t.visit_block(mut o.body)!
	if mut else_b := o.else_body {
		t.visit_block(mut else_b)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_for_stmt(mut o ForStmt) !AnyNode {
	expr_accept(mut o.index, mut t)!
	expr_accept(mut o.expr, mut t)!
	t.visit_block(mut o.body)!
	if mut else_b := o.else_body {
		t.visit_block(mut else_b)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_return_stmt(mut o ReturnStmt) !AnyNode {
	if mut e := o.expr {
		expr_accept(mut e, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_assert_stmt(mut o AssertStmt) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	if mut e := o.msg {
		expr_accept(mut e, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_del_stmt(mut o DelStmt) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_break_stmt(mut o BreakStmt) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_continue_stmt(mut o ContinueStmt) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_pass_stmt(mut o PassStmt) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_if_stmt(mut o IfStmt) !AnyNode {
	for mut e in o.expr {
		expr_accept(mut e, mut t)!
	}
	for mut body in o.body {
		t.visit_block(mut body)!
	}
	if mut else_b := o.else_body {
		t.visit_block(mut else_b)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_raise_stmt(mut o RaiseStmt) !AnyNode {
	if mut e := o.expr {
		expr_accept(mut e, mut t)!
	}
	if mut f := o.from {
		expr_accept(mut f, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_try_stmt(mut o TryStmt) !AnyNode {
	t.visit_block(mut o.body)!
	for mut h in o.handlers {
		t.visit_block(mut h)!
	}
	for mut v in o.vars {
		if mut vv := v {
			expr_accept(mut vv, mut t)!
		}
	}
	for mut tt in o.types {
		if mut type_expr := tt {
			expr_accept(mut type_expr, mut t)!
		}
	}
	if mut else_b := o.else_body {
		t.visit_block(mut else_b)!
	}
	if mut finally_b := o.finally_body {
		t.visit_block(mut finally_b)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_with_stmt(mut o WithStmt) !AnyNode {
	for mut e in o.expr {
		expr_accept(mut e, mut t)!
	}
	for mut target in o.target {
		if mut target_expr := target {
			expr_accept(mut target_expr, mut t)!
		}
	}
	t.visit_block(mut o.body)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_match_stmt(mut o MatchStmt) !AnyNode {
	expr_accept(mut o.subject, mut t)!
	for mut p in o.patterns {
		p.accept(mut t)!
	}
	for mut guard in o.guards {
		if mut g := guard {
			expr_accept(mut g, mut t)!
		}
	}
	for mut body in o.bodies {
		t.visit_block(mut body)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_global_decl(mut o GlobalDecl) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_nonlocal_decl(mut o NonlocalDecl) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_type_alias_stmt(mut o TypeAliasStmt) !AnyNode {
	expr_accept(mut o.value, mut t)!
	return AnyNode(MypyNode(o))
}

// --- definitions ---
pub fn (mut t NodeTraverser) visit_func_def(mut o FuncDef) !AnyNode {
	t.visit_block(mut o.body)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_overloaded_func_def(mut o OverloadedFuncDef) !AnyNode {
	for mut item in o.items {
		t.visit_func_def(mut item)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_class_def(mut o ClassDef) !AnyNode {
	t.visit_block(mut o.defs)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_decorator(mut o Decorator) !AnyNode {
	t.visit_func_def(mut o.func)!
	for mut dec in o.decorators {
		expr_accept(mut dec, mut t)!
	}
	return AnyNode(MypyNode(o))
}

// --- expressions ---
pub fn (mut t NodeTraverser) visit_int_expr(mut o IntExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_str_expr(mut o StrExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_bytes_expr(mut o BytesExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_float_expr(mut o FloatExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_complex_expr(mut o ComplexExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_ellipsis(mut o EllipsisExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_name_expr(mut o NameExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_star_expr(mut o StarExpr) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_member_expr(mut o MemberExpr) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_yield_from_expr(mut o YieldFromExpr) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_yield_expr(mut o YieldExpr) !AnyNode {
	if mut e := o.expr {
		expr_accept(mut e, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_call_expr(mut o CallExpr) !AnyNode {
	expr_accept(mut o.callee, mut t)!
	for mut a in o.args {
		expr_accept(mut a, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_op_expr(mut o OpExpr) !AnyNode {
	expr_accept(mut o.left, mut t)!
	expr_accept(mut o.right, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_comparison_expr(mut o ComparisonExpr) !AnyNode {
	for mut e in o.operands {
		expr_accept(mut e, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_cast_expr(mut o CastExpr) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_assert_type_expr(mut o AssertTypeExpr) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_reveal_expr(mut o RevealExpr) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_super_expr(mut o SuperExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_unary_expr(mut o UnaryExpr) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_assignment_expr(mut o AssignmentExpr) !AnyNode {
	expr_accept(mut o.target, mut t)!
	expr_accept(mut o.value, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_list_expr(mut o ListExpr) !AnyNode {
	for mut i in o.items {
		expr_accept(mut i, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_dict_expr(mut o DictExpr) !AnyNode {
	for mut item in o.items {
		if mut k := item.key {
			expr_accept(mut k, mut t)!
		}
		expr_accept(mut item.value, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_template_str_expr(mut o TemplateStrExpr) !AnyNode {
	_ = o
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_tuple_expr(mut o TupleExpr) !AnyNode {
	for mut i in o.items {
		expr_accept(mut i, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_set_expr(mut o SetExpr) !AnyNode {
	for mut i in o.items {
		expr_accept(mut i, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_index_expr(mut o IndexExpr) !AnyNode {
	expr_accept(mut o.base_, mut t)!
	expr_accept(mut o.index, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_type_application(mut o TypeApplication) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_lambda_expr(mut o LambdaExpr) !AnyNode {
	expr_accept(mut o.body, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_list_comprehension(mut o ListComprehension) !AnyNode {
	t.visit_generator_expr(mut o.generator)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_set_comprehension(mut o SetComprehension) !AnyNode {
	t.visit_generator_expr(mut o.generator)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_dictionary_comprehension(mut o DictionaryComprehension) !AnyNode {
	expr_accept(mut o.key, mut t)!
	expr_accept(mut o.value, mut t)!
	for mut seq in o.sequences {
		expr_accept(mut seq, mut t)!
	}
	for mut conds in o.condlists {
		for mut c in conds {
			expr_accept(mut c, mut t)!
		}
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_generator_expr(mut o GeneratorExpr) !AnyNode {
	expr_accept(mut o.left_expr, mut t)!
	for mut seq in o.sequences {
		expr_accept(mut seq, mut t)!
	}
	for mut conds in o.condlists {
		for mut c in conds {
			expr_accept(mut c, mut t)!
		}
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_slice_expr(mut o SliceExpr) !AnyNode {
	if mut b := o.begin {
		expr_accept(mut b, mut t)!
	}
	if mut e := o.end {
		expr_accept(mut e, mut t)!
	}
	if mut s := o.step {
		expr_accept(mut s, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_conditional_expr(mut o ConditionalExpr) !AnyNode {
	expr_accept(mut o.cond, mut t)!
	expr_accept(mut o.if_expr, mut t)!
	expr_accept(mut o.else_expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_type_var_expr(mut o TypeVarExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_paramspec_expr(mut o ParamSpecExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_type_var_tuple_expr(mut o TypeVarTupleExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_type_alias_expr(mut o TypeAliasExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_namedtuple_expr(mut o NamedTupleExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_enum_call_expr(mut o EnumCallExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_typeddict_expr(mut o TypedDictExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_newtype_expr(mut o NewTypeExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_promote_expr(mut o PromoteExpr) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_await_expr(mut o AwaitExpr) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_temp_node(mut o TempNode) !AnyNode {
	return AnyNode(MypyNode(o))
}

// --- patterns ---
pub fn (mut t NodeTraverser) visit_as_pattern(mut o AsPattern) !AnyNode {
	if mut p := o.pattern {
		pattern_accept(mut p, mut t)!
	}
	if mut n := o.name {
		t.visit_name_expr(mut n)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_or_pattern(mut o OrPattern) !AnyNode {
	for mut p in o.patterns {
		pattern_accept(mut p, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_value_pattern(mut o ValuePattern) !AnyNode {
	expr_accept(mut o.expr, mut t)!
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_singleton_pattern(mut o SingletonPattern) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_sequence_pattern(mut o SequencePattern) !AnyNode {
	for mut p in o.patterns {
		pattern_accept(mut p, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_starred_pattern(mut o StarredPattern) !AnyNode {
	if mut c := o.capture {
		t.visit_name_expr(mut c)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_mapping_pattern(mut o MappingPattern) !AnyNode {
	for mut k in o.keys {
		expr_accept(mut k, mut t)!
	}
	for mut p in o.values {
		pattern_accept(mut p, mut t)!
	}
	if mut r := o.rest {
		t.visit_name_expr(mut r)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_class_pattern(mut o ClassPattern) !AnyNode {
	expr_accept(mut o.class_ref, mut t)!
	for mut p in o.positionals {
		pattern_accept(mut p, mut t)!
	}
	for mut p in o.keyword_values {
		pattern_accept(mut p, mut t)!
	}
	return AnyNode(MypyNode(o))
}

// --- Lvalue ---
pub fn (mut t NodeTraverser) visit_lvalue(mut o Lvalue) !AnyNode {
	mut it_o := o
	match mut it_o {
		ListExpr { t.visit_list_expr(mut it_o)! }
		MemberExpr { t.visit_member_expr(mut it_o)! }
		NameExpr { t.visit_name_expr(mut it_o)! }
		StarExpr { t.visit_star_expr(mut it_o)! }
		TupleExpr { t.visit_tuple_expr(mut it_o)! }
	}
	return AnyNode(string(''))
}

// --- Others ---
pub fn (mut t NodeTraverser) visit_argument(mut o Argument) !AnyNode {
	if mut initializer := o.initializer {
		expr_accept(mut initializer, mut t)!
	}
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_type_param(mut o TypeParam) !AnyNode {
	return AnyNode(MypyNode(o))
}

pub fn (mut t NodeTraverser) visit_type_info(mut o TypeInfo) !AnyNode {
	return AnyNode(MypyNode(o))
}

// ---------------------------------------------------------------------------
// Dispatch helpers — needed because V sum-types require explicit match.
// ---------------------------------------------------------------------------

pub fn stmt_accept(mut s Statement, mut v NodeVisitor) !AnyNode {
	return match mut s {
		AssignmentStmt { v.visit_assignment_stmt(mut s)! }
		AssertStmt { v.visit_assert_stmt(mut s)! }
		Block { v.visit_block(mut s)! }
		BreakStmt { v.visit_break_stmt(mut s)! }
		ClassDef { v.visit_class_def(mut s)! }
		ContinueStmt { v.visit_continue_stmt(mut s)! }
		Decorator { v.visit_decorator(mut s)! }
		DelStmt { v.visit_del_stmt(mut s)! }
		ExpressionStmt { v.visit_expression_stmt(mut s)! }
		ForStmt { v.visit_for_stmt(mut s)! }
		FuncDef { v.visit_func_def(mut s)! }
		GlobalDecl { v.visit_global_decl(mut s)! }
		IfStmt { v.visit_if_stmt(mut s)! }
		Import { v.visit_import(mut s)! }
		ImportAll { v.visit_import_all(mut s)! }
		ImportFrom { v.visit_import_from(mut s)! }
		MatchStmt { v.visit_match_stmt(mut s)! }
		NonlocalDecl { v.visit_nonlocal_decl(mut s)! }
		OperatorAssignmentStmt { v.visit_operator_assignment_stmt(mut s)! }
		OverloadedFuncDef { v.visit_overloaded_func_def(mut s)! }
		PassStmt { v.visit_pass_stmt(mut s)! }
		RaiseStmt { v.visit_raise_stmt(mut s)! }
		ReturnStmt { v.visit_return_stmt(mut s)! }
		TryStmt { v.visit_try_stmt(mut s)! }
		TypeAliasStmt { v.visit_type_alias_stmt(mut s)! }
		WhileStmt { v.visit_while_stmt(mut s)! }
		WithStmt { v.visit_with_stmt(mut s)! }
	}
}

pub fn expr_accept(mut e Expression, mut v NodeVisitor) !AnyNode {
	return match mut e {
		AssignmentExpr { v.visit_assignment_expr(mut e)! }
		AwaitExpr { v.visit_await_expr(mut e)! }
		BytesExpr { v.visit_bytes_expr(mut e)! }
		CallExpr { v.visit_call_expr(mut e)! }
		CastExpr { v.visit_cast_expr(mut e)! }
		ComparisonExpr { v.visit_comparison_expr(mut e)! }
		ComplexExpr { v.visit_complex_expr(mut e)! }
		ConditionalExpr { v.visit_conditional_expr(mut e)! }
		DictExpr { v.visit_dict_expr(mut e)! }
		DictionaryComprehension { v.visit_dictionary_comprehension(mut e)! }
		EllipsisExpr { v.visit_ellipsis(mut e)! }
		EnumCallExpr { v.visit_enum_call_expr(mut e)! }
		FloatExpr { v.visit_float_expr(mut e)! }
		GeneratorExpr { v.visit_generator_expr(mut e)! }
		IndexExpr { v.visit_index_expr(mut e)! }
		IntExpr { v.visit_int_expr(mut e)! }
		LambdaExpr { v.visit_lambda_expr(mut e)! }
		ListComprehension { v.visit_list_comprehension(mut e)! }
		ListExpr { v.visit_list_expr(mut e)! }
		MemberExpr { v.visit_member_expr(mut e)! }
		NameExpr { v.visit_name_expr(mut e)! }
		NamedTupleExpr { v.visit_namedtuple_expr(mut e)! }
		NewTypeExpr { v.visit_newtype_expr(mut e)! }
		OpExpr { v.visit_op_expr(mut e)! }
		ParamSpecExpr { v.visit_paramspec_expr(mut e)! }
		PromoteExpr { v.visit_promote_expr(mut e)! }
		RevealExpr { v.visit_reveal_expr(mut e)! }
		SetComprehension { v.visit_set_comprehension(mut e)! }
		SetExpr { v.visit_set_expr(mut e)! }
		SliceExpr { v.visit_slice_expr(mut e)! }
		StarExpr { v.visit_star_expr(mut e)! }
		StrExpr { v.visit_str_expr(mut e)! }
		SuperExpr { v.visit_super_expr(mut e)! }
		TempNode { v.visit_temp_node(mut e)! }
		TemplateStrExpr { v.visit_template_str_expr(mut e)! }
		TupleExpr { v.visit_tuple_expr(mut e)! }
		TypeAliasExpr { v.visit_type_alias_expr(mut e)! }
		TypeApplication { v.visit_type_application(mut e)! }
		TypeVarExpr { v.visit_type_var_expr(mut e)! }
		TypeVarTupleExpr { v.visit_type_var_tuple_expr(mut e)! }
		TypedDictExpr { v.visit_typeddict_expr(mut e)! }
		UnaryExpr { v.visit_unary_expr(mut e)! }
		AssertTypeExpr { v.visit_assert_type_expr(mut e)! }
		FormatStringExpr {
			v.visit_template_str_expr(mut TemplateStrExpr{base: e.base, parts: [e.value]})!
		}
		YieldExpr { v.visit_yield_expr(mut e)! }
		YieldFromExpr { v.visit_yield_from_expr(mut e)! }
	}
}

pub fn pattern_accept(mut p PatternNode, mut v NodeVisitor) !AnyNode {
	return match mut p {
		AsPattern { v.visit_as_pattern(mut p)! }
		OrPattern { v.visit_or_pattern(mut p)! }
		ValuePattern { v.visit_value_pattern(mut p)! }
		SingletonPattern { v.visit_singleton_pattern(mut p)! }
		SequencePattern { v.visit_sequence_pattern(mut p)! }
		StarredPattern { v.visit_starred_pattern(mut p)! }
		MappingPattern { v.visit_mapping_pattern(mut p)! }
		ClassPattern { v.visit_class_pattern(mut p)! }
	}
}
