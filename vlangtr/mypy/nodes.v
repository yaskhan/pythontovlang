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
	accept(v NodeVisitor) !string
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

pub fn (n &Import) get_context() Context { return n.base.ctx }
pub fn (n &Import) accept(v NodeVisitor) !string { return v.visit_import(n)! }

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

pub fn (n &ImportFrom) get_context() Context { return n.base.ctx }
pub fn (n &ImportFrom) accept(v NodeVisitor) !string { return v.visit_import_from(n)! }

// from foo import *
pub struct ImportAll {
pub mut:
	base       NodeBase
	id         string
	relative   int
	is_top_level   bool
	is_unreachable bool
}

pub fn (n &ImportAll) get_context() Context { return n.base.ctx }
pub fn (n &ImportAll) accept(v NodeVisitor) !string { return v.visit_import_all(n)! }

// ---------------------------------------------------------------------------
// Block & basic statements
// ---------------------------------------------------------------------------

pub struct Block {
pub mut:
	base           NodeBase
	body           []Statement
	is_unreachable bool
}

pub fn (n &Block) get_context() Context { return n.base.ctx }
pub fn (n &Block) accept(v NodeVisitor) !string { return v.visit_block(n)! }

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
	| OperatorAssignmentStmt
	| OverloadedFuncDef
	| PassStmt
	| RaiseStmt
	| ReturnStmt
	| TryStmt
	| TypeAliasStmt
	| WhileStmt
	| WithStmt

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
	| TypeApplication
	| TypeVarExpr
	| TypeVarTupleExpr
	| TypedDictExpr
	| UnaryExpr
	| AssertTypeExpr
	| YieldExpr
	| YieldFromExpr

// ---------------------------------------------------------------------------
// Simple statement nodes
// ---------------------------------------------------------------------------

pub struct ExpressionStmt {
pub mut:
	base NodeBase
	expr Expression
}
pub fn (n &ExpressionStmt) get_context() Context { return n.base.ctx }
pub fn (n &ExpressionStmt) accept(v NodeVisitor) !string { return v.visit_expression_stmt(n)! }

pub struct AssignmentStmt {
pub mut:
	base     NodeBase
	lvalues  []Expression
	rvalue   Expression
	// type annotation if present
	type_annotation ?MypyType
	is_final_def bool
	is_alias_def bool
}
pub fn (n &AssignmentStmt) get_context() Context { return n.base.ctx }
pub fn (n &AssignmentStmt) accept(v NodeVisitor) !string { return v.visit_assignment_stmt(n)! }

pub struct OperatorAssignmentStmt {
pub mut:
	base   NodeBase
	op     string
	lvalue Expression
	rvalue Expression
}
pub fn (n &OperatorAssignmentStmt) get_context() Context { return n.base.ctx }
pub fn (n &OperatorAssignmentStmt) accept(v NodeVisitor) !string { return v.visit_operator_assignment_stmt(n)! }

pub struct WhileStmt {
pub mut:
	base      NodeBase
	expr      Expression
	body      Block
	else_body ?Block
}
pub fn (n &WhileStmt) get_context() Context { return n.base.ctx }
pub fn (n &WhileStmt) accept(v NodeVisitor) !string { return v.visit_while_stmt(n)! }

pub struct ForStmt {
pub mut:
	base           NodeBase
	index          Expression
	index_type     ?MypyType
	iter           Expression
	body           Block
	else_body      ?Block
	is_async       bool
}
pub fn (n &ForStmt) get_context() Context { return n.base.ctx }
pub fn (n &ForStmt) accept(v NodeVisitor) !string { return v.visit_for_stmt(n)! }

pub struct ReturnStmt {
pub mut:
	base NodeBase
	expr ?Expression
}
pub fn (n &ReturnStmt) get_context() Context { return n.base.ctx }
pub fn (n &ReturnStmt) accept(v NodeVisitor) !string { return v.visit_return_stmt(n)! }

pub struct AssertStmt {
pub mut:
	base NodeBase
	expr Expression
	msg  ?Expression
}
pub fn (n &AssertStmt) get_context() Context { return n.base.ctx }
pub fn (n &AssertStmt) accept(v NodeVisitor) !string { return v.visit_assert_stmt(n)! }

pub struct DelStmt {
pub mut:
	base NodeBase
	expr Expression
}
pub fn (n &DelStmt) get_context() Context { return n.base.ctx }
pub fn (n &DelStmt) accept(v NodeVisitor) !string { return v.visit_del_stmt(n)! }

