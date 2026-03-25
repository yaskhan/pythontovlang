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

import os as _

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
	get_context() Context
mut:
	accept(mut v NodeVisitor) !AnyNode
}

// ---------------------------------------------------------------------------
// Helper: NodeBase embeds Context so concrete structs don't repeat fields.
// ---------------------------------------------------------------------------

pub type TypeVarLikeExpr = TypeVarExpr | ParamSpecExpr | TypeVarTupleExpr

pub fn (t TypeVarLikeExpr) fullname() string {
	return match t {
		TypeVarExpr { t.fullname }
		ParamSpecExpr { t.fullname }
		TypeVarTupleExpr { t.fullname }
	}
}

pub fn (t TypeVarLikeExpr) default_() MypyTypeNode {
	return match t {
		TypeVarExpr { t.default_ }
		ParamSpecExpr { t.default_ }
		TypeVarTupleExpr { t.default_ }
	}
}

pub struct NodeBase {
pub mut:
	line       int = -1
	column     int = -1
	end_line   ?int
	end_column ?int
	ctx        Context
}

pub fn (n NodeBase) str() string {
	return 'Node(...)'
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
	base NodeBase
	// ids: list of (module_name, optional_alias)
	ids            []ImportAlias
	is_top_level   bool
	is_unreachable bool
	is_mypy_only   bool
}

pub struct ImportAlias {
pub:
	name  string
	alias ?string
}

pub fn (n Import) get_context() Context {
	return n.base.ctx
}

pub fn (mut n Import) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_import(mut n)!
}

// from foo import bar [as baz]
pub struct ImportFrom {
pub mut:
	base           NodeBase
	id             string
	relative       int
	names          []ImportAlias
	is_top_level   bool
	is_unreachable bool
	is_mypy_only   bool
}

pub fn (n ImportFrom) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ImportFrom) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_import_from(mut n)!
}

// from foo import *
pub struct ImportAll {
pub mut:
	base           NodeBase
	id             string
	relative       int
	is_top_level   bool
	is_unreachable bool
	is_mypy_only   bool
}

pub fn (n ImportAll) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ImportAll) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_import_all(mut n)!
}

// ---------------------------------------------------------------------------
pub type MypyNode = AssertStmt
	| AssignmentStmt
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
	| ConditionalExpr
	| DictExpr
	| DictionaryComprehension
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
	| NamedTupleExpr
	| NewTypeExpr
	| OpExpr
	| ParamSpecExpr
	| PlaceholderNode
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
	| Var
	| TypeInfo
	| Argument
	| MypyFile
	| TypeAlias
	| TypeParam
	| AsPattern
	| OrPattern
	| ValuePattern
	| SingletonPattern
	| SequencePattern
	| StarredPattern
	| MappingPattern
	| ClassPattern


pub fn (mut n MypyNode) is_statement() bool {
	match n {
		AssertStmt, AssignmentStmt, Block, BreakStmt, ClassDef, ContinueStmt, Decorator, DelStmt,
		ExpressionStmt, ForStmt, FuncDef, GlobalDecl, IfStmt, Import, ImportAll, ImportFrom,
		MatchStmt, NonlocalDecl, OperatorAssignmentStmt, OverloadedFuncDef, PassStmt, RaiseStmt,
		ReturnStmt, TryStmt, TypeAliasStmt, WhileStmt, WithStmt {
			return true
		}
		else {
			return false
		}
	}
}

pub fn (n MypyNode) as_pattern() ?PatternNode {
	match n {
		AsPattern, OrPattern, ValuePattern, SingletonPattern, SequencePattern, StarredPattern,
		MappingPattern, ClassPattern {
			return PatternNode(n)
		}
		else {
			return none
		}
	}
}

pub fn (n MypyNode) is_expression() bool {
	match n {
		AssignmentExpr, AwaitExpr, BytesExpr, CallExpr, CastExpr, ComparisonExpr, ComplexExpr,
		ConditionalExpr, DictExpr, DictionaryComprehension, EllipsisExpr, EnumCallExpr, FloatExpr,
		FormatStringExpr, GeneratorExpr, IndexExpr, IntExpr, LambdaExpr, ListComprehension,
		ListExpr, MemberExpr, NameExpr, NamedTupleExpr, NewTypeExpr, OpExpr, ParamSpecExpr,
		PromoteExpr, RevealExpr, SetComprehension, SetExpr, SliceExpr, StarExpr, StrExpr,
		SuperExpr, TempNode, TemplateStrExpr, TupleExpr, TypeAliasExpr, TypeApplication,
		TypeVarExpr, TypeVarTupleExpr, TypedDictExpr, UnaryExpr, AssertTypeExpr, YieldExpr,
		YieldFromExpr {
			return true
		}
		else {
			return false
		}
	}
}

pub fn (n MypyNode) as_statement() ?Statement {
	match n {
		AssertStmt, AssignmentStmt, Block, BreakStmt, ClassDef, ContinueStmt, Decorator, DelStmt,
		ExpressionStmt, ForStmt, FuncDef, GlobalDecl, IfStmt, Import, ImportAll, ImportFrom,
		MatchStmt, NonlocalDecl, OperatorAssignmentStmt, OverloadedFuncDef, PassStmt, RaiseStmt,
		ReturnStmt, TryStmt, TypeAliasStmt, WhileStmt, WithStmt {
			return Statement(n)
		}
		else { return none }
	}
}

