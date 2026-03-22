// types.v — Mypy type system representation
// Translated from mypy/types.py and mypy/type_visitor.py to V 0.5.x
//
// Translation decisions:
//   Python Generic[T] visitor   → V interface with !string return
//   TypeOfAny class-level Final → V enum
//   Optional[X]                 → ?X
//   Properties with lazy init   → fn with explicit cache pattern
//   TypeTranslator identity map → struct implementing TypeVisitor

module mypy

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

pub const any_strategy = 0
pub const all_strategy  = 1

// ---------------------------------------------------------------------------
// TypeOfAny — describes the origin of an Any type
// ---------------------------------------------------------------------------

pub enum TypeOfAny {
	unannotated            // 1 in Python
	explicit               // 2
	from_unimported_type   // 3
	from_omitted_generics  // 4
	from_error             // 5
	special_form           // 6
	from_another_any       // 7
	implementation_artifact // 8
	suggestion_engine      // 9
}

// ---------------------------------------------------------------------------
// TypeBase — common base for all type nodes (replaces Python Type(Context))
// ---------------------------------------------------------------------------

pub struct TypeBase {
pub mut:
	ctx           Context
	// -1 = uninitialised (lazy), 0 = false, 1 = true
	_can_be_true  int = -1
	_can_be_false int = -1
}

pub fn (mut t TypeBase) can_be_true() bool {
	if t._can_be_true == -1 {
		t._can_be_true = 1 // default: can be true
	}
	return t._can_be_true == 1
}

pub fn (mut t TypeBase) can_be_false() bool {
	if t._can_be_false == -1 {
		t._can_be_false = 1 // default: can be false
	}
	return t._can_be_false == 1
}

// ---------------------------------------------------------------------------
// TypeVisitor interface (replaces Python abstract TypeVisitor[T])
// We use !string as the return type across all visit methods.
// Concrete structs that need other return types should wrap in their own layer.
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
}

pub interface TypeResultVisitor {
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
}


// SyntheticTypeVisitor adds synthetic / pre-analysis type nodes
pub interface SyntheticTypeVisitor {
mut:
	// All TypeVisitor methods
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
	// Synthetic extras
	visit_type_list(t &TypeList) !string
	visit_callable_argument(t &CallableArgument) !string
	visit_ellipsis_type(t &EllipsisType) !string
	visit_raw_expression_type(t &RawExpressionType) !string
	visit_placeholder_type(t &PlaceholderType) !string
}

// ---------------------------------------------------------------------------
// MypyTypeNode — the concrete sum-type covering all type variants.
// Satisfies the MypyType interface declared in nodes.v.
// ---------------------------------------------------------------------------

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
	| ParametersType
	| ParamSpecType
	| PartialTypeT
	| PlaceholderType
	| RawExpressionType
	| TupleType
	| TypeAliasType
	| TypeList
	| TypeType
	| TypeVarTupleType
	| TypeVarType
	| TypedDictType
	| UnboundType
	| UninhabitedType
	| UnionType
	| UnpackType

// type_str dispatches on the sum-type to satisfy the MypyType interface.
pub fn (t MypyTypeNode) type_str() string {
	return match t {
		AnyType            { 'Any' }
		NoneType           { 'None' }
		UninhabitedType    { 'Never' }
		ErasedType         { '<erased>' }
		DeletedType        { '<deleted>' }
		EllipsisType       { '...' }
		UnboundType        { t.name }
		Instance           { t.type_name }
		TypeVarType        { t.name }
		ParamSpecType      { t.name }
		TypeVarTupleType   { t.name }
		LiteralType        { 'Literal[${t.value_repr()}]' }
		UnionType          { 'Union' }
		TupleType          { 'Tuple' }
		CallableType       { 'Callable' }
		Overloaded         { 'Overloaded' }
		TypeType           { 'Type' }
		TypeAliasType      { t.alias_name }
		TypedDictType      { 'TypedDict' }
		PartialTypeT       { 'PartialType' }
		RawExpressionType  { t.base_type_name }
		PlaceholderType    { t.fullname }
		TypeList           { 'TypeList' }
		CallableArgument   { 'CallableArgument' }
		ParametersType     { 'Parameters' }
		UnpackType         { 'Unpack' }
	}
}

