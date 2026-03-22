// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 03:05
// types.v — Base classes and utilities for Mypy types
// Переведён из mypy/types.py
//
// ---------------------------------------------------------------------------

module mypy

// ---------------------------------------------------------------------------
// Enumerations for Types
// ---------------------------------------------------------------------------

pub enum TypeOfAny {
    unannotated
    explicit
    from_error
    from_omitted_generics
    from_another_any
    special_form
    implementation_artifact
}

pub type TypeVarId = int
pub type TypeVarLikeType = TypeVarType | ParamSpecType | TypeVarTupleType

pub fn (t TypeVarLikeType) get_id() TypeVarId {
	return match t {
		TypeVarType { t.id }
		ParamSpecType { t.id }
		TypeVarTupleType { t.id }
	}
}

// ---------------------------------------------------------------------------
// TypeVisitor — интерфейс для посещения узлов типов.
// ---------------------------------------------------------------------------

pub interface TypeVisitor {
mut:
    visit_unbound_type(t &UnboundType) !string
    visit_any(t &AnyType) !string
    visit_none_type(t &NoneType) !string
    visit_uninhabited_type(t &UninhabitedType) !string
    visit_erased_type(t &ErasedType) !string
    visit_deleted_type(t &DeletedType) !string
    visit_type_var(t &TypeVarType) !string
    visit_param_spec(t &ParamSpecType) !string
    visit_parameters(t &ParametersType) !string
    visit_type_var_tuple(t &TypeVarTupleType) !string
    visit_instance(t &Instance) !string
    visit_callable_type(t &CallableType) !string
    visit_overloaded(t &Overloaded) !string
    visit_tuple_type(t &TupleType) !string
    visit_typeddict_type(t &TypedDictType) !string
    visit_literal_type(t &LiteralType) !string
    visit_union_type(t &UnionType) !string
    visit_partial_type(t &PartialTypeT) !string
    visit_type_type(t &TypeType) !string
    visit_type_alias_type(t &TypeAliasType) !string
    visit_unpack_type(t &UnpackType) !string
    
    // Complex extras
    visit_type_list(t &TypeList) !string
    visit_callable_argument(t &CallableArgument) !string
    visit_ellipsis_type(t &EllipsisType) !string
    visit_raw_expression_type(t &RawExpressionType) !string
    visit_placeholder_type(t &PlaceholderType) !string
}

// ITypeTranslator is an interface for visitors that transform types
pub interface ITypeTranslator {
mut:
    visit_unbound_type(t &UnboundType) !MypyTypeNode
    visit_any(t &AnyType) !MypyTypeNode
    visit_none_type(t &NoneType) !MypyTypeNode
    visit_uninhabited_type(t &UninhabitedType) !MypyTypeNode
    visit_erased_type(t &ErasedType) !MypyTypeNode
    visit_deleted_type(t &DeletedType) !MypyTypeNode
    visit_type_var(t &TypeVarType) !MypyTypeNode
    visit_param_spec(t &ParamSpecType) !MypyTypeNode
    visit_parameters(t &ParametersType) !MypyTypeNode
    visit_type_var_tuple(t &TypeVarTupleType) !MypyTypeNode
    visit_instance(t &Instance) !MypyTypeNode
    visit_callable_type(t &CallableType) !MypyTypeNode
    visit_overloaded(t &Overloaded) !MypyTypeNode
    visit_tuple_type(t &TupleType) !MypyTypeNode
    visit_typeddict_type(t &TypedDictType) !MypyTypeNode
    visit_literal_type(t &LiteralType) !MypyTypeNode
    visit_union_type(t &UnionType) !MypyTypeNode
    visit_partial_type(t &PartialTypeT) !MypyTypeNode
    visit_type_type(t &TypeType) !MypyTypeNode
    visit_type_alias_type(t &TypeAliasType) !MypyTypeNode
    visit_unpack_type(t &UnpackType) !MypyTypeNode
    
    visit_type_list(t &TypeList) !MypyTypeNode
    visit_callable_argument(t &CallableArgument) !MypyTypeNode
    visit_ellipsis_type(t &EllipsisType) !MypyTypeNode
    visit_raw_expression_type(t &RawExpressionType) !MypyTypeNode
    visit_placeholder_type(t &PlaceholderType) !MypyTypeNode
}

// ---------------------------------------------------------------------------
// MypyTypeSum — the concrete sum-type covering all type variants.
// ---------------------------------------------------------------------------

pub type MypyTypeSum = AnyType
    | CallableArgument
    | CallableType
    | DeletedType
    | EllipsisType
    | ErasedType
    | Instance
    | LiteralType
    | NoneType
    | Overloaded
    | ParamSpecType
    | ParametersType
    | PartialTypeT
    | PlaceholderType
    | RawExpressionType
    | TupleType
    | TypeAliasType
    | TypeList
    | TypeType
    | TypeVarTupleType
    | TypeVarType
    | UnboundType
    | UninhabitedType
    | UnionType
    | UnpackType

