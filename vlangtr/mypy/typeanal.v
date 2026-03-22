// Я Cline работаю над этим файлом. Начало: 2026-03-22 15:12
// typeanal.v — Semantic analysis of types
// Переведён из mypy/typeanal.py

module mypy

// analyze_type_alias анализирует правую часть определения типа алиаса
// Возвращает тип и множество имён алиасов, от которых он зависит
pub fn analyze_type_alias(typ MypyTypeNode, api SemanticAnalyzerCoreInterface, tvar_scope TypeVarLikeScope, plugin Plugin, options Options, cur_mod_node MypyFile, is_typeshed_stub bool, allow_placeholder bool, in_dynamic_func bool, global_scope bool, allowed_alias_tvars []TypeVarLikeType, alias_type_params_names []string, python_3_12_type_alias bool) (MypyTypeNode, map[string]bool) {
	analyzer := TypeAnalyser{
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
	fail_func                          fn (string, NodeBase, ErrorCode)
	note_func                          fn (string, NodeBase, ErrorCode)
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
pub fn (mut ta TypeAnalyser) visit_unbound_type(t UnboundTypeNode) MypyTypeNode {
	typ := ta.visit_unbound_type_nonoptional(t, false)
	if t.optional {
		return make_optional_type(typ)
	}
	return typ
}

// visit_unbound_type_nonoptional обрабатывает непривязанный тип (не optional)
pub fn (mut ta TypeAnalyser) visit_unbound_type_nonoptional(t UnboundTypeNode, defining_literal bool) MypyTypeNode {
	sym := ta.lookup_qualified(t.name, t)

	if sym != none {
		node := sym.node
		if node is PlaceholderNode {
			if node.becomes_typeinfo {
				if ta.api.final_iteration {
					ta.cannot_resolve_type(t)
					return AnyTypeNode{
						reason: TypeOfAny.from_error
					}
				} else if ta.allow_placeholder {
					ta.api.defer()
				} else {
					ta.api.record_incomplete_ref()
				}
				return PlaceholderTypeNode{
					fullname: node.fullname
					args:     ta.anal_array(t.args, true, true, true)
					line:     t.line
				}
			} else {
				if ta.api.final_iteration {
					ta.cannot_resolve_type(t)
					return AnyTypeNode{
						reason: TypeOfAny.from_error
					}
				} else {
					ta.api.record_incomplete_ref()
					return AnyTypeNode{
						reason: TypeOfAny.special_form
					}
				}
			}
		}

		if node == none {
			ta.fail('Internal error (node is None)', t)
			return AnyTypeNode{
				reason: TypeOfAny.special_form
			}
		}

		fullname := node.fullname
		hook := ta.plugin.get_type_analyze_hook(fullname)
		if hook != none {
			// TODO: вызов hook
		}

		tvar_def := ta.tvar_scope.get_binding(sym)
		if tvar_def != none {
			// TODO: проверка placeholder
		}

		if node is ParamSpecExprNode {
			// TODO: обработка ParamSpec
			return AnyTypeNode{
				reason: TypeOfAny.from_error
			}
		}

		if node is TypeVarExprNode {
			// TODO: обработка TypeVar
			return AnyTypeNode{
				reason: TypeOfAny.from_error
			}
		}

		if node is TypeVarTupleExprNode {
			// TODO: обработка TypeVarTuple
			return AnyTypeNode{
				reason: TypeOfAny.from_error
			}
		}

		special := ta.try_analyze_special_unbound_type(t, fullname)
		if special != none {
			return special
		}

		if node is TypeAliasNode {
			ta.aliases_used[fullname] = true
			// TODO: полная обработка алиасов
			return AnyTypeNode{
				reason: TypeOfAny.special_form
			}
		}

		if node is TypeInfoNode {
			return ta.analyze_type_with_type_info(node, t.args, t, t.empty_tuple_index)
		}

		return ta.analyze_unbound_type_without_type_info(t, sym, defining_literal)
	} else {
		return AnyTypeNode{
			reason: TypeOfAny.special_form
		}
	}
}

// try_analyze_special_unbound_type пытается обработать специальные типы
pub fn (ta TypeAnalyser) try_analyze_special_unbound_type(t UnboundTypeNode, fullname string) ?MypyTypeNode {
	if fullname == 'builtins.None' {
		return NoneTypeNode{}
	} else if fullname == 'typing.Any' {
		return AnyTypeNode{
			reason: TypeOfAny.explicit
			line:   t.line
		}
	} else if fullname in final_type_names {
		return AnyTypeNode{
			reason: TypeOfAny.from_error
		}
	} else if fullname in tuple_names {
		// TODO: обработка Tuple
		return AnyTypeNode{
			reason: TypeOfAny.special_form
		}
	} else if fullname == 'typing.Union' {
		items := ta.anal_array(t.args)
		return make_union(items)
	} else if fullname == 'typing.Optional' {
		if t.args.len != 1 {
			ta.fail('Optional[...] must have exactly one type argument', t)
			return AnyTypeNode{
				reason: TypeOfAny.from_error
			}
		}
		item := ta.anal_type(t.args[0])
		return make_optional_type(item)
	} else if fullname == 'typing.Callable' {
		return ta.analyze_callable_type(t)
	} else if fullname in type_names {
		// TODO: обработка Type[...]
		return AnyTypeNode{
			reason: TypeOfAny.special_form
		}
	} else if fullname in never_names {
		return UninhabitedTypeNode{}
	} else if fullname in literal_type_names {
		return ta.analyze_literal_type(t)
	} else if fullname in annotated_type_names {
		if t.args.len < 2 {
			ta.fail('Annotated[...] must have at least two arguments', t)
			return AnyTypeNode{
				reason: TypeOfAny.from_error
			}
		}
		return ta.anal_type(t.args[0])
	} else if fullname in self_type_names {
		// TODO: обработка Self
		return AnyTypeNode{
			reason: TypeOfAny.from_error
		}
	}
	return none
}

// analyze_type_with_type_info обрабатывает тип с TypeInfo
pub fn (ta TypeAnalyser) analyze_type_with_type_info(info TypeInfoNode, args []MypyTypeNode, ctx NodeBase, empty_tuple_index bool) MypyTypeNode {
	// TODO: полная реализация
	if args.len > 0 && info.fullname == 'builtins.tuple' {
		fallback := InstanceNode{
			typ:  info
			args: [AnyTypeNode{
				reason: TypeOfAny.special_form
			}]
			line: ctx.line
		}
		return TupleTypeNode{
			items:            ta.anal_array(args)
			partial_fallback: fallback
			line:             ctx.line
		}
	}

	instance := InstanceNode{
		typ:  info
		args: ta.anal_array(args)
		line: ctx.line
	}

	// TODO: проверка количества аргументов типов

	return instance
}

// analyze_unbound_type_without_type_info обрабатывает непривязанный тип без TypeInfo
pub fn (ta TypeAnalyser) analyze_unbound_type_without_type_info(t UnboundTypeNode, sym SymbolTableNode, defining_literal bool) MypyTypeNode {
	name := sym.fullname or { sym.node.name }
	ta.fail('Cannot interpret reference "${name}" as a type', t)
	return t
}

// visit_any обрабатывает Any
pub fn (ta TypeAnalyser) visit_any(t AnyTypeNode) MypyTypeNode {
	return t
}

// visit_none_type обрабатывает None
pub fn (ta TypeAnalyser) visit_none_type(t NoneTypeNode) MypyTypeNode {
	return t
}

// visit_uninhabited_type обрабатывает Never
pub fn (ta TypeAnalyser) visit_uninhabited_type(t UninhabitedTypeNode) MypyTypeNode {
	return t
}

// visit_instance обрабатывает Instance
pub fn (ta TypeAnalyser) visit_instance(t InstanceNode) MypyTypeNode {
	return t
}

// visit_type_var обрабатывает TypeVar
pub fn (ta TypeAnalyser) visit_type_var(t TypeVarTypeNode) MypyTypeNode {
	return t
}

// visit_tuple_type обрабатывает Tuple
pub fn (ta TypeAnalyser) visit_tuple_type(t TupleTypeNode) MypyTypeNode {
	if t.implicit && !ta.allow_tuple_literal {
		ta.fail('Syntax error in type annotation', t)
		return AnyTypeNode{
			reason: TypeOfAny.from_error
		}
	}
	return TupleTypeNode{
		items:            ta.anal_array(t.items)
		partial_fallback: t.partial_fallback
		line:             t.line
	}
}

// visit_union_type обрабатывает Union
pub fn (ta TypeAnalyser) visit_union_type(t UnionTypeNode) MypyTypeNode {
	return make_union(ta.anal_array(t.items))
}

// visit_callable_type обрабатывает Callable
pub fn (mut ta TypeAnalyser) visit_callable_type(t CallableTypeNode) MypyTypeNode {
	// TODO: полная реализация
	return t
}

// analyze_callable_type обрабатывает тип Callable
pub fn (mut ta TypeAnalyser) analyze_callable_type(t UnboundTypeNode) MypyTypeNode {
	fallback := ta.named_type('builtins.function')
	if t.args.len == 0 {
		any_type := AnyTypeNode{
			reason: TypeOfAny.from_omitted_generics
		}
		return callable_with_ellipsis(any_type, any_type, fallback)
	}
	// TODO: полная реализация
	return AnyTypeNode{
		reason: TypeOfAny.from_error
	}
}

// analyze_literal_type обрабатывает Literal
pub fn (ta TypeAnalyser) analyze_literal_type(t UnboundTypeNode) MypyTypeNode {
	if t.args.len == 0 {
		ta.fail('Literal[...] must have at least one parameter', t)
		return AnyTypeNode{
			reason: TypeOfAny.from_error
		}
	}
	// TODO: полная реализация
	return AnyTypeNode{
		reason: TypeOfAny.from_error
	}
}

// anal_type анализирует тип
pub fn (mut ta TypeAnalyser) anal_type(t MypyTypeNode, nested bool) MypyTypeNode {
	if nested {
		ta.nesting_level++
	}
	analyzed := t.accept(ta)
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
fn (ta TypeAnalyser) lookup_qualified(name string, ctx NodeBase) ?SymbolTableNode {
	return ta.api.lookup_qualified(name, ctx)
}

// cannot_resolve_type сообщает о невозможности разрешить тип
fn (ta TypeAnalyser) cannot_resolve_type(t UnboundTypeNode) {
	ta.api.fail('Cannot resolve name "${t.name}" (possible cyclic definition)', t)
	if ta.api.is_func_scope() {
		ta.note('Recursive types are not allowed at function scope', t)
	}
}

// named_type создаёт Instance по имени типа
fn (ta TypeAnalyser) named_type(fullname string) InstanceNode {
	node := ta.api.lookup_fully_qualified(fullname)
	return InstanceNode{
		typ:  node.node as TypeInfoNode
		args: []
	}
}

// fail сообщает об ошибке
fn (ta TypeAnalyser) fail(msg string, ctx NodeBase) {
	ta.fail_func(msg, ctx, errorcodes.valid_type)
}

// note сообщает примечание
fn (ta TypeAnalyser) note(msg string, ctx NodeBase) {
	ta.note_func(msg, ctx, errorcodes.valid_type)
}

// Константы
pub const final_type_names = ['typing.Final', 'typing_extensions.Final']
pub const tuple_names = ['builtins.tuple', 'typing.Tuple']
pub const type_names = ['builtins.type', 'typing.Type']
pub const never_names = ['typing.NoReturn', 'typing_extensions.NoReturn']
pub const literal_type_names = ['typing.Literal', 'typing_extensions.Literal']
pub const annotated_type_names = ['typing.Annotated', 'typing_extensions.Annotated']
pub const self_type_names = ['typing.Self', 'typing_extensions.Self']
pub const concat_type_names = ['typing.Concatenate', 'typing_extensions.Concatenate']

// Вспомогательные функции
fn make_optional_type(t MypyTypeNode) MypyTypeNode {
	if t is NoneTypeNode {
		return t
	}
	return make_union([t, NoneTypeNode{}])
}

fn make_union(items []MypyTypeNode) MypyTypeNode {
	if items.len == 1 {
		return items[0]
	}
	return UnionTypeNode{
		items: items
	}
}

fn callable_with_ellipsis(arg_type MypyTypeNode, ret_type MypyTypeNode, fallback InstanceNode) CallableTypeNode {
	return CallableTypeNode{
		arg_types:        [arg_type]
		arg_kinds:        [ArgKind.star, ArgKind.star2]
		arg_names:        ['', '']
		ret_type:         ret_type
		fallback:         fallback
		is_ellipsis_args: true
	}
}
