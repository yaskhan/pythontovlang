// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 03:45
module mypy

// MixedTraverserVisitor — обходчик, который посещает и узлы AST, и типы.
// Поскольку в V нет множественного наследования, мы встраиваем NodeTraverser
// и TypeTraverserVisitor.

pub struct MixedTraverserVisitor {
	NodeTraverser
	TypeTraverserVisitor
pub mut:
	in_type_alias_expr bool
}

// Symbol nodes

pub fn (mut v MixedTraverserVisitor) visit_var(o &Var) !string {
	v.visit_optional_type(o.typ)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_func_def(o &FuncDef) !string {
	v.NodeTraverser.visit_func_def(o)!
	v.visit_optional_type(o.typ)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_class_def(o &ClassDef) !string {
	v.NodeTraverser.visit_class_def(o)!
	if info := o.info {
		for base in info.bases {
			base.accept_synthetic(v)!
		}
		if sa := info.special_alias {
			sa.accept_synthetic(v)!
		}
	}
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_alias_expr(o &TypeAliasExpr) !string {
	v.NodeTraverser.visit_type_alias_expr(o)!
	// В Python: o.node.accept(self)
	// В V: TypeAliasExpr.node — это SymbolNode
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_var_expr(o &TypeVarExpr) !string {
	v.NodeTraverser.visit_type_var_expr(o)!
	o.upper_bound.accept_synthetic(v)!
	o.default_val.accept_synthetic(v)!
	for val in o.values {
		val.accept_synthetic(v)!
	}
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_typeddict_expr(o &TypedDictExpr) !string {
	v.NodeTraverser.visit_typeddict_expr(o)!
	if info := o.info {
		v.visit_optional_type(info.typeddict_type)!
	}
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_namedtuple_expr(o &NamedTupleExpr) !string {
	v.NodeTraverser.visit_namedtuple_expr(o)!
	if info := o.info {
		if tt := info.tuple_type {
			tt.accept_synthetic(v)!
		}
	}
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_promote_expr(o &PromoteExpr) !string {
	v.NodeTraverser.visit_promote_expr(o)!
	o.typ.accept_synthetic(v)!
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
	v.visit_optional_type(o.typ)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_alias_stmt(o &TypeAliasStmt) !string {
	v.NodeTraverser.visit_type_alias_stmt(o)!
	// В Python: o.alias_node.accept(self)
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_alias(o &TypeAlias) !string {
	v.NodeTraverser.visit_type_alias(o)!
	v.in_type_alias_expr = true
	o.target.accept_synthetic(v)!
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
	for typ in o.analyzed_types {
		typ.accept_synthetic(v)!
	}
	return ''
}

// Expressions

pub fn (mut v MixedTraverserVisitor) visit_cast_expr(o &CastExpr) !string {
	v.NodeTraverser.visit_cast_expr(o)!
	o.typ.accept_synthetic(v)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_assert_type_expr(o &AssertTypeExpr) !string {
	v.NodeTraverser.visit_assert_type_expr(o)!
	o.typ.accept_synthetic(v)!
	return ''
}

pub fn (mut v MixedTraverserVisitor) visit_type_application(o &TypeApplication) !string {
	v.NodeTraverser.visit_type_application(o)!
	for t in o.types {
		t.accept_synthetic(v)!
	}
	return ''
}

// Helpers

pub fn (mut v MixedTraverserVisitor) visit_optional_type(t ?MypyTypeNode) ! {
	if typ := t {
		typ.accept_synthetic(v)!
	}
}