// We implement the MypyTypeNode interface for the sum-type itself
pub fn (t MypyTypeSum) accept(mut v TypeVisitor) !string {
    return match t {
        AnyType { v.visit_any(&t)! }
        CallableArgument { v.visit_callable_argument(&t)! }
        CallableType { v.visit_callable_type(&t)! }
        DeletedType { v.visit_deleted_type(&t)! }
        EllipsisType { v.visit_ellipsis_type(&t)! }
        ErasedType { v.visit_erased_type(&t)! }
        Instance { v.visit_instance(&t)! }
        LiteralType { v.visit_literal_type(&t)! }
        NoneType { v.visit_none_type(&t)! }
        Overloaded { v.visit_overloaded(&t)! }
        ParamSpecType { v.visit_param_spec(&t)! }
        ParametersType { v.visit_parameters(&t)! }
        PartialTypeT { v.visit_partial_type(&t)! }
        PlaceholderType { v.visit_placeholder_type(&t)! }
        RawExpressionType { v.visit_raw_expression_type(&t)! }
        TupleType { v.visit_tuple_type(&t)! }
        TypeAliasType { v.visit_type_alias_type(&t)! }
        TypeList { v.visit_type_list(&t)! }
        TypeType { v.visit_type_type(&t)! }
        TypeVarTupleType { v.visit_type_var_tuple(&t)! }
        TypeVarType { v.visit_type_var(&t)! }
        UnboundType { v.visit_unbound_type(&t)! }
        UninhabitedType { v.visit_uninhabited_type(&t)! }
        UnionType { v.visit_union_type(&t)! }
        UnpackType { v.visit_unpack_type(&t)! }
    }
}

pub fn (t MypyTypeSum) accept_translator(mut v ITypeTranslator) !MypyTypeNode {
    return match t {
        AnyType { v.visit_any(&t)! }
        CallableArgument { v.visit_callable_argument(&t)! }
        CallableType { v.visit_callable_type(&t)! }
        DeletedType { v.visit_deleted_type(&t)! }
        EllipsisType { v.visit_ellipsis_type(&t)! }
        ErasedType { v.visit_erased_type(&t)! }
        Instance { v.visit_instance(&t)! }
        LiteralType { v.visit_literal_type(&t)! }
        NoneType { v.visit_none_type(&t)! }
        Overloaded { v.visit_overloaded(&t)! }
        ParamSpecType { v.visit_param_spec(&t)! }
        ParametersType { v.visit_parameters(&t)! }
        PartialTypeT { v.visit_partial_type(&t)! }
        PlaceholderType { v.visit_placeholder_type(&t)! }
        RawExpressionType { v.visit_raw_expression_type(&t)! }
        TupleType { v.visit_tuple_type(&t)! }
        TypeAliasType { v.visit_type_alias_type(&t)! }
        TypeList { v.visit_type_list(&t)! }
        TypeType { v.visit_type_type(&t)! }
        TypeVarTupleType { v.visit_type_var_tuple(&t)! }
        TypeVarType { v.visit_type_var(&t)! }
        UnboundType { v.visit_unbound_type(&t)! }
        UninhabitedType { v.visit_uninhabited_type(&t)! }
        UnionType { v.visit_union_type(&t)! }
        UnpackType { v.visit_unpack_type(&t)! }
    }
}

// ---------------------------------------------------------------------------
// Individual Type Classes
// Each of these MUST implement MypyTypeNode interface.
// ---------------------------------------------------------------------------

pub struct AnyType {
pub:
	type_of_any TypeOfAny
	source_any ?&AnyType = none
	line int = -1
	column int = -1
}
pub fn (t &AnyType) accept(mut v TypeVisitor) !string { return v.visit_any(t)! }

pub struct UnboundType {
pub:
	name string
	args []MypyTypeNode
	line int = -1
	column int = -1
}
pub fn (t &UnboundType) accept(mut v TypeVisitor) !string { return v.visit_unbound_type(t)! }

pub struct NoneType {
pub:
	line int = -1
	column int = -1
}
pub fn (t &NoneType) accept(mut v TypeVisitor) !string { return v.visit_none_type(t)! }

pub struct UninhabitedType {
pub:
	line int = -1
	column int = -1
}
pub fn (t &UninhabitedType) accept(mut v TypeVisitor) !string { return v.visit_uninhabited_type(t)! }

pub struct ErasedType {}
pub fn (t &ErasedType) accept(mut v TypeVisitor) !string { return v.visit_erased_type(t)! }

pub struct DeletedType {
pub:
	line int = -1
	column int = -1
}
pub fn (t &DeletedType) accept(mut v TypeVisitor) !string { return v.visit_deleted_type(t)! }