pub fn (t MypyTypeNode) accept(mut v TypeVisitor) !string {
	return match t {

		AnyType            { v.visit_any(&t)! }
		NoneType           { v.visit_none_type(&t)! }
		UninhabitedType    { v.visit_uninhabited_type(&t)! }
		ErasedType         { v.visit_erased_type(&t)! }
		DeletedType        { v.visit_deleted_type(&t)! }
		UnboundType        { v.visit_unbound_type(&t)! }
		Instance           { v.visit_instance(&t)! }
		TypeVarType        { v.visit_type_var(&t)! }
		ParamSpecType      { v.visit_param_spec(&t)! }
		TypeVarTupleType   { v.visit_type_var_tuple(&t)! }
		ParametersType     { v.visit_parameters(&t)! }
		TupleType          { v.visit_tuple_type(&t)! }
		TypedDictType      { v.visit_typeddict_type(&t)! }
		LiteralType        { v.visit_literal_type(&t)! }
		UnionType          { v.visit_union_type(&t)! }
		CallableType       { v.visit_callable_type(&t)! }
		Overloaded         { v.visit_overloaded(&t)! }
		TypeType           { v.visit_type_type(&t)! }
		TypeAliasType      { v.visit_type_alias_type(&t)! }
		UnpackType         { v.visit_unpack_type(&t)! }
		PartialTypeT       { v.visit_partial_type(&t)! }
		else {
			return error('TypeVisitor: node ${t.type_str()} is not a standard type')
		}
	}
}

pub fn (t MypyTypeNode) accept_res(mut v TypeResultVisitor) !MypyTypeNode {
	return match t {
		AnyType            { v.visit_any(&t)! }

		NoneType           { v.visit_none_type(&t)! }
		UninhabitedType    { v.visit_uninhabited_type(&t)! }
		ErasedType         { v.visit_erased_type(&t)! }
		DeletedType        { v.visit_deleted_type(&t)! }
		UnboundType        { v.visit_unbound_type(&t)! }
		Instance           { v.visit_instance(&t)! }
		TypeVarType        { v.visit_type_var(&t)! }
		ParamSpecType      { v.visit_param_spec(&t)! }
		TypeVarTupleType   { v.visit_type_var_tuple(&t)! }
		ParametersType     { v.visit_parameters(&t)! }
		TupleType          { v.visit_tuple_type(&t)! }
		TypedDictType      { v.visit_typeddict_type(&t)! }
		LiteralType        { v.visit_literal_type(&t)! }
		UnionType          { v.visit_union_type(&t)! }
		CallableType       { v.visit_callable_type(&t)! }
		Overloaded         { v.visit_overloaded(&t)! }
		TypeType           { v.visit_type_type(&t)! }
		TypeAliasType      { v.visit_type_alias_type(&t)! }
		UnpackType         { v.visit_unpack_type(&t)! }
		PartialTypeT       { v.visit_partial_type(&t)! }
		else { AnyType{type_of_any: .from_error} }
	}
}


