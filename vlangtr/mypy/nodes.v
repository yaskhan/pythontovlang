// nodes.v — Abstract syntax tree node classes
// Translated from mypy/nodes.py to V 0.5.x
//
// Key translation decisions:
//   Python class hierarchy  → V structs + interface Node
//   Optional fields (X|None) → ?X  (V option type)
//   ClassVar / Final         → module-level const
//   @abstractmethod          → interface method
//   Multiple inheritance     → embedded structs + interfaces
//   isinstance()             → V match on sum-type or `is` operator

module mypy

// ---------------------------------------------------------------------------
// Constants (replaces Python Final module-level variables)
// ---------------------------------------------------------------------------

pub const ldef = 0
pub const gdef = 1
pub const mdef = 2
pub const unbound_imported = 3

pub const reveal_type = 0
pub const reveal_locals = 1

// ---------------------------------------------------------------------------
// Context — base source-location carrier
// Replaces Python class Context with __slots__
// ---------------------------------------------------------------------------

pub struct Context {
pub mut:
	line       int = -1
	column     int = -1
	end_line   ?int
	end_column ?int
}

// set_line copies position info from another Context, or sets it from a raw int.
pub fn (mut c Context) set_line(target Context, column ?int, end_line ?int, end_column ?int) {
	c.line = target.line
	c.column = target.column
	c.end_line = target.end_line
	c.end_column = target.end_column
	if col := column {
		c.column = col
	}
	if el := end_line {
		c.end_line = el
	}
	if ec := end_column {
		c.end_column = ec
	}
}

pub fn (mut c Context) set_line_int(line int, column ?int) {
	c.line = line
	if col := column {
		c.column = col
	}
}

// ---------------------------------------------------------------------------
// Node — base for all non-type parse-tree nodes
// ---------------------------------------------------------------------------

// Node is the common interface every AST node must satisfy.
// Replaces the Python abstract Node(Context) class.
pub interface Node {
	// All nodes carry source position via embedded Context.
	get_context() Context
	// Visitor dispatch — returns !string so callers handle errors via `or`.
	accept(mut v NodeVisitor) !string
}

// ---------------------------------------------------------------------------
// Helper: NodeBase embeds Context so concrete structs don't repeat fields.
// ---------------------------------------------------------------------------

pub struct NodeBase {
pub mut:
	ctx Context
}

pub fn (n NodeBase) get_context() Context {
	return n.ctx
}

// ---------------------------------------------------------------------------
// Import nodes
// ---------------------------------------------------------------------------

// import foo [as bar], import baz
pub struct Import {
pub mut:
	base  NodeBase
	// ids: list of (module_name, optional_alias)
	ids   []ImportAlias
	is_top_level  bool
	is_unreachable bool
}

pub struct ImportAlias {
pub:
	name  string
	alias ?string
}

pub fn (mut n Import) get_context() Context { return n.base.ctx }
pub fn (mut n Import) accept(mut v NodeVisitor) !string { return v.visit_import(mut n)! }

// from foo import bar [as baz]
pub struct ImportFrom {
pub mut:
	base       NodeBase
	id         string
	relative   int
	names      []ImportAlias
	is_top_level   bool
	is_unreachable bool
}

pub fn (mut n ImportFrom) get_context() Context { return n.base.ctx }
pub fn (mut n ImportFrom) accept(mut v NodeVisitor) !string { return v.visit_import_from(mut n)! }

// from foo import *
pub struct ImportAll {
pub mut:
	base       NodeBase
	id         string
	relative   int
	is_top_level   bool
	is_unreachable bool
}

pub fn (mut n ImportAll) get_context() Context { return n.base.ctx }
pub fn (mut n ImportAll) accept(mut v NodeVisitor) !string { return v.visit_import_all(mut n)! }

// ---------------------------------------------------------------------------
pub type MypyNode = AssignmentStmt
	| Block
	| BreakStmt
	| ClassDef
	| ContinueStmt
	| Decorator
	| DelStmt
	| ExpressionStmt
	| ForStmt
	| FuncDef
	| GlobalDecl
	| IfStmt
	| Import
	| ImportAll
	| ImportFrom
	| MatchStmt
	| NonlocalDecl
	| OperatorAssignmentStmt
	| OverloadedFuncDef
	| PassStmt
	| RaiseStmt
	| ReturnStmt
	| TryStmt
	| TypeAliasStmt
	| WhileStmt
	| WithStmt
	| AssignmentExpr
	| AwaitExpr
	| BytesExpr
	| CallExpr
	| CastExpr
	| ComparisonExpr
	| ComplexExpr
	| DictExpr
	| DictComprehension
	| EllipsisExpr
	| EnumCallExpr
	| FloatExpr
	| FormatStringExpr
	| GeneratorExpr
	| IndexExpr
	| IntExpr
	| LambdaExpr
	| ListComprehension
	| ListExpr
	| MemberExpr
	| NameExpr
	| OpExpr
	| OverloadPartExpr
	| PlaceholderNode
	| PromoteExpr
	| RevealExpr
	| SetComprehension
	| SetExpr
	| SliceExpr
	| StarExpr
	| StrExpr
	| SuperExpr
	| TupleExpr
	| TypeAliasExpr
	| TypeApplication
	| UnaryExpr
	| YieldExpr
	| YieldFromExpr
	| Var
	| TypeInfo
	| Argument

// Block & basic statements
// ---------------------------------------------------------------------------

pub struct Block {
pub mut:
	base           NodeBase
	body           []Statement
	is_unreachable bool
}

pub fn (mut n Block) get_context() Context { return n.base.ctx }
pub fn (mut n Block) accept(mut v NodeVisitor) !string { return v.visit_block(mut n)! }

