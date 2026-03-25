// I, Antigravity, am working on this file. Started: 2026-03-22 03:26
module mypy

// ============================================================================
// Semantic Analysis Shared Definitions
// ============================================================================

pub const allow_incompatible_override = ['__slots__', '__deletable__', '__match_args__']

// Priorities for ordering of patches within the "patch" phase of semantic analysis
pub const priority_fallbacks = 1

pub interface SemanticAnalyzerCoreInterface {
	lookup_qualified(name string, ctx Context, suppress_errors bool) ?&SymbolTableNode
	lookup_fully_qualified(fullname string) &SymbolTableNode
	lookup_fully_qualified_or_none(fullname string) ?&SymbolTableNode
	fail(msg string, ctx Context, serious bool, blocker bool, code ?&ErrorCode)
	note(msg string, ctx Context, code ?&ErrorCode)
	incomplete_feature_enabled(feature string, ctx Context) bool
	record_incomplete_ref()
	defer(debug_context ?Context, force_progress bool)
	is_incomplete_namespace(fullname string) bool
	final_iteration() bool
	is_future_flag_set(flag string) bool
	is_stub_file() bool
	is_func_scope() bool
	get_current_type() ?&TypeInfo
}

pub interface SemanticAnalyzerInterface {
	// Inherit (manually) CoreInterface methods
	lookup_qualified(name string, ctx Context, suppress_errors bool) ?&SymbolTableNode
	lookup_fully_qualified(fullname string) &SymbolTableNode
	lookup_fully_qualified_or_none(fullname string) ?&SymbolTableNode
	fail(msg string, ctx Context, serious bool, blocker bool, code ?&ErrorCode)
	note(msg string, ctx Context, code ?&ErrorCode)
	incomplete_feature_enabled(feature string, ctx Context) bool
	record_incomplete_ref()
	defer(debug_context ?Context, force_progress bool)
	is_incomplete_namespace(fullname string) bool
	final_iteration() bool
	is_future_flag_set(flag string) bool
	is_stub_file() bool
	is_func_scope() bool
	get_current_type() ?&TypeInfo

	// Pass 2/3 spezifisch
	get_tvar_scope() &TypeVarLikeScope
	lookup(name string, ctx Context, suppress_errors bool) ?&SymbolTableNode
	named_type(fullname string, args []MypyTypeNode) &Instance
	named_type_or_none(fullname string, args []MypyTypeNode) ?&Instance
	accept(mut node Node) // Use Node interface from nodes.v
	anal_type(typ MypyTypeNode, tvar_scope ?&TypeVarLikeScope, allow_tuple_literal bool, allow_unbound_tvars bool, allow_typed_dict_special_forms bool, allow_placeholder bool, report_invalid_types bool, prohibit_self_type ?string, prohibit_special_class_field_types ?string) ?MypyTypeNode
	get_and_bind_all_tvars(type_exprs []Expression) []MypyTypeNode
	basic_new_typeinfo(name string, basetype_or_fallback &Instance, line int) &TypeInfo
	schedule_patch(priority int, patch fn ())
	add_symbol_table_node(name string, symbol &SymbolTableNode) bool
	current_symbol_table() map[string]&SymbolTableNode
	add_symbol(name string, node SymbolNodeRef, context Context, module_public bool, module_hidden bool, can_defer bool) bool
	add_symbol_skip_local(name string, node SymbolNodeRef)
	parse_bool(expr Expression) ?bool
	qualified_name(name string) string
	is_typeshed_stub_file() bool
	process_placeholder(name ?string, kind string, ctx Context, force_progress bool)

	// Plugin access
	get_plugin() &Plugin
}

pub fn set_callable_name(sig MypyTypeNode, fdef &FuncDef) MypyTypeNode {
	mut p_sig := sig
	if p_sig is CallableType {
		mut class_name := ''
		if info := fdef.info {
			class_name = info.name
			_ = class_name
			// return p_sig.with_name('${fdef.name} of ${class_name}')
			return p_sig
		} else {
			// return p_sig.with_name(fdef.name)
			return p_sig
		}
	}
	return sig
}

pub fn calculate_tuple_fallback(mut typ TupleType) {
	mut fallback := typ.partial_fallback or { return }
	if info := fallback.typ {
		assert info.fullname == 'builtins.tuple'
	}
	mut items := []MypyTypeNode{}
	flat_items := flatten_nested_tuples(typ.items)
	for item in flat_items {
		if item is UnpackType {
			mut unpacked_type_node := get_proper_type(item.@type)
			unpacked_type := get_proper_type(MypyTypeNode(unpacked_type_node))
			if unpacked_type is TypeVarTupleType {
				//
			}
			if unpacked_type is Instance {
				if inst_info := unpacked_type.typ {
					if inst_info.fullname == 'builtins.tuple' {
						items << unpacked_type.args[0]
					}
				}
			}
		} else {
			items << item
		}
	}
	fallback.args = [make_simplified_union(items, false)]
}

fn flatten_nested_tuples(items []MypyTypeNode) []MypyTypeNode {
	mut res := []MypyTypeNode{}
	for item in items {
		if item is TupleType {
			res << flatten_nested_tuples((item as TupleType).items)
		} else {
			res << item
		}
	}
	return res
}

pub fn has_placeholder(typ MypyTypeNode) bool {
	mut query := HasPlaceholders{}
	return query.query_type(typ)
}

pub struct HasPlaceholders {
	BoolTypeQuery
}

pub fn (mut q HasPlaceholders) visit_placeholder_type(t &PlaceholderType) bool {
	return true
}

pub fn find_dataclass_transform_spec(node ?Node) ?&DataclassTransformSpec {
	mut n := node or { return none }

	match mut n {
		CallExpr { n = n.callee }
		else {}
	}

	match mut n {
		RefExpr {
			// match n { NameExpr { ... } MemberExpr { ... } }
		}
		else {}
	}

	match mut n {
		Decorator { n = n.func }
		else {}
	}

	match mut n {
		OverloadedFuncDef {
			for candidate in n.items {
				if spec := find_dataclass_transform_spec(candidate) {
					return spec
				}
			}
		}
		FuncDef {
			return n.dataclass_transform_spec
		}
		ClassDef {
			if info := n.info {
				return find_dataclass_transform_spec_from_info(info)
			}
		}
		TypeInfo {
			return find_dataclass_transform_spec_from_info(n)
		}
		else {}
	}

	return none
}

fn find_dataclass_transform_spec_from_info(info &TypeInfo) ?&DataclassTransformSpec {
	for base in info.mro[1..] {
		if spec := base.dataclass_transform_spec {
			return spec
		}
	}
	if mtype := info.metaclass_type {
		if ti := mtype.typ {
			if spec := ti.dataclass_transform_spec {
				return spec
			}
		}
	}
	return none
}

pub fn require_bool_literal_argument(api SemanticAnalyzerInterface, expr Expression, name string, default ?bool) ?bool {
	val := api.parse_bool(expr)
	if val == none {
		api.fail('"${name}" argument must be a True or False literal', expr.get_context(), false, false,
			literal_req)
		return default
	}
	return val
}

pub fn parse_bool_helper(expr Expression) ?bool {
	if expr is NameExpr {
		if expr.fullname == 'builtins.True' {
			return true
		}
		if expr.fullname == 'builtins.False' {
			return false
		}
	}
	return none
}
