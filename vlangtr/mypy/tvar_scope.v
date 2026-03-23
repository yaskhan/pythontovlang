// I, Qwen Code, am working on this file. Started: 2026-03-22 18:30
// Type variable scope for mypy (tvar_scope.py)

module mypy

// TypeVarLikeType is a sum type for type variable-like types.
pub type TypeVarLikeType = TypeVarType | ParamSpecType | TypeVarTupleType

pub fn (t TypeVarLikeType) get_id() TypeVarId {
	return match t {
		TypeVarType { t.id }
		ParamSpecType { t.id }
		TypeVarTupleType { t.id }
	}
}

// FailFunc is a callback for reporting errors.
pub type FailFunc = fn (string, Context)

// TypeVarLikeScope holds bindings for type variables and parameter specifications.
// Node fullname -> TypeVarLikeType.
pub struct TypeVarLikeScope {
pub mut:
	// The scope dictionary: fullname -> TypeVarLikeType
	scope          map[string]TypeVarLikeType
	parent         ?&TypeVarLikeScope
	func_id        int
	class_id       int
	is_class_scope bool
	prohibited     ?&TypeVarLikeScope
	namespace      string
}

// TypeVarLikeDefaultFixer sets namespace for all TypeVarLikeTypes.
pub struct TypeVarLikeDefaultFixer {
pub mut:
	scope     &TypeVarLikeScope
	fail_func FailFunc
	source_tv &TypeVarLikeExpr
	context   Context
}

// new_type_var_like_scope creates a new TypeVarLikeScope.
pub fn new_type_var_like_scope(parent ?&TypeVarLikeScope,
	is_class_scope bool,
	prohibited ?&TypeVarLikeScope,
	namespace string) TypeVarLikeScope {
	mut scope := TypeVarLikeScope{
		scope:          map[string]TypeVarLikeType{}
		parent:         parent
		func_id:        0
		class_id:       0
		is_class_scope: is_class_scope
		prohibited:     prohibited
		namespace:      namespace
	}

	if parent != none {
		p := parent
		scope.func_id = p.func_id
		scope.class_id = p.class_id
	}

	return scope
}

// get_function_scope gets the nearest parent that's a function scope, not a class scope.
pub fn (mut s TypeVarLikeScope) get_function_scope() ?&TypeVarLikeScope {
	mut it := &s
	for it != none && it.is_class_scope {
		it = it.parent
	}
	return it
}

// allow_binding checks if a fullname can be bound in this scope.
pub fn (mut s TypeVarLikeScope) allow_binding(fullname string) bool {
	if fullname in s.scope {
		return false
	}

	if s.parent != none {
		if !s.parent!.allow_binding(fullname) {
			return false
		}
	}

	if s.prohibited != none {
		if !s.prohibited!.allow_binding(fullname) {
			return false
		}
	}

	return true
}

// method_frame creates a new scope frame for binding a method.
pub fn (mut s TypeVarLikeScope) method_frame(namespace string) TypeVarLikeScope {
	return new_type_var_like_scope(&s, false, none, namespace)
}

// class_frame creates a new scope frame for binding a class.
// Prohibits *this* class's tvars.
pub fn (mut s TypeVarLikeScope) class_frame(namespace string) TypeVarLikeScope {
	return new_type_var_like_scope(s.get_function_scope(), true, &s, namespace)
}

// new_unique_func_id creates a unique function ID.
// Used by plugin-like code that needs to make synthetic generic functions.
pub fn (mut s TypeVarLikeScope) new_unique_func_id() TypeVarId {
	s.func_id -= 1
	return TypeVarId{
		raw_id:    s.func_id
		namespace: s.namespace
	}
}