pub struct BreakStmt {
pub mut:
	base NodeBase
}
pub fn (n &BreakStmt) get_context() Context { return n.base.ctx }
pub fn (n &BreakStmt) accept(v NodeVisitor) !string { return v.visit_break_stmt(n)! }

pub struct ContinueStmt {
pub mut:
	base NodeBase
}
pub fn (n &ContinueStmt) get_context() Context { return n.base.ctx }
pub fn (n &ContinueStmt) accept(v NodeVisitor) !string { return v.visit_continue_stmt(n)! }

pub struct PassStmt {
pub mut:
	base NodeBase
}
pub fn (n &PassStmt) get_context() Context { return n.base.ctx }
pub fn (n &PassStmt) accept(v NodeVisitor) !string { return v.visit_pass_stmt(n)! }

pub struct IfStmt {
pub mut:
	base      NodeBase
	expr      []Expression
	body      []Block
	else_body ?Block
}
pub fn (n &IfStmt) get_context() Context { return n.base.ctx }
pub fn (n &IfStmt) accept(v NodeVisitor) !string { return v.visit_if_stmt(n)! }

pub struct RaiseStmt {
pub mut:
	base      NodeBase
	expr      ?Expression
	from_expr ?Expression
}
pub fn (n &RaiseStmt) get_context() Context { return n.base.ctx }
pub fn (n &RaiseStmt) accept(v NodeVisitor) !string { return v.visit_raise_stmt(n)! }

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
pub fn (n &TryStmt) get_context() Context { return n.base.ctx }
pub fn (n &TryStmt) accept(v NodeVisitor) !string { return v.visit_try_stmt(n)! }

pub struct WithStmt {
pub mut:
	base      NodeBase
	expr      []Expression
	target    []?Expression
	body      Block
	is_async  bool
}
pub fn (n &WithStmt) get_context() Context { return n.base.ctx }
pub fn (n &WithStmt) accept(v NodeVisitor) !string { return v.visit_with_stmt(n)! }

pub struct MatchStmt {
pub mut:
	base     NodeBase
	subject  Expression
	patterns []Pattern
	guards   []?Expression
	bodies   []Block
}
pub fn (n &MatchStmt) get_context() Context { return n.base.ctx }
pub fn (n &MatchStmt) accept(v NodeVisitor) !string { return v.visit_match_stmt(n)! }

pub struct GlobalDecl {
pub mut:
	base  NodeBase
	names []string
}
pub fn (n &GlobalDecl) get_context() Context { return n.base.ctx }
pub fn (n &GlobalDecl) accept(v NodeVisitor) !string { return v.visit_global_decl(n)! }

pub struct NonlocalDecl {
pub mut:
	base  NodeBase
	names []string
}
pub fn (n &NonlocalDecl) get_context() Context { return n.base.ctx }
pub fn (n &NonlocalDecl) accept(v NodeVisitor) !string { return v.visit_nonlocal_decl(n)! }

pub struct TypeAliasStmt {
pub mut:
	base       NodeBase
	name       NameExpr
	type_args  []TypeParam
	value      Expression
}
pub fn (n &TypeAliasStmt) get_context() Context { return n.base.ctx }
pub fn (n &TypeAliasStmt) accept(v NodeVisitor) !string { return v.visit_type_alias_stmt(n)! }

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
	type_annotation ?MypyType
	initializer     ?Expression
	kind            ArgKind
	pos_only        bool
}

pub struct TypeParam {
pub:
	name        string
	kind        int    // 0=TypeVar, 1=ParamSpec, 2=TypeVarTuple
	upper_bound ?MypyType
	default     ?MypyType
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
	type_           ?MypyType     // full callable type if known
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
}
pub fn (n &FuncDef) get_context() Context { return n.base.ctx }
pub fn (n &FuncDef) accept(v NodeVisitor) !string { return v.visit_func_def(n)! }

pub struct OverloadedFuncDef {
pub mut:
	base     NodeBase
	items    []FuncDef
	type_    ?MypyType
	fullname string
	is_final bool
	is_static bool
	is_class  bool
	is_property bool
}
pub fn (n &OverloadedFuncDef) get_context() Context { return n.base.ctx }
pub fn (n &OverloadedFuncDef) accept(v NodeVisitor) !string { return v.visit_overloaded_func_def(n)! }