pub fn (t MypyTypeNode) accept_synthetic(mut v SyntheticTypeVisitor) !string {
	return match t {

		AnyType            { v.visit_any(&t)! }
		NoneType           { v.visit_none_type(&t)! }
		UninhabitedType    { v.visit_uninhabited_type(&t)! }
		ErasedType         { v.visit_erased_type(&t)! }
		DeletedType        { v.visit_deleted_type(&t)! }
		UnboundType        { v.visit_unbound_type(&t)! }
		Instance           { v.visit_instance(&t)! }
		TypeVarType        { v.visit_type_var(&t)! }
		ParamSpecType      { v.visit_param_spec(&t)! }
		TypeVarTupleType   { v.visit_type_var_tuple(&t)! }
		ParametersType     { v.visit_parameters(&t)! }
		TupleType          { v.visit_tuple_type(&t)! }
		TypedDictType      { v.visit_typeddict_type(&t)! }
		LiteralType        { v.visit_literal_type(&t)! }
		UnionType          { v.visit_union_type(&t)! }
		CallableType       { v.visit_callable_type(&t)! }
		Overloaded         { v.visit_overloaded(&t)! }
		TypeType           { v.visit_type_type(&t)! }
		TypeAliasType      { v.visit_type_alias_type(&t)! }
		UnpackType         { v.visit_unpack_type(&t)! }
		PartialTypeT       { v.visit_partial_type(&t)! }
		TypeList           { v.visit_type_list(&t)! }
		CallableArgument   { v.visit_callable_argument(&t)! }
		EllipsisType       { v.visit_ellipsis_type(&t)! }
		RawExpressionType  { v.visit_raw_expression_type(&t)! }
		PlaceholderType    { v.visit_placeholder_type(&t)! }
	}
}

// ---------------------------------------------------------------------------
// TypeVarId
// ---------------------------------------------------------------------------

pub struct TypeVarId {
pub mut:
	raw_id     int
	meta_level int
	namespace  string
}

pub fn TypeVarId.new(raw_id int, meta_level int, namespace string) TypeVarId {
	return TypeVarId{ raw_id: raw_id, meta_level: meta_level, namespace: namespace }
}

pub fn (id TypeVarId) is_meta_var() bool {
	return id.meta_level > 0
}

// ---------------------------------------------------------------------------
// Concrete type structs
// ---------------------------------------------------------------------------

// AnyType
pub struct AnyType {
pub mut:
	base        TypeBase
	type_of_any TypeOfAny
	source_any  ?&AnyType   // original Any this was derived from
	missing_import_name ?string
}

pub fn (t &AnyType) type_str() string { return 'Any' }
pub fn (t &AnyType) accept(mut v TypeVisitor) !string { return v.visit_any(t)! }

// NoneType
pub struct NoneType {
pub mut:
	base TypeBase
}

pub fn (t &NoneType) type_str() string { return 'None' }
pub fn (t &NoneType) accept(mut v TypeVisitor) !string { return v.visit_none_type(t)! }

// UninhabitedType (NoReturn / Never)
pub struct UninhabitedType {
pub mut:
	base          TypeBase
	is_noreturn   bool
	ambiguous     bool
}

pub fn (t &UninhabitedType) type_str() string { return 'Never' }
pub fn (t &UninhabitedType) accept(mut v TypeVisitor) !string { return v.visit_uninhabited_type(t)! }

// ErasedType — placeholder for erased generics
pub struct ErasedType {
pub mut:
	base TypeBase
}

pub fn (t &ErasedType) type_str() string { return '<erased>' }
pub fn (t &ErasedType) accept(mut v TypeVisitor) !string { return v.visit_erased_type(t)! }

// DeletedType — type of a deleted variable
// DeletedType вЂ” type of a deleted variable
pub struct DeletedType {
pub mut:
	base   TypeBase
	source ?string
}

pub fn (t &DeletedType) type_str() string { return '<deleted>' }
pub fn (t &DeletedType) accept(mut v TypeVisitor) !string { return v.visit_deleted_type(t)! }

// UnboundType — a type name not yet resolved during semantic analysis
pub struct UnboundType {
pub mut:
	base          TypeBase
	name          string
	args          []MypyTypeNode
	optional      bool
	empty_tuple_index bool
	original_str_expr ?string
	original_str_fallback ?MypyTypeNode
}

pub fn (t &UnboundType) accept(mut v TypeVisitor) !string { return v.visit_unbound_type(t)! }

