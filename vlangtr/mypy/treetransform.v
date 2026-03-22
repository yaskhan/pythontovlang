// treetransform.v — Base visitor that implements an identity AST transform
// Translated from mypy/treetransform.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 19:30

module mypy

// TransformVisitor — трансформирует AST в идентичную копию
pub struct TransformVisitor {
pub mut:
	test_only            bool
	var_map              map[string]Var
	func_placeholder_map map[string]FuncDef
}

// new_transform_visitor создаёт новый TransformVisitor
pub fn new_transform_visitor() TransformVisitor {
	return TransformVisitor{
		test_only:            false
		var_map:              map[string]Var{}
		func_placeholder_map: map[string]FuncDef{}
	}
}

// node трансформирует узел AST
pub fn (mut t TransformVisitor) node(n Node) Node {
	return n.accept(mut t)
}

// expr трансформирует выражение
pub fn (mut t TransformVisitor) expr(e Expression) Expression {
	return e.accept(mut t)
}

// optional_expr трансформирует опциональное выражение
pub fn (mut t TransformVisitor) optional_expr(e ?Expression) ?Expression {
	if e == none {
		return none
	}
	return e.accept(mut t)
}

// expressions трансформирует список выражений
pub fn (mut t TransformVisitor) expressions(es []Expression) []Expression {
	mut result := []Expression{}
	for e in es {
		result << e.accept(mut t)
	}
	return result
}

// statements трансформирует список операторов
pub fn (mut t TransformVisitor) statements(ss []Statement) []Statement {
	mut result := []Statement{}
	for s in ss {
		result << s.accept(mut t)
	}
	return result
}

// block трансформирует блок
pub fn (mut t TransformVisitor) block(b Block) Block {
	return t.visit_block(b)
}

// optional_block трансформирует опциональный блок
pub fn (mut t TransformVisitor) optional_block(b ?Block) ?Block {
	if b == none {
		return none
	}
	return t.visit_block(b or { Block{} })
}

// blocks трансформирует список блоков
pub fn (mut t TransformVisitor) blocks(bs []Block) []Block {
	mut result := []Block{}
	for b in bs {
		result << t.visit_block(b)
	}
	return result
}

// type трансформирует тип
pub fn (mut t TransformVisitor) typ(tp MypyTypeNode) MypyTypeNode {
	return tp
}

// optional_type трансформирует опциональный тип
pub fn (mut t TransformVisitor) optional_type(tp ?MypyTypeNode) ?MypyTypeNode {
	if tp == none {
		return none
	}
	return t.typ(tp or { MypyTypeNode(none) })
}

// types трансформирует список типов
pub fn (mut t TransformVisitor) types(ts []MypyTypeNode) []MypyTypeNode {
	mut result := []MypyTypeNode{}
	for tp in ts {
		result << t.typ(tp)
	}
	return result
}

// pattern трансформирует паттерн
pub fn (mut t TransformVisitor) pattern(p Pattern) Pattern {
	return p.accept(mut t)
}

// visit_mypy_file посещает MypyFile
pub fn (mut t TransformVisitor) visit_mypy_file(node MypyFile) MypyFile {
	assert t.test_only, 'This visitor should not be used for whole files.'

	mut ignored_lines := map[int][]string{}
	for line, codes in node.ignored_lines {
		ignored_lines[line] = codes.clone()
	}

	mut new := MypyFile{
		defs:          t.statements(node.defs)
		is_bom:        node.is_bom
		ignored_lines: ignored_lines
	}
	new.fullname = node.fullname
	new.path = node.path
	new.names = node.names.clone()
	return new
}

// visit_import посещает Import
pub fn (mut t TransformVisitor) visit_import(node Import) Import {
	return Import{
		ids:    node.ids.clone()
		line:   node.line
		column: node.column
	}
}

// visit_import_from посещает ImportFrom
pub fn (mut t TransformVisitor) visit_import_from(node ImportFrom) ImportFrom {
	return ImportFrom{
		id:       node.id
		relative: node.relative
		names:    node.names.clone()
		line:     node.line
		column:   node.column
	}
}

// visit_import_all посещает ImportAll
pub fn (mut t TransformVisitor) visit_import_all(node ImportAll) ImportAll {
	return ImportAll{
		id:       node.id
		relative: node.relative
		line:     node.line
		column:   node.column
	}
}