pub struct Decorator {
pub mut:
	base       NodeBase
	func       FuncDef
	decorators []Expression
	var_        Var
	is_overload bool
}
pub fn (n &Decorator) get_context() Context { return n.base.ctx }
pub fn (n &Decorator) accept(v NodeVisitor) !string { return v.visit_decorator(n)! }

// Var — a variable / field / parameter
pub struct Var {
pub mut:
	base               NodeBase
	name               string
	fullname           string
	type_              ?MypyType
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
	explicit_self_type ?MypyType
}
pub fn (n &Var) get_context() Context { return n.base.ctx }
pub fn (n &Var) accept(v NodeVisitor) !string { return v.visit_var(n)! }

pub struct ClassDef {
pub mut:
	base         NodeBase
	name         string
	fullname     string
	defs         Block
	type_vars    []MypyType
	base_type_exprs []Expression
	removed_base_type_exprs []Expression
	metaclass    ?string
	decorators   []Expression
	keywords     map[string]Expression
	is_protocol  bool
	is_abstract  bool
	has_incompatible_baseclass bool
	type_params  []TypeParam
}
pub fn (n &ClassDef) get_context() Context { return n.base.ctx }
pub fn (n &ClassDef) accept(v NodeVisitor) !string { return v.visit_class_def(n)! }

// ---------------------------------------------------------------------------
// Expression nodes
// ---------------------------------------------------------------------------

pub struct IntExpr {
pub mut:
	base  NodeBase
	value i64
}
pub fn (n &IntExpr) get_context() Context { return n.base.ctx }
pub fn (n &IntExpr) accept(v NodeVisitor) !string { return v.visit_int_expr(n)! }

pub struct StrExpr {
pub mut:
	base  NodeBase
	value string
}
pub fn (n &StrExpr) get_context() Context { return n.base.ctx }
pub fn (n &StrExpr) accept(v NodeVisitor) !string { return v.visit_str_expr(n)! }

pub struct BytesExpr {
pub mut:
	base  NodeBase
	// stored as hex or escaped string, same as Python's bytes repr
	value string
}
pub fn (n &BytesExpr) get_context() Context { return n.base.ctx }
pub fn (n &BytesExpr) accept(v NodeVisitor) !string { return v.visit_bytes_expr(n)! }

pub struct FloatExpr {
pub mut:
	base  NodeBase
	value f64
}
pub fn (n &FloatExpr) get_context() Context { return n.base.ctx }
pub fn (n &FloatExpr) accept(v NodeVisitor) !string { return v.visit_float_expr(n)! }

pub struct ComplexExpr {
pub mut:
	base  NodeBase
	real  f64
	imag  f64
}
pub fn (n &ComplexExpr) get_context() Context { return n.base.ctx }
pub fn (n &ComplexExpr) accept(v NodeVisitor) !string { return v.visit_complex_expr(n)! }

pub struct EllipsisExpr {
pub mut:
	base NodeBase
}
pub fn (n &EllipsisExpr) get_context() Context { return n.base.ctx }
pub fn (n &EllipsisExpr) accept(v NodeVisitor) !string { return v.visit_ellipsis(n)! }

pub struct StarExpr {
pub mut:
	base NodeBase
	expr Expression
	// True when used inside a type annotation
	valid bool
}
pub fn (n &StarExpr) get_context() Context { return n.base.ctx }
pub fn (n &StarExpr) accept(v NodeVisitor) !string { return v.visit_star_expr(n)! }

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
pub fn (n &NameExpr) get_context() Context { return n.base.ctx }
pub fn (n &NameExpr) accept(v NodeVisitor) !string { return v.visit_name_expr(n)! }

// RefExpr — a reference expression (NameExpr or MemberExpr)
pub type RefExpr = NameExpr | MemberExpr

// SymbolNodeRef wraps resolved references to avoid circular sum-type issues.
pub type SymbolNodeRef = ClassDef | Decorator | FuncDef | MypyFile | OverloadedFuncDef | TypeAlias | TypeInfo | Var

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
pub fn (n &MemberExpr) get_context() Context { return n.base.ctx }
pub fn (n &MemberExpr) accept(v NodeVisitor) !string { return v.visit_member_expr(n)! }