// Instance — a concrete class instantiation (e.g. List[int])
pub struct Instance {
pub mut:
	base            TypeBase
	typ             ?&TypeInfo
	type_name       string   // fullname of the TypeInfo
	args            []MypyTypeNode
	last_known_value ?&LiteralType
	extra_attrs     ?ExtraAttrs
	invalid         bool
}

pub fn (t &Instance) accept(mut v TypeVisitor) !string { return v.visit_instance(t)! }

// ExtraAttrs holds per-instance extra structural information
pub struct ExtraAttrs {
pub mut:
	attrs     map[string]MypyTypeNode
	immutable map[string]bool
	mod_name  ?string
}

// TypeVarType
pub struct TypeVarType {
pub mut:
	base        TypeBase
	name        string
	fullname    string
	id          TypeVarId
	values      []MypyTypeNode
	upper_bound MypyTypeNode
	default_    MypyTypeNode
	variance    int   // INVARIANT=0, COVARIANT=1, CONTRAVARIANT=2, BIVARIANT=3
}

pub fn (t &TypeVarType) accept(mut v TypeVisitor) !string { return v.visit_type_var(t)! }

// ParamSpecType
pub enum ParamSpecFlavor {
	bare        // P
	args        // P.args
	kwargs      // P.kwargs
}

pub struct ParamSpecType {
pub mut:
	base        TypeBase
	name        string
	fullname    string
	id          TypeVarId
	flavor      ParamSpecFlavor
	upper_bound MypyTypeNode
	default_    MypyTypeNode
	// prefix for partially-applied callable
	prefix      ParametersType
}

pub fn (t &ParamSpecType) accept(mut v TypeVisitor) !string { return v.visit_param_spec(t)! }

// TypeVarTupleType
pub struct TypeVarTupleType {
pub mut:
	base            TypeBase
	name            string
	fullname        string
	id              TypeVarId
	upper_bound     MypyTypeNode
	default_        MypyTypeNode
	tuple_fallback  Instance
	min_len         int
}

pub fn (t &TypeVarTupleType) accept(mut v TypeVisitor) !string { return v.visit_type_var_tuple(t)! }

// ParametersType — P.args/P.kwargs represented as parameters list
pub struct ParametersType {
pub mut:
	base       TypeBase
	arg_types  []MypyTypeNode
	arg_kinds  []ArgKind
	arg_names  []?string
}

pub fn (t &ParametersType) accept(mut v TypeVisitor) !string { return v.visit_parameters(t)! }

// UnpackType — Unpack[T] for variadic generics
pub struct UnpackType {
pub mut:
	base       TypeBase
	type_      MypyTypeNode
	// True when this is from a TypeVarTuple, False from an explicit Unpack[...]
	from_star_syntax bool
}

pub fn (t &UnpackType) accept(mut v TypeVisitor) !string { return v.visit_unpack_type(t)! }

// FormalArgument — a single formal parameter in a callable
pub struct FormalArgument {
pub:
	name     ?string
	pos      ?int
	typ      MypyTypeNode
	required bool
}

// CallableType — function types
pub struct CallableType {
pub mut:
	base              TypeBase
	arg_types         []MypyTypeNode
	arg_kinds         []ArgKind
	arg_names         []?string
	ret_type          MypyTypeNode
	name              ?string
	definition        ?&FuncDef   // originating FuncDef if known
	variables         []MypyTypeNode // TypeVarLike variables
	is_type_obj       bool
	is_ellipsis_args  bool
	fallback          ?Instance
	is_classmethod    bool
	is_staticmethod   bool
	is_protocol       bool
	implicit          bool
	special_sig       ?string
	from_concatenate  bool
	imprecise_arg_kinds bool
	unpack_kwargs     bool
	// extra metadata for type-checking
	param_spec_id     ?TypeVarId
}

