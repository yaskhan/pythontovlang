// Я Codex работаю над этим файлом. Начало: 2026-03-22 20:46:30
// treetransform.v вЂ” Base visitor that implements an identity AST transform.
// РџРµСЂРµРІРµРґС‘РЅ РёР· mypy/treetransform.py

module mypy

// TransformVisitor вЂ” Р±Р°Р·РѕРІС‹Р№ РєР»Р°СЃСЃ РґР»СЏ С‚СЂР°РЅСЃС„РѕСЂРјР°С†РёРё AST.
// Р’ V РјС‹ СЂРµР°Р»РёР·СѓРµРј РµРіРѕ С‡РµСЂРµР· struct. РњС‹ С…СЂР°РЅРёРј СЂРµР·СѓР»СЊС‚Р°С‚ РІ РїРѕР»Рµ last_node,
// С‚Р°Рє РєР°Рє РёРЅС‚РµСЂС„РµР№СЃ NodeVisitor РІ V РІРѕР·РІСЂР°С‰Р°РµС‚ !string.
pub struct TransformVisitor {
pub mut:
	test_only            bool
	var_map              map[voidptr]&Var
	func_placeholder_map map[voidptr]&FuncDef
	last_node            MypyNode = PassStmt{} // Placeholder
}

pub fn new_transform_visitor() TransformVisitor {
	return TransformVisitor{
		test_only:            false
		var_map:              map[voidptr]&Var{}
		func_placeholder_map: map[voidptr]&FuncDef{}
	}
}

// node_transform вЂ” РѕСЃРЅРѕРІРЅРѕР№ РјРµС‚РѕРґ РґР»СЏ С‚СЂР°РЅСЃС„РѕСЂРјР°С†РёРё СѓР·Р»Р°.
pub fn (mut v TransformVisitor) node_transform(n Node) !MypyNode {
	n.accept(mut v)!
	return v.last_node
}

// expr_transform вЂ” С‚СЂР°РЅСЃС„РѕСЂРјР°С†РёСЏ РІС‹СЂР°Р¶РµРЅРёСЏ.
pub fn (mut v TransformVisitor) expr_transform(e Expression) !Expression {
	res := v.node_transform(e)!
	return res.as_expression() or { panic('Expected expression') }
}

// stmt_transform вЂ” С‚СЂР°РЅСЃС„РѕСЂРјР°С†РёСЏ СЃС‚РµР№С‚РјРµРЅС‚Р°.
pub fn (mut v TransformVisitor) stmt_transform(s Statement) !Statement {
	res := v.node_transform(s)!
	return res.as_statement() or { panic('Expected statement') }
}

// block_transform вЂ” С‚СЂР°РЅСЃС„РѕСЂРјР°С†РёСЏ Р±Р»РѕРєР°.
pub fn (mut v TransformVisitor) block_transform(mut b Block) !Block {
	mut new_body := []Statement{}
	for mut stmt in b.body {
		new_body << v.stmt_transform(stmt)!
	}
	return Block{
		base:           b.base
		body:           new_body
		is_unreachable: b.is_unreachable
	}
}

// expressions_transform вЂ” С‚СЂР°РЅСЃС„РѕСЂРјР°С†РёСЏ СЃРїРёСЃРєР° РІС‹СЂР°Р¶РµРЅРёР№.
pub fn (mut v TransformVisitor) expressions_transform(exprs []Expression) ![]Expression {
	mut res := []Expression{}
	for e in exprs {
		res << v.expr_transform(e)!
	}
	return res
}

// optional_expressions_transform вЂ” С‚СЂР°РЅСЃС„РѕСЂРјР°С†РёСЏ СЃРїРёСЃРєР° РѕРїС†РёРѕРЅР°Р»СЊРЅС‹С… РІС‹СЂР°Р¶РµРЅРёР№.
pub fn (mut v TransformVisitor) optional_expressions_transform(exprs []?Expression) ![]?Expression {
	mut res := []?Expression{}
	for e in exprs {
		if ex := e {
			res << v.expr_transform(ex)!
		} else {
			res << none
		}
	}
	return res
}

