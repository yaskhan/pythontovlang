// Я Cline работаю над этим файлом. Начало: 2026-03-22 15:12
// typeanal.v — Semantic analysis of types
// Переведён из mypy/typeanal.py

module mypy

// analyze_type_alias анализирует правую часть определения типа алиаса
// Возвращает тип и множество имён алиасов, от которых он зависит
pub fn analyze_type_alias(typ MypyTypeNode, api SemanticAnalyzerCoreInterface, tvar_scope TypeVarLikeScope, plugin Plugin, options Options, cur_mod_node MypyFile, is_typeshed_stub bool, allow_placeholder bool, in_dynamic_func bool, global_scope bool, allowed_alias_tvars []TypeVarLikeType, alias_type_params_names []string, python_3_12_type_alias bool) (MypyTypeNode, map[string]bool) {
	mut analyzer := TypeAnalyser{
		api:                     api
		tvar_scope:              tvar_scope
		plugin:                  plugin
		options:                 options
		cur_mod_node:            cur_mod_node
		is_typeshed_stub:        is_typeshed_stub
		defining_alias:          true
		allow_placeholder:       allow_placeholder
		prohibit_self_type:      'type alias target'
		allowed_alias_tvars:     allowed_alias_tvars
		alias_type_params_names: alias_type_params_names
		python_3_12_type_alias:  python_3_12_type_alias
	}
	analyzer.in_dynamic_func = in_dynamic_func
	analyzer.global_scope = global_scope
	res := analyzer.anal_type(typ, false)
	return res, analyzer.aliases_used
}

// TypeAnalyser — семантический анализатор для типов
// Конвертирует непривязанные типы в привязанные
pub struct TypeAnalyser {
pub mut:
	api                                SemanticAnalyzerCoreInterface
	fail_func                          fn (string, Context, ErrorCode) = unsafe { nil }
	note_func                          fn (string, Context, ErrorCode) = unsafe { nil }
	tvar_scope                         TypeVarLikeScope
	defining_alias                     bool
	python_3_12_type_alias             bool
	allow_tuple_literal                bool
	nesting_level                      int
	always_allow_new_syntax            bool
	allow_unbound_tvars                bool
	allowed_alias_tvars                []TypeVarLikeType
	alias_type_params_names            []string
	allow_placeholder                  bool
	allow_typed_dict_special_forms     bool
	allow_final                        bool
	allow_param_spec_literals          bool
	allow_ellipsis                     bool
	report_invalid_types               bool
	plugin                             Plugin
	options                            Options
	cur_mod_node                       MypyFile
	is_typeshed_stub                   bool
	aliases_used                       map[string]bool
	prohibit_self_type                 ?string
	prohibit_special_class_field_types ?string
	allow_type_any                     bool
	allow_type_var_tuple               bool
	allow_unpack                       bool
	in_dynamic_func                    bool
	global_scope                       bool
}

// visit_unbound_type обрабатывает непривязанный тип
pub fn (mut ta TypeAnalyser) visit_unbound_type(t &UnboundType) MypyTypeNode {
	typ := ta.visit_unbound_type_nonoptional(t, false)
	if t.optional {
		return make_optional_type(typ)
	}
	return typ
}

// visit_unbound_type_nonoptional обрабатывает непривязанный тип (не optional)
pub fn (mut ta TypeAnalyser) visit_unbound_type_nonoptional(t &UnboundType, defining_literal bool) MypyTypeNode {
	sym := ta.lookup_qualified(t.name, t.base.ctx)

	if sym != none {
		node_ref := sym.node or { return MypyTypeNode(*t) }

		if node_ref is PlaceholderNode {
			if node_ref.becomes_typeinfo {
				if ta.api.final_iteration() {
					ta.cannot_resolve_type(t)
					return MypyTypeNode(AnyType{
						type_of_any: .from_error
					})
				} else if ta.allow_placeholder {
					ta.api.defer(t.base.ctx, false)
				} else {
					ta.api.record_incomplete_ref()
				}
				return MypyTypeNode(PlaceholderType{
					fullname: node_ref.fullname
					args:     ta.anal_array(t.args)
				})
			} else {
				if ta.api.final_iteration() {
					ta.cannot_resolve_type(t)
					return MypyTypeNode(AnyType{
						type_of_any: .from_error
					})
				} else {
					ta.api.record_incomplete_ref()
					return MypyTypeNode(AnyType{
						type_of_any: .special_form
					})
				}
			}
		}

		fullname := node_ref.fullname()

		tvar_def := ta.tvar_scope.get_binding(fullname)
		if tvar_def != none {
			tv := tvar_def or { return MypyTypeNode(*t) }
			return match tv {
				TypeVarType { MypyTypeNode(tv) }
				ParamSpecType { MypyTypeNode(tv) }
				TypeVarTupleType { MypyTypeNode(tv) }
			}
		}

		if node_ref is ParamSpecExpr {
			return MypyTypeNode(ParamSpecType{
				id:          node_ref.id
				name:        node_ref.name
				fullname:    node_ref.fullname
				upper_bound: MypyTypeNode(Instance{
					typ: &TypeInfo{
						fullname: 'builtins.object'
					}
				})
			})
		}

		if node_ref is TypeVarExpr {
			return MypyTypeNode(TypeVarType{
				id:          node_ref.id
				name:        node_ref.name
				fullname:    node_ref.fullname
				upper_bound: MypyTypeNode(Instance{
					typ: &TypeInfo{
						fullname: 'builtins.object'
					}
				})
			})
		}

		special := ta.try_analyze_special_unbound_type(t, fullname)
		if special != none {
			return special or { MypyTypeNode(*t) }
		}

		if node_ref is TypeAlias {
			ta.aliases_used[fullname] = true
			return MypyTypeNode(TypeAliasType{
				alias_name: t.name
				alias:      node_ref
				args:       ta.anal_array(t.args)
			})
		}

		if node_ref is TypeInfo {
			return ta.analyze_type_with_type_info(node_ref, t.args, t.base.ctx)
		}

		return ta.analyze_unbound_type_without_type_info(t, sym, defining_literal)
	} else {
		return MypyTypeNode(AnyType{
			type_of_any: .special_form
		})
	}
}