pub fn (t &CallableType) accept(mut v TypeVisitor) !string { return v.visit_callable_type(t)! }

// Overloaded — a set of overloaded callable types
pub struct Overloaded {
pub mut:
	base     TypeBase
	items    []CallableType
	fallback ?Instance
}

pub fn (t &Overloaded) accept(mut v TypeVisitor) !string { return v.visit_overloaded(t)! }

// TupleType
pub struct TupleType {
pub mut:
	base             TypeBase
	items            []MypyTypeNode
	partial_fallback Instance
	implicit         bool
}

pub fn (t &TupleType) accept(mut v TypeVisitor) !string { return v.visit_tuple_type(t)! }

// TypedDictType
pub struct TypedDictType {
pub mut:
	base          TypeBase
	items         map[string]MypyTypeNode
	required_keys map[string]bool
	readonly_keys map[string]bool
	fallback      Instance
}

pub fn (t &TypedDictType) accept(mut v TypeVisitor) !string { return v.visit_typeddict_type(t)! }

// LiteralValue — the Python LiteralValue: int | str | bool | float
pub type LiteralValue = bool | f64 | i64 | string

// LiteralType — Literal[x]
pub struct LiteralType {
pub mut:
	base     TypeBase
	value    LiteralValue
	fallback Instance
}

pub fn (t &LiteralType) value_repr() string {
	return match t.value {
		i64    { t.value.str() }
		bool   { if t.value { 'True' } else { 'False' } }
		f64    { t.value.str() }
		string { "'${t.value}'" }
	}
}

pub fn (t &LiteralType) accept(mut v TypeVisitor) !string { return v.visit_literal_type(t)! }

// UnionType — X | Y | ...
pub struct UnionType {
pub mut:
	base             TypeBase
	items            []MypyTypeNode
	uses_pep604_syntax bool
}

pub fn (t &UnionType) accept(mut v TypeVisitor) !string { return v.visit_union_type(t)! }

// PartialTypeT — partial type for variables whose type is not yet fully inferred
// (named PartialTypeT to avoid collision with the visitor method name)
pub struct PartialTypeT {
pub mut:
	base    TypeBase
	type_   ?Instance
	var_    Var
	value_type ?Instance
}

pub fn (t &PartialTypeT) accept(mut v TypeVisitor) !string { return v.visit_partial_type(t)! }

// EllipsisType — used for Callable[..., X]
pub struct EllipsisType {
pub mut:
	base TypeBase
}

pub fn (t &EllipsisType) type_str() string { return '...' }
pub fn (t &EllipsisType) accept(mut v SyntheticTypeVisitor) !string { return v.visit_ellipsis_type(t)! }

// TypeType — Type[X]
pub struct TypeType {
pub mut:
	base         TypeBase
	item         MypyTypeNode
	is_type_form bool
}

pub fn (t &TypeType) accept(mut v TypeVisitor) !string { return v.visit_type_type(t)! }

// TypeAliasType — a type alias reference with args
pub struct TypeAliasType {
pub mut:
	base       TypeBase
	alias_name string        // fullname
	args       []MypyTypeNode
	// the actual alias node it refers to
	alias      ?&TypeAlias
}

pub fn (t &TypeAliasType) accept(mut v TypeVisitor) !string { return v.visit_type_alias_type(t)! }

// PlaceholderType вЂ” for names that couldn't be resolved yet
pub struct PlaceholderType {
pub mut:
	base     TypeBase
	fullname string
	args     []MypyTypeNode
}

pub fn (t &PlaceholderType) accept(mut v SyntheticTypeVisitor) !string { return v.visit_placeholder_type(t)! }

// RawExpressionType — a raw expression used in type context (pre-analysis)
pub struct RawExpressionType {
pub mut:
	base           TypeBase
	base_type_name string
	literal_value  ?LiteralValue
	note           ?string
}