// copy_argument копирует аргумент функции
pub fn (mut t TransformVisitor) copy_argument(argument Argument) Argument {
	mut arg := Argument{
		variable:        t.visit_var(argument.variable)
		type_annotation: argument.type_annotation
		initializer:     argument.initializer
		kind:            argument.kind
	}
	arg.set_line(argument)
	return arg
}

// visit_func_def посещает FuncDef
pub fn (mut t TransformVisitor) visit_func_def(node FuncDef) FuncDef {
	// Set up placeholder nodes for nested functions
	init := FuncMapInitializer{
		transformer: mut t
	}
	for stmt in node.body.body {
		stmt.accept(mut init)
	}

	mut args := []Argument{}
	for arg in node.arguments {
		args << t.copy_argument(arg)
	}

	mut new := FuncDef{
		name:      node.name
		arguments: args
		body:      t.block(node.body)
		type:      t.optional_type(node.type)
		line:      node.line
		column:    node.column
	}

	t.copy_function_attributes(mut new, node)

	new.fullname = node.fullname
	new.is_decorated = node.is_decorated
	new.is_conditional = node.is_conditional
	new.abstract_status = node.abstract_status
	new.is_static = node.is_static
	new.is_class = node.is_class
	new.is_property = node.is_property
	new.is_final = node.is_final
	new.original_def = node.original_def

	return new
}

// visit_lambda_expr посещает LambdaExpr
pub fn (mut t TransformVisitor) visit_lambda_expr(node LambdaExpr) LambdaExpr {
	mut args := []Argument{}
	for arg in node.arguments {
		args << t.copy_argument(arg)
	}

	mut new := LambdaExpr{
		arguments: args
		body:      t.block(node.body)
		type:      t.optional_type(node.type)
		line:      node.line
		column:    node.column
	}

	t.copy_function_attributes(mut new, node)
	return new
}

// copy_function_attributes копирует атрибуты функции
pub fn (mut t TransformVisitor) copy_function_attributes(mut new FuncItem, original FuncItem) {
	new.info = original.info
	new.min_args = original.min_args
	new.max_pos = original.max_pos
	new.is_overload = original.is_overload
	new.is_generator = original.is_generator
	new.is_coroutine = original.is_coroutine
	new.is_async_generator = original.is_async_generator
	new.is_awaitable_coroutine = original.is_awaitable_coroutine
	new.line = original.line
}

// visit_overloaded_func_def посещает OverloadedFuncDef
pub fn (mut t TransformVisitor) visit_overloaded_func_def(node OverloadedFuncDef) OverloadedFuncDef {
	mut items := []OverloadPart{}
	for item in node.items {
		items << item.accept(mut t)
	}

	mut new := OverloadedFuncDef{
		items: items
	}
	new.fullname = node.fullname
	new.type = t.optional_type(node.type)
	new.info = node.info
	new.is_static = node.is_static
	new.is_class = node.is_class
	new.is_property = node.is_property
	new.is_final = node.is_final

	if node.impl != none {
		new.impl = node.impl.accept(mut t)
	}

	return new
}

// visit_class_def посещает ClassDef
pub fn (mut t TransformVisitor) visit_class_def(node ClassDef) ClassDef {
	mut keywords := map[string]Expression{}
	for key, value in node.keywords {
		keywords[key] = t.expr(value)
	}

	mut new := ClassDef{
		name:            node.name
		defs:            t.block(node.defs)
		type_vars:       node.type_vars.clone()
		base_type_exprs: t.expressions(node.base_type_exprs)
		metaclass:       t.optional_expr(node.metaclass)
		keywords:        keywords
	}
	new.fullname = node.fullname
	new.info = node.info

	mut decorators := []Expression{}
	for decorator in node.decorators {
		decorators << t.expr(decorator)
	}
	new.decorators = decorators

	return new
}

// visit_global_decl посещает GlobalDecl
pub fn (mut t TransformVisitor) visit_global_decl(node GlobalDecl) GlobalDecl {
	return GlobalDecl{
		names:  node.names.clone()
		line:   node.line
		column: node.column
	}
}

// visit_nonlocal_decl посещает NonlocalDecl
pub fn (mut t TransformVisitor) visit_nonlocal_decl(node NonlocalDecl) NonlocalDecl {
	return NonlocalDecl{
		names:  node.names.clone()
		line:   node.line
		column: node.column
	}
}

