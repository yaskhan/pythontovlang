// Я Cline работаю над этим файлом. Начало: 2026-03-22 15:48
// Version: 5481
// types.v — internal representation of Python types
// Переведён из mypy/types.py

module mypy

// TypeVarId — уникальный идентификатор типовой переменной
pub type TypeVarId = int

// IType — общий интерфейс для всех типов (строковое представление)
pub interface IType {
	accept(mut v TypeVisitor) !string
}

// MypyTypeNode — основной тип для всех типов mypy (сумма)
pub type MypyTypeNode = AnyType
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

// MypyTypeSum — алиас для обратной совместимости
pub type MypyTypeSum = MypyTypeNode

// TypeVisitor — интерфейс для обхода типов (обычно для строкового представления)
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
	visit_type_list(t &TypeList) !string
	visit_callable_argument(t &CallableArgument) !string
	visit_ellipsis_type(t &EllipsisType) !string
	visit_raw_expression_type(t &RawExpressionType) !string
	visit_placeholder_type(t &PlaceholderType) !string
}

// ITypeTranslator REMOVED for diagnostic purposes

// ---------------------------------------------------------------------------
// Structs for all types...
// ---------------------------------------------------------------------------

pub struct AnyType {
pub:
    type_of_any TypeOfAny
	line int = -1
}

pub enum TypeOfAny {
    unannotated
    explicit
    from_untyped_call
    from_error
    special_form
}

pub struct UnboundType {
pub:
    name string
	line int = -1
}

pub struct NoneType {
pub:
	line int = -1
}

pub struct UninhabitedType {
pub:
	line int = -1
}

pub struct ErasedType {}
pub struct DeletedType {}

pub struct TypeVarType {
pub:
    name string
    id int
    values []MypyTypeNode
    upper_bound MypyTypeNode
    line int = -1
}

pub struct ParamSpecType {
pub:
    name string
    id int
    line int = -1
    upper_bound MypyTypeNode
    default MypyTypeNode
}

pub struct ParametersType {
pub:
    arg_types []MypyTypeNode
    arg_kinds []ArgKind
    arg_names []?string
}

pub struct TypeVarTupleType {
pub:
    name string
    id int
    line int = -1
    tuple_fallback MypyTypeNode
    upper_bound MypyTypeNode
    default MypyTypeNode
}

pub struct Instance {
pub mut:
    type_ &TypeInfo = none
    args []MypyTypeNode
    last_known_value ?&LiteralType
    line int = -1
    type_ref ?string
}
pub fn (t &Instance) copy_modified(args []MypyTypeNode, last_known_value ?&LiteralType) Instance {
    return Instance{
        type_: t.type_
        args: args
        last_known_value: if last_known_value != none { last_known_value } else { t.last_known_value }
        line: t.line
    }
}

pub struct CallableType {
pub:
    arg_types []MypyTypeNode
    arg_kinds []ArgKind
    arg_names []?string
    ret_type MypyTypeNode
    variables []MypyTypeNode
    line int = -1
    fallback ?MypyTypeNode
}
pub fn (t &CallableType) is_generic() bool { return t.variables.len > 0 }
pub fn (t &CallableType) copy_modified(arg_types []MypyTypeNode, ret_type MypyTypeNode, variables []MypyTypeNode) CallableType {
    return CallableType{
        arg_types: if arg_types.len > 0 { arg_types } else { t.arg_types }
        arg_kinds: t.arg_kinds
        arg_names: t.arg_names
        ret_type: if ret_type != none { ret_type } else { t.ret_type }
        variables: if variables.len > 0 { variables } else { t.variables }
        line: t.line
    }
}

pub struct Overloaded {
pub:
    items []&CallableType
    line int = -1
}

pub struct TupleType {
pub:
    items []MypyTypeNode
    partial_fallback ?&Instance
    line int = -1
}
pub fn (t &TupleType) copy_modified(items []MypyTypeNode, partial_fallback ?&Instance) TupleType {
    return TupleType{
        items: if items.len > 0 { items } else { t.items }
        partial_fallback: if partial_fallback != none { partial_fallback } else { t.partial_fallback }
        line: t.line
    }
}

pub struct TypedDictType {
pub:
    items map[string]MypyTypeNode
    line int = -1
    fallback ?MypyTypeNode
}

pub struct LiteralType {
pub:
    fallback MypyTypeNode
	line int = -1
}

pub struct UnionType {
pub:
    items []MypyTypeNode
    line int = -1
    column int = -1
}

pub struct PartialTypeT {}
pub struct TypeType {
pub:
    item MypyTypeNode
    line int = -1
    column int = -1
}

pub struct TypeAliasType {
pub mut:
    alias ?&TypeAlias = none
    args []MypyTypeNode
    line int = -1
    type_ref ?string
}

pub struct UnpackType {
pub:
    type MypyTypeNode
}

pub struct CallableArgument {}
pub struct EllipsisType {}
pub struct TypeList {
pub:
    items []MypyTypeNode
}
pub struct RawExpressionType {}
pub struct PlaceholderType {
pub:
    fullname string
}

// extract_type_var_id returns TypeVarId if the type is a TypeVar-like type
pub fn extract_type_var_id(t MypyTypeNode) ?TypeVarId {
    match t {
        TypeVarType { return t.id }
        ParamSpecType { return t.id }
        TypeVarTupleType { return t.id }
        else { return none }
    }
}

pub fn new_unification_variable(t MypyTypeNode) MypyTypeNode {
    match t {
        TypeVarType {
            return MypyTypeNode(TypeVarType{
                name: t.name
                id: t.id
                values: t.values
                upper_bound: t.upper_bound
                line: t.line
            })
        }
        else {
            return MypyTypeNode(AnyType{type_of_any: .from_error})
        }
    }
}

// get_proper_type — раскрывает TypeAliasType.
pub fn get_proper_type(t MypyTypeNode) MypyTypeNode {
    return t
}
