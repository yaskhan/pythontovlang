// I, Antigravity, am working on this file. Started: 2026-03-22 03:50
module mypy

// Check type argument properties (e.g., that 'int' in C[int] is valid).

pub struct TypeArgumentAnalyzer {
	MixedTraverserVisitor
pub mut:
	errors                 &Errors
	options                &Options
	is_typeshed_file       bool
	named_type_func        ?fn (string, []MypyTypeNode) &Instance = none
	scope                  Scope
	recurse_into_functions bool = true
	seen_aliases           map[string]bool
}

pub fn (mut v TypeArgumentAnalyzer) visit_mypy_file(mut o MypyFile) !AnyNode {
	v.errors.set_file(o.path, o.fullname)
	// scope.module_scope contextual block
	prev_scope := v.scope.enter_module(o.fullname)
	defer { v.scope.leave(prev_scope) }

	// parent call (but NodeTraverser.visit_mypy_file)
	for mut stmt in o.defs {
		stmt_accept(mut stmt, mut v)!
	}
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) visit_func_def(mut o FuncDef) !AnyNode {
	if !v.recurse_into_functions {
		return ''
	}
	prev_scope := v.scope.enter_function(o)
	defer { v.scope.leave(prev_scope) }

	v.MixedTraverserVisitor.visit_func_def(mut o)!
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) visit_class_def(mut o ClassDef) !AnyNode {
	if info := o.info {
		prev_scope := v.scope.enter_class(info)
		defer { v.scope.leave(prev_scope) }
		v.MixedTraverserVisitor.visit_class_def(mut o)!
	} else {
		v.MixedTraverserVisitor.visit_class_def(mut o)!
	}
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) visit_block(mut o Block) !AnyNode {
	if !o.is_unreachable {
		v.MixedTraverserVisitor.visit_block(mut o)!
	}
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) visit_type_alias_type(t &TypeAliasType) !AnyNode {
	v.MixedTraverserVisitor.visit_type_alias_type(t)!
	// In V: t.alias is ?&TypeAlias
	alias := t.alias or { return error('TypeArgumentAnalyzer: Unfixed type alias') }
	if alias.fullname in v.seen_aliases {
		return ''
	}
	v.seen_aliases[alias.fullname] = true
	defer { v.seen_aliases.delete(alias.fullname) }

	is_error, is_invalid := v.validate_args(alias.name, t.args, alias.alias_tvars, Context{line: t.line})

	if is_invalid {
		// Erase args
		// t.args = ...
	}

	if !is_error {
		// Check expansion
		// get_proper_type(t).accept_synthetic(v)!
	}
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) visit_tuple_type(t &TupleType) !AnyNode {
	// t.items = flatten_nested_tuples(t.items)
	for i, it in t.items {
		if v.check_non_paramspec(it, 'tuple', Context{line: t.line}) {
			// t.items[i] = ...
		}
	}
	v.MixedTraverserVisitor.visit_tuple_type(t)!
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) visit_instance(t &Instance) !AnyNode {
	v.MixedTraverserVisitor.visit_instance(t)!
	info := t.typ // In Instance it is TypeInfo
	// if info is FakeInfo ...

	// defn := info.defn
	// is_error, is_invalid := v.validate_args(info.name, t.args, defn.type_vars, t.base.ctx)
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) check_non_paramspec(arg MypyTypeNode, tv_kind string, context Context) bool {
	if arg is ParamSpecType {
				v.fail('Invalid location for ParamSpec', context, valid_type.code)
		// note ...
		return true
	}
	if arg is ParametersType {
		v.fail('Cannot use Parameters for ${tv_kind}, only for ParamSpec', context, valid_type.code)
		return true
	}
	return false
}

pub fn (mut v TypeArgumentAnalyzer) validate_args(name string, args []MypyTypeNode, type_vars []MypyTypeNode, ctx Context) (bool, bool) {
	mut is_error := false
	mut is_invalid := false

	for i, arg in args {
		if i >= type_vars.len {
			break
		}
		tvar := type_vars[i]

		context := ctx

		if tvar is TypeVarType {
			if v.check_non_paramspec(arg, 'regular type variable', context) {
				is_invalid = true
				continue
			}

			if tvar.values.len > 0 {
				mut arg_values := []MypyTypeNode{}
				if arg is TypeVarType {
					if arg.values.len == 0 {
						is_error = true
						v.fail('Invalid TypeVar "${arg.name}" as type argument for "${name}"',
							context, type_var.code)
						continue
					}
					arg_values = arg.values.clone()
				} else {
					arg_values = [arg]
				}

				if v.check_type_var_values(name, arg_values, tvar.name, tvar.values, context) {
					is_error = true
				}
			}

			upper_bound := tvar.upper_bound
			// Simplified subtype check placeholder
			// if !is_subtype(arg, upper_bound) { ... }
		} else if tvar is ParamSpecType {
			p_arg := get_proper_type(arg)
			if p_arg !is ParamSpecType && p_arg !is ParametersType && p_arg !is AnyType {
				is_invalid = true
				v.fail('Can only replace ParamSpec with a parameter types list or another ParamSpec, got ${p_arg.type_str()}',
					context, valid_type.code)
			}
		}
	}

	if is_invalid {
		is_error = true
	}
	return is_error, is_invalid
}

pub fn (mut v TypeArgumentAnalyzer) visit_unpack_type(typ &UnpackType) !AnyNode {
	v.MixedTraverserVisitor.visit_unpack_type(typ)!
	p_type := get_proper_type(typ.@type)

	if p_type is TupleType || p_type is TypeVarTupleType {
		return ''
	}

	if p_type is Instance && (p_type.typ or { return '' }).fullname == 'builtins.tuple' {
		return ''
	}

	if p_type !is UnboundType && p_type !is AnyType {
		v.fail('Invalid location for Unpack', typ.base_ctx.ctx, valid_type.code)
	}
	// typ.type_ = v.named_type_func('builtins.tuple', [AnyType{kind: .from_error}])
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) check_type_var_values(name string, actuals []MypyTypeNode, arg_name string, valids []MypyTypeNode, context Context) bool {
	mut is_err := false
	for actual in actuals {
		p_actual := get_proper_type(actual)
		if p_actual is AnyType || p_actual is UnboundType {
			continue
		}

		mut found := false
		for valid in valids {
			if is_same_type(p_actual, valid) {
				found = true
				break
			}
		}

		if !found {
			is_err = true
			v.fail('Incompatible value for TypeVar "${arg_name}" in "${name}"', context,
				type_var.code)
		}
	}
	return is_err
}

pub fn (mut v TypeArgumentAnalyzer) fail(msg string, context Context, code string) {
	v.errors.report(context.line, context.column, msg, code, 'error', false, false)
}

pub fn (mut v TypeArgumentAnalyzer) note(msg string, context Context, code string) {
	v.errors.report(context.line, context.column, msg, code, 'note', false, false)
}