// visit_block посещает Block
pub fn (mut t TransformVisitor) visit_block(node Block) Block {
	return Block{
		body:           t.statements(node.body)
		is_unreachable: node.is_unreachable
		line:           node.line
		column:         node.column
	}
}

// visit_decorator посещает Decorator
pub fn (mut t TransformVisitor) visit_decorator(node Decorator) Decorator {
	func := t.visit_func_def(node.func)
	func.line = node.func.line

	mut decorators := []Expression{}
	for decorator in node.decorators {
		decorators << t.expr(decorator)
	}

	mut new := Decorator{
		func:       func
		decorators: decorators
		var:        t.visit_var(node.var)
	}
	new.is_overload = node.is_overload
	new.line = node.line
	column:
	node.column

	return new
}

// visit_var посещает Var
pub fn (mut t TransformVisitor) visit_var(node Var) Var {
	key := '${node.name}:${node.line}'
	if key in t.var_map {
		return t.var_map[key]
	}

	mut new := Var{
		name:   node.name
		type:   t.optional_type(node.type)
		line:   node.line
		column: node.column
	}
	new.fullname = node.fullname
	new.info = node.info
	new.is_self = node.is_self
	new.is_ready = node.is_ready
	new.is_initialized_in_class = node.is_initialized_in_class
	new.is_staticmethod = node.is_staticmethod
	new.is_classmethod = node.is_classmethod
	new.is_property = node.is_property
	new.is_final = node.is_final
	new.final_value = node.final_value
	new.final_unset_in_class = node.final_unset_in_class
	new.final_set_in_init = node.final_set_in_init
	new.set_line(node)

	t.var_map[key] = new
	return new
}

// visit_expression_stmt посещает ExpressionStmt
pub fn (mut t TransformVisitor) visit_expression_stmt(node ExpressionStmt) ExpressionStmt {
	return ExpressionStmt{
		expr:   t.expr(node.expr)
		line:   node.line
		column: node.column
	}
}

// visit_assignment_stmt посещает AssignmentStmt
pub fn (mut t TransformVisitor) visit_assignment_stmt(node AssignmentStmt) AssignmentStmt {
	mut lvalues := []Expression{}
	for lv in node.lvalues {
		lvalues << t.expr(lv)
	}

	mut new := AssignmentStmt{
		lvalues: lvalues
		rvalue:  t.expr(node.rvalue)
		type:    t.optional_type(node.type)
		line:    node.line
		column:  node.column
	}
	new.is_final_def = node.is_final_def
	return new
}

// visit_operator_assignment_stmt посещает OperatorAssignmentStmt
pub fn (mut t TransformVisitor) visit_operator_assignment_stmt(node OperatorAssignmentStmt) OperatorAssignmentStmt {
	return OperatorAssignmentStmt{
		op:     node.op
		lvalue: t.expr(node.lvalue)
		rvalue: t.expr(node.rvalue)
		line:   node.line
		column: node.column
	}
}

// visit_while_stmt посещает WhileStmt
pub fn (mut t TransformVisitor) visit_while_stmt(node WhileStmt) WhileStmt {
	return WhileStmt{
		expr:      t.expr(node.expr)
		body:      t.block(node.body)
		else_body: t.optional_block(node.else_body)
		line:      node.line
		column:    node.column
	}
}

// visit_for_stmt посещает ForStmt
pub fn (mut t TransformVisitor) visit_for_stmt(node ForStmt) ForStmt {
	mut new := ForStmt{
		index:                 t.expr(node.index)
		expr:                  t.expr(node.expr)
		body:                  t.block(node.body)
		else_body:             t.optional_block(node.else_body)
		unanalyzed_index_type: t.optional_type(node.unanalyzed_index_type)
		line:                  node.line
		column:                node.column
	}
	new.is_async = node.is_async
	new.index_type = t.optional_type(node.index_type)
	return new
}

// visit_return_stmt посещает ReturnStmt
pub fn (mut t TransformVisitor) visit_return_stmt(node ReturnStmt) ReturnStmt {
	return ReturnStmt{
		expr:   t.optional_expr(node.expr)
		line:   node.line
		column: node.column
	}
}

// visit_assert_stmt посещает AssertStmt
pub fn (mut t TransformVisitor) visit_assert_stmt(node AssertStmt) AssertStmt {
	return AssertStmt{
		expr:   t.expr(node.expr)
		msg:    t.optional_expr(node.msg)
		line:   node.line
		column: node.column
	}
}