// Statement is a sum-type that covers every statement node.
// V sum-types must be declared with all concrete variants.
pub type Statement = AssignmentStmt
	| Block
	| BreakStmt
	| ClassDef
	| ContinueStmt
	| Decorator
	| DelStmt
	| ExpressionStmt
	| ForStmt
	| FuncDef
	| GlobalDecl
	| IfStmt
	| Import
	| ImportAll
	| ImportFrom
	| MatchStmt
	| NonlocalDecl
	| WithStmt

pub fn (s Statement) get_context() Context {
	return match s {
		AssignmentStmt { s.base.ctx }
		Block { s.base.ctx }
		BreakStmt { s.base.ctx }
		ClassDef { s.base.ctx }
		ContinueStmt { s.base.ctx }
		Decorator { s.base.ctx }
		DelStmt { s.base.ctx }
		ExpressionStmt { s.base.ctx }
		ForStmt { s.base.ctx }
		FuncDef { s.base.ctx }
		GlobalDecl { s.base.ctx }
		IfStmt { s.base.ctx }
		Import { s.base.ctx }
		ImportAll { s.base.ctx }
		ImportFrom { s.base.ctx }
		MatchStmt { s.base.ctx }
		NonlocalDecl { s.base.ctx }
		OperatorAssignmentStmt { s.base.ctx }
		OverloadedFuncDef { s.base.ctx }
		PassStmt { s.base.ctx }
		RaiseStmt { s.base.ctx }
		ReturnStmt { s.base.ctx }
		TryStmt { s.base.ctx }
		TypeAliasStmt { s.base.ctx }
		WhileStmt { s.base.ctx }
		WithStmt { s.base.ctx }
	}
}

pub fn (s Statement) accept(mut v NodeVisitor) !string {
	return match s {
		AssignmentStmt { v.visit_assignment_stmt(&s)! }
		Block { v.visit_block(&s)! }
		BreakStmt { v.visit_break_stmt(&s)! }
		ClassDef { v.visit_class_def(&s)! }
		ContinueStmt { v.visit_continue_stmt(&s)! }
		Decorator { v.visit_decorator(&s)! }
		DelStmt { v.visit_del_stmt(&s)! }
		ExpressionStmt { v.visit_expression_stmt(&s)! }
		ForStmt { v.visit_for_stmt(&s)! }
		FuncDef { v.visit_func_def(&s)! }
		GlobalDecl { v.visit_global_decl(&s)! }
		IfStmt { v.visit_if_stmt(&s)! }
		Import { v.visit_import(&s)! }
		ImportAll { v.visit_import_all(&s)! }
		ImportFrom { v.visit_import_from(&s)! }
		MatchStmt { v.visit_match_stmt(&s)! }
		NonlocalDecl { v.visit_nonlocal_decl(&s)! }
		OperatorAssignmentStmt { v.visit_operator_assignment_stmt(&s)! }
		OverloadedFuncDef { v.visit_overloaded_func_def(&s)! }
		PassStmt { v.visit_pass_stmt(&s)! }
		RaiseStmt { v.visit_raise_stmt(&s)! }
		ReturnStmt { v.visit_return_stmt(&s)! }
		TryStmt { v.visit_try_stmt(&s)! }
		TypeAliasStmt { v.visit_type_alias_stmt(&s)! }
		WhileStmt { v.visit_while_stmt(&s)! }
		WithStmt { v.visit_with_stmt(&s)! }
	}
}


// Expression sum-type
pub type Expression = AssignmentExpr
	| AwaitExpr
	| BytesExpr
	| CallExpr
	| CastExpr
	| ComparisonExpr
	| ComplexExpr
	| ConditionalExpr
	| DictExpr
	| DictionaryComprehension
	| EllipsisExpr
	| EnumCallExpr
	| FloatExpr
	| GeneratorExpr
	| IndexExpr
	| IntExpr
	| LambdaExpr
	| ListComprehension
	| ListExpr
	| MemberExpr
	| NameExpr
	| NamedTupleExpr
	| NewTypeExpr
	| OpExpr
	| ParamSpecExpr
	| PromoteExpr
	| RevealExpr
	| SetComprehension
	| SetExpr
	| SliceExpr
	| StarExpr
	| StrExpr
	| SuperExpr
	| TempNode
	| TemplateStrExpr
	| TupleExpr
	| TypeAliasExpr
	| UnaryExpr
	| YieldFromExpr

pub fn (e Expression) get_context() Context {
	return match e {
		AssignmentExpr { e.base.ctx }
		AwaitExpr { e.base.ctx }
		BytesExpr { e.base.ctx }
		CallExpr { e.base.ctx }
		CastExpr { e.base.ctx }
		ComparisonExpr { e.base.ctx }
		ComplexExpr { e.base.ctx }
		ConditionalExpr { e.base.ctx }
		DictExpr { e.base.ctx }
		DictionaryComprehension { e.base.ctx }
		EllipsisExpr { e.base.ctx }
		EnumCallExpr { e.base.ctx }
		FloatExpr { e.base.ctx }
		GeneratorExpr { e.base.ctx }
		IndexExpr { e.base.ctx }
		IntExpr { e.base.ctx }
		LambdaExpr { e.base.ctx }
		ListComprehension { e.base.ctx }
		ListExpr { e.base.ctx }
		MemberExpr { e.base.ctx }
		NameExpr { e.base.ctx }
		NamedTupleExpr { e.base.ctx }
		NewTypeExpr { e.base.ctx }
		OpExpr { e.base.ctx }
		ParamSpecExpr { e.base.ctx }
		PromoteExpr { e.base.ctx }
		RevealExpr { e.base.ctx }
		SetComprehension { e.base.ctx }
		SetExpr { e.base.ctx }
		SliceExpr { e.base.ctx }
		StarExpr { e.base.ctx }
		StrExpr { e.base.ctx }
		SuperExpr { e.base.ctx }
		TempNode { e.base.ctx }
		TemplateStrExpr { e.base.ctx }
		TupleExpr { e.base.ctx }
		TypeAliasExpr { e.base.ctx }
		TypeApplication { e.base.ctx }
		TypeVarExpr { e.base.ctx }
		TypeVarTupleExpr { e.base.ctx }
		TypedDictExpr { e.base.ctx }
		UnaryExpr { e.base.ctx }
		AssertTypeExpr { e.base.ctx }
		YieldExpr { e.base.ctx }
		YieldFromExpr { e.base.ctx }
	}
}