pub fn (n MypyNode) as_expression() ?Expression {
	match n {
		AssignmentExpr, AwaitExpr, BytesExpr, CallExpr, CastExpr, ComparisonExpr, ComplexExpr,
		ConditionalExpr, DictExpr, DictionaryComprehension, EllipsisExpr, EnumCallExpr, FloatExpr,
		FormatStringExpr, GeneratorExpr, IndexExpr, IntExpr, LambdaExpr, ListComprehension,
		ListExpr, MemberExpr, NameExpr, NamedTupleExpr, NewTypeExpr, OpExpr, ParamSpecExpr,
		PromoteExpr, RevealExpr, SetComprehension, SetExpr, SliceExpr, StarExpr, StrExpr,
		SuperExpr, TempNode, TemplateStrExpr, TupleExpr, TypeAliasExpr, TypeApplication,
		TypeVarExpr, TypeVarTupleExpr, TypedDictExpr, UnaryExpr, AssertTypeExpr, YieldExpr,
		YieldFromExpr {
			return Expression(n)
		}
		else { return none }
	}
}

pub fn (n MypyNode) get_context() Context {
	return match n {
		AssertStmt, AssignmentStmt, Block, BreakStmt, ClassDef, ContinueStmt, Decorator, DelStmt,
		ExpressionStmt, ForStmt, FuncDef, GlobalDecl, IfStmt, Import, ImportAll, ImportFrom,
		MatchStmt, NonlocalDecl, OperatorAssignmentStmt, OverloadedFuncDef, PassStmt, RaiseStmt,
		ReturnStmt, TryStmt, TypeAliasStmt, WhileStmt, WithStmt, AssignmentExpr, AwaitExpr,
		BytesExpr, CallExpr, CastExpr, ComparisonExpr, ComplexExpr, ConditionalExpr, DictExpr,
		DictionaryComprehension, EllipsisExpr, EnumCallExpr, FloatExpr, FormatStringExpr,
		GeneratorExpr, IndexExpr, IntExpr, LambdaExpr, ListComprehension, ListExpr, MemberExpr,
		NameExpr, NamedTupleExpr, NewTypeExpr, OpExpr, ParamSpecExpr, PlaceholderNode, PromoteExpr,
		RevealExpr, SetComprehension, SetExpr, SliceExpr, StarExpr, StrExpr, SuperExpr, TempNode,
		TemplateStrExpr, TupleExpr, TypeAliasExpr, TypeApplication, TypeVarExpr, TypeVarTupleExpr,
		TypedDictExpr, UnaryExpr, AssertTypeExpr, YieldExpr, YieldFromExpr, Var, TypeInfo,
		Argument, MypyFile, TypeAlias, TypeParam, AsPattern, OrPattern, ValuePattern, SingletonPattern, SequencePattern, StarredPattern, MappingPattern, ClassPattern {
			n.get_context()
		}
	}
}

pub fn (mut n MypyNode) accept(mut v NodeVisitor) !AnyNode {
	return match mut n {
		AssertStmt, AssignmentStmt, Block, BreakStmt, ClassDef, ContinueStmt, Decorator, DelStmt,
		ExpressionStmt, ForStmt, FuncDef, GlobalDecl, IfStmt, Import, ImportAll, ImportFrom,
		MatchStmt, NonlocalDecl, OperatorAssignmentStmt, OverloadedFuncDef, PassStmt, RaiseStmt,
		ReturnStmt, TryStmt, TypeAliasStmt, WhileStmt, WithStmt, AssignmentExpr, AwaitExpr,
		BytesExpr, CallExpr, CastExpr, ComparisonExpr, ComplexExpr, ConditionalExpr, DictExpr,
		DictionaryComprehension, EllipsisExpr, EnumCallExpr, FloatExpr, FormatStringExpr,
		GeneratorExpr, IndexExpr, IntExpr, LambdaExpr, ListComprehension, ListExpr, MemberExpr,
		NameExpr, NamedTupleExpr, NewTypeExpr, OpExpr, ParamSpecExpr, PlaceholderNode, PromoteExpr,
		RevealExpr, SetComprehension, SetExpr, SliceExpr, StarExpr, StrExpr, SuperExpr, TempNode,
		TemplateStrExpr, TupleExpr, TypeAliasExpr, TypeApplication, TypeVarExpr, TypeVarTupleExpr,
		TypedDictExpr, UnaryExpr, AssertTypeExpr, YieldExpr, YieldFromExpr, Var, TypeInfo,
		Argument, MypyFile, TypeAlias, TypeParam, AsPattern, OrPattern, ValuePattern, SingletonPattern, SequencePattern, StarredPattern, MappingPattern, ClassPattern {
			n.accept(mut v)!
		}
	}
}

pub struct Block {
pub mut:
	base           NodeBase
	body           []Statement
	is_unreachable bool
}

pub fn (n Block) str() string {
	return 'Block'
}

pub fn (n Block) get_context() Context {
	return n.base.ctx
}

pub fn (mut n Block) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_block(mut n)!
}
// Block & basic statements
// ---------------------------------------------------------------------------

pub type Statement = AssertStmt
	| AssignmentStmt
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

pub fn (s Statement) str() string {
	return 'Statement(...)'
}