pub struct YieldFromExpr {
pub mut:
	base NodeBase
	expr Expression
}
pub fn (n &YieldFromExpr) get_context() Context { return n.base.ctx }
pub fn (n &YieldFromExpr) accept(v NodeVisitor) !string { return v.visit_yield_from_expr(n)! }

pub struct YieldExpr {
pub mut:
	base NodeBase
	expr ?Expression
}
pub fn (n &YieldExpr) get_context() Context { return n.base.ctx }
pub fn (n &YieldExpr) accept(v NodeVisitor) !string { return v.visit_yield_expr(n)! }

pub struct CallExpr {
pub mut:
	base      NodeBase
	callee    Expression
	args      []Expression
	arg_kinds []ArgKind
	arg_names []?string
}
pub fn (n &CallExpr) get_context() Context { return n.base.ctx }
pub fn (n &CallExpr) accept(v NodeVisitor) !string { return v.visit_call_expr(n)! }

pub struct IndexExpr {
pub mut:
	base   NodeBase
	base_  Expression
	index  Expression
	// analyzed type if this is a type alias or similar
	analyzed ?Expression
}
pub fn (n &IndexExpr) get_context() Context { return n.base.ctx }
pub fn (n &IndexExpr) accept(v NodeVisitor) !string { return v.visit_index_expr(n)! }

pub struct UnaryExpr {
pub mut:
	base NodeBase
	op   string
	expr Expression
}
pub fn (n &UnaryExpr) get_context() Context { return n.base.ctx }
pub fn (n &UnaryExpr) accept(v NodeVisitor) !string { return v.visit_unary_expr(n)! }

pub struct AssignmentExpr {
pub mut:
	base   NodeBase
	target NameExpr
	value  Expression
}
pub fn (n &AssignmentExpr) get_context() Context { return n.base.ctx }
pub fn (n &AssignmentExpr) accept(v NodeVisitor) !string { return v.visit_assignment_expr(n)! }

pub struct OpExpr {
pub mut:
	base       NodeBase
	op         string
	left       Expression
	right      Expression
	// right operand type after analysis (used for `in`/`not in`)
	right_type ?MypyType
}
pub fn (n &OpExpr) get_context() Context { return n.base.ctx }
pub fn (n &OpExpr) accept(v NodeVisitor) !string { return v.visit_op_expr(n)! }

pub struct ComparisonExpr {
pub mut:
	base      NodeBase
	operators []string
	operands  []Expression
}
pub fn (n &ComparisonExpr) get_context() Context { return n.base.ctx }
pub fn (n &ComparisonExpr) accept(v NodeVisitor) !string { return v.visit_comparison_expr(n)! }

pub struct SliceExpr {
pub mut:
	base       NodeBase
	begin_index ?Expression
	end_index   ?Expression
	stride      ?Expression
}
pub fn (n &SliceExpr) get_context() Context { return n.base.ctx }
pub fn (n &SliceExpr) accept(v NodeVisitor) !string { return v.visit_slice_expr(n)! }

pub struct CastExpr {
pub mut:
	base NodeBase
	expr Expression
	type_ MypyType
}
pub fn (n &CastExpr) get_context() Context { return n.base.ctx }
pub fn (n &CastExpr) accept(v NodeVisitor) !string { return v.visit_cast_expr(n)! }

pub struct AssertTypeExpr {
pub mut:
	base  NodeBase
	expr  Expression
	type_ MypyType
}
pub fn (n &AssertTypeExpr) get_context() Context { return n.base.ctx }
pub fn (n &AssertTypeExpr) accept(v NodeVisitor) !string { return v.visit_assert_type_expr(n)! }

pub struct RevealExpr {
pub mut:
	base   NodeBase
	kind   int   // reveal_type or reveal_locals
	expr   ?Expression
	is_imported bool
}
pub fn (n &RevealExpr) get_context() Context { return n.base.ctx }
pub fn (n &RevealExpr) accept(v NodeVisitor) !string { return v.visit_reveal_expr(n)! }

pub struct SuperExpr {
pub mut:
	base   NodeBase
	name   string
	info   ?TypeInfo
}
pub fn (n &SuperExpr) get_context() Context { return n.base.ctx }
pub fn (n &SuperExpr) accept(v NodeVisitor) !string { return v.visit_super_expr(n)! }

pub struct ListExpr {
pub mut:
	base  NodeBase
	items []Expression
}
pub fn (n &ListExpr) get_context() Context { return n.base.ctx }
pub fn (n &ListExpr) accept(v NodeVisitor) !string { return v.visit_list_expr(n)! }

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