pub fn (e Expression) accept(mut v NodeVisitor) !string {
	return match e {
		AssignmentExpr { v.visit_assignment_expr(&e)! }
		AwaitExpr { v.visit_await_expr(&e)! }
		BytesExpr { v.visit_bytes_expr(&e)! }
		CallExpr { v.visit_call_expr(&e)! }
		CastExpr { v.visit_cast_expr(&e)! }
		ComparisonExpr { v.visit_comparison_expr(&e)! }
		ComplexExpr { v.visit_complex_expr(&e)! }
		ConditionalExpr { v.visit_conditional_expr(&e)! }
		DictExpr { v.visit_dict_expr(&e)! }
		DictionaryComprehension { v.visit_dictionary_comprehension(&e)! }
		EllipsisExpr { v.visit_ellipsis(&e)! }
		EnumCallExpr { v.visit_enum_call_expr(&e)! }
		FloatExpr { v.visit_float_expr(&e)! }
		GeneratorExpr { v.visit_generator_expr(&e)! }
		IndexExpr { v.visit_index_expr(&e)! }
		IntExpr { v.visit_int_expr(&e)! }
		LambdaExpr { v.visit_lambda_expr(&e)! }
		ListComprehension { v.visit_list_comprehension(&e)! }
		ListExpr { v.visit_list_expr(&e)! }
		MemberExpr { v.visit_member_expr(&e)! }
		NameExpr { v.visit_name_expr(&e)! }
		NamedTupleExpr { v.visit_namedtuple_expr(&e)! }
		NewTypeExpr { v.visit_newtype_expr(&e)! }
		OpExpr { v.visit_op_expr(&e)! }
		ParamSpecExpr { v.visit_paramspec_expr(&e)! }
		PromoteExpr { v.visit_promote_expr(&e)! }
		RevealExpr { v.visit_reveal_expr(&e)! }
		SetComprehension { v.visit_set_comprehension(&e)! }
		SetExpr { v.visit_set_expr(&e)! }
		SliceExpr { v.visit_slice_expr(&e)! }
		StarExpr { v.visit_star_expr(&e)! }
		StrExpr { v.visit_str_expr(&e)! }
		SuperExpr { v.visit_super_expr(&e)! }
		TempNode { v.visit_temp_node(&e)! }
		TemplateStrExpr { v.visit_template_str_expr(&e)! }
		TupleExpr { v.visit_tuple_expr(&e)! }
		TypeAliasExpr { v.visit_type_alias_expr(&e)! }
		TypeApplication { v.visit_type_application(&e)! }
		TypeVarExpr { v.visit_type_var_expr(&e)! }
		TypeVarTupleExpr { v.visit_type_var_tuple_expr(&e)! }
		TypedDictExpr { v.visit_typeddict_expr(&e)! }
		UnaryExpr { v.visit_unary_expr(&e)! }
		AssertTypeExpr { v.visit_assert_type_expr(&e)! }
		YieldExpr { v.visit_yield_expr(&e)! }
		YieldFromExpr { v.visit_yield_from_expr(&e)! }
	}
}


// ---------------------------------------------------------------------------
// Simple statement nodes
// ---------------------------------------------------------------------------

pub struct ExpressionStmt {
pub mut:
	base NodeBase
	expr Expression
}
pub fn (mut n ExpressionStmt) get_context() Context { return n.base.ctx }
pub fn (mut n ExpressionStmt) accept(mut v NodeVisitor) !string { return v.visit_expression_stmt(mut n)! }

pub struct AssignmentStmt {
pub mut:
	base     NodeBase
	lvalues  []Expression
	rvalue   Expression
	// type annotation if present
	type_annotation ?MypyTypeNode
	is_final_def bool
	is_alias_def bool
}
pub fn (mut n AssignmentStmt) get_context() Context { return n.base.ctx }
pub fn (mut n AssignmentStmt) accept(mut v NodeVisitor) !string { return v.visit_assignment_stmt(mut n)! }

pub struct OperatorAssignmentStmt {
pub mut:
	base   NodeBase
	op     string
	lvalue Expression
	rvalue Expression
}
pub fn (mut n OperatorAssignmentStmt) get_context() Context { return n.base.ctx }
pub fn (mut n OperatorAssignmentStmt) accept(mut v NodeVisitor) !string { return v.visit_operator_assignment_stmt(mut n)! }

pub struct WhileStmt {
pub mut:
	base      NodeBase
	expr      Expression
	body      Block
	else_body ?Block
}
pub fn (mut n WhileStmt) get_context() Context { return n.base.ctx }
pub fn (mut n WhileStmt) accept(mut v NodeVisitor) !string { return v.visit_while_stmt(mut n)! }

pub struct ForStmt {
pub mut:
	base           NodeBase
	index          Expression
	index_type     ?MypyTypeNode
	iter           Expression
	body           Block
	else_body      ?Block
	is_async       bool
}
pub fn (mut n ForStmt) get_context() Context { return n.base.ctx }
pub fn (mut n ForStmt) accept(mut v NodeVisitor) !string { return v.visit_for_stmt(mut n)! }

