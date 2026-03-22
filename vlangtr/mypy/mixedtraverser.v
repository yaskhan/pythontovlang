// MixedTraverserVisitor — traverses both AST nodes and types.
module mypy

pub struct MixedTraverserVisitor {
	NodeTraverser
	TypeTraverserVisitor
pub mut:
	in_type_alias_expr bool
}

// Symbol nodes

pub fn (mut v MixedTraverserVisitor) visit_var(o &Var) !string {
	v.visit_optional_type(o.type_)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_func_def(o &FuncDef) !string {
	v.NodeTraverser.visit_func_def(o)!
	v.visit_optional_type(o.type_)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_class_def(o &ClassDef) !string {
	v.NodeTraverser.visit_class_def(o)!
	if info := o.info {
		for base in info.bases {
			MypyTypeNode(base).accept(v)!
		}
	}
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_alias_expr(o &TypeAliasExpr) !string {
	v.NodeTraverser.visit_type_alias_expr(o)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_var_expr(o &TypeVarExpr) !string {
	v.NodeTraverser.visit_type_var_expr(o)!
	o.upper_bound.accept(v)!
	o.default_.accept(v)!
	for val in o.values {
		val.accept(v)!
	}
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_typeddict_expr(o &TypedDictExpr) !string {
	v.NodeTraverser.visit_typeddict_expr(o)!
	// TypedDict info traversal (simplified — info is not always available on the expr node)
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_namedtuple_expr(o &NamedTupleExpr) !string {
	v.NodeTraverser.visit_namedtuple_expr(o)!
	// NamedTuple info traversal (simplified)
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_promote_expr(o &PromoteExpr) !string {
	v.NodeTraverser.visit_promote_expr(o)!
	o.type_.accept(v)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_newtype_expr(o &NewTypeExpr) !string {
	v.NodeTraverser.visit_newtype_expr(o)!
	v.visit_optional_type(o.old_type)!
	return ''
}

// Statements

pub fn (mut v MixedTraverserVisitor) visit_assignment_stmt(o &AssignmentStmt) !string {
	v.NodeTraverser.visit_assignment_stmt(o)!
	v.visit_optional_type(o.type_annotation)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_alias_stmt(o &TypeAliasStmt) !string {
	v.NodeTraverser.visit_type_alias_stmt(o)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_alias(o &TypeAlias) !string {
	v.NodeTraverser.visit_type_alias(o)!
	v.in_type_alias_expr = true
	o.target.accept(v)!
	v.in_type_alias_expr = false
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_for_stmt(o &ForStmt) !string {
	v.NodeTraverser.visit_for_stmt(o)!
	v.visit_optional_type(o.index_type)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_with_stmt(o &WithStmt) !string {
	v.NodeTraverser.visit_with_stmt(o)!
	// WithStmt doesn't have analyzed_types field; skip
	return ''
}

// Expressions

pub fn (mut v MixedTraverserVisitor) visit_cast_expr(o &CastExpr) !string {
	v.NodeTraverser.visit_cast_expr(o)!
	o.type_.accept(v)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_assert_type_expr(o &AssertTypeExpr) !string {
	v.NodeTraverser.visit_assert_type_expr(o)!
	o.type_.accept(v)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_application(o &TypeApplication) !string {
	v.NodeTraverser.visit_type_application(o)!
	for t in o.types {
		t.accept(v)!
	}
	return ''
}

// Helpers

pub fn (mut v MixedTraverserVisitor) visit_optional_type(t ?MypyTypeNode) !string {
	if typ := t {
		typ.accept(v)!
	}
	return ''
}
