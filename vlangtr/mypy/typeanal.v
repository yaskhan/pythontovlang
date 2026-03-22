// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 12:15
module mypy

// typeanal.v — Семантический анализатор для типов.
// Преобразует неразрешённые (Unbound) типы в семантически корректные MypyTypeNode.

pub struct TypeAnalyser {
pub mut:
	options           &Options
	errors            &Errors
	is_typeshed_file  bool
	
	// Состояние обхода
	allow_any         bool
	allow_tuple_literal bool
	allow_unbound_tvars bool
	
	// Контекст для lookup (интерфейс из semanal_shared.v)
	api               &SemanticAnalyzerInterface = unsafe { nil }
}

pub fn (mut t TypeAnalyser) accept(typ MypyTypeNode) MypyTypeNode {
	return typ.accept_translator(mut t)
}

// --- Реализация TypeTranslator ---

pub fn (mut t TypeAnalyser) visit_unbound_type(typ &UnboundType) MypyTypeNode {
	// 1. Поиск символа через API семантического анализатора
	if t.api == unsafe { nil } {
		return MypyTypeNode(*typ)
	}
	
	sym := t.api.lookup(typ.name, Context(NodeBase{ctx: typ.ctx}), false) or {
		// t.errors.report(typ.ctx.line, typ.ctx.column, "Name '${typ.name}' is not defined", .error, none)
		return MypyTypeNode(AnyType{type_of_any: .from_error})
	}
	
	node := sym.node or {
		return MypyTypeNode(AnyType{type_of_any: .from_error})
	}
	
	if node is TypeInfo {
		// Собираем аргументы
		mut args := []MypyTypeNode{}
		for arg in typ.args {
			args << t.accept(arg)
		}
		return MypyTypeNode(Instance{
			typ: node
			args: args
		})
	}
	
	if node is TypeAlias {
		return MypyTypeNode(TypeAliasType{
			alias_name: typ.name
			// target_type: node.target
		})
	}

	return MypyTypeNode(AnyType{type_of_any: .from_error})
}

pub fn (mut t TypeAnalyser) visit_any(typ &AnyType) MypyTypeNode {
	return MypyTypeNode(*typ)
}

pub fn (mut t TypeAnalyser) visit_none_type(typ &NoneType) MypyTypeNode {
	return MypyTypeNode(*typ)
}

pub fn (mut t TypeAnalyser) visit_instance(typ &Instance) MypyTypeNode {
	mut new_args := []MypyTypeNode{}
	for arg in typ.args {
		new_args << t.accept(arg)
	}
	return MypyTypeNode(Instance{
		typ: typ.typ
		args: new_args
		last_known_value: typ.last_known_value
	})
}

pub fn (mut t TypeAnalyser) visit_callable_type(typ &CallableType) MypyTypeNode {
	mut new_arg_types := []?MypyTypeNode{}
	for arg in typ.arg_types {
		if a := arg {
			new_arg_types << t.accept(a)
		} else {
			new_arg_types << none
		}
	}
	return MypyTypeNode(CallableType{
		base: typ.base
		arg_types: new_arg_types
		arg_kinds: typ.arg_kinds
		arg_names: typ.arg_names
		ret_type: t.accept(typ.ret_type)
	})
}

pub fn (mut t TypeAnalyser) visit_tuple_type(typ &TupleType) MypyTypeNode {
	mut new_items := []MypyTypeNode{}
	for item in typ.items {
		new_items << t.accept(item)
	}
	return MypyTypeNode(TupleType{
		base: typ.base
		items: new_items
		partial_fallback: typ.partial_fallback // Instance
	})
}

pub fn (mut t TypeAnalyser) visit_union_type(typ &UnionType) MypyTypeNode {
	mut new_items := []MypyTypeNode{}
	for item in typ.items {
		new_items << t.accept(item)
	}
	return MypyTypeNode(UnionType{
		base: typ.base
		items: new_items
	})
}

// --- Заглушки для остальных типов ---

pub fn (mut t TypeAnalyser) visit_uninhabited_type(typ &UninhabitedType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_erased_type(typ &ErasedType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_deleted_type(typ &DeletedType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_type_var(typ &TypeVarType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_param_spec(typ &ParamSpecType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_parameters(typ &ParametersType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_type_var_tuple(typ &TypeVarTupleType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_typeddict_type(typ &TypedDictType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_literal_type(typ &LiteralType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_partial_type(typ &PartialTypeT) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_type_type(typ &TypeType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_type_alias_type(typ &TypeAliasType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_unpack_type(typ &UnpackType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_type_list(typ &TypeList) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_callable_argument(typ &CallableArgument) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_ellipsis_type(typ &EllipsisType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_raw_expression_type(typ &RawExpressionType) MypyTypeNode { return MypyTypeNode(*typ) }
pub fn (mut t TypeAnalyser) visit_placeholder_type(typ &PlaceholderType) MypyTypeNode { return MypyTypeNode(*typ) }