pub struct ReturnStmt {
pub mut:
	base NodeBase
	expr ?Expression
}
pub fn (mut n ReturnStmt) get_context() Context { return n.base.ctx }
pub fn (mut n ReturnStmt) accept(mut v NodeVisitor) !string { return v.visit_return_stmt(mut n)! }

pub struct AssertStmt {
pub mut:
	base NodeBase
	expr Expression
	msg  ?Expression
}
pub fn (mut n AssertStmt) get_context() Context { return n.base.ctx }
pub fn (mut n AssertStmt) accept(mut v NodeVisitor) !string { return v.visit_assert_stmt(mut n)! }

pub struct DelStmt {
pub mut:
	base NodeBase
	expr Expression
}
pub fn (mut n DelStmt) get_context() Context { return n.base.ctx }
pub fn (mut n DelStmt) accept(mut v NodeVisitor) !string { return v.visit_del_stmt(mut n)! }

pub struct BreakStmt {
pub mut:
	base NodeBase
}
pub fn (mut n BreakStmt) get_context() Context { return n.base.ctx }
pub fn (mut n BreakStmt) accept(mut v NodeVisitor) !string { return v.visit_break_stmt(mut n)! }

pub struct ContinueStmt {
pub mut:
	base NodeBase
}
pub fn (mut n ContinueStmt) get_context() Context { return n.base.ctx }
pub fn (mut n ContinueStmt) accept(mut v NodeVisitor) !string { return v.visit_continue_stmt(mut n)! }

pub struct PassStmt {
pub mut:
	base NodeBase
}
pub fn (mut n PassStmt) get_context() Context { return n.base.ctx }
pub fn (mut n PassStmt) accept(mut v NodeVisitor) !string { return v.visit_pass_stmt(mut n)! }

pub struct IfStmt {
pub mut:
	base      NodeBase
	expr      []Expression
	body      []Block
	else_body ?Block
}
pub fn (mut n IfStmt) get_context() Context { return n.base.ctx }
pub fn (mut n IfStmt) accept(mut v NodeVisitor) !string { return v.visit_if_stmt(mut n)! }

pub struct RaiseStmt {
pub mut:
	base      NodeBase
	expr      ?Expression
	from_expr ?Expression
}
pub fn (mut n RaiseStmt) get_context() Context { return n.base.ctx }
pub fn (mut n RaiseStmt) accept(mut v NodeVisitor) !string { return v.visit_raise_stmt(mut n)! }

pub struct TryStmt {
pub mut:
	base        NodeBase
	body        Block
	// parallel arrays: types[i] matches vars[i] (var may be absent)
	types       []?Expression
	vars        []?NameExpr
	handlers    []Block
	else_body   ?Block
	finally_body ?Block
}
pub fn (mut n TryStmt) get_context() Context { return n.base.ctx }
pub fn (mut n TryStmt) accept(mut v NodeVisitor) !string { return v.visit_try_stmt(mut n)! }

pub struct WithStmt {
pub mut:
	base      NodeBase
	expr      []Expression
	target    []?Expression
	body      Block
	is_async  bool
}
pub fn (mut n WithStmt) get_context() Context { return n.base.ctx }
pub fn (mut n WithStmt) accept(mut v NodeVisitor) !string { return v.visit_with_stmt(mut n)! }

pub struct MatchStmt {
pub mut:
	base     NodeBase
	subject  Expression
	patterns []Pattern
	guards   []?Expression
	bodies   []Block
}
pub fn (mut n MatchStmt) get_context() Context { return n.base.ctx }
pub fn (mut n MatchStmt) accept(mut v NodeVisitor) !string { return v.visit_match_stmt(mut n)! }

pub struct GlobalDecl {
pub mut:
	base  NodeBase
	names []string
}
pub fn (mut n GlobalDecl) get_context() Context { return n.base.ctx }
pub fn (mut n GlobalDecl) accept(mut v NodeVisitor) !string { return v.visit_global_decl(mut n)! }

pub struct NonlocalDecl {
pub mut:
	base  NodeBase
	names []string
}
pub fn (mut n NonlocalDecl) get_context() Context { return n.base.ctx }
pub fn (mut n NonlocalDecl) accept(mut v NodeVisitor) !string { return v.visit_nonlocal_decl(mut n)! }

pub struct TypeAliasStmt {
pub mut:
	base       NodeBase
	name       NameExpr
	type_args  []TypeParam
	value      Expression
}
pub fn (mut n TypeAliasStmt) get_context() Context { return n.base.ctx }
pub fn (mut n TypeAliasStmt) accept(mut v NodeVisitor) !string { return v.visit_type_alias_stmt(mut n)! }

// ---------------------------------------------------------------------------
// Function & class definitions
// ---------------------------------------------------------------------------

// ArgKind replaces the Python ArgKind enum
pub enum ArgKind {
	arg_pos       // ordinary positional
	arg_opt       // optional positional
	arg_star      // *args
	arg_named     // keyword-only
	arg_named_opt // optional keyword-only
	arg_star2     // **kwargs
}

pub struct Argument {
pub mut:
	base            NodeBase
	variable        Var
	type_annotation ?MypyTypeNode
	initializer     ?Expression
	kind            ArgKind
	pos_only        bool
}

pub struct TypeParam {
pub:
	name        string
	kind        int    // 0=TypeVar, 1=ParamSpec, 2=TypeVarTuple
	upper_bound ?MypyTypeNode
	default     ?MypyTypeNode
}

// FuncDef — a single function or method definition
pub struct FuncDef {
pub mut:
	base            NodeBase
	name            string        // unqualified name
	arguments       []Argument
	arg_names       []?string
	arg_kinds       []ArgKind
	body            Block
	type_           ?MypyTypeNode     // full callable type if known
	is_overload     bool
	is_generator    bool
	is_coroutine    bool
	is_async_generator bool
	is_decorated    bool
	is_stub         bool
	is_final        bool
	is_class        bool          // @classmethod
	is_static       bool         // @staticmethod
	is_property     bool
	is_settable_property bool
	is_explicit_override bool
	type_params     []TypeParam
	fullname        string
	abstract_status int // 0=concrete, 1=abstract, 2=implicitly_abstract
}

