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

pub fn (t TypeVarLikeType) as_node() MypyTypeNode {
	return match t {
		TypeVarType { MypyTypeNode(t) }
		ParamSpecType { MypyTypeNode(t) }
		TypeVarTupleType { MypyTypeNode(t) }
	}
}

pub fn (t TypeVarLikeType) fullname() string {
	return match t {
		TypeVarType { t.fullname }
		ParamSpecType { t.fullname }
		TypeVarTupleType { t.fullname }
	}
}

// FailFunc is a callback for reporting errors.
pub type FailFunc = fn (string, Context)

// TypeVarLikeScope holds bindings for type variables and parameter specifications.
// Node fullname -> TypeVarLikeType.
@[heap]
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
	fail_func ?FailFunc
	source_tv TypeVarLikeExpr
	result    MypyTypeNode
	context   Context
}

// new_type_var_like_scope creates a new TypeVarLikeScope.
pub fn new_type_var_like_scope(parent ?&TypeVarLikeScope,
	is_class_scope bool,
	prohibited ?&TypeVarLikeScope,
	namespace string) TypeVarLikeScope {
	mut scope := TypeVarLikeScope{
		scope:          map[string]TypeVarLikeType{}
		func_id:        0
		class_id:       0
		is_class_scope: is_class_scope
		namespace:      namespace
	}
	scope.parent = parent
	scope.prohibited = prohibited

	if parent != none {
		p := parent
		scope.func_id = p.func_id
		scope.class_id = p.class_id
	}

	return scope
}

// get_function_scope gets the nearest parent that's a function scope, not a class scope.
pub fn (mut s TypeVarLikeScope) get_function_scope() ?&TypeVarLikeScope {
	if !s.is_class_scope {
		return &s
	}
	mut curr := s.parent
	for {
		if mut c := curr {
			if c.is_class_scope {
				curr = c.parent
				continue
			}
		}
		break
	}
	return curr
}

