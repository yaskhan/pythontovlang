// treetransform.v — AST node transformer.
// Translated from mypy/treetransform.py to V 0.5.x

module mypy

pub struct TransformVisitor {
pub mut:
	test_only bool
}

pub fn (mut t TransformVisitor) node(mut n Node) !AnyNode {
	return n.accept(mut t)!
}

pub fn (mut t TransformVisitor) expr(mut e Expression) Expression {
	res := e.accept(mut t) or { return e }
	if res is MypyNode {
		if res.is_expression() {
			return res.as_expression() or { return e }
		}
	}
	return e
}

pub fn (mut t TransformVisitor) optional_expr(e ?Expression) ?Expression {
	if mut ee := e {
		res := ee.accept(mut t) or { return e }
		if res is MypyNode {
			if res.is_expression() {
				return res.as_expression() or { return e }
			}
		}
	}
	return e
}

pub fn (mut t TransformVisitor) statements(mut ss []Statement) []Statement {
	mut result := []Statement{}
	for i in 0 .. ss.len {
		mut s := ss[i]
		node := s.accept(mut t) or {
			result << ss[i]
			continue
		}
		if mut n := node.as_mypy_node() {
			if n.is_statement() {
				result << n.as_statement() or { ss[i] }
			} else {
				result << ss[i]
			}
		} else {
			result << ss[i]
		}
	}
	return result
}

pub fn (mut t TransformVisitor) block(mut b Block) Block {
	node := t.visit_block(mut b) or { return b }
	if mut n := node.as_mypy_node() {
		match mut n {
			Block { return n }
			else {}
		}
	}
	return b
}

pub fn (mut t TransformVisitor) typ(tp MypyTypeNode) MypyTypeNode {
	return tp
}

pub fn (mut t TransformVisitor) optional_typ(tp ?MypyTypeNode) ?MypyTypeNode {
	if _ := tp {
		return t.typ(tp or { panic('unreachable') })
	}
	return none
}

pub fn (mut t TransformVisitor) pattern(mut p PatternNode) PatternNode {
	res := p.accept(mut t) or { return p }
	if mut n := res.as_mypy_node() {
		return n.as_pattern() or { *p }
	}
	if mut pat := res.as_pattern() {
		return pat
	}
	return *p
}

pub fn (mut t TransformVisitor) visit_mypy_file(mut node MypyFile) !AnyNode {
	assert t.test_only, 'This visitor should not be used for whole files.'
	mut ignored_lines := node.ignored_lines.clone()
	mut new := MypyFile{
		base:          node.base
		defs:          t.statements(mut node.defs)
		is_bom:        node.is_bom
		ignored_lines: ignored_lines
	}
	new.fullname = node.fullname
	new.path = node.path
	new.names = SymbolTable{
		symbols: node.names.symbols.clone()
	}
	return AnyNode(MypyNode(new))
}

pub fn (mut t TransformVisitor) copy_argument(mut argument Argument) Argument {
	mut variable_res := t.visit_var(mut argument.variable) or { return argument }
	mut variable := argument.variable
	if mut n := variable_res.as_mypy_node() {
		if n is Var {
			variable = n as Var
		}
	}
	return Argument{
		variable:        variable
		type_annotation: argument.type_annotation
		initializer:     t.optional_expr(argument.initializer)
		kind:            argument.kind
	}
}

pub struct FuncMapInitializer {
	NodeTraverser
	transformer TransformVisitor
}

pub fn (mut f FuncMapInitializer) visit_func_def(mut node FuncDef) !AnyNode {
	return AnyNode(MypyNode(node))
}

pub fn (mut f FuncMapInitializer) visit_block(mut node Block) !AnyNode {
	for mut stmt in node.body {
		stmt.accept(mut f)!
	}
	return AnyNode(MypyNode(node))
}

