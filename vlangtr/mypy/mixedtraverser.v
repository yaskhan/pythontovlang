// MixedTraverserVisitor — traverses both AST nodes and types.
module mypy

pub struct MixedTraverserVisitor {
	NodeTraverser
	TypeTraverserVisitor
pub mut:
	in_type_alias_expr bool
}

// Symbol nodes

pub fn (mut v MixedTraverserVisitor) visit_var(mut o Var) !AnyNode {
	v.visit_optional_type(o.type_)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_func_def(mut o FuncDef) !AnyNode {
	v.NodeTraverser.visit_func_def(mut o)!
	v.visit_optional_type(o.type_)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_class_def(mut o ClassDef) !AnyNode {
	v.NodeTraverser.visit_class_def(mut o)!
	if info := o.info {
		for base in info.bases {
			v.visit_optional_type(MypyTypeNode(base))!
		}
	}
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_alias_expr(mut o TypeAliasExpr) !AnyNode {
	v.NodeTraverser.visit_type_alias_expr(mut o)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_var_expr(mut o TypeVarExpr) !AnyNode {
	v.NodeTraverser.visit_type_var_expr(mut o)!
	v.visit_optional_type(o.upper_bound)!
	v.visit_optional_type(o.default_)!
	for val in o.values {
		v.visit_optional_type(val)!
	}
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_typeddict_expr(mut o TypedDictExpr) !AnyNode {
	v.NodeTraverser.visit_typeddict_expr(mut o)!
	// TypedDict info traversal (simplified — info is not always available on the expr node)
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_namedtuple_expr(mut o NamedTupleExpr) !AnyNode {
	v.NodeTraverser.visit_namedtuple_expr(mut o)!
	// NamedTuple info traversal (simplified)
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_promote_expr(mut o PromoteExpr) !AnyNode {
	v.NodeTraverser.visit_promote_expr(mut o)!
	v.visit_optional_type(o.type_)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_newtype_expr(mut o NewTypeExpr) !AnyNode {
	v.NodeTraverser.visit_newtype_expr(mut o)!
	v.visit_optional_type(o.old_type)!
	return ''
}

// Statements

pub fn (mut v MixedTraverserVisitor) visit_assignment_stmt(mut o AssignmentStmt) !AnyNode {
	v.NodeTraverser.visit_assignment_stmt(mut o)!
	v.visit_optional_type(o.type_annotation)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_alias_stmt(mut o TypeAliasStmt) !AnyNode {
	v.NodeTraverser.visit_type_alias_stmt(mut o)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_alias(mut o TypeAlias) !AnyNode {
	v.NodeTraverser.visit_type_alias(mut o)!
	v.in_type_alias_expr = true
	v.visit_optional_type(o.target)!
	v.in_type_alias_expr = false
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_for_stmt(mut o ForStmt) !AnyNode {
	v.NodeTraverser.visit_for_stmt(mut o)!
	v.visit_optional_type(o.index_type)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_with_stmt(mut o WithStmt) !AnyNode {
	v.NodeTraverser.visit_with_stmt(mut o)!
	// WithStmt doesn't have analyzed_types field; skip
	return ''
}

// Expressions

pub fn (mut v MixedTraverserVisitor) visit_cast_expr(mut o CastExpr) !AnyNode {
	v.NodeTraverser.visit_cast_expr(mut o)!
	v.visit_optional_type(o.type)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_assert_type_expr(mut o AssertTypeExpr) !AnyNode {
	v.NodeTraverser.visit_assert_type_expr(mut o)!
	v.visit_optional_type(o.type)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_application(mut o TypeApplication) !AnyNode {
	v.NodeTraverser.visit_type_application(mut o)!
	for t in o.types {
		v.visit_optional_type(t)!
	}
	return ''
}

// Helpers

pub fn (mut v MixedTraverserVisitor) visit_optional_type(t ?MypyTypeNode) !AnyNode {
	if typ := t {
		typ.accept(mut v)!
	}
	return ''
}