pub fn (t &RawExpressionType) accept(mut v SyntheticTypeVisitor) !string { return v.visit_raw_expression_type(t)! }

// TypeList — a list of types used in some synthetic contexts
pub struct TypeList {
pub mut:
	base  TypeBase
	items []MypyTypeNode
}

pub fn (t &TypeList) accept(mut v SyntheticTypeVisitor) !string { return v.visit_type_list(t)! }

// CallableArgument — an argument within a Callable type annotation
pub struct CallableArgument {
pub mut:
	base    TypeBase
	typ     MypyTypeNode
	name    ?string
	constructor ?string
}

pub fn (t &CallableArgument) accept(mut v SyntheticTypeVisitor) !string { return v.visit_callable_argument(t)! }

// ---------------------------------------------------------------------------
// TypeTranslator — identity transformation base
// Subclasses override specific visit_* methods to rewrite types.
// ---------------------------------------------------------------------------

pub struct TypeTranslator {
pub mut:
	// Optional cache: maps pointer address to translated type.
	// Using a plain map since V doesn't have Python's object-keyed maps.
	cache map[u64]MypyTypeNode
}

pub fn (mut tr TypeTranslator) get_cached(t &TypeBase) ?MypyTypeNode {
	ptr := u64(usize(t))
	return tr.cache[ptr] or { return none }
}

pub fn (mut tr TypeTranslator) set_cached(orig &TypeBase, new MypyTypeNode) {
	ptr := u64(usize(orig))
	tr.cache[ptr] = new
}

// Default pass-through implementations for TypeTranslator:

pub fn (mut tr TypeTranslator) visit_unbound_type(t &UnboundType) !MypyTypeNode {
	mut args := []MypyTypeNode{}
	for a in t.args {
		args << tr.translate_type(a)!
	}
	mut result := *t
	result.args = args
	return result
}

pub fn (mut tr TypeTranslator) visit_any(t &AnyType) !MypyTypeNode { return *t }
pub fn (mut tr TypeTranslator) visit_none_type(t &NoneType) !MypyTypeNode { return *t }
pub fn (mut tr TypeTranslator) visit_uninhabited_type(t &UninhabitedType) !MypyTypeNode { return *t }
pub fn (mut tr TypeTranslator) visit_erased_type(t &ErasedType) !MypyTypeNode { return *t }
pub fn (mut tr TypeTranslator) visit_deleted_type(t &DeletedType) !MypyTypeNode { return *t }
pub fn (mut tr TypeTranslator) visit_type_var(t &TypeVarType) !MypyTypeNode { return *t }
pub fn (mut tr TypeTranslator) visit_param_spec(t &ParamSpecType) !MypyTypeNode { return *t }
pub fn (mut tr TypeTranslator) visit_type_var_tuple(t &TypeVarTupleType) !MypyTypeNode { return *t }
pub fn (mut tr TypeTranslator) visit_partial_type(t &PartialTypeT) !MypyTypeNode { return *t }

pub fn (mut tr TypeTranslator) visit_unpack_type(t &UnpackType) !MypyTypeNode {
	inner := tr.translate_type(t.type_)!
	mut result := *t
	result.type_ = inner
	return result
}

pub fn (mut tr TypeTranslator) visit_parameters(t &ParametersType) !MypyTypeNode {
	mut result := *t
	result.arg_types = tr.translate_type_list(t.arg_types)!
	return result
}

pub fn (mut tr TypeTranslator) visit_instance(t &Instance) !MypyTypeNode {
	mut result := *t
	result.args = tr.translate_type_list(t.args)!
	return result
}

pub fn (mut tr TypeTranslator) visit_callable_type(t &CallableType) !MypyTypeNode {
	mut result := *t
	result.arg_types = tr.translate_type_list(t.arg_types)!
	result.ret_type = tr.translate_type(t.ret_type)!
	return result
}