pub fn (mut n FuncDef) get_context() Context { return n.base.ctx }
pub fn (mut n FuncDef) accept(mut v NodeVisitor) !string { return v.visit_func_def(mut n)! }

pub struct OverloadedFuncDef {
pub mut:
	base     NodeBase
	items    []FuncDef
	type_    ?MypyTypeNode
	fullname string
	is_final bool
	is_static bool
	is_class  bool
	is_property bool
}
pub fn (mut n OverloadedFuncDef) get_context() Context { return n.base.ctx }
pub fn (mut n OverloadedFuncDef) accept(mut v NodeVisitor) !string { return v.visit_overloaded_func_def(mut n)! }

pub struct Decorator {
pub mut:
	base       NodeBase
	func       FuncDef
	decorators []Expression
	var_        Var
	is_overload bool
}
pub fn (mut n Decorator) get_context() Context { return n.base.ctx }
pub fn (mut n Decorator) accept(mut v NodeVisitor) !string { return v.visit_decorator(mut n)! }

// Var — a variable / field / parameter
pub struct Var {
pub mut:
	base               NodeBase
	name               string
	fullname           string
	type_              ?MypyTypeNode
	is_self            bool
	is_cls             bool
	is_ready           bool
	is_initialized_in_class bool
	is_staticmethod    bool
	is_classvar        bool
	is_property        bool
	is_settable_property bool
	is_final           bool
	is_inferred        bool
	final_value        ?Expression
	explicit_self_type ?MypyTypeNode
	is_abstract_var    bool
	has_explicit_value bool
	info               ?&TypeInfo
}
pub fn (mut n Var) get_context() Context { return n.base.ctx }
pub fn (mut n &Var) accept(mut v NodeVisitor) !string { return v.visit_var(mut n)! }

pub struct ClassDef {
pub mut:
	base         NodeBase
	name         string
	fullname     string
	defs         Block
	type_vars    []MypyTypeNode
	base_type_exprs []Expression
	removed_base_type_exprs []Expression
	metaclass    ?string
	decorators   []Expression
	info         ?&TypeInfo

	keywords     map[string]Expression
	is_protocol  bool
	is_abstract  bool
	has_incompatible_baseclass bool
	type_params  []TypeParam
}
pub fn (mut n ClassDef) get_context() Context { return n.base.ctx }
pub fn (mut n ClassDef) accept(mut v NodeVisitor) !string { return v.visit_class_def(mut n)! }

// ---------------------------------------------------------------------------
// Expression nodes
// ---------------------------------------------------------------------------

pub struct IntExpr {
pub mut:
	base  NodeBase
	value i64
}
pub fn (mut n IntExpr) get_context() Context { return n.base.ctx }
pub fn (mut n IntExpr) accept(mut v NodeVisitor) !string { return v.visit_int_expr(mut n)! }

pub struct StrExpr {
pub mut:
	base  NodeBase
	value string
}
pub fn (mut n StrExpr) get_context() Context { return n.base.ctx }
pub fn (mut n StrExpr) accept(mut v NodeVisitor) !string { return v.visit_str_expr(mut n)! }

pub struct BytesExpr {
pub mut:
	base  NodeBase
	// stored as hex or escaped string, same as Python's bytes repr
	value string
}
pub fn (mut n BytesExpr) get_context() Context { return n.base.ctx }
pub fn (mut n BytesExpr) accept(mut v NodeVisitor) !string { return v.visit_bytes_expr(mut n)! }

pub struct FloatExpr {
pub mut:
	base  NodeBase
	value f64
}
pub fn (mut n FloatExpr) get_context() Context { return n.base.ctx }
pub fn (mut n FloatExpr) accept(mut v NodeVisitor) !string { return v.visit_float_expr(mut n)! }

pub struct ComplexExpr {
pub mut:
	base  NodeBase
	real  f64
	imag  f64
}
pub fn (mut n ComplexExpr) get_context() Context { return n.base.ctx }
pub fn (mut n ComplexExpr) accept(mut v NodeVisitor) !string { return v.visit_complex_expr(mut n)! }

pub struct EllipsisExpr {
pub mut:
	base NodeBase
}
pub fn (mut n EllipsisExpr) get_context() Context { return n.base.ctx }
pub fn (mut n EllipsisExpr) accept(mut v NodeVisitor) !string { return v.visit_ellipsis(mut n)! }

pub struct StarExpr {
pub mut:
	base NodeBase
	expr Expression
	// True when used inside a type annotation
	valid bool
}
pub fn (mut n StarExpr) get_context() Context { return n.base.ctx }
pub fn (mut n StarExpr) accept(mut v NodeVisitor) !string { return v.visit_star_expr(mut n)! }

// NameExpr — a bare identifier reference
pub struct NameExpr {
pub mut:
	base            NodeBase
	name            string
	fullname        string
	kind            int = ldef
	node            ?SymbolNodeRef
	is_special_form bool
}
pub fn (mut n NameExpr) get_context() Context { return n.base.ctx }
pub fn (mut n NameExpr) accept(mut v NodeVisitor) !string { return v.visit_name_expr(mut n)! }

// RefExpr — a reference expression (NameExpr or MemberExpr)
pub type RefExpr = NameExpr | MemberExpr

// SymbolNodeRef wraps resolved references to avoid circular sum-type issues.
pub type SymbolNodeRef = ClassDef | Decorator | FuncDef | MypyFile | OverloadedFuncDef | TypeAlias | TypeInfo | Var