pub fn (s Statement) get_context() Context {
	return match s {
		AssertStmt, AssignmentStmt, Block, BreakStmt, ClassDef, ContinueStmt, Decorator, DelStmt,
		ExpressionStmt, ForStmt, FuncDef, GlobalDecl, IfStmt, Import, ImportAll, ImportFrom,
		MatchStmt, NonlocalDecl, OperatorAssignmentStmt, OverloadedFuncDef, PassStmt, RaiseStmt,
		ReturnStmt, TryStmt, TypeAliasStmt, WhileStmt, WithStmt {
			s.get_context()
		}
	}
}

pub fn (mut s Statement) accept(mut v NodeVisitor) !AnyNode {
	return match mut s {
		AssertStmt, AssignmentStmt, Block, BreakStmt, ClassDef, ContinueStmt, Decorator, DelStmt,
		ExpressionStmt, ForStmt, FuncDef, GlobalDecl, IfStmt, Import, ImportAll, ImportFrom,
		MatchStmt, NonlocalDecl, OperatorAssignmentStmt, OverloadedFuncDef, PassStmt, RaiseStmt,
		ReturnStmt, TryStmt, TypeAliasStmt, WhileStmt, WithStmt {
			s.accept(mut v)!
		}
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
	| FormatStringExpr
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

pub type Lvalue = ListExpr | MemberExpr | NameExpr | StarExpr | TupleExpr

pub fn (e Expression) as_lvalue() ?Lvalue {
	return match e {
		ListExpr { Lvalue(e) }
		MemberExpr { Lvalue(e) }
		NameExpr { Lvalue(e) }
		StarExpr { Lvalue(e) }
		TupleExpr { Lvalue(e) }
		else { none }
	}
}

pub fn (e Expression) get_context() Context {
	return match e {
		AssignmentExpr, AwaitExpr, BytesExpr, CallExpr, CastExpr, ComparisonExpr, ComplexExpr,
		ConditionalExpr, DictExpr, DictionaryComprehension, EllipsisExpr, EnumCallExpr, FloatExpr,
		FormatStringExpr, GeneratorExpr, IndexExpr, IntExpr, LambdaExpr, ListComprehension,
		ListExpr, MemberExpr, NameExpr, NamedTupleExpr, NewTypeExpr, OpExpr, ParamSpecExpr,
		PromoteExpr, RevealExpr, SetComprehension, SetExpr, SliceExpr, StarExpr, StrExpr,
		SuperExpr, TempNode, TemplateStrExpr, TupleExpr, TypeAliasExpr, TypeApplication,
		TypeVarExpr, TypeVarTupleExpr, TypedDictExpr, UnaryExpr, AssertTypeExpr, YieldExpr,
		YieldFromExpr {
			e.get_context()
		}
	}
}
pub fn (e Expression) as_ref_expr() ?RefExpr {
	return match e {
		NameExpr { RefExpr(e) }
		MemberExpr { RefExpr(e) }
		else { none }
	}
}

pub fn (mut e Expression) accept(mut v NodeVisitor) !AnyNode {
	return match mut e {
		AssignmentExpr, AwaitExpr, BytesExpr, CallExpr, CastExpr, ComparisonExpr, ComplexExpr,
		ConditionalExpr, DictExpr, DictionaryComprehension, EllipsisExpr, EnumCallExpr, FloatExpr,
		FormatStringExpr, GeneratorExpr, IndexExpr, IntExpr, LambdaExpr, ListComprehension,
		ListExpr, MemberExpr, NameExpr, NamedTupleExpr, NewTypeExpr, OpExpr, ParamSpecExpr,
		PromoteExpr, RevealExpr, SetComprehension, SetExpr, SliceExpr, StarExpr, StrExpr,
		SuperExpr, TempNode, TemplateStrExpr, TupleExpr, TypeAliasExpr, TypeApplication,
		TypeVarExpr, TypeVarTupleExpr, TypedDictExpr, UnaryExpr, AssertTypeExpr, YieldExpr,
		YieldFromExpr {
			e.accept(mut v)!
		}
	}
}

pub fn (lval Lvalue) accept(mut v NodeVisitor) !AnyNode {
	mut it_lval := lval
	return match mut it_lval {
		NameExpr { v.visit_name_expr(mut it_lval)! }
		MemberExpr { v.visit_member_expr(mut it_lval)! }
		TupleExpr {
			for mut item in it_lval.items {
				if mut l := item.as_lvalue() {
					v.visit_lvalue(mut l)!
				}
			}
			return AnyNode(string(''))
		}
		ListExpr {
			for mut item in it_lval.items {
				if mut l := item.as_lvalue() {
					v.visit_lvalue(mut l)!
				}
			}
			return AnyNode(string(''))
		}
		StarExpr {
			if mut l := it_lval.expr.as_lvalue() {
				v.visit_lvalue(mut l)!
			}
			return AnyNode(string(''))
		}
	}
}

pub struct ExpressionStmt {
pub mut:
	base NodeBase
	expr Expression
}

pub fn (n ExpressionStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ExpressionStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_expression_stmt(mut n)!
}

pub struct AssignmentStmt {
pub mut:
	base    NodeBase
	lvalues []Expression
	rvalue  Expression
	// type annotation if present
	type_annotation ?MypyTypeNode
	is_final_def    bool
	is_alias_def    bool
}

pub fn (n AssignmentStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n AssignmentStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_assignment_stmt(mut n)!
}

pub struct OperatorAssignmentStmt {
pub mut:
	base   NodeBase
	op     string
	lvalue Lvalue
	rvalue Expression
}

pub fn (n OperatorAssignmentStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n OperatorAssignmentStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_operator_assignment_stmt(mut n)!
}

pub struct WhileStmt {
pub mut:
	base      NodeBase
	expr      Expression
	body      Block
	else_body ?Block
}

pub fn (n WhileStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n WhileStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_while_stmt(mut n)!
}

pub struct ForStmt {
pub mut:
	base      NodeBase
	index     Expression
	expr      Expression
	body      Block
	else_body ?Block
	is_async  bool
	index_type ?MypyTypeNode
}

pub fn (n ForStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ForStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_for_stmt(mut n)!
}

pub struct ReturnStmt {
pub mut:
	base NodeBase
	expr ?Expression
}

pub fn (n ReturnStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ReturnStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_return_stmt(mut n)!
}

pub struct IfStmt {
pub mut:
	base      NodeBase
	expr      []Expression
	body      []Block
	else_body ?Block
}

pub fn (n IfStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n IfStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_if_stmt(mut n)!
}

pub struct BreakStmt {
pub mut:
	base NodeBase
}

pub fn (n BreakStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n BreakStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_break_stmt(mut n)!
}

pub struct ContinueStmt {
pub mut:
	base NodeBase
}

pub fn (n ContinueStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ContinueStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_continue_stmt(mut n)!
}

pub struct PassStmt {
pub mut:
	base NodeBase
}

pub fn (n PassStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n PassStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_pass_stmt(mut n)!
}

pub struct RaiseStmt {
pub mut:
	base NodeBase
	expr ?Expression
	from ?Expression
}

pub fn (n RaiseStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n RaiseStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_raise_stmt(mut n)!
}

pub struct TryStmt {
pub mut:
	base NodeBase
	body Block
	// parallel arrays: types[i] matches vars[i] (var may be absent)
	types        []?Expression
	vars         []?NameExpr
	handlers     []Block
	else_body    ?Block
	finally_body ?Block
	is_star      bool
}

pub fn (n TryStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TryStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_try_stmt(mut n)!
}

pub struct WithStmt {
pub mut:
	base     NodeBase
	expr     []Expression
	target   []?Expression
	body     Block
	is_async bool
}

pub fn (n WithStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n WithStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_with_stmt(mut n)!
}

pub struct DelStmt {
pub mut:
	base NodeBase
	expr Expression
}

pub fn (n DelStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n DelStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_del_stmt(mut n)!
}

pub struct GlobalDecl {
pub mut:
	base  NodeBase
	names []string
}

pub fn (n GlobalDecl) get_context() Context {
	return n.base.ctx
}

pub fn (mut n GlobalDecl) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_global_decl(mut n)!
}

pub struct NonlocalDecl {
pub mut:
	base  NodeBase
	names []string
}

pub fn (n NonlocalDecl) get_context() Context {
	return n.base.ctx
}

pub fn (mut n NonlocalDecl) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_nonlocal_decl(mut n)!
}