pub fn (mut tr TypeTranslator) visit_tuple_type(t &TupleType) !MypyTypeNode {
	mut result := *t
	result.items = tr.translate_type_list(t.items)!
	return result
}

pub fn (mut tr TypeTranslator) visit_typeddict_type(t &TypedDictType) !MypyTypeNode {
	if cached := tr.get_cached(&t.base) {
		return cached
	}
	mut items := map[string]MypyTypeNode{}
	for k, v in t.items {
		items[k] = tr.translate_type(v)!
	}
	mut result := *t
	result.items = items
	tr.set_cached(&t.base, result)
	return result
}

pub fn (mut tr TypeTranslator) visit_literal_type(t &LiteralType) !MypyTypeNode {
	return *t
}

pub fn (mut tr TypeTranslator) visit_union_type(t &UnionType) !MypyTypeNode {
	use_cache := t.items.len > 3
	if use_cache {
		if cached := tr.get_cached(&t.base) {
			return cached
		}
	}
	mut result := *t
	result.items = tr.translate_type_list(t.items)!
	if use_cache {
		tr.set_cached(&t.base, result)
	}
	return result
}

pub fn (mut tr TypeTranslator) visit_overloaded(t &Overloaded) !MypyTypeNode {
	mut items := []CallableType{}
	for item in t.items {
		translated := tr.translate_type(item)!
		items << translated as CallableType
	}
	mut result := *t
	result.items = items
	return result
}

pub fn (mut tr TypeTranslator) visit_type_type(t &TypeType) !MypyTypeNode {
	mut result := *t
	result.item = tr.translate_type(t.item)!
	return result
}

// translate_type dispatches on MypyTypeNode sum-type
pub fn (mut tr TypeTranslator) translate_type(t MypyTypeNode) !MypyTypeNode {
	return match t {
		AnyType           { tr.visit_any(&t)! }
		NoneType          { tr.visit_none_type(&t)! }
		UninhabitedType   { tr.visit_uninhabited_type(&t)! }
		ErasedType        { tr.visit_erased_type(&t)! }
		DeletedType       { tr.visit_deleted_type(&t)! }
		UnboundType       { tr.visit_unbound_type(&t)! }
		Instance          { tr.visit_instance(&t)! }
		TypeVarType       { tr.visit_type_var(&t)! }
		ParamSpecType     { tr.visit_param_spec(&t)! }
		TypeVarTupleType  { tr.visit_type_var_tuple(&t)! }
		ParametersType    { tr.visit_parameters(&t)! }
		UnpackType        { tr.visit_unpack_type(&t)! }
		CallableType      { tr.visit_callable_type(&t)! }
		Overloaded        { tr.visit_overloaded(&t)! }
		TupleType         { tr.visit_tuple_type(&t)! }
		TypedDictType     { tr.visit_typeddict_type(&t)! }
		LiteralType       { tr.visit_literal_type(&t)! }
		UnionType         { tr.visit_union_type(&t)! }
		PartialTypeT      { tr.visit_partial_type(&t)! }
		TypeType          { tr.visit_type_type(&t)! }
		TypeAliasType     { error('TypeTranslator: visit_type_alias_type must be overridden') }
		PlaceholderType   { error('TypeTranslator: visit_placeholder_type not available here') }
		RawExpressionType { error('TypeTranslator: visit_raw_expression_type not available here') }
		TypeList          { error('TypeTranslator: visit_type_list not available here') }
		CallableArgument  { error('TypeTranslator: visit_callable_argument not available here') }
		EllipsisType      { error('TypeTranslator: visit_ellipsis_type not available here') }
	}
}

pub fn (mut tr TypeTranslator) translate_type_list(types []MypyTypeNode) ![]MypyTypeNode {
	mut result := []MypyTypeNode{}
	for t in types {
		result << tr.translate_type(t)!
	}
	return result
}

// ---------------------------------------------------------------------------
// BoolTypeQuery — base for recursive bool queries over a type tree
// ---------------------------------------------------------------------------

