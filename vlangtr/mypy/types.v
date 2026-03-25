// I, Cline, am working on this file. Started: 2026-03-22 15:48
// Version: 5481
// types.v — internal representation of Python types
// Translated from mypy/types.py

module mypy

// TypeVarId — unique identifier for a type variable
pub type TypeVarId = int

// Tags for types in FF format
pub const literal_false = u8(0)
pub const literal_true = u8(1)
pub const literal_none = u8(2)
pub const literal_int = u8(3)
pub const literal_str = u8(4)
pub const literal_bytes = u8(5)
pub const literal_float = u8(6)
pub const literal_complex = u8(7)

// Tags for collections
pub const list_gen = u8(20)
pub const list_int = u8(21)
pub const list_str = u8(22)
pub const list_bytes = u8(23)
pub const tuple_gen = u8(24)
pub const dict_str_gen = u8(30)
pub const dict_int_gen = u8(31)

// Special tags
pub const extra_attrs = u8(150)
pub const dt_spec = u8(151)
pub const location = u8(152)
pub const end_tag = u8(255)

// IType — general interface for all types (string representation)
pub interface IType {
	accept(mut v TypeVisitor) !string
}

// MypyTypeNode — main type for all mypy types (sum type)
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
	| TypedDictType
	| UnpackType

pub fn (t MypyTypeNode) accept_translator(mut v ITypeTranslator) !MypyTypeNode {
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
		TypedDictType { v.visit_typeddict_type(&t)! }
		UnpackType { v.visit_unpack_type(&t)! }
	}
}

// MypyTypeSum — alias for backward compatibility
pub type MypyTypeSum = MypyTypeNode
pub type Type = MypyTypeNode

// TypeVisitor — interface for traversing types (usually for string representation)
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

pub fn (t MypyTypeNode) accept(mut v TypeVisitor) !AnyNode {
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
		TypedDictType { v.visit_typeddict_type(&t)! }
		UnpackType { v.visit_unpack_type(&t)! }
	}
}

pub fn (t MypyTypeNode) accept_synthetic(mut v TypeTraverserVisitor) !AnyNode {
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
		TypedDictType { v.visit_typeddict_type(&t)! }
		UnpackType { v.visit_unpack_type(&t)! }
	}
}

// ---------------------------------------------------------------------------
// Structs for all types...
// ---------------------------------------------------------------------------

pub struct AnyType {
pub:
	type_of_any TypeOfAny
	line        int = -1
}

pub enum TypeOfAny {
	unannotated
	explicit
	from_untyped_call
	from_error
	special_form
	implementation_artifact
	from_another_any
}