pub struct AssertStmt {
pub mut:
	base NodeBase
	expr Expression
	msg  ?Expression
}

pub fn (n AssertStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n AssertStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_assert_stmt(mut n)!
}

pub struct TypeAliasStmt {
pub mut:
	base      NodeBase
	name      NameExpr
	type_args []TypeParam
	value     Expression
}

pub fn (n TypeAliasStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TypeAliasStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_type_alias_stmt(mut n)!
}

// ---------------------------------------------------------------------------
// Match statement (Python 3.10+)
// ---------------------------------------------------------------------------

pub struct MatchStmt {
pub mut:
	base     NodeBase
	subject  Expression
	patterns []Pattern
	guards   []?Expression
	bodies   []Block
}

pub fn (n MatchStmt) get_context() Context {
	return n.base.ctx
}

pub fn (mut n MatchStmt) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_match_stmt(mut n)!
}

pub enum ArgKind {
	arg_pos       // ordinary positional
	arg_opt       // optional positional
	arg_star      // *args
	arg_named     // keyword-only
	arg_named_opt // optional keyword-only
	arg_star2     // **kwargs
}

pub fn (k ArgKind) is_required() bool {
	return k == .arg_pos || k == .arg_named
}

pub fn (k ArgKind) is_optional() bool {
	return k == .arg_opt || k == .arg_named_opt
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

pub fn (n Argument) get_context() Context {
	return n.base.ctx
}

pub fn (mut n Argument) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_argument(mut n)!
}

pub struct TypeParam {
pub mut:
	name         string
	kind         int // 0=TypeVar, 1=ParamSpec, 2=TypeVarTuple
	upper_bound  ?MypyTypeNode
	default_     ?MypyTypeNode
	values       []MypyTypeNode
}

pub fn (n TypeParam) get_context() Context {
	return Context{}
}

pub fn (mut n TypeParam) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_type_param(mut n)!
}

