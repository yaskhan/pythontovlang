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
pub fn (mut t NodeTraverser) visit_mypy_file(o &MypyFile) !string {
	for stmt in o.defs {
		stmt_accept(stmt, t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_var(o &Var) !string { return '' }

pub fn (mut t NodeTraverser) visit_type_alias(o &TypeAlias) !string { return '' }

pub fn (mut t NodeTraverser) visit_placeholder_node(o &PlaceholderNode) !string { return '' }

// --- imports ---
pub fn (mut t NodeTraverser) visit_import(o &Import) !string         { return '' }
pub fn (mut t NodeTraverser) visit_import_from(o &ImportFrom) !string { return '' }
pub fn (mut t NodeTraverser) visit_import_all(o &ImportAll) !string  { return '' }

// --- block & simple statements ---
pub fn (mut t NodeTraverser) visit_block(o &Block) !string {
	for stmt in o.body {
		stmt_accept(stmt, t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_expression_stmt(o &ExpressionStmt) !string {
	expr_accept(o.expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_assignment_stmt(o &AssignmentStmt) !string {
	for lv in o.lvalues {
		expr_accept(lv, t)!
	}
	expr_accept(o.rvalue, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_operator_assignment_stmt(o &OperatorAssignmentStmt) !string {
	expr_accept(o.lvalue, t)!
	expr_accept(o.rvalue, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_while_stmt(o &WhileStmt) !string {
	expr_accept(o.expr, t)!
	t.visit_block(&o.body)!
	if else_b := o.else_body {
		t.visit_block(&else_b)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_for_stmt(o &ForStmt) !string {
	expr_accept(o.index, t)!
	expr_accept(o.iter, t)!
	t.visit_block(&o.body)!
	if else_b := o.else_body {
		t.visit_block(&else_b)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_return_stmt(o &ReturnStmt) !string {
	if e := o.expr {
		expr_accept(e, t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_assert_stmt(o &AssertStmt) !string {
	expr_accept(o.expr, t)!
	if msg := o.msg {
		expr_accept(msg, t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_del_stmt(o &DelStmt) !string {
	expr_accept(o.expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_break_stmt(o &BreakStmt) !string    { return '' }
pub fn (mut t NodeTraverser) visit_continue_stmt(o &ContinueStmt) !string { return '' }
pub fn (mut t NodeTraverser) visit_pass_stmt(o &PassStmt) !string      { return '' }

pub fn (mut t NodeTraverser) visit_if_stmt(o &IfStmt) !string {
	for expr in o.expr {
		expr_accept(expr, t)!
	}
	for b in o.body {
		t.visit_block(&b)!
	}
	if else_b := o.else_body {
		t.visit_block(&else_b)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_raise_stmt(o &RaiseStmt) !string {
	if e := o.expr { expr_accept(e, t)! }
	if e := o.from_expr { expr_accept(e, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_try_stmt(o &TryStmt) !string {
	t.visit_block(&o.body)!
	for te in o.types {
		if e := te { expr_accept(e, t)! }
	}
	for v in o.vars {
		if n := v { t.visit_name_expr(&n)! }
	}
	for h in o.handlers {
		t.visit_block(&h)!
	}
	if else_b := o.else_body   { t.visit_block(&else_b)! }
	if fin   := o.finally_body { t.visit_block(&fin)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_with_stmt(o &WithStmt) !string {
	for e in o.expr { expr_accept(e, t)! }
	for target in o.target {
		if e := target { expr_accept(e, t)! }
	}
	t.visit_block(&o.body)!
	return ''
}

pub fn (mut t NodeTraverser) visit_match_stmt(o &MatchStmt) !string {
	expr_accept(o.subject, t)!
	for guard in o.guards {
		if g := guard { expr_accept(g, t)! }
	}
	for body in o.bodies {
		t.visit_block(&body)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_global_decl(o &GlobalDecl) !string   { return '' }
pub fn (mut t NodeTraverser) visit_nonlocal_decl(o &NonlocalDecl) !string { return '' }

pub fn (mut t NodeTraverser) visit_type_alias_stmt(o &TypeAliasStmt) !string {
	expr_accept(o.value, t)!
	return ''
}

// --- definitions ---
pub fn (mut t NodeTraverser) visit_func_def(o &FuncDef) !string {
	t.visit_block(&o.body)!
	return ''
}

pub fn (mut t NodeTraverser) visit_overloaded_func_def(o &OverloadedFuncDef) !string {
	for item in o.items {
		t.visit_func_def(&item)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_class_def(o &ClassDef) !string {
	t.visit_block(&o.defs)!
	return ''
}

pub fn (mut t NodeTraverser) visit_decorator(o &Decorator) !string {
	t.visit_func_def(&o.func)!
	for dec in o.decorators {
		expr_accept(dec, t)!
	}
	return ''
}

// --- expressions ---
pub fn (mut t NodeTraverser) visit_int_expr(o &IntExpr) !string    { return '' }
pub fn (mut t NodeTraverser) visit_str_expr(o &StrExpr) !string    { return '' }
pub fn (mut t NodeTraverser) visit_bytes_expr(o &BytesExpr) !string { return '' }
pub fn (mut t NodeTraverser) visit_float_expr(o &FloatExpr) !string { return '' }
pub fn (mut t NodeTraverser) visit_complex_expr(o &ComplexExpr) !string { return '' }
pub fn (mut t NodeTraverser) visit_ellipsis(o &EllipsisExpr) !string { return '' }
pub fn (mut t NodeTraverser) visit_name_expr(o &NameExpr) !string  { return '' }

pub fn (mut t NodeTraverser) visit_star_expr(o &StarExpr) !string {
	expr_accept(o.expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_member_expr(o &MemberExpr) !string {
	expr_accept(o.expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_yield_from_expr(o &YieldFromExpr) !string {
	expr_accept(o.expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_yield_expr(o &YieldExpr) !string {
	if e := o.expr { expr_accept(e, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_call_expr(o &CallExpr) !string {
	expr_accept(o.callee, t)!
	for a in o.args { expr_accept(a, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_op_expr(o &OpExpr) !string {
	expr_accept(o.left, t)!
	expr_accept(o.right, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_comparison_expr(o &ComparisonExpr) !string {
	for e in o.operands { expr_accept(e, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_cast_expr(o &CastExpr) !string {
	expr_accept(o.expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_assert_type_expr(o &AssertTypeExpr) !string {
	expr_accept(o.expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_reveal_expr(o &RevealExpr) !string {
	if e := o.expr { expr_accept(e, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_super_expr(o &SuperExpr) !string { return '' }

pub fn (mut t NodeTraverser) visit_unary_expr(o &UnaryExpr) !string {
	expr_accept(o.expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_assignment_expr(o &AssignmentExpr) !string {
	t.visit_name_expr(&o.target)!
	expr_accept(o.value, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_list_expr(o &ListExpr) !string {
	for i in o.items { expr_accept(i, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_dict_expr(o &DictExpr) !string {
	for item in o.items {
		if k := item.key { expr_accept(k, t)! }
		expr_accept(item.value, t)!
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_template_str_expr(o &TemplateStrExpr) !string {
	for p in o.parts { expr_accept(p, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_tuple_expr(o &TupleExpr) !string {
	for i in o.items { expr_accept(i, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_set_expr(o &SetExpr) !string {
	for i in o.items { expr_accept(i, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_index_expr(o &IndexExpr) !string {
	expr_accept(o.base_, t)!
	expr_accept(o.index, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_type_application(o &TypeApplication) !string {
	expr_accept(o.expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_lambda_expr(o &LambdaExpr) !string {
	t.visit_block(&o.body)!
	return ''
}

pub fn (mut t NodeTraverser) visit_list_comprehension(o &ListComprehension) !string {
	t.visit_generator_expr(&o.generator)!
	return ''
}

pub fn (mut t NodeTraverser) visit_set_comprehension(o &SetComprehension) !string {
	t.visit_generator_expr(&o.generator)!
	return ''
}

pub fn (mut t NodeTraverser) visit_dictionary_comprehension(o &DictionaryComprehension) !string {
	expr_accept(o.key, t)!
	expr_accept(o.value, t)!
	for seq in o.sequences { expr_accept(seq, t)! }
	for conds in o.condlists {
		for c in conds { expr_accept(c, t)! }
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_generator_expr(o &GeneratorExpr) !string {
	expr_accept(o.left_expr, t)!
	for seq in o.sequences { expr_accept(seq, t)! }
	for conds in o.condlists {
		for c in conds { expr_accept(c, t)! }
	}
	return ''
}

pub fn (mut t NodeTraverser) visit_slice_expr(o &SliceExpr) !string {
	if b := o.begin_index { expr_accept(b, t)! }
	if e := o.end_index   { expr_accept(e, t)! }
	if s := o.stride      { expr_accept(s, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_conditional_expr(o &ConditionalExpr) !string {
	expr_accept(o.cond, t)!
	expr_accept(o.if_expr, t)!
	expr_accept(o.else_expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_type_var_expr(o &TypeVarExpr) !string      { return '' }
pub fn (mut t NodeTraverser) visit_paramspec_expr(o &ParamSpecExpr) !string   { return '' }
pub fn (mut t NodeTraverser) visit_type_var_tuple_expr(o &TypeVarTupleExpr) !string { return '' }
pub fn (mut t NodeTraverser) visit_type_alias_expr(o &TypeAliasExpr) !string  { return '' }
pub fn (mut t NodeTraverser) visit_namedtuple_expr(o &NamedTupleExpr) !string { return '' }
pub fn (mut t NodeTraverser) visit_enum_call_expr(o &EnumCallExpr) !string    { return '' }
pub fn (mut t NodeTraverser) visit_typeddict_expr(o &TypedDictExpr) !string   { return '' }
pub fn (mut t NodeTraverser) visit_newtype_expr(o &NewTypeExpr) !string       { return '' }
pub fn (mut t NodeTraverser) visit_promote_expr(o &PromoteExpr) !string       { return '' }

pub fn (mut t NodeTraverser) visit_await_expr(o &AwaitExpr) !string {
	expr_accept(o.expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_temp_node(o &TempNode) !string { return '' }

// --- patterns ---
pub fn (mut t NodeTraverser) visit_as_pattern(o &AsPattern) !string {
	if p := o.pattern { pattern_accept(p, t)! }
	if n := o.name    { t.visit_name_expr(&n)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_or_pattern(o &OrPattern) !string {
	for p in o.patterns { pattern_accept(p, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_value_pattern(o &ValuePattern) !string {
	expr_accept(o.expr, t)!
	return ''
}

pub fn (mut t NodeTraverser) visit_singleton_pattern(o &SingletonPattern) !string { return '' }

pub fn (mut t NodeTraverser) visit_sequence_pattern(o &SequencePattern) !string {
	for p in o.patterns { pattern_accept(p, t)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_starred_pattern(o &StarredPattern) !string {
	if c := o.capture { t.visit_name_expr(&c)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_mapping_pattern(o &MappingPattern) !string {
	for k in o.keys   { expr_accept(k, t)! }
	for p in o.values { pattern_accept(p, t)! }
	if r := o.rest    { t.visit_name_expr(&r)! }
	return ''
}

pub fn (mut t NodeTraverser) visit_class_pattern(o &ClassPattern) !string {
	expr_accept(o.class_ref, t)!
	for p in o.positionals    { pattern_accept(p, t)! }
	for p in o.keyword_values { pattern_accept(p, t)! }
	return ''
}

// ---------------------------------------------------------------------------
// Dispatch helpers — needed because V sum-types require explicit match.
// These are package-level free functions, not methods.
// ---------------------------------------------------------------------------

pub fn stmt_accept(s Statement, mut v NodeVisitor) !string {
	return match s {
		AssignmentStmt         { v.visit_assignment_stmt(&s)! }
		Block                  { v.visit_block(&s)! }
		BreakStmt              { v.visit_break_stmt(&s)! }
		ClassDef               { v.visit_class_def(&s)! }
		ContinueStmt           { v.visit_continue_stmt(&s)! }
		Decorator              { v.visit_decorator(&s)! }
		DelStmt                { v.visit_del_stmt(&s)! }
		ExpressionStmt         { v.visit_expression_stmt(&s)! }
		ForStmt                { v.visit_for_stmt(&s)! }
		FuncDef                { v.visit_func_def(&s)! }
		GlobalDecl             { v.visit_global_decl(&s)! }
		IfStmt                 { v.visit_if_stmt(&s)! }
		Import                 { v.visit_import(&s)! }
		ImportAll              { v.visit_import_all(&s)! }
		ImportFrom             { v.visit_import_from(&s)! }
		MatchStmt              { v.visit_match_stmt(&s)! }
		NonlocalDecl           { v.visit_nonlocal_decl(&s)! }
		OperatorAssignmentStmt { v.visit_operator_assignment_stmt(&s)! }
		OverloadedFuncDef      { v.visit_overloaded_func_def(&s)! }
		PassStmt               { v.visit_pass_stmt(&s)! }
		RaiseStmt              { v.visit_raise_stmt(&s)! }
		ReturnStmt             { v.visit_return_stmt(&s)! }
		TryStmt                { v.visit_try_stmt(&s)! }
		TypeAliasStmt          { v.visit_type_alias_stmt(&s)! }
		WhileStmt              { v.visit_while_stmt(&s)! }
		WithStmt               { v.visit_with_stmt(&s)! }
	}
}

pub fn expr_accept(e Expression, mut v NodeVisitor) !string {
	return match e {
		AssignmentExpr         { v.visit_assignment_expr(&e)! }
		AwaitExpr              { v.visit_await_expr(&e)! }
		BytesExpr              { v.visit_bytes_expr(&e)! }
		CallExpr               { v.visit_call_expr(&e)! }
		CastExpr               { v.visit_cast_expr(&e)! }
		ComparisonExpr         { v.visit_comparison_expr(&e)! }
		ComplexExpr            { v.visit_complex_expr(&e)! }
		ConditionalExpr        { v.visit_conditional_expr(&e)! }
		DictExpr               { v.visit_dict_expr(&e)! }
		DictionaryComprehension { v.visit_dictionary_comprehension(&e)! }
		EllipsisExpr           { v.visit_ellipsis(&e)! }
		EnumCallExpr           { v.visit_enum_call_expr(&e)! }
		FloatExpr              { v.visit_float_expr(&e)! }
		GeneratorExpr          { v.visit_generator_expr(&e)! }
		IndexExpr              { v.visit_index_expr(&e)! }
		IntExpr                { v.visit_int_expr(&e)! }
		LambdaExpr             { v.visit_lambda_expr(&e)! }
		ListComprehension      { v.visit_list_comprehension(&e)! }
		ListExpr               { v.visit_list_expr(&e)! }
		MemberExpr             { v.visit_member_expr(&e)! }
		NameExpr               { v.visit_name_expr(&e)! }
		NamedTupleExpr         { v.visit_namedtuple_expr(&e)! }
		NewTypeExpr            { v.visit_newtype_expr(&e)! }
		OpExpr                 { v.visit_op_expr(&e)! }
		ParamSpecExpr          { v.visit_paramspec_expr(&e)! }
		PromoteExpr            { v.visit_promote_expr(&e)! }
		RevealExpr             { v.visit_reveal_expr(&e)! }
		SetComprehension       { v.visit_set_comprehension(&e)! }
		SetExpr                { v.visit_set_expr(&e)! }
		SliceExpr              { v.visit_slice_expr(&e)! }
		StarExpr               { v.visit_star_expr(&e)! }
		StrExpr                { v.visit_str_expr(&e)! }
		SuperExpr              { v.visit_super_expr(&e)! }
		TempNode               { v.visit_temp_node(&e)! }
		TemplateStrExpr        { v.visit_template_str_expr(&e)! }
		TupleExpr              { v.visit_tuple_expr(&e)! }
		TypeAliasExpr          { v.visit_type_alias_expr(&e)! }
		TypeApplication        { v.visit_type_application(&e)! }
		TypeVarExpr            { v.visit_type_var_expr(&e)! }
		TypeVarTupleExpr       { v.visit_type_var_tuple_expr(&e)! }
		TypedDictExpr          { v.visit_typeddict_expr(&e)! }
		UnaryExpr              { v.visit_unary_expr(&e)! }
		AssertTypeExpr         { v.visit_assert_type_expr(&e)! }
		YieldExpr              { v.visit_yield_expr(&e)! }
		YieldFromExpr          { v.visit_yield_from_expr(&e)! }
	}
}