pub struct TypeVarType {
pub:
	name string
	id int
	values []MypyTypeNode
	upper_bound MypyTypeNode
	line int = -1
}
pub fn (t &TypeVarType) accept(mut v TypeVisitor) !string { return v.visit_type_var(t)! }

pub struct ParamSpecType {
pub:
    name string
    id int
    line int = -1
}
pub fn (t &ParamSpecType) accept(mut v TypeVisitor) !string { return v.visit_param_spec(t)! }

pub struct ParametersType {
pub:
    types []MypyTypeNode
    kinds []ArgKind
    names []?string
    line int = -1
}
pub fn (t &ParametersType) accept(mut v TypeVisitor) !string { return v.visit_parameters(t)! }

pub struct TypeVarTupleType {
pub:
    name string
    id int
    line int = -1
}
pub fn (t &TypeVarTupleType) accept(mut v TypeVisitor) !string { return v.visit_type_var_tuple(t)! }

pub struct Instance {
pub mut:
	type_ &TypeInfo
	args []MypyTypeNode
	line int = -1
	column int = -1
}
pub fn (t &Instance) accept(mut v TypeVisitor) !string { return v.visit_instance(t)! }

pub struct CallableType {
pub mut:
	arg_types []MypyTypeNode
	arg_kinds []ArgKind
	arg_names []?string
	ret_type MypyTypeNode
	fallback ?&Instance = none
	name ?string
	line int = -1
	column int = -1
}
pub fn (t &CallableType) accept(mut v TypeVisitor) !string { return v.visit_callable_type(t)! }

pub struct Overloaded {
pub:
	items []&CallableType
	line int = -1
}
pub fn (t &Overloaded) accept(mut v TypeVisitor) !string { return v.visit_overloaded(t)! }

pub struct TupleType {
pub:
	items []MypyTypeNode
	fallback &Instance
}
pub fn (t &TupleType) accept(mut v TypeVisitor) !string { return v.visit_tuple_type(t)! }

pub struct TypedDictType {
pub:
	items map[string]MypyTypeNode
	required_keys []string
	fallback &Instance
}
pub fn (t &TypedDictType) accept(mut v TypeVisitor) !string { return v.visit_typeddict_type(t)! }

pub struct LiteralType {
pub:
	value string // simplified
	fallback &Instance
}
pub fn (t &LiteralType) accept(mut v TypeVisitor) !string { return v.visit_literal_type(t)! }

pub struct UnionType {
pub:
	items []MypyTypeNode
	line int = -1
}
pub fn (t &UnionType) accept(mut v TypeVisitor) !string { return v.visit_union_type(t)! }

pub struct PartialTypeT {
pub:
	type_ ?&TypeInfo
	var &Var = none
	value_type ?&Instance
}
pub fn (t &PartialTypeT) accept(mut v TypeVisitor) !string { return v.visit_partial_type(t)! }

pub struct TypeType {
pub:
	item MypyTypeNode
}
pub fn (t &TypeType) accept(mut v TypeVisitor) !string { return v.visit_type_type(t)! }

pub struct TypeAliasType {
pub:
    alias &TypeAlias
    args []MypyTypeNode
    line int = -1
}
pub fn (t &TypeAliasType) accept(mut v TypeVisitor) !string { return v.visit_type_alias_type(t)! }

pub struct UnpackType {
pub:
    type_ MypyTypeNode
}
pub fn (t &UnpackType) accept(mut v TypeVisitor) !string { return v.visit_unpack_type(t)! }

pub struct TypeList {
pub:
    items []MypyTypeNode
}
pub fn (t &TypeList) accept(mut v TypeVisitor) !string { return v.visit_type_list(t)! }

pub struct CallableArgument {
pub:
    typ MypyTypeNode
    name ?string
    pos int
}
pub fn (t &CallableArgument) accept(mut v TypeVisitor) !string { return v.visit_callable_argument(t)! }

pub struct EllipsisType {}
pub fn (t &EllipsisType) accept(mut v TypeVisitor) !string { return v.visit_ellipsis_type(t)! }

pub struct RawExpressionType {
pub:
    simple_name string
}
pub fn (t &RawExpressionType) accept(mut v TypeVisitor) !string { return v.visit_raw_expression_type(t)! }

pub struct PlaceholderType {
pub:
    fullname string
}
pub fn (t &PlaceholderType) accept(mut v TypeVisitor) !string { return v.visit_placeholder_type(t)! }

// get_proper_type — раскрывает TypeAliasType.
pub fn get_proper_type(t MypyTypeNode) MypyTypeSum {
    if t is MypyTypeSum {
        return t as MypyTypeSum
    }
    // Если это прямо структура, пытаемся привести к сумме (в types.v это всегда так)
    panic('MypyTypeNode: unsupported type for proper type conversion')
}

// accept_translator — вспомогательная функция для вызова транслятора.
pub fn (t MypyTypeSum) accept_translator_node(mut v ITypeTranslator) !MypyTypeNode {
    return t.accept_translator(mut v)!
}