@[heap]
pub struct FuncDef {
pub mut:
	base                 NodeBase
	name                 string // unqualified name
	arguments            []Argument
	arg_names            []?string
	arg_kinds            []ArgKind
	body                 Block
	type_                ?MypyTypeNode // full callable type if known
	is_overload          bool
	is_generator         bool
	is_coroutine         bool
	is_async_generator   bool
	is_decorated         bool
	is_stub              bool
	is_final             bool
	is_class             bool // @classmethod
	is_static            bool // @staticmethod
	is_property          bool
	is_settable_property bool
	is_explicit_override bool
	type_params          []TypeParam
	fullname             string
	abstract_status      int // 0=concrete, 1=abstract, 2=implicitly_abstract
	info                 ?&TypeInfo
	is_mypy_only         bool
	is_unreachable       bool
	is_conditional       bool
	def_or_infer_vars    bool
	max_pos              int
	dataclass_transform_spec ?&DataclassTransformSpec
}

pub fn (n FuncDef) get_context() Context {
	return n.base.ctx
}

pub fn (mut n FuncDef) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_func_def(mut n)!
}

@[heap]
pub struct OverloadedFuncDef {
pub mut:
	base  NodeBase
	items []FuncDef
	type_ ?MypyTypeNode
	info  ?&TypeInfo
}

pub fn (n OverloadedFuncDef) get_context() Context {
	return n.base.ctx
}

pub fn (mut n OverloadedFuncDef) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_overloaded_func_def(mut n)!
}

pub type FuncItem = FuncDef | OverloadedFuncDef | LambdaExpr | Decorator

@[heap]
pub struct Decorator {
pub mut:
	base        NodeBase
	func        FuncDef
	decorators  []Expression
	var_        Var
	is_overload bool
}

pub fn (n Decorator) get_context() Context {
	return n.base.ctx
}

pub fn (mut n Decorator) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_decorator(mut n)!
}

// Var — a variable / field / parameter
pub struct Var {
pub mut:
	base                    NodeBase
	name                    string
	fullname                string
	type_                   ?MypyTypeNode
	is_self                 bool
	is_cls                  bool
	is_ready                bool
	is_initialized_in_class bool
	is_staticmethod         bool
	is_classvar             bool
	is_property             bool
	is_settable_property    bool
	is_final                bool
	is_inferred             bool
	final_value             ?Expression
	explicit_self_type      ?MypyTypeNode
	is_abstract_var         bool
	has_explicit_value      bool
	info                    ?&TypeInfo
}

pub fn (n Var) get_context() Context {
	return n.base.ctx
}

pub fn (mut n Var) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_var(mut n)!
}

@[heap]
pub struct ClassDef {
pub mut:
	base                    NodeBase
	name                    string
	fullname                string
	defs                    Block
	type_vars               []MypyTypeNode
	base_type_exprs         []Expression
	removed_base_type_exprs []Expression
	metaclass               ?string
	decorators              []Expression
	info                    ?&TypeInfo

	keywords                   map[string]Expression
	is_protocol                bool
	is_abstract                bool
	has_incompatible_baseclass bool
	type_params                []TypeParam
}

pub fn (n ClassDef) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ClassDef) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_class_def(mut n)!
}

// ---------------------------------------------------------------------------
// Expression nodes
// ---------------------------------------------------------------------------

pub struct IntExpr {
pub mut:
	base  NodeBase
	value i64
}

pub fn (n IntExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n IntExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_int_expr(mut n)!
}

pub struct StrExpr {
pub mut:
	base  NodeBase
	value string
}

pub fn (n StrExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n StrExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_str_expr(mut n)!
}

pub struct BytesExpr {
pub mut:
	base  NodeBase
	value string
}

pub fn (n BytesExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n BytesExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_bytes_expr(mut n)!
}

pub struct FloatExpr {
pub mut:
	base  NodeBase
	value f64
}

pub fn (n FloatExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n FloatExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_float_expr(mut n)!
}

pub struct ComplexExpr {
pub mut:
	base NodeBase
	real f64
	imag f64
}

pub fn (n ComplexExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ComplexExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_complex_expr(mut n)!
}

pub struct EllipsisExpr {
pub mut:
	base NodeBase
}

pub fn (n EllipsisExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n EllipsisExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_ellipsis(mut n)!
}

pub struct StarExpr {
pub mut:
	base NodeBase
	expr Expression
	// True when used inside a type annotation
	valid bool
}

pub fn (n StarExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n StarExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_star_expr(mut n)!
}

@[heap]
pub struct NameExpr {
pub mut:
	base            NodeBase
	name            string
	kind            int // ldef, gdef, etc.
	fullname        string
	node            ?MypyNode
	is_inferred_def bool
	is_special_form bool
}

pub fn (n NameExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n NameExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_name_expr(mut n)!
}

@[heap]
pub struct MemberExpr {
pub mut:
	base     NodeBase
	expr     Expression
	name     string
	fullname string
	kind     int
	node     ?MypyNode
	def_var  ?Var
}

pub fn (n MemberExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n MemberExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_member_expr(mut n)!
}

pub struct YieldFromExpr {
pub mut:
	base NodeBase
	expr Expression
}

pub fn (n YieldFromExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n YieldFromExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_yield_from_expr(mut n)!
}

pub struct YieldExpr {
pub mut:
	base NodeBase
	expr ?Expression
}

pub fn (n YieldExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n YieldExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_yield_expr(mut n)!
}