// bind_new binds a new type variable to this scope.
pub fn (mut s TypeVarLikeScope) bind_new(name string,
	tvar_expr &TypeVarLikeExpr,
	fail_func FailFunc,
	context Context) TypeVarLikeType {
	if s.is_class_scope {
		s.class_id += 1
	} else {
		s.func_id -= 1
	}

	i := if s.is_class_scope { s.class_id } else { s.func_id }
	namespace := s.namespace

	// Defaults may reference other type variables.
	default := tvar_expr.default.accept(TypeVarLikeDefaultFixer{
		scope:     &s
		fail_func: fail_func
		source_tv: tvar_expr
		context:   context
	})!

	tvar_def := match tvar_expr {
		TypeVarExpr {
			tve := tvar_expr as TypeVarExpr
			TypeVarType{
				base:        TypeBase{}
				name:        name
				fullname:    tve.fullname
				raw_id:      TypeVarId{
					raw_id:    i
					namespace: namespace
				}
				values:      tve.values
				upper_bound: tve.upper_bound
				default:     default
				variance:    tve.variance
				line:        tve.line
				column:      tve.column
			}
		}
		ParamSpecExpr {
			pse := tvar_expr as ParamSpecExpr
			ParamSpecType{
				base:        TypeBase{}
				name:        name
				fullname:    pse.fullname
				raw_id:      TypeVarId{
					raw_id:    i
					namespace: namespace
				}
				flavor:      param_spec_flavor_bare
				upper_bound: pse.upper_bound
				default:     default
				line:        pse.line
				column:      pse.column
			}
		}
		TypeVarTupleExpr {
			tvte := tvar_expr as TypeVarTupleExpr
			TypeVarTupleType{
				base:           TypeBase{}
				name:           name
				fullname:       tvte.fullname
				raw_id:         TypeVarId{
					raw_id:    i
					namespace: namespace
				}
				upper_bound:    tvte.upper_bound
				default:        default
				tuple_fallback: tvte.tuple_fallback
				min_len:        tvte.min_len
			}
		}
		else {
			panic('Unexpected TypeVarLikeExpr type')
		}
	}

	s.scope[tvar_expr.fullname] = tvar_def
	return tvar_def
}

// bind_existing binds an existing type variable to this scope.
pub fn (mut s TypeVarLikeScope) bind_existing(tvar_def TypeVarLikeType) {
	s.scope[tvar_def.fullname] = tvar_def
}

// get_binding gets the binding for a fullname.
pub fn (mut s TypeVarLikeScope) get_binding(item string) ?TypeVarLikeType {
	fullname := item

	if fullname in s.scope {
		return s.scope[fullname]
	}

	if s.parent != none {
		return s.parent!.get_binding(fullname)
	}

	return none
}

// visit_type_var fixes TypeVarType defaults.
pub fn (mut f TypeVarLikeDefaultFixer) visit_type_var(t &TypeVarType) !MypyTypeNode {
	existing := f.scope.get_binding(t.fullname)
	if existing == none {
		f.report_unbound_tvar(t)
		return AnyType{
			base:        TypeBase{}
			type_of_any: type_of_any_from_error
		}
	}
	ex := existing or {
		return AnyType{
			base:        TypeBase{}
			type_of_any: type_of_any_from_error
		}
	}

	return MypyTypeNode(ex)
}

// visit_param_spec fixes ParamSpecType defaults.
pub fn (mut f TypeVarLikeDefaultFixer) visit_param_spec(t &ParamSpecType) !MypyTypeNode {
	existing := f.scope.get_binding(t.fullname)
	if existing == none {
		f.report_unbound_tvar(t)
		return AnyType{
			base:        TypeBase{}
			type_of_any: type_of_any_from_error
		}
	}
	ex := existing or {
		return AnyType{
			base:        TypeBase{}
			type_of_any: type_of_any_from_error
		}
	}

	return MypyTypeNode(ex)
}

// visit_type_var_tuple fixes TypeVarTupleType defaults.
pub fn (mut f TypeVarLikeDefaultFixer) visit_type_var_tuple(t &TypeVarTupleType) !MypyTypeNode {
	existing := f.scope.get_binding(t.fullname)
	if existing == none {
		f.report_unbound_tvar(t)
		return AnyType{
			base:        TypeBase{}
			type_of_any: type_of_any_from_error
		}
	}
	ex := existing or {
		return AnyType{
			base:        TypeBase{}
			type_of_any: type_of_any_from_error
		}
	}

	return MypyTypeNode(ex)
}

// visit_type_alias_type handles TypeAliasType.
pub fn (mut f TypeVarLikeDefaultFixer) visit_type_alias_type(t &TypeAliasType) !MypyTypeNode {
	return t
}

// report_unbound_tvar reports an unbound type variable.
fn (mut f TypeVarLikeDefaultFixer) report_unbound_tvar(tvar TypeVarLikeType) {
	f.fail_func('Type variable ${tvar.name} referenced in the default of ${f.source_tv.name} is unbound',
		f.context)
}