pub fn (mut t TransformVisitor) visit_int_expr(mut node IntExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_str_expr(mut node StrExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_bytes_expr(mut node BytesExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_float_expr(mut node FloatExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_complex_expr(mut node ComplexExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_ellipsis(mut node EllipsisExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_star_expr(mut node StarExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_name_expr(mut node NameExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_member_expr(mut node MemberExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_yield_from_expr(mut node YieldFromExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_yield_expr(mut node YieldExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_call_expr(mut node CallExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_op_expr(mut node OpExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_comparison_expr(mut node ComparisonExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_cast_expr(mut node CastExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_assert_type_expr(mut node AssertTypeExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_reveal_expr(mut node RevealExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_super_expr(mut node SuperExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_unary_expr(mut node UnaryExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_assignment_expr(mut node AssignmentExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_list_expr(mut node ListExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_dict_expr(mut node DictExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_template_str_expr(mut node TemplateStrExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_tuple_expr(mut node TupleExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_set_expr(mut node SetExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_index_expr(mut node IndexExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_type_application(mut node TypeApplication) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_lambda_expr(mut node LambdaExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_list_comprehension(mut node ListComprehension) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_set_comprehension(mut node SetComprehension) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_dictionary_comprehension(mut node DictionaryComprehension) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_generator_expr(mut node GeneratorExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_slice_expr(mut node SliceExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_conditional_expr(mut node ConditionalExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_type_var_expr(mut node TypeVarExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_paramspec_expr(mut node ParamSpecExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_type_var_tuple_expr(mut node TypeVarTupleExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_type_alias_expr(mut node TypeAliasExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_namedtuple_expr(mut node NamedTupleExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_enum_call_expr(mut node EnumCallExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_typeddict_expr(mut node TypedDictExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_newtype_expr(mut node NewTypeExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_promote_expr(mut node PromoteExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_await_expr(mut node AwaitExpr) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_temp_node(mut node TempNode) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_assignment_stmt(mut node AssignmentStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_for_stmt(mut node ForStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_with_stmt(mut node WithStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_del_stmt(mut node DelStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_func_def(mut node FuncDef) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_overloaded_func_def(mut node OverloadedFuncDef) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_class_def(mut node ClassDef) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_global_decl(mut node GlobalDecl) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_nonlocal_decl(mut node NonlocalDecl) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_decorator(mut node Decorator) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_import(mut node Import) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_import_from(mut node ImportFrom) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_import_all(mut node ImportAll) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_block(mut node Block) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_expression_stmt(mut node ExpressionStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_operator_assignment_stmt(mut node OperatorAssignmentStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_while_stmt(mut node WhileStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_return_stmt(mut node ReturnStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_assert_stmt(mut node AssertStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_if_stmt(mut node IfStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_break_stmt(mut node BreakStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_continue_stmt(mut node ContinueStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_pass_stmt(mut node PassStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_raise_stmt(mut node RaiseStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_try_stmt(mut node TryStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_type_alias_stmt(mut node TypeAliasStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_match_stmt(mut node MatchStmt) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_as_pattern(mut node AsPattern) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_or_pattern(mut node OrPattern) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_value_pattern(mut node ValuePattern) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_singleton_pattern(mut node SingletonPattern) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_sequence_pattern(mut node SequencePattern) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_starred_pattern(mut node StarredPattern) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_mapping_pattern(mut node MappingPattern) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_class_pattern(mut node ClassPattern) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_var(mut node Var) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_type_alias(mut node TypeAlias) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_placeholder_node(mut node PlaceholderNode) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_argument(mut node Argument) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_type_param(mut node TypeParam) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_type_info(mut node TypeInfo) !AnyNode { return AnyNode(MypyNode(node)) }

pub fn (mut t TransformVisitor) visit_lvalue(mut node Lvalue) !AnyNode {
	match mut node {
		ListExpr { return AnyNode(MypyNode(node)) }
		MemberExpr { return AnyNode(MypyNode(node)) }
		NameExpr { return AnyNode(MypyNode(node)) }
		StarExpr { return AnyNode(MypyNode(node)) }
		TupleExpr { return AnyNode(MypyNode(node)) }
	}
}