@[heap]
pub struct CallExpr {
pub mut:
	base      NodeBase
	callee    Expression
	args      []Expression
	arg_kinds []ArgKind
	arg_names []?string
	type_args []MypyTypeNode
	typ       ?MypyTypeNode
	analyzed  ?Expression
}

pub fn (n CallExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n CallExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_call_expr(mut n)!
}

pub struct IndexExpr {
pub mut:
	base  NodeBase
	base_ Expression
	index Expression
}

pub fn (n IndexExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n IndexExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_index_expr(mut n)!
}

@[heap]
pub struct OpExpr {
pub mut:
	base  NodeBase
	op    string
	left  Expression
	right Expression
	type_ ?MypyTypeNode
}

pub fn (n OpExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n OpExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_op_expr(mut n)!
}

@[heap]
pub struct ComparisonExpr {
pub mut:
	base      NodeBase
	operators []string
	operands  []Expression
}

pub fn (n ComparisonExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ComparisonExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_comparison_expr(mut n)!
}

pub struct UnaryExpr {
pub mut:
	base NodeBase
	op   string
	expr Expression
}

pub fn (n UnaryExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n UnaryExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_unary_expr(mut n)!
}

pub struct CastExpr {
pub mut:
	base NodeBase
	expr Expression
	type ?MypyTypeNode
}

pub fn (n CastExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n CastExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_cast_expr(mut n)!
}

pub struct AssertTypeExpr {
pub mut:
	base NodeBase
	expr Expression
	type ?MypyTypeNode
}

pub fn (n AssertTypeExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n AssertTypeExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_assert_type_expr(mut n)!
}

pub struct RevealExpr {
pub mut:
	base  NodeBase
	expr  Expression
	kind  int // reveal_type, reveal_locals
	lines []string
}

pub fn (n RevealExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n RevealExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_reveal_expr(mut n)!
}

pub struct SuperExpr {
pub mut:
	base NodeBase
	name string
	info ?&TypeInfo
}

pub fn (n SuperExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n SuperExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_super_expr(mut n)!
}

pub struct AssignmentExpr {
pub mut:
	base   NodeBase
	target Expression
	value  Expression
}

pub fn (n AssignmentExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n AssignmentExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_assignment_expr(mut n)!
}

pub struct ListExpr {
pub mut:
	base  NodeBase
	items []Expression
}

pub fn (n ListExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ListExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_list_expr(mut n)!
}

pub struct DictEntry {
pub mut:
	key   ?Expression
	value Expression
}

pub struct DictExpr {
pub mut:
	base  NodeBase
	items []DictEntry
}

pub fn (n DictExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n DictExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_dict_expr(mut n)!
}

pub struct TemplateStrExpr {
pub mut:
	base  NodeBase
	parts []string
}

pub fn (n TemplateStrExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TemplateStrExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_template_str_expr(mut n)!
}

pub struct FormatStringExpr {
pub mut:
	base  NodeBase
	value string
}

pub fn (n FormatStringExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n FormatStringExpr) accept(mut v NodeVisitor) !AnyNode {
	// visit_format_string_expr might not exist yet, using visit_template_str_expr or adding it
	return v.visit_template_str_expr(mut TemplateStrExpr{base: n.base, parts: [n.value]})! 
}

pub struct TupleExpr {
pub mut:
	base  NodeBase
	items []Expression
}

pub fn (n TupleExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TupleExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_tuple_expr(mut n)!
}

pub struct SetExpr {
pub mut:
	base  NodeBase
	items []Expression
}

pub fn (n SetExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n SetExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_set_expr(mut n)!
}

// GeneratorExpr covers both generator expressions and all comprehension types.
pub struct GeneratorExpr {
pub mut:
	base      NodeBase
	left_expr Expression
	indices   []Expression
	sequences []Expression
	condlists [][]Expression
	is_async  []bool
}

pub fn (n GeneratorExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n GeneratorExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_generator_expr(mut n)!
}

pub struct ListComprehension {
pub mut:
	base      NodeBase
	generator GeneratorExpr
}

pub fn (n ListComprehension) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ListComprehension) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_list_comprehension(mut n)!
}

pub struct SetComprehension {
pub mut:
	base      NodeBase
	generator GeneratorExpr
}

pub fn (n SetComprehension) get_context() Context {
	return n.base.ctx
}

pub fn (mut n SetComprehension) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_set_comprehension(mut n)!
}

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

pub fn (n DictionaryComprehension) get_context() Context {
	return n.base.ctx
}

pub fn (mut n DictionaryComprehension) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_dictionary_comprehension(mut n)!
}

pub struct ConditionalExpr {
pub mut:
	base      NodeBase
	cond      Expression
	if_expr   Expression
	else_expr Expression
}

pub fn (n ConditionalExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ConditionalExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_conditional_expr(mut n)!
}

pub struct TypeApplication {
pub mut:
	base  NodeBase
	expr  Expression
	types []MypyTypeNode
}

pub fn (n TypeApplication) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TypeApplication) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_type_application(mut n)!
}

pub struct LambdaExpr {
pub mut:
	base         NodeBase
	arguments    []Argument
	arg_names    []?string
	arg_kinds    []ArgKind
	body         Expression
	type_        ?MypyTypeNode
	is_generator bool
}

pub fn (n LambdaExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n LambdaExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_lambda_expr(mut n)!
}