pub fn (mut n SymbolNodeRef) fullname() string {
	return match n {
		ClassDef { n.fullname }
		Decorator { n.func.fullname }
		FuncDef { n.fullname }
		MypyFile { n.fullname }
		OverloadedFuncDef { n.fullname }
		TypeAlias { n.fullname }
		TypeInfo { n.fullname }
		Var { n.fullname }
	}
}

pub struct MemberExpr {
pub mut:
	base            NodeBase
	expr            Expression
	name            string
	fullname        ?string
	kind            int = ldef
	node            ?SymbolNodeRef
	is_inferred_def bool
	def_var         ?Var
}
pub fn (mut n MemberExpr) get_context() Context { return n.base.ctx }
pub fn (mut n MemberExpr) accept(mut v NodeVisitor) !string { return v.visit_member_expr(mut n)! }

pub struct YieldFromExpr {
pub mut:
	base NodeBase
	expr Expression
}
pub fn (mut n YieldFromExpr) get_context() Context { return n.base.ctx }
pub fn (mut n YieldFromExpr) accept(mut v NodeVisitor) !string { return v.visit_yield_from_expr(mut n)! }

pub struct YieldExpr {
pub mut:
	base NodeBase
	expr ?Expression
}
pub fn (mut n YieldExpr) get_context() Context { return n.base.ctx }
pub fn (mut n YieldExpr) accept(mut v NodeVisitor) !string { return v.visit_yield_expr(mut n)! }

pub struct CallExpr {
pub mut:
	base      NodeBase
	callee    Expression
	args      []Expression
	arg_kinds []ArgKind
	arg_names []?string
}
pub fn (mut n CallExpr) get_context() Context { return n.base.ctx }
pub fn (mut n CallExpr) accept(mut v NodeVisitor) !string { return v.visit_call_expr(mut n)! }

pub struct IndexExpr {
pub mut:
	base   NodeBase
	base_  Expression
	index  Expression
	// analyzed type if this is a type alias or similar
	analyzed ?Expression
}
pub fn (mut n IndexExpr) get_context() Context { return n.base.ctx }
pub fn (mut n IndexExpr) accept(mut v NodeVisitor) !string { return v.visit_index_expr(mut n)! }

pub struct UnaryExpr {
pub mut:
	base NodeBase
	op   string
	expr Expression
}
pub fn (mut n UnaryExpr) get_context() Context { return n.base.ctx }
pub fn (mut n UnaryExpr) accept(mut v NodeVisitor) !string { return v.visit_unary_expr(mut n)! }

pub struct AssignmentExpr {
pub mut:
	base   NodeBase
	target NameExpr
	value  Expression
}
pub fn (mut n AssignmentExpr) get_context() Context { return n.base.ctx }
pub fn (mut n AssignmentExpr) accept(mut v NodeVisitor) !string { return v.visit_assignment_expr(mut n)! }

pub struct OpExpr {
pub mut:
	base       NodeBase
	op         string
	left       Expression
	right      Expression
	// right operand type after analysis (used for `in`/`not in`)
	right_type ?MypyTypeNode
}
pub fn (mut n OpExpr) get_context() Context { return n.base.ctx }
pub fn (mut n OpExpr) accept(mut v NodeVisitor) !string { return v.visit_op_expr(mut n)! }

pub struct ComparisonExpr {
pub mut:
	base      NodeBase
	operators []string
	operands  []Expression
}
pub fn (mut n ComparisonExpr) get_context() Context { return n.base.ctx }
pub fn (mut n ComparisonExpr) accept(mut v NodeVisitor) !string { return v.visit_comparison_expr(mut n)! }

pub struct SliceExpr {
pub mut:
	base       NodeBase
	begin_index ?Expression
	end_index   ?Expression
	stride      ?Expression
}
pub fn (mut n SliceExpr) get_context() Context { return n.base.ctx }
pub fn (mut n SliceExpr) accept(mut v NodeVisitor) !string { return v.visit_slice_expr(mut n)! }

pub struct CastExpr {
pub mut:
	base NodeBase
	expr Expression
	type_ MypyTypeNode
}
pub fn (mut n CastExpr) get_context() Context { return n.base.ctx }
pub fn (mut n CastExpr) accept(mut v NodeVisitor) !string { return v.visit_cast_expr(mut n)! }

pub struct AssertTypeExpr {
pub mut:
	base  NodeBase
	expr  Expression
	type_ MypyTypeNode
}
pub fn (mut n AssertTypeExpr) get_context() Context { return n.base.ctx }
pub fn (mut n AssertTypeExpr) accept(mut v NodeVisitor) !string { return v.visit_assert_type_expr(mut n)! }

pub struct RevealExpr {
pub mut:
	base   NodeBase
	kind   int   // reveal_type or reveal_locals
	expr   ?Expression
	is_imported bool
}
pub fn (mut n RevealExpr) get_context() Context { return n.base.ctx }
pub fn (mut n RevealExpr) accept(mut v NodeVisitor) !string { return v.visit_reveal_expr(mut n)! }

pub struct SuperExpr {
pub mut:
	base   NodeBase
	name   string
	info   ?TypeInfo
}
pub fn (mut n SuperExpr) get_context() Context { return n.base.ctx }
pub fn (mut n SuperExpr) accept(mut v NodeVisitor) !string { return v.visit_super_expr(mut n)! }

pub struct ListExpr {
pub mut:
	base  NodeBase
	items []Expression
}
pub fn (mut n ListExpr) get_context() Context { return n.base.ctx }
pub fn (mut n ListExpr) accept(mut v NodeVisitor) !string { return v.visit_list_expr(mut n)! }

pub struct DictExpr {
pub mut:
	base  NodeBase
	// key is none for **spread entries
	items []DictItem
}

pub struct DictItem {
pub:
	key   ?Expression
	value Expression
}