// try_analyze_special_unbound_type пытается обработать специальные типы
pub fn (mut ta TypeAnalyser) try_analyze_special_unbound_type(t &UnboundType, fullname string) ?MypyTypeNode {
	if fullname == 'builtins.None' {
		return MypyTypeNode(NoneType{})
	} else if fullname == 'typing.Any' {
		return MypyTypeNode(AnyType{
			type_of_any: .explicit
		})
	} else if fullname == 'typing.Union' {
		items := ta.anal_array(t.args)
		return make_union(items)
	} else if fullname == 'typing.Optional' {
		if t.args.len != 1 {
			ta.fail('Optional[...] must have exactly one type argument', t.base.ctx)
			return MypyTypeNode(AnyType{
				type_of_any: .from_error
			})
		}
		item := ta.anal_type(t.args[0], true)
		return make_optional_type(item)
	} else if fullname == 'typing.Callable' {
		return ta.analyze_callable_type(t)
	} else if fullname == 'typing.Literal' {
		return ta.analyze_literal_type(t)
	} else if fullname == 'typing.Annotated' {
		if t.args.len > 0 {
			return ta.anal_type(t.args[0], true)
		}
	}
	return none
}

// analyze_type_with_type_info обрабатывает тип с TypeInfo
pub fn (mut ta TypeAnalyser) analyze_type_with_type_info(info &TypeInfo, args []MypyTypeNode, ctx Context) MypyTypeNode {
	if args.len > 0 && info.fullname == 'builtins.tuple' {
		fallback := Instance{
			typ:  info
			args: [MypyTypeNode(AnyType{
				type_of_any: .special_form
			})]
		}
		return MypyTypeNode(TupleType{
			items:            ta.anal_array(args)
			partial_fallback: fallback
		})
	}

	instance := Instance{
		typ:  info
		args: ta.anal_array(args)
	}
	return MypyTypeNode(instance)
}

// analyze_unbound_type_without_type_info обрабатывает непривязанный тип без TypeInfo
pub fn (mut ta TypeAnalyser) analyze_unbound_type_without_type_info(t &UnboundType, sym &SymbolTableNode, defining_literal bool) MypyTypeNode {
	ta.fail('Cannot interpret reference as a type', t.base.ctx)
	return MypyTypeNode(*t)
}

// visit_any обрабатывает Any
pub fn (mut ta TypeAnalyser) visit_any(t &AnyType) MypyTypeNode {
	return MypyTypeNode(*t)
}

// visit_none_type обрабатывает None
pub fn (mut ta TypeAnalyser) visit_none_type(t &NoneType) MypyTypeNode {
	return MypyTypeNode(*t)
}

// visit_uninhabited_type обрабатывает Never
pub fn (mut ta TypeAnalyser) visit_uninhabited_type(t &UninhabitedType) MypyTypeNode {
	return MypyTypeNode(*t)
}

// visit_instance обрабатывает Instance
pub fn (mut ta TypeAnalyser) visit_instance(t &Instance) MypyTypeNode {
	return MypyTypeNode(Instance{
		typ:              t.typ
		args:             ta.anal_array(t.args)
		last_known_value: t.last_known_value
	})
}

// visit_type_var обрабатывает TypeVar
pub fn (mut ta TypeAnalyser) visit_type_var(t &TypeVarType) MypyTypeNode {
	return MypyTypeNode(*t)
}