// Type variable / special-form expression nodes
pub struct TypeVarExpr {
pub mut:
	base        NodeBase
	id          int
	name        string
	fullname    string
	values      []MypyTypeNode
	upper_bound MypyTypeNode
	default_    MypyTypeNode
	variance    int
}

pub fn (n TypeVarExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TypeVarExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_type_var_expr(mut n)!
}

pub struct ParamSpecExpr {
pub mut:
	base        NodeBase
	id          int
	name        string
	fullname    string
	upper_bound MypyTypeNode
	default_    MypyTypeNode
}

pub fn (n ParamSpecExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n ParamSpecExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_paramspec_expr(mut n)!
}

pub struct TypeVarTupleExpr {
pub mut:
	base        NodeBase
	id          int
	name        string
	fullname    string
	upper_bound MypyTypeNode
	default_    MypyTypeNode
}

pub fn (n TypeVarTupleExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TypeVarTupleExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_type_var_tuple_expr(mut n)!
}

pub struct TypeAliasExpr {
pub mut:
	base NodeBase
	node TypeAlias
}

pub fn (n TypeAliasExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TypeAliasExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_type_alias_expr(mut n)!
}

pub struct NamedTupleExpr {
pub mut:
	base          NodeBase
	info          TypeInfo
	is_typed_dict bool
}

pub fn (n NamedTupleExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n NamedTupleExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_namedtuple_expr(mut n)!
}

pub struct TypedDictExpr {
pub mut:
	base NodeBase
	info TypeInfo
}

pub fn (n TypedDictExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TypedDictExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_typeddict_expr(mut n)!
}

pub struct EnumCallExpr {
pub mut:
	base   NodeBase
	info   TypeInfo
	items  []string
	values []?Expression
}

pub fn (n EnumCallExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n EnumCallExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_enum_call_expr(mut n)!
}

pub struct PromoteExpr {
pub mut:
	base  NodeBase
	type_ MypyTypeNode
}

pub fn (n PromoteExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n PromoteExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_promote_expr(mut n)!
}

pub struct NewTypeExpr {
pub mut:
	base     NodeBase
	name     string
	old_type ?MypyTypeNode
	info     ?TypeInfo
}

pub fn (n NewTypeExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n NewTypeExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_newtype_expr(mut n)!
}

pub struct AwaitExpr {
pub mut:
	base NodeBase
	expr Expression
}

pub fn (n AwaitExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n AwaitExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_await_expr(mut n)!
}

pub struct SliceExpr {
pub mut:
	base  NodeBase
	begin ?Expression
	end   ?Expression
	step  ?Expression
}

pub fn (n SliceExpr) get_context() Context {
	return n.base.ctx
}

pub fn (mut n SliceExpr) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_slice_expr(mut n)!
}

// TempNode is a placeholder node created during semantic analysis
pub struct TempNode {
pub mut:
	base    NodeBase
	type_   MypyTypeNode
	no_rhs  bool
	context ?Node
}

pub fn (n TempNode) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TempNode) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_temp_node(mut n)!
}

// ---------------------------------------------------------------------------
// Top-level file node
// ---------------------------------------------------------------------------

@[heap]
pub struct MypyFile {
pub mut:
	base                    NodeBase
	defs                    []Statement
	path                    string
	fullpath                string
	fullname                string
	is_stub                 bool
	is_partial_stub_package bool
	names                   SymbolTable
	imports                 []ImportBase
	is_bom                  bool
	plugin_deps             map[string]bool
	ignored_lines           []int
}

pub fn (f &MypyFile) is_package_init_file() bool {
	return f.path.ends_with('__init__.py') || f.path.ends_with('__init__.pyi')
}

// ImportBase is the interface for Import, ImportFrom, ImportAll
pub interface ImportBase {
	get_context() Context
}

pub fn (n MypyFile) get_context() Context {
	return n.base.ctx
}

pub fn (mut n MypyFile) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_mypy_file(mut n)!
}

// ---------------------------------------------------------------------------
// Symbol table
// ---------------------------------------------------------------------------

// Use constants from line 18-21

pub struct SymbolTableNode {
pub mut:
	kind             int
	node             ?SymbolNodeRef
	module_public    bool
	module_hidden    bool
	implicit         bool
	plugin_generated bool
	no_serialize     bool
	cross_ref        ?string
}

pub struct SymbolTable {
pub mut:
	symbols map[string]SymbolTableNode
}

// ---------------------------------------------------------------------------
// TypeInfo — the semantic representation of a class (stub only here;
// full detail lives in the type-checker layer)
// ---------------------------------------------------------------------------

@[heap]
pub struct TypeInfo {
pub mut:
	base        NodeBase
	name        string
	fullname    string
	module_name string
	// whether this is a named tuple, protocol, etc.
	is_abstract             bool
	is_protocol             bool
	is_named_tuple          bool
	is_enum                 bool
	is_newtype              bool
	has_type_var_tuple_type bool
	names                   SymbolTable
	defn                    ?&ClassDef
	// mro: method resolution order (list of TypeInfo components)
	mro []&TypeInfo

	type_vars           []MypyTypeNode
	bases               []Instance
	promote_types       []MypyTypeNode // Added for join.v
	abstract_attributes []string
	typeddict_type      ?MypyTypeNode
	declared_metaclass  ?Instance
	is_final            bool
	tuple_type          ?&TupleType
	metaclass_type      ?&Instance
	dataclass_transform_spec ?&DataclassTransformSpec
}