// visit_del_stmt посещает DelStmt
pub fn (mut t TransformVisitor) visit_del_stmt(node DelStmt) DelStmt {
	return DelStmt{
		expr:   t.expr(node.expr)
		line:   node.line
		column: node.column
	}
}

// visit_if_stmt посещает IfStmt
pub fn (mut t TransformVisitor) visit_if_stmt(node IfStmt) IfStmt {
	return IfStmt{
		expr:      t.expressions(node.expr)
		body:      t.blocks(node.body)
		else_body: t.optional_block(node.else_body)
		line:      node.line
		column:    node.column
	}
}

// visit_break_stmt посещает BreakStmt
pub fn (mut t TransformVisitor) visit_break_stmt(node BreakStmt) BreakStmt {
	return BreakStmt{
		line:   node.line
		column: node.column
	}
}

// visit_continue_stmt посещает ContinueStmt
pub fn (mut t TransformVisitor) visit_continue_stmt(node ContinueStmt) ContinueStmt {
	return ContinueStmt{
		line:   node.line
		column: node.column
	}
}

// visit_pass_stmt посещает PassStmt
pub fn (mut t TransformVisitor) visit_pass_stmt(node PassStmt) PassStmt {
	return PassStmt{
		line:   node.line
		column: node.column
	}
}

// visit_raise_stmt посещает RaiseStmt
pub fn (mut t TransformVisitor) visit_raise_stmt(node RaiseStmt) RaiseStmt {
	return RaiseStmt{
		expr:      t.optional_expr(node.expr)
		from_expr: t.optional_expr(node.from_expr)
		line:      node.line
		column:    node.column
	}
}

// visit_try_stmt посещает TryStmt
pub fn (mut t TransformVisitor) visit_try_stmt(node TryStmt) TryStmt {
	mut vars := []?Expression{}
	for v in node.vars {
		vars << t.optional_expr(v)
	}

	mut types := []?Expression{}
	for tp in node.types {
		types << t.optional_expr(tp)
	}

	mut handlers := []Block{}
	for h in node.handlers {
		handlers << t.block(h)
	}

	mut new := TryStmt{
		body:         t.block(node.body)
		vars:         vars
		types:        types
		handlers:     handlers
		else_body:    t.optional_block(node.else_body)
		finally_body: t.optional_block(node.finally_body)
		line:         node.line
		column:       node.column
	}
	new.is_star = node.is_star
	return new
}

// visit_with_stmt посещает WithStmt
pub fn (mut t TransformVisitor) visit_with_stmt(node WithStmt) WithStmt {
	mut targets := []?Expression{}
	for target in node.target {
		targets << t.optional_expr(target)
	}

	mut new := WithStmt{
		expr:            t.expressions(node.expr)
		target:          targets
		body:            t.block(node.body)
		unanalyzed_type: t.optional_type(node.unanalyzed_type)
		line:            node.line
		column:          node.column
	}
	new.is_async = node.is_async

	mut analyzed_types := []MypyTypeNode{}
	for typ in node.analyzed_types {
		analyzed_types << t.typ(typ)
	}
	new.analyzed_types = analyzed_types

	return new
}

// visit_int_expr посещает IntExpr
pub fn (mut t TransformVisitor) visit_int_expr(node IntExpr) IntExpr {
	return IntExpr{
		value:  node.value
		line:   node.line
		column: node.column
	}
}

// visit_str_expr посещает StrExpr
pub fn (mut t TransformVisitor) visit_str_expr(node StrExpr) StrExpr {
	return StrExpr{
		value:  node.value
		line:   node.line
		column: node.column
	}
}

// visit_bytes_expr посещает BytesExpr
pub fn (mut t TransformVisitor) visit_bytes_expr(node BytesExpr) BytesExpr {
	return BytesExpr{
		value:  node.value
		line:   node.line
		column: node.column
	}
}

// visit_float_expr посещает FloatExpr
pub fn (mut t TransformVisitor) visit_float_expr(node FloatExpr) FloatExpr {
	return FloatExpr{
		value:  node.value
		line:   node.line
		column: node.column
	}
}

// visit_complex_expr посещает ComplexExpr
pub fn (mut t TransformVisitor) visit_complex_expr(node ComplexExpr) ComplexExpr {
	return ComplexExpr{
		value:  node.value
		line:   node.line
		column: node.column
	}
}