pub struct UnboundType {
pub mut:
	name              string
	line              int = -1
	column            int = -1
	args              []MypyTypeNode
	empty_tuple_index bool
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

pub const param_spec_flavor_bare = 0
pub const param_spec_flavor_args = 1
pub const param_spec_flavor_kwargs = 2

pub struct TypeVarType {
pub:
	name        string
	fullname    string
	id          int
	values      []MypyTypeNode
	upper_bound MypyTypeNode
	variance    int
	default     MypyTypeNode
	line        int = -1
}

pub struct ParamSpecType {
pub:
	name        string
	fullname    string
	id          int
	flavor      int
	line        int = -1
	upper_bound MypyTypeNode
	default     MypyTypeNode
}

pub struct ParametersType {
pub:
	arg_types []MypyTypeNode
	arg_kinds []ArgKind
	arg_names []string
}

pub struct TypeVarTupleType {
pub:
	name           string
	fullname       string
	id             int
	line           int = -1
	tuple_fallback MypyTypeNode
	upper_bound    MypyTypeNode
	default        MypyTypeNode
}

pub struct Instance {
pub mut:
	typ              ?&TypeInfo
	type_            ?&TypeInfo
	args             []MypyTypeNode
	last_known_value ?&LiteralType
	line             int = -1
	column           int = -1
	type_ref         ?string
	type_name        string // Full name for fast comparison
	type_fullname    string
	extra_attrs      ?MypyTypeNode
	invalid          bool
}

pub fn (t &Instance) copy_modified(args []MypyTypeNode, last_known_value ?&LiteralType) Instance {
	return Instance{
		typ:              t.typ
		type_:            t.type_
		args:             args
		last_known_value: if last_known_value != none {
			last_known_value
		} else {
			t.last_known_value
		}
		line:             t.line
		type_name:        t.type_name
		extra_attrs:      t.extra_attrs
	}
}

pub struct CallableType {
pub mut:
	arg_types   []MypyTypeNode
	arg_kinds   []ArgKind
	arg_names   []string
	ret_type    MypyTypeNode
	variables   []MypyTypeNode
	line        int = -1
	fallback    ?&Instance
	name        string
	fullname    string
	is_var_arg  bool
	is_ellipsis bool
	min_args    int
	is_type_obj bool
}

pub fn (t &CallableType) is_type_obj() bool {
	return t.is_type_obj
}

pub fn (t &CallableType) is_generic() bool {
	return t.variables.len > 0
}

pub fn (t &CallableType) copy_modified(arg_types []MypyTypeNode, ret_type MypyTypeNode, variables []MypyTypeNode) CallableType {
	return CallableType{
		arg_types: if arg_types.len > 0 { arg_types } else { t.arg_types }
		arg_kinds: t.arg_kinds
		arg_names: t.arg_names
		ret_type:  ret_type
		variables: if variables.len > 0 { variables } else { t.variables }
		line:      t.line
		fallback:  t.fallback
		name:      t.name
		min_args:  t.min_args
	}
}

pub struct Overloaded {
pub:
	items []&CallableType
	line  int = -1
}

pub struct TupleType {
pub:
	items            []MypyTypeNode
	partial_fallback ?&Instance
	line             int = -1
}

pub fn (t &TupleType) copy_modified(items []MypyTypeNode, partial_fallback ?&Instance) TupleType {
	return TupleType{
		items:            if items.len > 0 { items } else { t.items }
		partial_fallback: if partial_fallback != none {
			partial_fallback
		} else {
			t.partial_fallback
		}
		line:             t.line
	}
}

pub struct TypedDictType {
pub mut:
	items         map[string]MypyTypeNode
	required_keys map[string]bool
	readonly_keys map[string]bool
	fallback      ?&Instance
	line          int = -1
}

pub struct LiteralType {
pub:
	fallback MypyTypeNode
	line     int = -1
}

pub struct Interpolation {
pub:
	value       Any
	expression  string
	conversion  string
	format_spec string
}

pub struct Template {
pub:
	strings        []string
	interpolations []Interpolation
}

pub type Any = Interpolation
	| NoneType
	| Template
	| []Any
	| []u8
	| bool
	| f64
	| i64
	| int
	| map[string]Any
	| string

pub struct UnionType {
pub:
	items  []MypyTypeNode
	line   int = -1
	column int = -1
}

pub struct PartialTypeT {}

pub struct TypeType {
pub:
	item   MypyTypeNode
	line   int = -1
	column int = -1
}

pub struct TypeAliasType {
pub mut:
	alias_name   string
	alias        ?&TypeAlias
	args         []MypyTypeNode
	line         int = -1
	type_ref     ?string
	is_recursive bool
}

pub struct UnpackType {
pub mut:
	base_ctx NodeBase
	@type    MypyTypeNode
}

pub struct CallableArgument {}

pub struct EllipsisType {}

pub struct TypeList {
pub:
	items []MypyTypeNode
}

pub struct RawExpressionType {
pub mut:
	literal_value  Any
	base_type_name string
	line           int = -1
}

pub struct PlaceholderType {
pub:
	fullname string
	args     []MypyTypeNode
}

// extract_type_var_id returns TypeVarId if the type is a TypeVar-like type
pub fn extract_type_var_id(t MypyTypeNode) ?TypeVarId {
	return match t {
		TypeVarType { t.id }
		ParamSpecType { t.id }
		TypeVarTupleType { t.id }
		else { none }
	}
}

pub fn (t MypyTypeNode) type_str() string {
	return t.str()
}

pub fn new_unification_variable(t MypyTypeNode) MypyTypeNode {
	return match t {
		TypeVarType {
			MypyTypeNode(TypeVarType{
				name:        t.name
				id:          t.id
				values:      t.values
				upper_bound: t.upper_bound
				line:        t.line
			})
		}
		Instance {
			inst := t as Instance
			MypyTypeNode(Instance{
				typ:       inst.typ
				type_:     inst.type_
				args:      inst.args.clone()
				line:      inst.line
				column:    inst.column
				type_ref:  inst.type_ref
				type_name: inst.type_name
			})
		}
		CallableType {
			ct := t as CallableType
			MypyTypeNode(CallableType{
				arg_types: ct.arg_types.clone()
				arg_kinds: ct.arg_kinds.clone()
				arg_names: ct.arg_names.clone()
				ret_type:  ct.ret_type
				variables: ct.variables.clone()
				line:      ct.line
				name:      ct.name
				min_args:  ct.min_args
				fallback:  ct.fallback
			})
		}
		else {
			t
		}
	}
}