pub struct DataclassTransformSpec {
pub:
	eq_default       bool
	order_default    bool
	kw_only_default  bool
	frozen_default   bool
	field_specifiers []string
}

pub fn (n TypeInfo) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TypeInfo) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_type_info(mut n)!
}

// TypeAlias — a type alias node in the symbol table
pub struct TypeAlias {
pub mut:
	base        NodeBase
	target      MypyTypeNode
	name        string
	fullname    string
	alias_tvars []MypyTypeNode
	no_args     bool
	eager       bool
}

pub fn (n TypeAlias) get_context() Context {
	return n.base.ctx
}

pub fn (mut n TypeAlias) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_type_alias(mut n)!
}

pub fn (i TypeInfo) has_base(fullname string) bool {
	if i.fullname == fullname {
		return true
	}
	for it in i.mro {
		if it.fullname == fullname {
			return true
		}
	}
	return false
}

// PlaceholderNode — for names not yet fully resolved during semanal
@[heap]
pub struct PlaceholderNode {
pub mut:
	base             NodeBase
	fullname         string
	node             ?SymbolNodeRef
	becomes_typeinfo bool
}

pub fn (n PlaceholderNode) get_context() Context {
	return n.base.ctx
}

pub fn (mut n PlaceholderNode) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_placeholder_node(mut n)!
}

// MypyTypeNode is defined in types.v

// Pattern is an interface implemented by all match-pattern nodes in patterns.v.
pub interface Pattern {
	get_context() Context
mut:
	accept(mut v NodeVisitor) !AnyNode
}

// SymbolNodeRef wraps resolved references to avoid circular sum-type issues.
pub type SymbolNodeRef = ClassDef
	| Decorator
	| FuncDef
	| MypyFile
	| OverloadedFuncDef
	| PlaceholderNode
	| TypeAlias
	| TypeParam
	| ParamSpecExpr
	| TypeVarExpr
	| TypeVarTupleExpr
	| AsPattern
	| OrPattern
	| ValuePattern
	| SingletonPattern
	| SequencePattern
	| StarredPattern
	| MappingPattern
	| ClassPattern
	| TypeInfo
	| Var

pub fn (n SymbolNodeRef) as_mypy_node() MypyNode {
	return match n {
		ClassDef { MypyNode(n) }
		Decorator { MypyNode(n) }
		FuncDef { MypyNode(n) }
		MypyFile { MypyNode(n) }
		OverloadedFuncDef { MypyNode(n) }
		PlaceholderNode { MypyNode(n) }
		TypeAlias { MypyNode(n) }
		TypeInfo { MypyNode(n) }
		Var { MypyNode(n) }
		else { panic('unreachable') }
	}
}

pub fn (n SymbolNodeRef) fullname() string {
	match n {
		ClassDef { return n.fullname }
		Decorator { return n.func.fullname }
		FuncDef { return n.fullname }
		MypyFile { return n.fullname }
		OverloadedFuncDef {
			if n.items.len > 0 {
				return n.items[0].fullname
			}
			return ''
		}
		TypeAlias { return n.fullname }
		TypeInfo { return n.fullname }
		Var { return n.fullname }
		PlaceholderNode { return n.fullname }
		else { return '' }
	}
	return ''
}

pub fn (n SymbolNodeRef) node_type() ?MypyTypeNode {
	return match n {
		FuncDef { n.type_ }
		Var { n.type_ }
		Decorator { n.func.type_ }
		OverloadedFuncDef { MypyTypeNode(n.items[0].type_?) }
		else { none }
	}
}

pub fn (n SymbolNodeRef) get_context() Context {
	return match n {
		ClassDef { n.get_context() }
		Decorator { n.get_context() }
		FuncDef { n.get_context() }
		MypyFile { n.get_context() }
		OverloadedFuncDef { n.get_context() }
		TypeAlias { n.get_context() }
		TypeInfo { n.get_context() }
		Var { n.get_context() }
		PlaceholderNode { n.get_context() }
		else { n.get_context() }
	}
}

pub fn (mut n SymbolNodeRef) accept(mut v NodeVisitor) !AnyNode {
	mut it_n := n
	return match mut it_n {
		ClassDef { it_n.accept(mut v)! }
		Decorator { it_n.accept(mut v)! }
		FuncDef { it_n.accept(mut v)! }
		MypyFile { it_n.accept(mut v)! }
		OverloadedFuncDef { it_n.accept(mut v)! }
		TypeAlias { it_n.accept(mut v)! }
		TypeInfo { it_n.accept(mut v)! }
		Var { it_n.accept(mut v)! }
		PlaceholderNode { it_n.accept(mut v)! }
		else { return AnyNode(string('')) }
	}
}

pub type VarNode = Var | FuncDef

pub type RefExpr = MemberExpr | NameExpr

pub fn (n RefExpr) get_context() Context {
	return match n {
		MemberExpr, NameExpr { n.get_context() }
	}
}

pub fn (mut n RefExpr) accept(mut v NodeVisitor) !AnyNode {
	return match mut n {
		MemberExpr, NameExpr { n.accept(mut v)! }
	}
}

pub fn (e Expression) str() string {
	return 'Expression(...)'
}

