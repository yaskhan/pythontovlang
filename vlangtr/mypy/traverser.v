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
pub fn (mut t NodeTraverser) visit_mypy_file(mut o MypyFile) !string {
	for stmt in o.defs {
		stmt_accept(stmt, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_var(mut o Var) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_type_alias(mut o TypeAlias) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_placeholder_node(mut o PlaceholderNode) !string {
	return ''
}

// --- imports ---
pub fn (mut t NodeTraverser) visit_import(mut o Import) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_import_from(mut o ImportFrom) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_import_all(mut o ImportAll) !string {
	return ''
}

// --- block & simple statements ---
pub fn (mut t NodeTraverser) visit_block(mut o Block) !string {
	for stmt in o.body {
		stmt_accept(stmt, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_expression_stmt(mut o ExpressionStmt) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_assignment_stmt(mut o AssignmentStmt) !string {
	for lv in o.lvalues {
		expr_accept(lv, mut t)!
	}
	expr_accept(o.rvalue, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_operator_assignment_stmt(mut o OperatorAssignmentStmt) !string {
	t.visit_lvalue(mut o.lvalue)!
	expr_accept(o.rvalue, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_while_stmt(mut o WhileStmt) !string {
	expr_accept(o.expr, mut t)!
	t.visit_block(mut o.body)!
	if else_b := o.else_body {
		t.visit_block(mut else_b)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_for_stmt(mut o ForStmt) !string {
	expr_accept(o.index, mut t)!
	expr_accept(o.expr, mut t)!
	t.visit_block(mut o.body)!
	if else_b := o.else_body {
		t.visit_block(mut else_b)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_return_stmt(mut o ReturnStmt) !string {
	if e := o.expr {
		expr_accept(e, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_assert_stmt(mut o AssertStmt) !string {
	expr_accept(o.expr, mut t)!
	if msg := o.msg {
		expr_accept(msg, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_del_stmt(mut o DelStmt) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_break_stmt(mut o BreakStmt) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_continue_stmt(mut o ContinueStmt) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_pass_stmt(mut o PassStmt) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_if_stmt(mut o IfStmt) !string {
	for expr in o.expr {
		expr_accept(expr, mut t)!
	}
	for b in o.body {
		t.visit_block(mut b)!
	}
	if else_b := o.else_body {
		t.visit_block(mut else_b)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_raise_stmt(mut o RaiseStmt) !string {
	if e := o.expr {
		expr_accept(e, mut t)!
	}
	if e := o.from {
		expr_accept(e, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_try_stmt(mut o TryStmt) !string {
	t.visit_block(mut o.body)!
	for te in o.types {
		if e := te {
			expr_accept(e, mut t)!
		}
	}
	for v in o.vars {
		if n := v {
			t.visit_name_expr(mut n)!
		}
	}
	for h in o.handlers {
		t.visit_block(mut h)!
	}
	if else_b := o.else_body {
		t.visit_block(mut else_b)!
	}
	if fin := o.finally_body {
		t.visit_block(mut fin)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_with_stmt(mut o WithStmt) !string {
	for e in o.expr {
		expr_accept(e, mut t)!
	}
	for target in o.target {
		if e := target {
			expr_accept(e, mut t)!
		}
	}
	t.visit_block(mut o.body)!
	return ''
}

pub fn (mut t NodeTraverser) visit_match_stmt(mut o MatchStmt) !string {
	expr_accept(o.subject, mut t)!
	for guard in o.guards {
		if g := guard {
			expr_accept(g, mut t)!
		}
	}
	for body in o.bodies {
		t.visit_block(mut body)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_global_decl(mut o GlobalDecl) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_nonlocal_decl(mut o NonlocalDecl) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_type_alias_stmt(mut o TypeAliasStmt) !string {
	expr_accept(o.value, mut t)!
	return ''
}

// --- definitions ---
pub fn (mut t NodeTraverser) visit_func_def(mut o FuncDef) !string {
	t.visit_block(mut o.body)!
	return ''
}

pub fn (mut t NodeTraverser) visit_overloaded_func_def(mut o OverloadedFuncDef) !string {
	for item in o.items {
		t.visit_func_def(mut item)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_class_def(mut o ClassDef) !string {
	t.visit_block(mut o.defs)!
	return ''
}

pub fn (mut t NodeTraverser) visit_decorator(mut o Decorator) !string {
	t.visit_func_def(mut o.func)!
	for dec in o.decorators {
		expr_accept(dec, mut t)!
	}
	return ''
}

// --- expressions ---
pub fn (mut t NodeTraverser) visit_int_expr(mut o IntExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_str_expr(mut o StrExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_bytes_expr(mut o BytesExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_float_expr(mut o FloatExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_complex_expr(mut o ComplexExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_ellipsis(mut o EllipsisExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_name_expr(mut o NameExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_star_expr(mut o StarExpr) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_member_expr(mut o MemberExpr) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_yield_from_expr(mut o YieldFromExpr) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_yield_expr(mut o YieldExpr) !string {
	if e := o.expr {
		expr_accept(e, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_call_expr(mut o CallExpr) !string {
	expr_accept(o.callee, mut t)!
	for a in o.args {
		expr_accept(a, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_op_expr(mut o OpExpr) !string {
	expr_accept(o.left, mut t)!
	expr_accept(o.right, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_comparison_expr(mut o ComparisonExpr) !string {
	for e in o.operands {
		expr_accept(e, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_cast_expr(mut o CastExpr) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_assert_type_expr(mut o AssertTypeExpr) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_reveal_expr(mut o RevealExpr) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_super_expr(mut o SuperExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_unary_expr(mut o UnaryExpr) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_assignment_expr(mut o AssignmentExpr) !string {
	expr_accept(o.target, mut t)!
	expr_accept(o.value, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_list_expr(mut o ListExpr) !string {
	for i in o.items {
		expr_accept(i, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_dict_expr(mut o DictExpr) !string {
	for item in o.items {
		if item.len > 0 {
			expr_accept(item[0], mut t)!
		}
		if item.len > 1 {
			expr_accept(item[1], mut t)!
		}
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_template_str_expr(mut o TemplateStrExpr) !string {
	_ = o
	return ''
}

pub fn (mut t NodeTraverser) visit_tuple_expr(mut o TupleExpr) !string {
	for i in o.items {
		expr_accept(i, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_set_expr(mut o SetExpr) !string {
	for i in o.items {
		expr_accept(i, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_index_expr(mut o IndexExpr) !string {
	expr_accept(o.base_, mut t)!
	expr_accept(o.index, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_type_application(mut o TypeApplication) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_lambda_expr(mut o LambdaExpr) !string {
	expr_accept(o.body, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_list_comprehension(mut o ListComprehension) !string {
	t.visit_generator_expr(mut o.generator)!
	return ''
}

pub fn (mut t NodeTraverser) visit_set_comprehension(mut o SetComprehension) !string {
	t.visit_generator_expr(mut o.generator)!
	return ''
}

pub fn (mut t NodeTraverser) visit_dictionary_comprehension(mut o DictionaryComprehension) !string {
	expr_accept(o.key, mut t)!
	expr_accept(o.value, mut t)!
	for seq in o.sequences {
		expr_accept(seq, mut t)!
	}
	for conds in o.condlists {
		for c in conds {
			expr_accept(c, mut t)!
		}
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_generator_expr(mut o GeneratorExpr) !string {
	expr_accept(o.left_expr, mut t)!
	for seq in o.sequences {
		expr_accept(seq, mut t)!
	}
	for conds in o.condlists {
		for c in conds {
			expr_accept(c, mut t)!
		}
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_slice_expr(mut o SliceExpr) !string {
	if b := o.begin {
		expr_accept(b, mut t)!
	}
	if e := o.end {
		expr_accept(e, mut t)!
	}
	if s := o.step {
		expr_accept(s, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_conditional_expr(mut o ConditionalExpr) !string {
	expr_accept(o.cond, mut t)!
	expr_accept(o.if_expr, mut t)!
	expr_accept(o.else_expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_type_var_expr(mut o TypeVarExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_paramspec_expr(mut o ParamSpecExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_type_var_tuple_expr(mut o TypeVarTupleExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_type_alias_expr(mut o TypeAliasExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_namedtuple_expr(mut o NamedTupleExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_enum_call_expr(mut o EnumCallExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_typeddict_expr(mut o TypedDictExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_newtype_expr(mut o NewTypeExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_promote_expr(mut o PromoteExpr) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_await_expr(mut o AwaitExpr) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_temp_node(mut o TempNode) !string {
	return ''
}

// --- patterns ---
pub fn (mut t NodeTraverser) visit_as_pattern(mut o AsPattern) !string {
	if mut p := o.pattern {
		pattern_accept(mut p, mut t)!
	}
	if n := o.name {
		t.visit_name_expr(mut n)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_or_pattern(mut o OrPattern) !string {
	for p in o.patterns {
		mut p_mut := p
		pattern_accept(mut p_mut, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_value_pattern(mut o ValuePattern) !string {
	expr_accept(o.expr, mut t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_singleton_pattern(mut o SingletonPattern) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_sequence_pattern(mut o SequencePattern) !string {
	for p in o.patterns {
		mut p_mut := p
		pattern_accept(mut p_mut, mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_starred_pattern(mut o StarredPattern) !string {
	if c := o.capture {
		t.visit_name_expr(mut c)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_mapping_pattern(mut o MappingPattern) !string {
	for k in o.keys {
		expr_accept(k, mut t)!
	}
	for p in o.values {
		mut p_mut := p
		pattern_accept(mut p_mut, mut t)!
	}
	if r := o.rest {
		t.visit_name_expr(mut r)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_class_pattern(mut o ClassPattern) !string {
	expr_accept(o.class_ref, mut t)!
	for p in o.positionals {
		mut p_mut := p
		pattern_accept(mut p_mut, mut t)!
	}
	for p in o.keyword_values {
		mut p_mut := p
		pattern_accept(mut p_mut, mut t)!
	}
	return ''
}

// ---------------------------------------------------------------------------
// Dispatch helpers — needed because V sum-types require explicit match.
// These are package-level free functions, not methods.
// ---------------------------------------------------------------------------

pub fn stmt_accept(s Statement, mut v NodeVisitor) !string {
	mut ss := s
	match mut ss {
		AssignmentStmt { v.visit_assignment_stmt(mut ss)! }
		AssertStmt { v.visit_assert_stmt(mut ss)! }
		Block { v.visit_block(mut ss)! }
		BreakStmt { v.visit_break_stmt(mut ss)! }
		ClassDef { v.visit_class_def(mut ss)! }
		ContinueStmt { v.visit_continue_stmt(mut ss)! }
		Decorator { v.visit_decorator(mut ss)! }
		DelStmt { v.visit_del_stmt(mut ss)! }
		ExpressionStmt { v.visit_expression_stmt(mut ss)! }
		ForStmt { v.visit_for_stmt(mut ss)! }
		FuncDef { v.visit_func_def(mut ss)! }
		GlobalDecl { v.visit_global_decl(mut ss)! }
		IfStmt { v.visit_if_stmt(mut ss)! }
		Import { v.visit_import(mut ss)! }
		ImportAll { v.visit_import_all(mut ss)! }
		ImportFrom { v.visit_import_from(mut ss)! }
		MatchStmt { v.visit_match_stmt(mut ss)! }
		NonlocalDecl { v.visit_nonlocal_decl(mut ss)! }
		OperatorAssignmentStmt { v.visit_operator_assignment_stmt(mut ss)! }
		OverloadedFuncDef { v.visit_overloaded_func_def(mut ss)! }
		PassStmt { v.visit_pass_stmt(mut ss)! }
		RaiseStmt { v.visit_raise_stmt(mut ss)! }
		ReturnStmt { v.visit_return_stmt(mut ss)! }
		TryStmt { v.visit_try_stmt(mut ss)! }
		TypeAliasStmt { v.visit_type_alias_stmt(mut ss)! }
		WhileStmt { v.visit_while_stmt(mut ss)! }
		WithStmt { v.visit_with_stmt(mut ss)! }
	}
	return ''
}

pub fn expr_accept(e Expression, mut v NodeVisitor) !string {
	mut ee := e
	match mut ee {
		AssignmentExpr { v.visit_assignment_expr(mut ee)! }
		AwaitExpr { v.visit_await_expr(mut ee)! }
		BytesExpr { v.visit_bytes_expr(mut ee)! }
		CallExpr { v.visit_call_expr(mut ee)! }
		CastExpr { v.visit_cast_expr(mut ee)! }
		ComparisonExpr { v.visit_comparison_expr(mut ee)! }
		ComplexExpr { v.visit_complex_expr(mut ee)! }
		ConditionalExpr { v.visit_conditional_expr(mut ee)! }
		DictExpr { v.visit_dict_expr(mut ee)! }
		DictionaryComprehension { v.visit_dictionary_comprehension(mut ee)! }
		EllipsisExpr { v.visit_ellipsis(mut ee)! }
		EnumCallExpr { v.visit_enum_call_expr(mut ee)! }
		FloatExpr { v.visit_float_expr(mut ee)! }
		GeneratorExpr { v.visit_generator_expr(mut ee)! }
		IndexExpr { v.visit_index_expr(mut ee)! }
		IntExpr { v.visit_int_expr(mut ee)! }
		LambdaExpr { v.visit_lambda_expr(mut ee)! }
		ListComprehension { v.visit_list_comprehension(mut ee)! }
		ListExpr { v.visit_list_expr(mut ee)! }
		MemberExpr { v.visit_member_expr(mut ee)! }
		NameExpr { v.visit_name_expr(mut ee)! }
		NamedTupleExpr { v.visit_namedtuple_expr(mut ee)! }
		NewTypeExpr { v.visit_newtype_expr(mut ee)! }
		OpExpr { v.visit_op_expr(mut ee)! }
		ParamSpecExpr { v.visit_paramspec_expr(mut ee)! }
		PromoteExpr { v.visit_promote_expr(mut ee)! }
		RevealExpr { v.visit_reveal_expr(mut ee)! }
		SetComprehension { v.visit_set_comprehension(mut ee)! }
		SetExpr { v.visit_set_expr(mut ee)! }
		SliceExpr { v.visit_slice_expr(mut ee)! }
		StarExpr { v.visit_star_expr(mut ee)! }
		StrExpr { v.visit_str_expr(mut ee)! }
		SuperExpr { v.visit_super_expr(mut ee)! }
		TempNode { v.visit_temp_node(mut ee)! }
		TemplateStrExpr { v.visit_template_str_expr(mut ee)! }
		TupleExpr { v.visit_tuple_expr(mut ee)! }
		TypeAliasExpr { v.visit_type_alias_expr(mut ee)! }
		TypeApplication { v.visit_type_application(mut ee)! }
		TypeVarExpr { v.visit_type_var_expr(mut ee)! }
		TypeVarTupleExpr { v.visit_type_var_tuple_expr(mut ee)! }
		TypedDictExpr { v.visit_typeddict_expr(mut ee)! }
		UnaryExpr { v.visit_unary_expr(mut ee)! }
		AssertTypeExpr { v.visit_assert_type_expr(mut ee)! }
		FormatStringExpr {
			mut te := TemplateStrExpr{base: ee.base, parts: [ee.value]}
			v.visit_template_str_expr(mut te)!
		}
		YieldExpr { v.visit_yield_expr(mut ee)! }
		YieldFromExpr { v.visit_yield_from_expr(mut ee)! }
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_argument(mut o Argument) !string {
	if mut initializer := o.initializer {
		initializer.accept(mut t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_type_param(mut o TypeParam) !string {
	_ = o
	return ''
}

pub fn (mut t NodeTraverser) visit_type_info(mut o TypeInfo) !string {
	return ''
}

pub fn (mut t NodeTraverser) visit_lvalue(mut o Lvalue) !string {
	mut it_o := o
	match mut it_o {
		ListExpr { t.visit_list_expr(mut it_o)! }
		MemberExpr { t.visit_member_expr(mut it_o)! }
		NameExpr { t.visit_name_expr(mut it_o)! }
		StarExpr { t.visit_star_expr(mut it_o)! }
		TupleExpr { t.visit_tuple_expr(mut it_o)! }
	}
	return ''
}



