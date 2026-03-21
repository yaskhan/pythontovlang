// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 03:40
module mypy

// TypeTraverserVisitor — базовый класс для обхода всех компонентов типа.
// В V мы реализуем его как структуру, методы которой можно переопределять
// через встраивание (embedding), либо использовать как есть.

pub struct TypeTraverserVisitor {}

pub fn (mut v TypeTraverserVisitor) visit_unbound_type(t &UnboundType) !string {
	v.traverse_type_list(t.args)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_any(t &AnyType) !string {
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_none_type(t &NoneType) !string {
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_uninhabited_type(t &UninhabitedType) !string {
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_erased_type(t &ErasedType) !string {
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_deleted_type(t &DeletedType) !string {
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_type_var(t &TypeVarType) !string {
	// Мы не обходим значения и верхнюю границу, так как они привязаны к определению TVar
	// Но можем обойти значение по умолчанию, если оно есть.
	t.default_.accept_synthetic(v)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_param_spec(t &ParamSpecType) !string {
	t.default_.accept_synthetic(v)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_parameters(t &ParametersType) !string {
	v.traverse_type_list(t.arg_types)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_type_var_tuple(t &TypeVarTupleType) !string {
	t.default_.accept_synthetic(v)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_instance(t &Instance) !string {
	v.traverse_type_list(t.args)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_callable_type(t &CallableType) !string {
	v.traverse_type_list(t.arg_types)!
	t.ret_type.accept_synthetic(v)!
	// Fallback обычно не обходится, чтобы избежать циклов,
	// но если нужно — можно добавить.
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_overloaded(t &Overloaded) !string {
	for item in t.items {
		item.accept_synthetic(v)!
	}
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_tuple_type(t &TupleType) !string {
	v.traverse_type_list(t.items)!
	t.partial_fallback.accept_synthetic(v)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_typeddict_type(t &TypedDictType) !string {
	for _, val in t.items {
		val.accept_synthetic(v)!
	}
	t.fallback.accept_synthetic(v)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_union_type(t &UnionType) !string {
	v.traverse_type_list(t.items)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_partial_type(t &PartialTypeT) !string {
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_type_type(t &TypeType) !string {
	t.item.accept_synthetic(v)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_type_alias_type(t &TypeAliasType) !string {
	v.traverse_type_list(t.args)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_unpack_type(t &UnpackType) !string {
	t.type_.accept_synthetic(v)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_literal_type(t &LiteralType) !string {
	t.fallback.accept_synthetic(v)!
	return ''
}

// Synthetic extras

pub fn (mut v TypeTraverserVisitor) visit_type_list(t &TypeList) !string {
	v.traverse_type_list(t.items)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_callable_argument(t &CallableArgument) !string {
	t.typ.accept_synthetic(v)!
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_ellipsis_type(t &EllipsisType) !string {
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_raw_expression_type(t &RawExpressionType) !string {
	return ''
}

pub fn (mut v TypeTraverserVisitor) visit_placeholder_type(t &PlaceholderType) !string {
	v.traverse_type_list(t.args)!
	return ''
}

// Helpers

pub fn (mut v TypeTraverserVisitor) traverse_type_list(types []MypyTypeNode) ! {
	for t in types {
		t.accept_synthetic(v)!
	}
}