pub struct BoolTypeQuery {
pub mut:
	strategy        int  // any_strategy or all_strategy
	default_        bool
	seen_aliases    map[string]bool  // fullname → visited
	skip_alias_target bool
}

pub fn BoolTypeQuery.new(strategy int) BoolTypeQuery {
	default_ := strategy != any_strategy
	return BoolTypeQuery{ strategy: strategy, default_: default_ }
}

pub fn (mut q BoolTypeQuery) reset() {
	q.seen_aliases = map[string]bool{}
}

pub fn (mut q BoolTypeQuery) query_types(types []MypyTypeNode) bool {
	if q.strategy == any_strategy {
		for t in types {
			if q.accept(t) {
				return true
			}
		}
		return false
	} else {
		for t in types {
			if !q.accept(t) {
				return false
			}
		}
		return true
	}
}

// accept dispatches on the sum-type; subclasses override individual visit_* methods.
pub fn (mut q BoolTypeQuery) accept(t MypyTypeNode) bool {
	return match t {
		AnyType           { q.visit_any(&t) }
		NoneType          { q.visit_none_type(&t) }
		UninhabitedType   { q.visit_uninhabited_type(&t) }
		ErasedType        { q.visit_erased_type(&t) }
		DeletedType       { q.visit_deleted_type(&t) }
		UnboundType       { q.query_types(t.args) }
		Instance          { q.query_types(t.args) }
		TypeVarType       { q.query_types([t.upper_bound, t.default_] + t.values) }
		ParamSpecType     { q.query_types([t.upper_bound, t.default_]) }
		TypeVarTupleType  { q.query_types([t.upper_bound, t.default_]) }
		ParametersType    { q.query_types(t.arg_types) }
		UnpackType        { q.query_types([t.type_]) }
		CallableType      {
			args := q.query_types(t.arg_types)
			ret  := q.accept(t.ret_type)
			if q.strategy == any_strategy { args || ret } else { args && ret }
		}
		TupleType         { q.query_types([t.partial_fallback] + t.items) }
		TypedDictType     { q.query_types(t.items.values().map(it)) }
		LiteralType       { q.default_ }
		UnionType         { q.query_types(t.items) }
		Overloaded        { q.query_types(t.items.map(MypyTypeNode(it))) }
		TypeType          { q.accept(t.item) }
		PartialTypeT      { q.default_ }
		TypeAliasType     { q.visit_type_alias(&t) }
		PlaceholderType   { q.query_types(t.args) }
		RawExpressionType { q.default_ }
		TypeList          { q.query_types(t.items) }
		CallableArgument  { q.accept(t.typ) }
		EllipsisType      { q.default_ }
	}
}

pub fn (mut q BoolTypeQuery) visit_any(t &AnyType) bool          { return q.default_ }
pub fn (mut q BoolTypeQuery) visit_none_type(t &NoneType) bool   { return q.default_ }
pub fn (mut q BoolTypeQuery) visit_uninhabited_type(t &UninhabitedType) bool { return q.default_ }
pub fn (mut q BoolTypeQuery) visit_erased_type(t &ErasedType) bool { return q.default_ }
pub fn (mut q BoolTypeQuery) visit_deleted_type(t &DeletedType) bool { return q.default_ }

pub fn (mut q BoolTypeQuery) visit_type_alias(t &TypeAliasType) bool {
	if q.skip_alias_target {
		return q.query_types(t.args)
	}
	key := t.alias_name
	if key in q.seen_aliases {
		return q.default_
	}
	q.seen_aliases[key] = true
	// Would normally expand via get_proper_type; here just query args
	return q.query_types(t.args)
}


pub fn get_proper_type(typ MypyTypeNode) MypyTypeNode {
	// В Mypy это разворачивание TypeAliasType.
	// Пока заглушка: возвращаем как есть.
	return typ
}