// patterns_transform вЂ” С‚СЂР°РЅСЃС„РѕСЂРјР°С†РёСЏ СЃРїРёСЃРєР° РїР°С‚С‚РµСЂРЅРѕРІ.
pub fn (mut v TransformVisitor) patterns_transform(patterns []Pattern) ![]Pattern {
	mut res := []Pattern{}
	for mut p in patterns {
		p.accept(mut v)!
		res << v.last_node as Pattern
	}
	return res
}

// --- Implementation of NodeVisitor methods ---

pub fn (mut v TransformVisitor) visit_mypy_file(mut node MypyFile) !string {
	if !v.test_only {
		panic('This visitor should not be used for whole files.')
	}
	mut new_defs := []Statement{}
	for mut d in node.defs {
		new_defs << v.stmt_transform(d)!
	}
	v.last_node = MypyFile{
		base:      node.base
		defs:      new_defs
		is_bom:    node.is_bom
		path:      node.path
		_fullname: node._fullname
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_import(mut node Import) !string {
	v.last_node = Import{
		base:           node.base
		ids:            node.ids.clone()
		is_top_level:   node.is_top_level
		is_unreachable: node.is_unreachable
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_import_from(mut node ImportFrom) !string {
	v.last_node = ImportFrom{
		base:           node.base
		id:             node.id
		relative:       node.relative
		names:          node.names.clone()
		is_top_level:   node.is_top_level
		is_unreachable: node.is_unreachable
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_import_all(mut node ImportAll) !string {
	v.last_node = ImportAll{
		base:           node.base
		id:             node.id
		relative:       node.relative
		is_top_level:   node.is_top_level
		is_unreachable: node.is_unreachable
	}
	return ''
}

pub fn (mut v TransformVisitor) copy_argument(mut argument Argument) !Argument {
	mut var_node := argument.variable
	v.visit_var(mut var_node)!
	res_var := v.last_node as Var

	mut init := ?Expression(none)
	if node_init := argument.initializer {
		init = v.expr_transform(node_init)!
	}

	return Argument{
		base:            argument.base
		variable:        res_var
		type_annotation: argument.type_annotation
		initializer:     init
		kind:            argument.kind
		pos_only:        argument.pos_only
	}
}

pub fn (mut v TransformVisitor) visit_func_def(mut node FuncDef) !string {
	// Setup placeholders for nested functions
	mut init_visitor := FuncMapInitializer{
		transformer: v
	}
	for mut stmt in node.body.body {
		stmt_accept(stmt, mut init_visitor)!
	}

	mut new_args := []Argument{}
	for mut arg in node.arguments {
		new_args << v.copy_argument(mut arg)!
	}

	mut new_body := v.block_transform(mut node.body)!

	mut new := FuncDef{
		base:      node.base
		name:      node.name
		arguments: new_args
		body:      new_body
		type_:     node.type_
	}

	v.copy_function_attributes(mut new, node)

	new.fullname = node.fullname
	new.is_decorated = node.is_decorated
	new.abstract_status = node.abstract_status
	new.is_static = node.is_static
	new.is_class = node.is_class
	new.is_property = node.is_property
	new.is_final = node.is_final

	ptr := voidptr(node)
	if ptr in v.func_placeholder_map {
		// Replace placeholder content
		mut placeholder := v.func_placeholder_map[ptr]
		placeholder.name = new.name
		placeholder.arguments = new.arguments
		placeholder.body = new.body
		placeholder.type_ = new.type_
		v.last_node = placeholder
	} else {
		v.last_node = new
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_lambda_expr(mut node LambdaExpr) !string {
	mut new_args := []Argument{}
	for mut arg in node.arguments {
		new_args << v.copy_argument(mut arg)!
	}
	mut new_body := v.block_transform(mut node.body)!

	mut new := LambdaExpr{
		base:      node.base
		arguments: new_args
		body:      new_body
		type_:     node.type_
	}
	v.copy_function_attributes_item(mut new, node)
	v.last_node = new
	return ''
}

pub fn (mut v TransformVisitor) copy_function_attributes(mut new FuncDef, original FuncDef) {
	new.min_args = original.min_args
	new.is_overload = original.is_overload
	new.is_generator = original.is_generator
	new.is_coroutine = original.is_coroutine
	new.is_async_generator = original.is_async_generator
}

pub fn (mut v TransformVisitor) copy_function_attributes_item(mut new LambdaExpr, original LambdaExpr) {
	// Items relevant for lambda
}

pub fn (mut v TransformVisitor) visit_overloaded_func_def(mut node OverloadedFuncDef) !string {
	mut items := []FuncDef{}
	for mut item in node.items {
		v.visit_func_def(mut item)!
		items << v.last_node as FuncDef
	}
	mut new := OverloadedFuncDef{
		base:        node.base
		items:       items
		type_:       node.type_
		fullname:    node.fullname
		is_final:    node.is_final
		is_static:   node.is_static
		is_class:    node.is_class
		is_property: node.is_property
	}
	v.last_node = new
	return ''
}

pub fn (mut v TransformVisitor) visit_class_def(mut node ClassDef) !string {
	v.last_node = ClassDef{
		base:            node.base
		name:            node.name
		defs:            v.block_transform(mut node.defs)!
		type_vars:       node.type_vars.clone()
		base_type_exprs: v.expressions_transform(node.base_type_exprs)!
		metaclass:       if e := node.metaclass { v.expr_transform(e)! } else { none }
		fullname:        node.fullname
		info:            node.info
		decorators:      v.expressions_transform(node.decorators)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_global_decl(mut node GlobalDecl) !string {
	v.last_node = GlobalDecl{
		base:  node.base
		names: node.names.clone()
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_nonlocal_decl(mut node NonlocalDecl) !string {
	v.last_node = NonlocalDecl{
		base:  node.base
		names: node.names.clone()
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_block(mut node Block) !string {
	v.last_node = v.block_transform(mut node)!
	return ''
}

pub fn (mut v TransformVisitor) visit_decorator(mut node Decorator) !string {
	mut func_node := node.func
	v.visit_func_def(mut func_node)!
	func := v.last_node as FuncDef
	v.last_node = Decorator{
		base:       node.base
		func:       func
		decorators: v.expressions_transform(node.decorators)!
		var:        v.visit_var_helper(mut node.var)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_var_helper(mut node Var) !Var {
	v.visit_var(mut node)!
	return v.last_node as Var
}

pub fn (mut v TransformVisitor) visit_var(mut node Var) !string {
	ptr := voidptr(node)
	if ptr in v.var_map {
		v.last_node = v.var_map[ptr]
		return ''
	}
	new := &Var{
		base:            node.base
		name:            node.name
		type_:           node.type_
		fullname:        node.fullname
		is_self:         node.is_self
		is_ready:        node.is_ready
		is_staticmethod: node.is_staticmethod
		is_classmethod:  node.is_classmethod
		is_property:     node.is_property
		is_final:        node.is_final
	}
	v.var_map[ptr] = new
	v.last_node = *new
	return ''
}

pub fn (mut v TransformVisitor) visit_expression_stmt(mut node ExpressionStmt) !string {
	v.last_node = ExpressionStmt{
		base: node.base
		expr: v.expr_transform(node.expr)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_assignment_stmt(mut node AssignmentStmt) !string {
	v.last_node = AssignmentStmt{
		base:            node.base
		lvalues:         v.expressions_transform(node.lvalues)!
		rvalue:          v.expr_transform(node.rvalue)!
		type_annotation: node.type_annotation
		is_final_def:    node.is_final_def
		is_alias_def:    node.is_alias_def
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_operator_assignment_stmt(mut node OperatorAssignmentStmt) !string {
	v.last_node = OperatorAssignmentStmt{
		base:   node.base
		op:     node.op
		lvalue: v.expr_transform(node.lvalue)!
		rvalue: v.expr_transform(node.rvalue)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_while_stmt(mut node WhileStmt) !string {
	v.last_node = WhileStmt{
		base:      node.base
		expr:      v.expr_transform(node.expr)!
		body:      v.block_transform(mut node.body)!
		else_body: if mut eb := node.else_body { v.block_transform(mut eb)! } else { none }
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_for_stmt(mut node ForStmt) !string {
	mut new := ForStmt{
		base:       node.base
		index:      v.expr_transform(node.index)!
		iter:       v.expr_transform(node.iter)!
		body:       v.block_transform(mut node.body)!
		else_body:  if mut eb := node.else_body { v.block_transform(mut eb)! } else { none }
		is_async:   node.is_async
		index_type: node.index_type
	}
	v.last_node = new
	return ''
}

pub fn (mut v TransformVisitor) visit_return_stmt(mut node ReturnStmt) !string {
	v.last_node = ReturnStmt{
		base: node.base
		expr: if e := node.expr { v.expr_transform(e)! } else { none }
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_assert_stmt(mut node AssertStmt) !string {
	v.last_node = AssertStmt{
		base: node.base
		expr: v.expr_transform(node.expr)!
		msg:  if m := node.msg { v.expr_transform(m)! } else { none }
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_del_stmt(mut node DelStmt) !string {
	v.last_node = DelStmt{
		base: node.base
		expr: v.expr_transform(node.expr)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_if_stmt(mut node IfStmt) !string {
	v.last_node = IfStmt{
		base:      node.base
		expr:      v.expressions_transform(node.expr)!
		body:      v.blocks_transform(node.body)!
		else_body: if mut eb := node.else_body { v.block_transform(mut eb)! } else { none }
	}
	return ''
}

pub fn (mut v TransformVisitor) blocks_transform(blocks []Block) ![]Block {
	mut res := []Block{}
	for mut b in blocks {
		res << v.block_transform(mut b)!
	}
	return res
}

pub fn (mut v TransformVisitor) visit_break_stmt(mut node BreakStmt) !string {
	v.last_node = *node
	return ''
}

pub fn (mut v TransformVisitor) visit_continue_stmt(mut node ContinueStmt) !string {
	v.last_node = *node
	return ''
}

pub fn (mut v TransformVisitor) visit_pass_stmt(mut node PassStmt) !string {
	v.last_node = *node
	return ''
}

pub fn (mut v TransformVisitor) visit_raise_stmt(mut node RaiseStmt) !string {
	v.last_node = RaiseStmt{
		base:      node.base
		expr:      if e := node.expr { v.expr_transform(e)! } else { none }
		from_expr: if fe := node.from_expr { v.expr_transform(fe)! } else { none }
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_try_stmt(mut node TryStmt) !string {
	v.last_node = TryStmt{
		base:         node.base
		body:         v.block_transform(mut node.body)!
		types:        v.optional_expressions_transform(node.types)!
		vars:         v.optional_names_transform(node.vars)!
		handlers:     v.blocks_transform(node.handlers)!
		else_body:    if mut eb := node.else_body { v.block_transform(mut eb)! } else { none }
		finally_body: if mut fb := node.finally_body { v.block_transform(mut fb)! } else { none }
	}
	return ''
}

pub fn (mut v TransformVisitor) optional_names_transform(names []?NameExpr) ![]?NameExpr {
	mut res := []?NameExpr{}
	for n in names {
		if node := n {
			mut mut_node := node
			v.visit_name_expr(mut mut_node)!
			res << v.last_node as NameExpr
		} else {
			res << none
		}
	}
	return res
}

pub fn (mut v TransformVisitor) visit_type_alias_stmt(mut node TypeAliasStmt) !string {
	v.last_node = TypeAliasStmt{
		base:      node.base
		name:      node.name
		type_args: node.type_args.clone()
		value:     v.expr_transform(node.value)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_as_pattern(mut node AsPattern) !string {
	v.last_node = AsPattern{
		pattern: if mut p := node.pattern { v.pattern_transform(mut p)! } else { none }
		name:    if node_n := node.name {
			mut n := node_n
			v.visit_name_expr(mut n)!
			v.last_node as NameExpr
		} else {
			none
		}
	}
	return ''
}

pub fn (mut v TransformVisitor) pattern_transform(mut p Pattern) !Pattern {
	p.accept(mut v)!
	return v.last_node as Pattern
}

pub fn (mut v TransformVisitor) visit_or_pattern(mut node OrPattern) !string {
	v.last_node = OrPattern{
		patterns: v.patterns_transform(node.patterns)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_value_pattern(mut node ValuePattern) !string {
	v.last_node = ValuePattern{
		expr: v.expr_transform(node.expr)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_singleton_pattern(mut node SingletonPattern) !string {
	v.last_node = *node
	return ''
}

pub fn (mut v TransformVisitor) visit_sequence_pattern(mut node SequencePattern) !string {
	v.last_node = SequencePattern{
		patterns: v.patterns_transform(node.patterns)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_starred_pattern(mut node StarredPattern) !string {
	v.last_node = StarredPattern{
		capture: if node_c := node.capture {
			mut c := node_c
			v.visit_name_expr(mut c)!
			v.last_node as NameExpr
		} else {
			none
		}
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_mapping_pattern(mut node MappingPattern) !string {
	v.last_node = MappingPattern{
		keys:   v.expressions_transform(node.keys)!
		values: v.patterns_transform(node.values)!
		rest:   if node_r := node.rest {
			mut r := node_r
			v.visit_name_expr(mut r)!
			v.last_node as NameExpr
		} else {
			none
		}
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_class_pattern(mut node ClassPattern) !string {
	mut class_ref_exp := node.class_ref
	v.visit_member_expr(mut class_ref_exp)! // Simple assumption
	class_ref := v.last_node as MemberExpr

	v.last_node = ClassPattern{
		class_ref:      class_ref
		positionals:    v.patterns_transform(node.positionals)!
		keyword_keys:   node.keyword_keys.clone()
		keyword_values: v.patterns_transform(node.keyword_values)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_match_stmt(mut node MatchStmt) !string {
	v.last_node = MatchStmt{
		base:     node.base
		subject:  v.expr_transform(node.subject)!
		patterns: v.patterns_transform(node.patterns)!
		guards:   v.optional_expressions_transform(node.guards)!
		bodies:   v.blocks_transform(node.bodies)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_star_expr(mut node StarExpr) !string {
	v.last_node = StarExpr{
		base: node.base
		expr: v.expr_transform(node.expr)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_int_expr(mut node IntExpr) !string {
	v.last_node = *node
	return ''
}

pub fn (mut v TransformVisitor) visit_str_expr(mut node StrExpr) !string {
	v.last_node = *node
	return ''
}

pub fn (mut v TransformVisitor) visit_bytes_expr(mut node BytesExpr) !string {
	v.last_node = *node
	return ''
}

pub fn (mut v TransformVisitor) visit_float_expr(mut node FloatExpr) !string {
	v.last_node = *node
	return ''
}

pub fn (mut v TransformVisitor) visit_complex_expr(mut node ComplexExpr) !string {
	v.last_node = *node
	return ''
}

pub fn (mut v TransformVisitor) visit_ellipsis(mut node EllipsisExpr) !string {
	v.last_node = *node
	return ''
}

pub fn (mut v TransformVisitor) visit_name_expr(mut node NameExpr) !string {
	mut res := NameExpr{
		base:            node.base
		name:            node.name
		is_special_form: node.is_special_form
	}
	v.copy_ref(mut res, node)
	v.last_node = res
	return ''
}

pub fn (mut v TransformVisitor) copy_ref(mut new NameExpr, original NameExpr) {
	new.kind = original.kind
	new.fullname = original.fullname
	// Node transformation logic
	new.node = original.node
}

pub fn (mut v TransformVisitor) visit_member_expr(mut node MemberExpr) !string {
	mut member := MemberExpr{
		base: node.base
		expr: v.expr_transform(node.expr)!
		name: node.name
	}
	// Copy ref logic simplified
	v.last_node = member
	return ''
}

pub fn (mut v TransformVisitor) visit_yield_from_expr(mut node YieldFromExpr) !string {
	v.last_node = YieldFromExpr{
		base: node.base
		expr: v.expr_transform(node.expr)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_yield_expr(mut node YieldExpr) !string {
	v.last_node = YieldExpr{
		base: node.base
		expr: if e := node.expr { v.expr_transform(e)! } else { none }
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_await_expr(mut node AwaitExpr) !string {
	v.last_node = AwaitExpr{
		base: node.base
		expr: v.expr_transform(node.expr)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_call_expr(mut node CallExpr) !string {
	v.last_node = CallExpr{
		base:      node.base
		callee:    v.expr_transform(node.callee)!
		args:      v.expressions_transform(node.args)!
		arg_kinds: node.arg_kinds.clone()
		arg_names: node.arg_names.clone()
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_op_expr(mut node OpExpr) !string {
	v.last_node = OpExpr{
		base:        node.base
		op:          node.op
		left:        v.expr_transform(node.left)!
		right:       v.expr_transform(node.right)!
		method_type: node.method_type
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_comparison_expr(mut node ComparisonExpr) !string {
	v.last_node = ComparisonExpr{
		base:         node.base
		operators:    node.operators.clone()
		operands:     v.expressions_transform(node.operands)!
		method_types: node.method_types.clone()
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_cast_expr(mut node CastExpr) !string {
	v.last_node = CastExpr{
		base: node.base
		expr: v.expr_transform(node.expr)!
		type: node.type
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_reveal_expr(mut node RevealExpr) !string {
	v.last_node = RevealExpr{
		base: node.base
		kind: node.kind
		expr: if e := node.expr { v.expr_transform(e)! } else { none }
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_super_expr(mut node SuperExpr) !string {
	mut call := node.call
	v.visit_call_expr(mut call)!
	res_call := v.last_node as CallExpr
	v.last_node = SuperExpr{
		base: node.base
		name: node.name
		call: res_call
		info: node.info
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_assignment_expr(mut node AssignmentExpr) !string {
	mut target := node.target
	v.visit_name_expr(mut target)!
	res_target := v.last_node as NameExpr
	v.last_node = AssignmentExpr{
		base:   node.base
		target: res_target
		value:  v.expr_transform(node.value)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_unary_expr(mut node UnaryExpr) !string {
	v.last_node = UnaryExpr{
		base:        node.base
		op:          node.op
		expr:        v.expr_transform(node.expr)!
		method_type: node.method_type
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_list_expr(mut node ListExpr) !string {
	v.last_node = ListExpr{
		base:  node.base
		items: v.expressions_transform(node.items)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_dict_expr(mut node DictExpr) !string {
	mut new_items := []DictItem{}
	for item in node.items {
		new_items << DictItem{
			key:   if k := item.key { v.expr_transform(k)! } else { none }
			value: v.expr_transform(item.value)!
		}
	}
	v.last_node = DictExpr{
		base:  node.base
		items: new_items
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_template_str_expr(mut node TemplateStrExpr) !string {
	v.last_node = TemplateStrExpr{
		base:  node.base
		parts: v.expressions_transform(node.parts)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_tuple_expr(mut node TupleExpr) !string {
	v.last_node = TupleExpr{
		base:  node.base
		items: v.expressions_transform(node.items)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_set_expr(mut node SetExpr) !string {
	v.last_node = SetExpr{
		base:  node.base
		items: v.expressions_transform(node.items)!
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_index_expr(mut node IndexExpr) !string {
	v.last_node = IndexExpr{
		base:        node.base
		base_:       v.expr_transform(node.base_)!
		index:       v.expr_transform(node.index)!
		method_type: node.method_type
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_type_application(mut node TypeApplication) !string {
	v.last_node = TypeApplication{
		base:  node.base
		expr:  v.expr_transform(node.expr)!
		types: node.types.clone()
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_list_comprehension(mut node ListComprehension) !string {
	mut generator := node.generator
	v.visit_generator_expr(mut generator)!
	res_gen := v.last_node as GeneratorExpr
	v.last_node = ListComprehension{
		base:      node.base
		generator: res_gen
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_set_comprehension(mut node SetComprehension) !string {
	mut generator := node.generator
	v.visit_generator_expr(mut generator)!
	res_gen := v.last_node as GeneratorExpr
	v.last_node = SetComprehension{
		base:      node.base
		generator: res_gen
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_dictionary_comprehension(mut node DictionaryComprehension) !string {
	v.last_node = DictionaryComprehension{
		base:      node.base
		key:       v.expr_transform(node.key)!
		value:     v.expr_transform(node.value)!
		sequences: v.expressions_transform(node.sequences)!
		condlists: v.condlists_transform(node.condlists)!
		is_async:  node.is_async
	}
	return ''
}

pub fn (mut v TransformVisitor) condlists_transform(conds [][]Expression) ![][]Expression {
	mut res := [][]Expression{}
	for c in conds {
		res << v.expressions_transform(c)!
	}
	return res
}

pub fn (mut v TransformVisitor) visit_generator_expr(mut node GeneratorExpr) !string {
	v.last_node = GeneratorExpr{
		base:      node.base
		left_expr: v.expr_transform(node.left_expr)!
		sequences: v.expressions_transform(node.sequences)!
		condlists: v.condlists_transform(node.condlists)!
		is_async:  node.is_async
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_slice_expr(mut node SliceExpr) !string {
	v.last_node = SliceExpr{
		base:        node.base
		begin_index: if b := node.begin_index { v.expr_transform(b)! } else { none }
		end_index:   if e := node.end_index { v.expr_transform(e)! } else { none }
		stride:      if s := node.stride { v.expr_transform(s)! } else { none }
	}
	return ''
}

pub fn (mut v TransformVisitor) visit_conditional_expr(mut node ConditionalExpr) !string {
	v.last_node = ConditionalExpr{
		base:      node.base
		cond:      v.expr_transform(node.cond)!
		if_expr:   v.expr_transform(node.if_expr)!
		else_expr: v.expr_transform(node.else_expr)!
	}
	return ''
}

// More visit methods... (Intentionally omitting complex ones for brevity)

pub fn (mut v TransformVisitor) visit_type_alias(mut o TypeAlias) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_placeholder_node(mut o PlaceholderNode) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_type_var_expr(mut o TypeVarExpr) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_paramspec_expr(mut o ParamSpecExpr) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_type_var_tuple_expr(mut o TypeVarTupleExpr) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_type_alias_expr(mut o TypeAliasExpr) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_namedtuple_expr(mut o NamedTupleExpr) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_enum_call_expr(mut o EnumCallExpr) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_typeddict_expr(mut o TypedDictExpr) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_newtype_expr(mut o NewTypeExpr) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_promote_expr(mut o PromoteExpr) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_temp_node(mut o TempNode) !string {
	v.last_node = *o
	return ''
}

pub fn (mut v TransformVisitor) visit_assert_type_expr(mut o AssertTypeExpr) !string {
	v.last_node = *o
	return ''
}

// ---------------------------------------------------------------------------
// FuncMapInitializer вЂ” concrete no-op NodeVisitor traverser for nested funcs
// ---------------------------------------------------------------------------

pub struct FuncMapInitializer {
pub mut:
	transformer &TransformVisitor = unsafe { nil }
}

pub fn (mut f FuncMapInitializer) visit_mypy_file(mut o MypyFile) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_var(mut o Var) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_type_alias(mut o TypeAlias) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_placeholder_node(mut o PlaceholderNode) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_import(mut o Import) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_import_from(mut o ImportFrom) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_import_all(mut o ImportAll) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_block(mut o Block) !string {
	for mut s in o.body {
		stmt_accept(s, mut f)!
	}
	return ''
}

pub fn (mut f FuncMapInitializer) visit_expression_stmt(mut o ExpressionStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_assignment_stmt(mut o AssignmentStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_operator_assignment_stmt(mut o OperatorAssignmentStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_while_stmt(mut o WhileStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_for_stmt(mut o ForStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_return_stmt(mut o ReturnStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_assert_stmt(mut o AssertStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_del_stmt(mut o DelStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_if_stmt(mut o IfStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_break_stmt(mut o BreakStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_continue_stmt(mut o ContinueStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_pass_stmt(mut o PassStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_raise_stmt(mut o RaiseStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_try_stmt(mut o TryStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_type_alias_stmt(mut o TypeAliasStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_match_stmt(mut o MatchStmt) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_func_def(mut node FuncDef) !string {
	ptr := voidptr(node)
	if ptr !in f.transformer.func_placeholder_map {
		f.transformer.func_placeholder_map[ptr] = &FuncDef{
			base: node.base
			name: node.name
			// placeholder
		}
	}
	return ''
}

// More visitor methods to satisfy interface... (Empty)
pub fn (mut f FuncMapInitializer) visit_overloaded_func_def(mut o OverloadedFuncDef) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_class_def(mut o ClassDef) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_decorator(mut o Decorator) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_int_expr(mut o IntExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_str_expr(mut o StrExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_bytes_expr(mut o BytesExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_float_expr(mut o FloatExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_complex_expr(mut o ComplexExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_ellipsis(mut o EllipsisExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_star_expr(mut o StarExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_name_expr(mut o NameExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_member_expr(mut o MemberExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_yield_from_expr(mut o YieldFromExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_yield_expr(mut o YieldExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_call_expr(mut o CallExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_op_expr(mut o OpExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_comparison_expr(mut o ComparisonExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_cast_expr(mut o CastExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_assert_type_expr(mut o AssertTypeExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_reveal_expr(mut o RevealExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_super_expr(mut o SuperExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_unary_expr(mut o UnaryExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_assignment_expr(mut o AssignmentExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_list_expr(mut o ListExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_dict_expr(mut o DictExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_template_str_expr(mut o TemplateStrExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_tuple_expr(mut o TupleExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_set_expr(mut o SetExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_index_expr(mut o IndexExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_type_application(mut o TypeApplication) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_lambda_expr(mut o LambdaExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_list_comprehension(mut o ListComprehension) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_set_comprehension(mut o SetComprehension) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_dictionary_comprehension(mut o DictionaryComprehension) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_generator_expr(mut o GeneratorExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_slice_expr(mut o SliceExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_conditional_expr(mut o ConditionalExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_type_var_expr(mut o TypeVarExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_paramspec_expr(mut o ParamSpecExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_type_var_tuple_expr(mut o TypeVarTupleExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_type_alias_expr(mut o TypeAliasExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_namedtuple_expr(mut o NamedTupleExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_enum_call_expr(mut o EnumCallExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_typeddict_expr(mut o TypedDictExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_newtype_expr(mut o NewTypeExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_promote_expr(mut o PromoteExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_await_expr(mut o AwaitExpr) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_temp_node(mut o TempNode) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_as_pattern(mut o AsPattern) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_or_pattern(mut o OrPattern) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_value_pattern(mut o ValuePattern) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_singleton_pattern(mut o SingletonPattern) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_sequence_pattern(mut o SequencePattern) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_starred_pattern(mut o StarredPattern) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_mapping_pattern(mut o MappingPattern) !string {
	return ''
}

pub fn (mut f FuncMapInitializer) visit_class_pattern(mut o ClassPattern) !string {
	return ''
}