// visit_ellipsis посещает EllipsisExpr
pub fn (mut t TransformVisitor) visit_ellipsis(node EllipsisExpr) EllipsisExpr {
	return EllipsisExpr{
		line:   node.line
		column: node.column
	}
}

// visit_name_expr посещает NameExpr
pub fn (mut t TransformVisitor) visit_name_expr(node NameExpr) NameExpr {
	return t.duplicate_name(node)
}

// duplicate_name дублирует NameExpr
pub fn (mut t TransformVisitor) duplicate_name(node NameExpr) NameExpr {
	mut new := NameExpr{
		name:   node.name
		line:   node.line
		column: node.column
	}
	t.copy_ref(mut new, node)
	new.is_special_form = node.is_special_form
	return new
}

// visit_member_expr посещает MemberExpr
pub fn (mut t TransformVisitor) visit_member_expr(node MemberExpr) MemberExpr {
	mut member := MemberExpr{
		expr:   t.expr(node.expr)
		name:   node.name
		line:   node.line
		column: node.column
	}
	if node.def_var != none {
		member.def_var = node.def_var
	}
	t.copy_ref(mut member, node)
	return member
}

// copy_ref копирует ссылки
pub fn (mut t TransformVisitor) copy_ref(mut new RefExpr, original RefExpr) {
	new.kind = original.kind
	new.fullname = original.fullname

	target := original.node
	if target is Var {
		if original.kind != 'GDEF' {
			target = t.visit_var(target)
		}
	} else if target is Decorator {
		// target = t.visit_var((target as Decorator).var)
	} else if target is FuncDef {
		// Use placeholder if exists
		// target = t.func_placeholder_map.get(target, target)
	}
	new.node = target

	new.is_new_def = original.is_new_def
	new.is_inferred_def = original.is_inferred_def
}

// visit_call_expr посещает CallExpr
pub fn (mut t TransformVisitor) visit_call_expr(node CallExpr) CallExpr {
	return CallExpr{
		callee:    t.expr(node.callee)
		args:      t.expressions(node.args)
		arg_kinds: node.arg_kinds.clone()
		arg_names: node.arg_names.clone()
		analyzed:  t.optional_expr(node.analyzed)
		line:      node.line
		column:    node.column
	}
}

// visit_op_expr посещает OpExpr
pub fn (mut t TransformVisitor) visit_op_expr(node OpExpr) OpExpr {
	mut new := OpExpr{
		op:     node.op
		left:   t.expr(node.left)
		right:  t.expr(node.right)
		line:   node.line
		column: node.column
	}
	new.method_type = t.optional_type(node.method_type)
	return new
}

// visit_comparison_expr посещает ComparisonExpr
pub fn (mut t TransformVisitor) visit_comparison_expr(node ComparisonExpr) ComparisonExpr {
	mut new := ComparisonExpr{
		operators: node.operators.clone()
		operands:  t.expressions(node.operands)
		line:      node.line
		column:    node.column
	}
	mut method_types := []?MypyTypeNode{}
	for mt in node.method_types {
		method_types << t.optional_type(mt)
	}
	new.method_types = method_types
	return new
}

// visit_cast_expr посещает CastExpr
pub fn (mut t TransformVisitor) visit_cast_expr(node CastExpr) CastExpr {
	return CastExpr{
		expr:   t.expr(node.expr)
		type:   t.type(node.type)
		line:   node.line
		column: node.column
	}
}

// visit_assert_type_expr посещает AssertTypeExpr
pub fn (mut t TransformVisitor) visit_assert_type_expr(node AssertTypeExpr) AssertTypeExpr {
	return AssertTypeExpr{
		expr:   t.expr(node.expr)
		type:   t.type(node.type)
		line:   node.line
		column: node.column
	}
}

// visit_reveal_expr посещает RevealExpr
pub fn (mut t TransformVisitor) visit_reveal_expr(node RevealExpr) RevealExpr {
	if node.kind == 'REVEAL_TYPE' {
		if node.expr != none {
			return RevealExpr{
				kind:   node.kind
				expr:   t.expr(node.expr or { Expression(none) })
				line:   node.line
				column: node.column
			}
		}
	}
	return node
}