pub fn (mut n DictExpr) get_context() Context { return n.base.ctx }
pub fn (mut n DictExpr) accept(mut v NodeVisitor) !string { return v.visit_dict_expr(mut n)! }

// f-strings / template strings (Python TemplateStrExpr / JoinedStr)
pub struct TemplateStrExpr {
pub mut:
	base  NodeBase
	parts []Expression
}
pub fn (mut n TemplateStrExpr) get_context() Context { return n.base.ctx }
pub fn (mut n TemplateStrExpr) accept(mut v NodeVisitor) !string { return v.visit_template_str_expr(mut n)! }

pub struct TupleExpr {
pub mut:
	base  NodeBase
	items []Expression
}
pub fn (mut n TupleExpr) get_context() Context { return n.base.ctx }
pub fn (mut n TupleExpr) accept(mut v NodeVisitor) !string { return v.visit_tuple_expr(mut n)! }

pub struct SetExpr {
pub mut:
	base  NodeBase
	items []Expression
}
pub fn (mut n SetExpr) get_context() Context { return n.base.ctx }
pub fn (mut n SetExpr) accept(mut v NodeVisitor) !string { return v.visit_set_expr(mut n)! }

// GeneratorExpr covers both generator expressions and all comprehension types.
pub struct GeneratorExpr {
pub mut:
	base          NodeBase
	left_expr     Expression
	indices       []Expression
	sequences     []Expression
	condlists     [][]Expression
	is_async      []bool
}
pub fn (mut n GeneratorExpr) get_context() Context { return n.base.ctx }
pub fn (mut n GeneratorExpr) accept(mut v NodeVisitor) !string { return v.visit_generator_expr(mut n)! }

pub struct ListComprehension {
pub mut:
	base NodeBase
	generator GeneratorExpr
}
pub fn (mut n ListComprehension) get_context() Context { return n.base.ctx }
pub fn (mut n ListComprehension) accept(mut v NodeVisitor) !string { return v.visit_list_comprehension(mut n)! }

pub struct SetComprehension {
pub mut:
	base NodeBase
	generator GeneratorExpr
}
pub fn (mut n SetComprehension) get_context() Context { return n.base.ctx }
pub fn (mut n SetComprehension) accept(mut v NodeVisitor) !string { return v.visit_set_comprehension(mut n)! }

pub struct DictionaryComprehension {
pub mut:
	base      NodeBase
	key       Expression
	value     Expression
	indices   []Expression
	sequences []Expression
	condlists [][]Expression
	is_async  []bool
}
pub fn (mut n DictionaryComprehension) get_context() Context { return n.base.ctx }
pub fn (mut n DictionaryComprehension) accept(mut v NodeVisitor) !string { return v.visit_dictionary_comprehension(mut n)! }

pub struct ConditionalExpr {
pub mut:
	base      NodeBase
	cond      Expression
	if_expr   Expression
	else_expr Expression
}
pub fn (mut n ConditionalExpr) get_context() Context { return n.base.ctx }
pub fn (mut n ConditionalExpr) accept(mut v NodeVisitor) !string { return v.visit_conditional_expr(mut n)! }

pub struct TypeApplication {
pub mut:
	base   NodeBase
	expr   Expression
	types  []MypyTypeNode
}
pub fn (mut n TypeApplication) get_context() Context { return n.base.ctx }
pub fn (mut n TypeApplication) accept(mut v NodeVisitor) !string { return v.visit_type_application(mut n)! }

pub struct LambdaExpr {
pub mut:
	base      NodeBase
	arguments []Argument
	arg_names []?string
	arg_kinds []ArgKind
	body      Expression
	type_     ?MypyTypeNode
}
pub fn (mut n LambdaExpr) get_context() Context { return n.base.ctx }
pub fn (mut n LambdaExpr) accept(mut v NodeVisitor) !string { return v.visit_lambda_expr(mut n)! }

// Type variable / special-form expression nodes
pub struct TypeVarExpr {
pub mut:
	base        NodeBase
	name        string
	fullname    string
	values      []MypyTypeNode
	upper_bound MypyTypeNode
	default_    MypyTypeNode
	variance    int
}
pub fn (mut n TypeVarExpr) get_context() Context { return n.base.ctx }
pub fn (mut n TypeVarExpr) accept(mut v NodeVisitor) !string { return v.visit_type_var_expr(mut n)! }

pub struct ParamSpecExpr {
pub mut:
	base     NodeBase
	name     string
	fullname string
	upper_bound MypyTypeNode
	default_ MypyTypeNode
}
pub fn (mut n ParamSpecExpr) get_context() Context { return n.base.ctx }
pub fn (mut n ParamSpecExpr) accept(mut v NodeVisitor) !string { return v.visit_paramspec_expr(mut n)! }

pub struct TypeVarTupleExpr {
pub mut:
	base     NodeBase
	name     string
	fullname string
	upper_bound MypyTypeNode
	default_ MypyTypeNode
}
pub fn (mut n TypeVarTupleExpr) get_context() Context { return n.base.ctx }
pub fn (mut n TypeVarTupleExpr) accept(mut v NodeVisitor) !string { return v.visit_type_var_tuple_expr(mut n)! }

pub struct TypeAliasExpr {
pub mut:
	base  NodeBase
	node  TypeAlias
}
pub fn (mut n TypeAliasExpr) get_context() Context { return n.base.ctx }
pub fn (mut n TypeAliasExpr) accept(mut v NodeVisitor) !string { return v.visit_type_alias_expr(mut n)! }

pub struct NamedTupleExpr {
pub mut:
	base    NodeBase
	info    TypeInfo
	is_typed_dict bool
}
pub fn (mut n NamedTupleExpr) get_context() Context { return n.base.ctx }
pub fn (mut n NamedTupleExpr) accept(mut v NodeVisitor) !string { return v.visit_namedtuple_expr(mut n)! }

