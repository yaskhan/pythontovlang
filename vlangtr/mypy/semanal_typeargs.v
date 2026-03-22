// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 03:50
module mypy

// Проверка свойств аргументов типов (например, того, что 'int' в C[int] является валидным).

pub struct TypeArgumentAnalyzer {
	MixedTraverserVisitor
pub mut:
	errors                 &Errors
	options                &Options
	is_typeshed_file       bool
	named_type_func        fn (string, []MypyTypeNode) &Instance
	scope                  Scope
	recurse_into_functions bool = true
	seen_aliases           map[string]bool
}

pub fn (mut v TypeArgumentAnalyzer) visit_mypy_file(o &MypyFile) !string {
	v.errors.set_file(o.path, o.fullname, v.scope, v.options)
	// scope.module_scope contextual block
	prev_scope := v.scope.enter_module(o.fullname)
	defer { v.scope.leave(prev_scope) }

	// parent call (but NodeTraverser.visit_mypy_file)
	for stmt in o.defs {
		stmt_accept(stmt, v)!
	}
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) visit_func_def(o &FuncDef) !string {
	if !v.recurse_into_functions {
		return ''
	}
	prev_scope := v.scope.enter_function(o)
	defer { v.scope.leave(prev_scope) }

	v.MixedTraverserVisitor.visit_func_def(o)!
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) visit_class_def(o &ClassDef) !string {
	if info := o.info {
		prev_scope := v.scope.enter_class(info)
		defer { v.scope.leave(prev_scope) }
		v.MixedTraverserVisitor.visit_class_def(o)!
	} else {
		v.MixedTraverserVisitor.visit_class_def(o)!
	}
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) visit_block(o &Block) !string {
	if !o.is_unreachable {
		v.NodeTraverser.visit_block(o)!
	}
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) visit_type_alias_type(t &TypeAliasType) !string {
	v.TypeTraverserVisitor.visit_type_alias_type(t)!
	// В V: t.alias — это ?&TypeAlias
	alias := t.alias or { return error('TypeArgumentAnalyzer: Unfixed type alias ${t.alias_name}') }

	if t in v.seen_aliases { // Need a way to check identity or use fullname
		return ''
	}
	v.seen_aliases[t.alias_name] = true
	defer { v.seen_aliases.delete(t.alias_name) }

	is_error, is_invalid := v.validate_args(alias.name, t.args, alias.alias_tvars, t.base.ctx)

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

pub fn (mut v TypeArgumentAnalyzer) visit_tuple_type(t &TupleType) !string {
	// t.items = flatten_nested_tuples(t.items)
	for i, it in t.items {
		if v.check_non_paramspec(it, 'tuple', t.base.ctx) {
			// t.items[i] = ...
		}
	}
	v.TypeTraverserVisitor.visit_tuple_type(t)!
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) visit_instance(t &Instance) !string {
	v.TypeTraverserVisitor.visit_instance(t)!
	info := t.typ // In Instance it is TypeInfo
	// if info is FakeInfo ...

	// defn := info.defn
	// is_error, is_invalid := v.validate_args(info.name, t.args, defn.type_vars, t.base.ctx)
	return ''
}

pub fn (mut v TypeArgumentAnalyzer) check_non_paramspec(arg MypyTypeNode, tv_kind string, context Context) bool {
	if arg is ParamSpecType {
		v.fail('Invalid location for ParamSpec', context, valid_type)
		// note ...
		return true
	}
	if arg is ParametersType {
		v.fail('Cannot use Parameters for ${tv_kind}, only for ParamSpec', context, valid_type)
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

		context := if arg.base_ctx().line < 0 { ctx } else { arg.base_ctx() }

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
							context, code_type_var)
						continue
					}
					arg_values = arg.values
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
					context, valid_type)
			}
		}
	}

	if is_invalid {
		is_error = true
	}
	return is_error, is_invalid
}

pub fn (mut v TypeArgumentAnalyzer) visit_unpack_type(typ &UnpackType) !string {
	v.TypeTraverserVisitor.visit_unpack_type(typ)!
	p_type := get_proper_type(typ.type_)

	if p_type is TupleType || p_type is TypeVarTupleType {
		return ''
	}

	if p_type is Instance && p_type.typ.fullname == 'builtins.tuple' {
		return ''
	}

	if p_type !is UnboundType && p_type !is AnyType {
		v.fail('Invalid location for Unpack', p_type.base_ctx(), valid_type)
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
				code_type_var)
		}
	}
	return is_err
}

pub fn (mut v TypeArgumentAnalyzer) fail(msg string, context Context, code ?&ErrorCode) {
	v.errors.report(context.line, context.column, msg, code)
}

pub fn (mut v TypeArgumentAnalyzer) note(msg string, context Context, code ?&ErrorCode) {
	v.errors.report(context.line, context.column, msg, .note, code)
}