pub fn (n &DictExpr) get_context() Context { return n.base.ctx }
pub fn (n &DictExpr) accept(v NodeVisitor) !string { return v.visit_dict_expr(n)! }

// f-strings / template strings (Python TemplateStrExpr / JoinedStr)
pub struct TemplateStrExpr {
pub mut:
	base  NodeBase
	parts []Expression
}
pub fn (n &TemplateStrExpr) get_context() Context { return n.base.ctx }
pub fn (n &TemplateStrExpr) accept(v NodeVisitor) !string { return v.visit_template_str_expr(n)! }

pub struct TupleExpr {
pub mut:
	base  NodeBase
	items []Expression
}
pub fn (n &TupleExpr) get_context() Context { return n.base.ctx }
pub fn (n &TupleExpr) accept(v NodeVisitor) !string { return v.visit_tuple_expr(n)! }

pub struct SetExpr {
pub mut:
	base  NodeBase
	items []Expression
}
pub fn (n &SetExpr) get_context() Context { return n.base.ctx }
pub fn (n &SetExpr) accept(v NodeVisitor) !string { return v.visit_set_expr(n)! }

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
pub fn (n &GeneratorExpr) get_context() Context { return n.base.ctx }
pub fn (n &GeneratorExpr) accept(v NodeVisitor) !string { return v.visit_generator_expr(n)! }

pub struct ListComprehension {
pub mut:
	base NodeBase
	generator GeneratorExpr
}
pub fn (n &ListComprehension) get_context() Context { return n.base.ctx }
pub fn (n &ListComprehension) accept(v NodeVisitor) !string { return v.visit_list_comprehension(n)! }

pub struct SetComprehension {
pub mut:
	base NodeBase
	generator GeneratorExpr
}
pub fn (n &SetComprehension) get_context() Context { return n.base.ctx }
pub fn (n &SetComprehension) accept(v NodeVisitor) !string { return v.visit_set_comprehension(n)! }

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
pub fn (n &DictionaryComprehension) get_context() Context { return n.base.ctx }
pub fn (n &DictionaryComprehension) accept(v NodeVisitor) !string { return v.visit_dictionary_comprehension(n)! }

pub struct ConditionalExpr {
pub mut:
	base      NodeBase
	cond      Expression
	if_expr   Expression
	else_expr Expression
}
pub fn (n &ConditionalExpr) get_context() Context { return n.base.ctx }
pub fn (n &ConditionalExpr) accept(v NodeVisitor) !string { return v.visit_conditional_expr(n)! }

pub struct TypeApplication {
pub mut:
	base   NodeBase
	expr   Expression
	types  []MypyType
}
pub fn (n &TypeApplication) get_context() Context { return n.base.ctx }
pub fn (n &TypeApplication) accept(v NodeVisitor) !string { return v.visit_type_application(n)! }

pub struct LambdaExpr {
pub mut:
	base      NodeBase
	arguments []Argument
	arg_names []?string
	arg_kinds []ArgKind
	body      Expression
	type_     ?MypyType
}
pub fn (n &LambdaExpr) get_context() Context { return n.base.ctx }
pub fn (n &LambdaExpr) accept(v NodeVisitor) !string { return v.visit_lambda_expr(n)! }

// Type variable / special-form expression nodes
pub struct TypeVarExpr {
pub mut:
	base        NodeBase
	name        string
	fullname    string
	values      []MypyType
	upper_bound MypyType
	default_    MypyType
	variance    int
}
pub fn (n &TypeVarExpr) get_context() Context { return n.base.ctx }
pub fn (n &TypeVarExpr) accept(v NodeVisitor) !string { return v.visit_type_var_expr(n)! }

pub struct ParamSpecExpr {
pub mut:
	base     NodeBase
	name     string
	fullname string
	upper_bound MypyType
	default_ MypyType
}
pub fn (n &ParamSpecExpr) get_context() Context { return n.base.ctx }
pub fn (n &ParamSpecExpr) accept(v NodeVisitor) !string { return v.visit_paramspec_expr(n)! }

pub struct TypeVarTupleExpr {
pub mut:
	base     NodeBase
	name     string
	fullname string
	upper_bound MypyType
	default_ MypyType
}
pub fn (n &TypeVarTupleExpr) get_context() Context { return n.base.ctx }
pub fn (n &TypeVarTupleExpr) accept(v NodeVisitor) !string { return v.visit_type_var_tuple_expr(n)! }