// allow_binding checks if a fullname can be bound in this scope.
pub fn (mut s TypeVarLikeScope) allow_binding(fullname string) bool {
	if fullname in s.scope {
		return false
	}

	if mut p := s.parent {
		if !p.allow_binding(fullname) {
			return false
		}
	}

	if mut ph := s.prohibited {
		if !ph.allow_binding(fullname) {
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
	return TypeVarId(s.func_id)
}

// bind_new binds a new type variable to this scope.
pub fn (mut s TypeVarLikeScope) bind_new(name string,
	tvar_expr &TypeVarLikeExpr,
	fail_func FailFunc,
	context Context) !TypeVarLikeType {
	if s.is_class_scope {
		s.class_id += 1
	} else {
		s.func_id -= 1
	}

	i := if s.is_class_scope { s.class_id } else { s.func_id }
	// Defaults may reference other type variables.
	mut def_fixer := TypeVarLikeDefaultFixer{
		scope:     &s
		fail_func: fail_func
		source_tv: *tvar_expr
		context:   context
	}
	def_fixer.result = tvar_expr.default_().accept_translator(mut def_fixer)!
	tvar_def := match tvar_expr {
		TypeVarExpr {
			tve := tvar_expr as TypeVarExpr
			TypeVarLikeType(TypeVarType{
				name:        name
				fullname:    tve.fullname
				id:          i
				values:      tve.values
				upper_bound: tve.upper_bound
				variance:    tve.variance
				line:        tve.base.line
			})
		}
		ParamSpecExpr {
			pse := tvar_expr as ParamSpecExpr
			TypeVarLikeType(ParamSpecType{
				name:        name
				fullname:    pse.fullname
				id:          i
				flavor:      param_spec_flavor_bare
				upper_bound: pse.upper_bound
				line:        pse.base.line
			})
		}
		TypeVarTupleExpr {
			tvte := tvar_expr as TypeVarTupleExpr
			TypeVarLikeType(TypeVarTupleType{
				name:           name
				fullname:       tvte.fullname
				id:             i
				upper_bound:    tvte.upper_bound
				tuple_fallback: AnyType{
					type_of_any: TypeOfAny.from_error
				}
				line:           tvte.base.line
			})
		}
	}

	s.scope[tvar_expr.fullname()] = tvar_def
	return tvar_def
}

// bind_existing binds an existing type variable to this scope.
pub fn (mut s TypeVarLikeScope) bind_existing(tvar_def TypeVarLikeType) {
	s.scope[tvar_def.fullname()] = tvar_def
}

// get_binding gets the binding for a fullname.
pub fn (mut s TypeVarLikeScope) get_binding(item string) ?TypeVarLikeType {
	fullname := item

	if binding := s.scope[fullname] {
		return binding
	}

	if mut p := s.parent {
		return p.get_binding(fullname)
	}

	return none
}

// visit_type_var fixes TypeVarType defaults.
pub fn (mut f TypeVarLikeDefaultFixer) visit_type_var(t &TypeVarType) !MypyTypeNode {
	existing := f.scope.get_binding(t.fullname)
	if existing == none {
		// f.report_unbound_tvar(t)
		return AnyType{
			
			type_of_any: TypeOfAny.from_error
		}
	}
	ex := existing or {
		return AnyType{
			
			type_of_any: TypeOfAny.from_error
		}
	}

	return ex.as_node()
}

// visit_param_spec fixes ParamSpecType defaults.
pub fn (mut f TypeVarLikeDefaultFixer) visit_param_spec(t &ParamSpecType) !MypyTypeNode {
	existing := f.scope.get_binding(t.fullname)
	if existing == none {
		// f.report_unbound_tvar(t)
		return AnyType{
			
			type_of_any: TypeOfAny.from_error
		}
	}
	ex := existing or {
		return AnyType{
			
			type_of_any: TypeOfAny.from_error
		}
	}

	return ex.as_node()
}

// visit_type_var_tuple fixes TypeVarTupleType defaults.
pub fn (mut f TypeVarLikeDefaultFixer) visit_type_var_tuple(t &TypeVarTupleType) !MypyTypeNode {
	existing := f.scope.get_binding(t.fullname)
	if existing == none {
		// f.report_unbound_tvar(t)
		return AnyType{
			
			type_of_any: TypeOfAny.from_error
		}
	}
	ex := existing or {
		return AnyType{
			
			type_of_any: TypeOfAny.from_error
		}
	}

	return ex.as_node()
}

// visit_type_alias_type handles TypeAliasType.
pub fn (mut f TypeVarLikeDefaultFixer) visit_type_alias_type(t &TypeAliasType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

// report_unbound_tvar reports an unbound type variable.
fn (mut f TypeVarLikeDefaultFixer) report_unbound_tvar(tvar TypeVarLikeType) {
	if fail_func := f.fail_func {
		fail_func('Type variable ${tvar.name} referenced in the default of ${f.source_tv.name} is unbound',
			f.context)
	}
}

pub fn (mut f TypeVarLikeDefaultFixer) visit_unbound_type(t &UnboundType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_any(t &AnyType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_none_type(t &NoneType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_uninhabited_type(t &UninhabitedType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_erased_type(t &ErasedType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_deleted_type(t &DeletedType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_parameters(t &ParametersType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_instance(t &Instance) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_callable_type(t &CallableType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_overloaded(t &Overloaded) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_tuple_type(t &TupleType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_typeddict_type(t &TypedDictType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_literal_type(t &LiteralType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_union_type(t &UnionType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_partial_type(t &PartialTypeT) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_type_type(t &TypeType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_unpack_type(t &UnpackType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_type_list(t &TypeList) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_callable_argument(t &CallableArgument) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_ellipsis_type(t &EllipsisType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_raw_expression_type(t &RawExpressionType) !MypyTypeNode { return MypyTypeNode(*t) }
pub fn (mut f TypeVarLikeDefaultFixer) visit_placeholder_type(t &PlaceholderType) !MypyTypeNode { return MypyTypeNode(*t) }
