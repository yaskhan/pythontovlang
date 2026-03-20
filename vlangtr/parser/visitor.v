module main

// ==================== VISITOR PATTERN ====================

interface Visitor {
mut:
	visit_module(node &Module)
	visit_expr(node &Expr)
	visit_function_def(node &FunctionDef)
	visit_class_def(node &ClassDef)
	visit_if(node &If)
	visit_for(node &For)
	visit_while(node &While)
	visit_with(node &With)
	visit_try(node &Try)
	visit_try_star(node &TryStar)
	visit_match(node &Match)
	visit_assign(node &Assign)
	visit_aug_assign(node &AugAssign)
	visit_ann_assign(node &AnnAssign)
	visit_return(node &Return)
	visit_import(node &Import)
	visit_import_from(node &ImportFrom)
	visit_global(node &Global)
	visit_nonlocal(node &Nonlocal)
	visit_assert(node &Assert)
	visit_raise(node &Raise)
	visit_delete(node &Delete)
	visit_pass(node &Pass)
	visit_break(node &Break)
	visit_continue(node &Continue)
	visit_binary_op(node &BinaryOp)
	visit_unary_op(node &UnaryOp)
	visit_compare(node &Compare)
	visit_call(node &Call)
	visit_name(node &Name)
	visit_constant(node &Constant)
	visit_list(node &List)
	visit_dict(node &Dict)
	visit_tuple(node &Tuple)
	visit_set(node &Set)
	visit_attribute(node &Attribute)
	visit_subscript(node &Subscript)
	visit_slice(node &Slice)
	visit_lambda(node &Lambda)
	visit_list_comp(node &ListComp)
	visit_dict_comp(node &DictComp)
	visit_set_comp(node &SetComp)
	visit_generator(node &GeneratorExp)
	visit_if_exp(node &IfExp)
	visit_await(node &Await)
	visit_yield(node &Yield)
	visit_yield_from(node &YieldFrom)
	visit_starred(node &Starred)
	visit_none_expr(node &NoneExpr)
	visit_joined_str(node &JoinedStr)
	visit_formatted_value(node &FormattedValue)
	// Patterns
	visit_match_value(node &MatchValue)
	visit_match_singleton(node &MatchSingleton)
	visit_match_sequence(node &MatchSequence)
	visit_match_mapping(node &MatchMapping)
	visit_match_class(node &MatchClass)
	visit_match_star(node &MatchStar)
	visit_match_as(node &MatchAs)
	visit_match_or(node &MatchOr)
	visit_named_expr(node &NamedExpr)
}

// walk dispatches a Statement node to the appropriate visitor method
fn walk_stmt(mut v Visitor, node Statement) {
	match node {
		Module             { v.visit_module(node) }
		Expr               { v.visit_expr(node) }
		FunctionDef        { v.visit_function_def(node) }
		ClassDef           { v.visit_class_def(node) }
		If                 { v.visit_if(node) }
		For                { v.visit_for(node) }
		While              { v.visit_while(node) }
		With               { v.visit_with(node) }
		Try                { v.visit_try(node) }
		TryStar            { v.visit_try_star(node) }
		Match              { v.visit_match(node) }
		Assign             { v.visit_assign(node) }
		AugAssign          { v.visit_aug_assign(node) }
		AnnAssign          { v.visit_ann_assign(node) }
		Return             { v.visit_return(node) }
		Import             { v.visit_import(node) }
		ImportFrom         { v.visit_import_from(node) }
		Global             { v.visit_global(node) }
		Nonlocal           { v.visit_nonlocal(node) }
		Assert             { v.visit_assert(node) }
		Raise              { v.visit_raise(node) }
		Delete             { v.visit_delete(node) }
		Pass               { v.visit_pass(node) }
		Break              { v.visit_break(node) }
		Continue           { v.visit_continue(node) }
		else               {}
	}
}

// walk_expr dispatches an Expression node to the appropriate visitor method
fn walk_expr(mut v Visitor, node Expression) {
	match node {
		Name           { v.visit_name(node) }
		Constant       { v.visit_constant(node) }
		List           { v.visit_list(node) }
		Dict           { v.visit_dict(node) }
		Tuple          { v.visit_tuple(node) }
		Set            { v.visit_set(node) }
		BinaryOp       { v.visit_binary_op(node) }
		UnaryOp        { v.visit_unary_op(node) }
		Compare        { v.visit_compare(node) }
		Call           { v.visit_call(node) }
		Attribute      { v.visit_attribute(node) }
		Subscript      { v.visit_subscript(node) }
		Slice          { v.visit_slice(node) }
		Lambda         { v.visit_lambda(node) }
		ListComp       { v.visit_list_comp(node) }
		DictComp       { v.visit_dict_comp(node) }
		SetComp        { v.visit_set_comp(node) }
		GeneratorExp   { v.visit_generator(node) }
		IfExp          { v.visit_if_exp(node) }
		Await          { v.visit_await(node) }
		Yield          { v.visit_yield(node) }
		YieldFrom      { v.visit_yield_from(node) }
		Starred        { v.visit_starred(node) }
		NoneExpr       { v.visit_none_expr(node) }
		JoinedStr      { v.visit_joined_str(node) }
		FormattedValue { v.visit_formatted_value(node) }
		NamedExpr      { v.visit_named_expr(node) }
		else           {}
	}
}

// walk_pattern dispatches a Pattern node to the appropriate visitor method
fn walk_pattern(mut v Visitor, node Pattern) {
	match node {
		MatchValue     { v.visit_match_value(node) }
		MatchSingleton { v.visit_match_singleton(node) }
		MatchSequence  { v.visit_match_sequence(node) }
		MatchMapping   { v.visit_match_mapping(node) }
		MatchClass     { v.visit_match_class(node) }
		MatchStar      { v.visit_match_star(node) }
		MatchAs        { v.visit_match_as(node) }
		MatchOr        { v.visit_match_or(node) }
		else           {}
	}
}