pub struct TypeAliasExpr {
pub mut:
	base  NodeBase
	node  TypeAlias
}
pub fn (n &TypeAliasExpr) get_context() Context { return n.base.ctx }
pub fn (n &TypeAliasExpr) accept(v NodeVisitor) !string { return v.visit_type_alias_expr(n)! }

pub struct NamedTupleExpr {
pub mut:
	base    NodeBase
	info    TypeInfo
	is_typed_dict bool
}
pub fn (n &NamedTupleExpr) get_context() Context { return n.base.ctx }
pub fn (n &NamedTupleExpr) accept(v NodeVisitor) !string { return v.visit_namedtuple_expr(n)! }

pub struct TypedDictExpr {
pub mut:
	base NodeBase
	info TypeInfo
}
pub fn (n &TypedDictExpr) get_context() Context { return n.base.ctx }
pub fn (n &TypedDictExpr) accept(v NodeVisitor) !string { return v.visit_typeddict_expr(n)! }

pub struct EnumCallExpr {
pub mut:
	base     NodeBase
	info     TypeInfo
	items    []string
	values   []?Expression
}
pub fn (n &EnumCallExpr) get_context() Context { return n.base.ctx }
pub fn (n &EnumCallExpr) accept(v NodeVisitor) !string { return v.visit_enum_call_expr(n)! }

pub struct PromoteExpr {
pub mut:
	base  NodeBase
	type_ MypyType
}
pub fn (n &PromoteExpr) get_context() Context { return n.base.ctx }
pub fn (n &PromoteExpr) accept(v NodeVisitor) !string { return v.visit_promote_expr(n)! }

pub struct NewTypeExpr {
pub mut:
	base     NodeBase
	name     string
	old_type ?MypyType
	info     ?TypeInfo
}
pub fn (n &NewTypeExpr) get_context() Context { return n.base.ctx }
pub fn (n &NewTypeExpr) accept(v NodeVisitor) !string { return v.visit_newtype_expr(n)! }

pub struct AwaitExpr {
pub mut:
	base NodeBase
	expr Expression
}
pub fn (n &AwaitExpr) get_context() Context { return n.base.ctx }
pub fn (n &AwaitExpr) accept(v NodeVisitor) !string { return v.visit_await_expr(n)! }

// TempNode is a placeholder node created during semantic analysis
pub struct TempNode {
pub mut:
	base      NodeBase
	type_     MypyType
	no_rhs    bool
	context   ?Node
}
pub fn (n &TempNode) get_context() Context { return n.base.ctx }
pub fn (n &TempNode) accept(v NodeVisitor) !string { return v.visit_temp_node(n)! }

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

pub fn (n &MypyFile) get_context() Context { return n.base.ctx }
pub fn (n &MypyFile) accept(v NodeVisitor) !string { return v.visit_mypy_file(n)! }

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

pub type SymbolTable = map[string]SymbolTableNode

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
	names         SymbolTable
	defn          ClassDef
	// mro: method resolution order (list of TypeInfo fullnames)
	mro           []string
}

// TypeAlias — a type alias node in the symbol table
pub struct TypeAlias {
pub mut:
	base         NodeBase
	target       MypyType
	name         string
	fullname     string
	alias_tvars  []string
	no_args      bool
	eager        bool
}
pub fn (n &TypeAlias) get_context() Context { return n.base.ctx }
pub fn (n &TypeAlias) accept(v NodeVisitor) !string { return v.visit_type_alias(n)! }

// PlaceholderNode — for names not yet fully resolved during semanal
pub struct PlaceholderNode {
pub mut:
	base         NodeBase
	fullname     string
	node         Node
	becomes_typeinfo bool
}
pub fn (n &PlaceholderNode) get_context() Context { return n.base.ctx }
pub fn (n &PlaceholderNode) accept(v NodeVisitor) !string { return v.visit_placeholder_node(n)! }

// ---------------------------------------------------------------------------
// MypyType — opaque wrapper used in nodes to avoid a circular import with
// types.v. The real type hierarchy lives in types.v.
// ---------------------------------------------------------------------------

// MypyType is an interface so that types.v can implement it fully.
pub type MypyType = MypyTypeNode

// Pattern is an interface implemented by all match-pattern nodes in patterns.v.
pub interface Pattern {
	get_context() Context
}