// visit_tuple_type обрабатывает Tuple
pub fn (mut ta TypeAnalyser) visit_tuple_type(t &TupleType) MypyTypeNode {
	return MypyTypeNode(TupleType{
		items:            ta.anal_array(t.items)
		partial_fallback: t.partial_fallback
	})
}

// visit_union_type обрабатывает Union
pub fn (mut ta TypeAnalyser) visit_union_type(t &UnionType) MypyTypeNode {
	return make_union(ta.anal_array(t.items))
}

// visit_callable_type обрабатывает Callable
pub fn (mut ta TypeAnalyser) visit_callable_type(t &CallableType) MypyTypeNode {
	mut new_arg_types := []MypyTypeNode{}
	for arg in t.arg_types {
		new_arg_types << ta.anal_type(arg, true)
	}
	return MypyTypeNode(CallableType{
		base:      t.base
		arg_types: new_arg_types
		arg_kinds: t.arg_kinds
		arg_names: t.arg_names
		ret_type:  ta.anal_type(t.ret_type, true)
		name:      t.name
	})
}

// analyze_callable_type обрабатывает тип Callable
pub fn (mut ta TypeAnalyser) analyze_callable_type(t &UnboundType) MypyTypeNode {
	if t.args.len != 2 {
		return MypyTypeNode(AnyType{
			type_of_any: .special_form
		})
	}

	mut arg_types := []MypyTypeNode{}
	mut arg_kinds := []ArgKind{}
	mut arg_names := []?string{}

	args_spec := t.args[0]
	if args_spec is TypeList {
		for arg in args_spec.items {
			arg_types << ta.anal_type(arg, true)
			arg_kinds << .arg_pos
			arg_names << none
		}
	} else if args_spec is EllipsisType {
		// Represented by empty arg_types + is_type_obj = false in Mypy?
		// Actually Mypy uses a special flag.
	}

	ret_type := ta.anal_type(t.args[1], true)

	return MypyTypeNode(CallableType{
		arg_types: arg_types
		arg_kinds: arg_kinds
		arg_names: arg_names
		ret_type:  ret_type
	})
}

// analyze_literal_type обрабатывает Literal
pub fn (mut ta TypeAnalyser) analyze_literal_type(t &UnboundType) MypyTypeNode {
	return MypyTypeNode(AnyType{
		type_of_any: .special_form
	})
}

// anal_type анализирует тип
pub fn (mut ta TypeAnalyser) anal_type(t MypyTypeNode, nested bool) MypyTypeNode {
	if nested {
		ta.nesting_level++
	}
	analyzed := t.accept_translator(mut ta)
	if nested {
		ta.nesting_level--
	}
	return analyzed
}

// anal_array анализирует массив типов
pub fn (mut ta TypeAnalyser) anal_array(a []MypyTypeNode) []MypyTypeNode {
	mut res := []MypyTypeNode{}
	for t in a {
		res << ta.anal_type(t, true)
	}
	return res
}

// lookup_qualified ищет квалифицированное имя
fn (ta TypeAnalyser) lookup_qualified(name string, ctx Context) ?&SymbolTableNode {
	return ta.api.lookup_qualified(name, ctx, false)
}

// cannot_resolve_type сообщает о невозможности разрешить тип
fn (mut ta TypeAnalyser) cannot_resolve_type(t &UnboundType) {
	ta.fail('Cannot resolve name "${t.name}" (possible cyclic definition)', t.base.ctx)
}

// fail сообщает об ошибке
fn (mut ta TypeAnalyser) fail(msg string, ctx Context) {
	if ta.fail_func != unsafe { nil } {
		ta.fail_func(msg, ctx, .valid_type)
	} else {
		ta.api.fail(msg, ctx, false, false, none)
	}
}

// Вспомогательные функции
fn make_optional_type(t MypyTypeNode) MypyTypeNode {
	return make_union([t, MypyTypeNode(NoneType{})])
}

fn make_union(items []MypyTypeNode) MypyTypeNode {
	if items.len == 1 {
		return items[0]
	}
	return MypyTypeNode(UnionType{
		items: items
	})
}

// --- Stub implementations for TypeTranslator interface ---
pub fn (mut ta TypeAnalyser) visit_erased_type(t &ErasedType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_deleted_type(t &DeletedType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_param_spec(t &ParamSpecType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_parameters(t &ParametersType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_type_var_tuple(t &TypeVarTupleType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_partial_type(t &PartialTypeT) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_type_type(t &TypeType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_type_alias_type(t &TypeAliasType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_unpack_type(t &UnpackType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_placeholder_type(t &PlaceholderType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_literal_type(t &LiteralType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_overloaded(t &Overloaded) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_typeddict_type(t &TypedDictType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_callable_argument(t &CallableArgument) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_ellipsis_type(t &EllipsisType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_raw_expression_type(t &RawExpressionType) MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut ta TypeAnalyser) visit_type_list(t &TypeList) MypyTypeNode {
	return MypyTypeNode(*t)
}
