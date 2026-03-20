module main

// ==================== VISITOR PATTERN ====================

interface Visitor {
mut:
	visit_module(node &Module)
	visit_expression_stmt(node &ExpressionStmt)
	visit_function_def(node &FunctionDef)
	visit_class_def(node &ClassDef)
	visit_if(node &If)
	visit_for(node &For)
	visit_while(node &While)
	visit_with(node &With)
	visit_try(node &Try)
	visit_match(node &Match)
	visit_assignment(node &Assignment)
	visit_aug_assignment(node &AugmentedAssignment)
	visit_ann_assignment(node &AnnAssignment)
	visit_return(node &Return)
	visit_import(node &Import)
	visit_import_from(node &ImportFrom)
	visit_global(node &Global)
	visit_nonlocal(node &Nonlocal)
	visit_assert(node &Assert)
	visit_raise(node &Raise)
	visit_try_handler(node &ExceptHandler)
	visit_delete(node &Delete)
	visit_pass(node &Pass)
	visit_break(node &Break)
	visit_continue(node &Continue)
	visit_binary_op(node &BinaryOp)
	visit_unary_op(node &UnaryOp)
	visit_compare(node &Compare)
	visit_call(node &Call)
	visit_identifier(node &Identifier)
	visit_number(node &NumberLiteral)
	visit_string(node &StringLiteral)
	visit_bool(node &BoolLiteral)
	visit_none(node &NoneLiteral)
	visit_list(node &ListLiteral)
	visit_dict(node &DictLiteral)
	visit_tuple(node &TupleLiteral)
	visit_set(node &SetLiteral)
	visit_attribute(node &Attribute)
	visit_subscript(node &Subscript)
	visit_slice(node &Slice)
	visit_lambda(node &Lambda)
	visit_list_comp(node &ListComp)
	visit_dict_comp(node &DictComp)
	visit_set_comp(node &SetComp)
	visit_generator(node &GeneratorExp)
	visit_if_expr(node &IfExpr)
	visit_await(node &Await)
	visit_yield(node &Yield)
	visit_yield_from(node &YieldFrom)
	visit_starred(node &StarredExpr)
}

// walk dispatches a Statement node to the appropriate visitor method
fn walk_stmt(mut v Visitor, node Statement) {
	match node {
		Module             { v.visit_module(node) }
		ExpressionStmt     { v.visit_expression_stmt(node) }
		FunctionDef        { v.visit_function_def(node) }
		ClassDef           { v.visit_class_def(node) }
		If                 { v.visit_if(node) }
		For                { v.visit_for(node) }
		While              { v.visit_while(node) }
		With               { v.visit_with(node) }
		Try                { v.visit_try(node) }
		Match              { v.visit_match(node) }
		Assignment         { v.visit_assignment(node) }
		AugmentedAssignment{ v.visit_aug_assignment(node) }
		AnnAssignment      { v.visit_ann_assignment(node) }
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
		TypeAlias          {} // no-op for now
		else               {}
	}
}

// walk_expr dispatches an Expression node to the appropriate visitor method
fn walk_expr(mut v Visitor, node Expression) {
	match node {
		Identifier     { v.visit_identifier(node) }
		NumberLiteral  { v.visit_number(node) }
		StringLiteral  { v.visit_string(node) }
		BoolLiteral    { v.visit_bool(node) }
		NoneLiteral    { v.visit_none(node) }
		ListLiteral    { v.visit_list(node) }
		DictLiteral    { v.visit_dict(node) }
		TupleLiteral   { v.visit_tuple(node) }
		SetLiteral     { v.visit_set(node) }
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
		IfExpr         { v.visit_if_expr(node) }
		Await          { v.visit_await(node) }
		Yield          { v.visit_yield(node) }
		YieldFrom      { v.visit_yield_from(node) }
		StarredExpr    { v.visit_starred(node) }
		else           {}
	}
}