// visit_super_expr посещает SuperExpr
pub fn (mut t TransformVisitor) visit_super_expr(node SuperExpr) SuperExpr {
	call := t.expr(node.call)
	mut new := SuperExpr{
		name:   node.name
		call:   call
		line:   node.line
		column: node.column
	}
	new.info = node.info
	return new
}

// visit_assignment_expr посещает AssignmentExpr
pub fn (mut t TransformVisitor) visit_assignment_expr(node AssignmentExpr) AssignmentExpr {
	return AssignmentExpr{
		target: t.duplicate_name(node.target)
		value:  t.expr(node.value)
		line:   node.line
		column: node.column
	}
}

// visit_unary_expr посещает UnaryExpr
pub fn (mut t TransformVisitor) visit_unary_expr(node UnaryExpr) UnaryExpr {
	mut new := UnaryExpr{
		op:     node.op
		expr:   t.expr(node.expr)
		line:   node.line
		column: node.column
	}
	new.method_type = t.optional_type(node.method_type)
	return new
}

// visit_list_expr посещает ListExpr
pub fn (mut t TransformVisitor) visit_list_expr(node ListExpr) ListExpr {
	return ListExpr{
		items:  t.expressions(node.items)
		line:   node.line
		column: node.column
	}
}

// visit_dict_expr посещает DictExpr
pub fn (mut t TransformVisitor) visit_dict_expr(node DictExpr) DictExpr {
	mut items := []DictItem{}
	for key, value in node.items {
		items << DictItem{
			key:   if key == none { none } else { t.expr(key or { Expression(none) }) }
			value: t.expr(value)
		}
	}
	return DictExpr{
		items:  items
		line:   node.line
		column: node.column
	}
}

// visit_tuple_expr посещает TupleExpr
pub fn (mut t TransformVisitor) visit_tuple_expr(node TupleExpr) TupleExpr {
	return TupleExpr{
		items:  t.expressions(node.items)
		line:   node.line
		column: node.column
	}
}

// visit_set_expr посещает SetExpr
pub fn (mut t TransformVisitor) visit_set_expr(node SetExpr) SetExpr {
	return SetExpr{
		items:  t.expressions(node.items)
		line:   node.line
		column: node.column
	}
}

// visit_index_expr посещает IndexExpr
pub fn (mut t TransformVisitor) visit_index_expr(node IndexExpr) IndexExpr {
	mut new := IndexExpr{
		base:   t.expr(node.base)
		index:  t.expr(node.index)
		line:   node.line
		column: node.column
	}
	if node.method_type != none {
		new.method_type = t.type(node.method_type or { MypyTypeNode(none) })
	}
	if node.analyzed != none {
		analyzed := node.analyzed or { Expression(none) }
		if analyzed is TypeApplication {
			// new.analyzed = t.visit_type_application(analyzed)
		} else if analyzed is TypeAliasExpr {
			// new.analyzed = t.visit_type_alias_expr(analyzed)
		}
	}
	return new
}

// visit_type_application посещает TypeApplication
pub fn (mut t TransformVisitor) visit_type_application(node TypeApplication) TypeApplication {
	return TypeApplication{
		expr:   t.expr(node.expr)
		types:  t.types(node.types)
		line:   node.line
		column: node.column
	}
}

// visit_slice_expr посещает SliceExpr
pub fn (mut t TransformVisitor) visit_slice_expr(node SliceExpr) SliceExpr {
	return SliceExpr{
		begin_index: t.optional_expr(node.begin_index)
		end_index:   t.optional_expr(node.end_index)
		stride:      t.optional_expr(node.stride)
		line:        node.line
		column:      node.column
	}
}

// visit_conditional_expr посещает ConditionalExpr
pub fn (mut t TransformVisitor) visit_conditional_expr(node ConditionalExpr) ConditionalExpr {
	return ConditionalExpr{
		cond:      t.expr(node.cond)
		if_expr:   t.expr(node.if_expr)
		else_expr: t.expr(node.else_expr)
		line:      node.line
		column:    node.column
	}
}

// FuncMapInitializer — инициализатор placeholder для функций
pub struct FuncMapInitializer {
pub mut:
	transformer TransformVisitor
}

pub fn (mut f FuncMapInitializer) visit_func_def(node FuncDef) {
	// Placeholder initialization
}

pub fn (mut f FuncMapInitializer) visit_block(node Block) {
	for stmt in node.body {
		stmt.accept(mut f)
	}
}