pub struct TypedDictExpr {
pub mut:
	base NodeBase
	info TypeInfo
}
pub fn (mut n TypedDictExpr) get_context() Context { return n.base.ctx }
pub fn (mut n TypedDictExpr) accept(mut v NodeVisitor) !string { return v.visit_typeddict_expr(mut n)! }

pub struct EnumCallExpr {
pub mut:
	base     NodeBase
	info     TypeInfo
	items    []string
	values   []?Expression
}
pub fn (mut n EnumCallExpr) get_context() Context { return n.base.ctx }
pub fn (mut n EnumCallExpr) accept(mut v NodeVisitor) !string { return v.visit_enum_call_expr(mut n)! }

pub struct PromoteExpr {
pub mut:
	base  NodeBase
	type_ MypyTypeNode
}
pub fn (mut n PromoteExpr) get_context() Context { return n.base.ctx }
pub fn (mut n PromoteExpr) accept(mut v NodeVisitor) !string { return v.visit_promote_expr(mut n)! }

pub struct NewTypeExpr {
pub mut:
	base     NodeBase
	name     string
	old_type ?MypyTypeNode
	info     ?TypeInfo
}
pub fn (mut n NewTypeExpr) get_context() Context { return n.base.ctx }
pub fn (mut n NewTypeExpr) accept(mut v NodeVisitor) !string { return v.visit_newtype_expr(mut n)! }

pub struct AwaitExpr {
pub mut:
	base NodeBase
	expr Expression
}
pub fn (mut n AwaitExpr) get_context() Context { return n.base.ctx }
pub fn (mut n AwaitExpr) accept(mut v NodeVisitor) !string { return v.visit_await_expr(mut n)! }

// TempNode is a placeholder node created during semantic analysis
pub struct TempNode {
pub mut:
	base      NodeBase
	type_     MypyTypeNode
	no_rhs    bool
	context   ?Node
}
pub fn (mut n TempNode) get_context() Context { return n.base.ctx }
pub fn (mut n TempNode) accept(mut v NodeVisitor) !string { return v.visit_temp_node(mut n)! }

// ---------------------------------------------------------------------------
// Top-level file node
// ---------------------------------------------------------------------------

pub struct MypyFile {
pub mut:
	base           NodeBase
	defs           []Statement
	path           string
	fullpath       string
	fullname       string
	is_stub        bool
	is_partial_stub_package bool
	names          SymbolTable
	imports        []ImportBase
	is_bom         bool
	plugin_deps    map[string]bool
}

// ImportBase is the interface for Import, ImportFrom, ImportAll
pub interface ImportBase {
	get_context() Context
}

pub fn (mut n MypyFile) get_context() Context { return n.base.ctx }
pub fn (mut n &MypyFile) accept(mut v NodeVisitor) !string { return v.visit_mypy_file(mut n)! }

// ---------------------------------------------------------------------------
// Symbol table
// ---------------------------------------------------------------------------

pub enum SymbolKind {
	ldef
	gdef
	mdef
	unbound_imported
}

pub struct SymbolTableNode {
pub mut:
	kind       SymbolKind
	node       ?SymbolNodeRef
	module_public bool
	module_hidden bool
	implicit   bool
	plugin_generated bool
	no_serialize bool
}

pub struct SymbolTable {
pub mut:
	symbols map[string]SymbolTableNode
}

// ---------------------------------------------------------------------------
// TypeInfo — the semantic representation of a class (stub only here;
// full detail lives in the type-checker layer)
// ---------------------------------------------------------------------------

pub struct TypeInfo {
pub mut:
	base      NodeBase
	name      string
	fullname  string
	module_name string
	// whether this is a named tuple, protocol, etc.
	is_abstract   bool
	is_protocol   bool
	is_named_tuple bool
	is_enum       bool
	is_newtype     bool
	has_type_var_tuple_type bool
	names         SymbolTable
	defn          ?&ClassDef
	// mro: method resolution order (list of TypeInfo components)
	mro           []&TypeInfo

	type_vars     []MypyTypeNode
	bases         []Instance
	abstract_attributes []string
	typeddict_type      ?MypyTypeNode
	declared_metaclass  ?Instance
	is_final            bool
	tuple_type          ?&TupleType
	metaclass_type      ?&Instance
}



// TypeAlias — a type alias node in the symbol table
pub struct TypeAlias {
pub mut:
	base         NodeBase
	target       MypyTypeNode
	name         string
	fullname     string
	alias_tvars  []string
	no_args      bool
	eager        bool
}
pub fn (mut n TypeAlias) get_context() Context { return n.base.ctx }
pub fn (mut n &TypeAlias) accept(mut v NodeVisitor) !string { return v.visit_type_alias(mut n)! }
pub fn (mut i TypeInfo) has_base(fullname string) bool {
	for it in i.mro {
		if it.fullname == fullname { return true }
	}
	return false
}

// PlaceholderNode — for names not yet fully resolved during semanal
pub struct PlaceholderNode {
pub mut:
	base         NodeBase
	fullname     string
	node         Node
	becomes_typeinfo bool
}
pub fn (mut n PlaceholderNode) get_context() Context { return n.base.ctx }
pub fn (mut n &PlaceholderNode) accept(mut v NodeVisitor) !string { return v.visit_placeholder_node(mut n)! }

// ---------------------------------------------------------------------------
// MypyTypeNode — opaque wrapper used in nodes to avoid a circular import with
// types.v. The real type hierarchy lives in types.v.
// ---------------------------------------------------------------------------

// MypyTypeNode is an interface so that types.v can implement it fully.
pub interface MypyTypeNode {
	accept(mut v TypeVisitor) !string
}

// Pattern is an interface implemented by all match-pattern nodes in patterns.v.
pub interface Pattern {
	get_context() Context
}
