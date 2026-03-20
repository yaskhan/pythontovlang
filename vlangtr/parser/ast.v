module main

// ==================== AST BASE ====================

interface ASTNode {
	get_token() Token
	str() string
}

// ==================== EXPRESSIONS ====================

interface Expression {
	ASTNode
}

// ==================== STATEMENTS ====================

interface Statement {
	ASTNode
}

// ==================== PATTERN ====================

interface Pattern {
	ASTNode
}

// ──────────────────────────────────────────────────
// Enums
// ──────────────────────────────────────────────────

enum ExprContext {
	load
	store
	del
}

// ──────────────────────────────────────────────────
// Expressions
// ──────────────────────────────────────────────────

struct Name {
pub:
	token Token
	id    string
pub mut:
	ctx   ExprContext
}

fn (n &Name) get_token() Token { return n.token }
fn (n &Name) str() string      { return 'Name(id=\'${n.id}\', ctx=${n.ctx})' }

// ──────────────────────────────────────────────────

struct Constant {
pub:
	token Token
	value string // Store as string for simplicity in debug output, or use any
}

fn (n &Constant) get_token() Token { return n.token }
fn (n &Constant) str() string      { return 'Constant(value=${n.value})' }

// None placeholder for Dict keys with **kwargs
struct NoneExpr {
pub:
	token Token
}

fn (n &NoneExpr) get_token() Token { return n.token }
fn (n &NoneExpr) str() string      { return 'None' }

// ──────────────────────────────────────────────────

struct FormattedValue {
pub:
	token        Token
	value        Expression
	conversion   int // -1 (none), 115 (s), 114 (r), 97 (a)
	format_spec  ?Expression // JoinedStr
}

fn (n &FormattedValue) get_token() Token { return n.token }
fn (n &FormattedValue) str() string      { return 'FormattedValue' }

// ──────────────────────────────────────────────────

struct JoinedStr {
pub:
	token  Token
	values []Expression // Constant or FormattedValue
}

fn (n &JoinedStr) get_token() Token { return n.token }
fn (n &JoinedStr) str() string      { return 'JoinedStr' }

// ──────────────────────────────────────────────────

struct List {
pub:
	token    Token
	elements []Expression
pub mut:
	ctx      ExprContext
}

fn (n &List) get_token() Token { return n.token }
fn (n &List) str() string      { return 'List(elts=[...], ctx=${n.ctx})' }

// ──────────────────────────────────────────────────

struct DictEntry {
pub:
	key   Expression
	value Expression
}

struct Dict {
pub:
	token Token
	keys  []Expression
	values []Expression
}

fn (n &Dict) get_token() Token { return n.token }
fn (n &Dict) str() string      { return 'Dict(keys=[...], values=[...])' }

// ──────────────────────────────────────────────────

struct Tuple {
pub:
	token    Token
	elements []Expression
pub mut:
	ctx      ExprContext
}

fn (n &Tuple) get_token() Token { return n.token }
fn (n &Tuple) str() string      { return 'Tuple(elts=[...], ctx=${n.ctx})' }

// ──────────────────────────────────────────────────

struct Set {
pub:
	token    Token
	elements []Expression
}

fn (n &Set) get_token() Token { return n.token }
fn (n &Set) str() string      { return 'Set(elts=[...])' }

// ──────────────────────────────────────────────────

struct BinaryOp {
pub:
	token    Token
	left     Expression
	op       Token
	right    Expression
}

fn (n &BinaryOp) get_token() Token { return n.token }
fn (n &BinaryOp) str() string      { return 'BinOp(op=${n.op.value})' }

// ──────────────────────────────────────────────────

struct UnaryOp {
pub:
	token    Token
	op       Token
	operand  Expression
}

fn (n &UnaryOp) get_token() Token { return n.token }
fn (n &UnaryOp) str() string      { return 'UnaryOp(op=${n.op.value})' }

// ──────────────────────────────────────────────────

struct Compare {
pub:
	token       Token
	left        Expression
	ops         []Token
	comparators []Expression
}

fn (n &Compare) get_token() Token { return n.token }
fn (n &Compare) str() string      { return 'Compare' }

// ──────────────────────────────────────────────────

struct KeywordArg {
pub:
	arg   string
	value Expression
}

struct Call {
pub:
	token    Token
	func     Expression
	args     []Expression
	keywords []KeywordArg
}

fn (n &Call) get_token() Token { return n.token }
fn (n &Call) str() string      { return 'Call(func=${n.func.str()})' }

// ──────────────────────────────────────────────────

struct Attribute {
pub:
	token Token
	value Expression
	attr  string
pub mut:
	ctx   ExprContext
}

fn (n &Attribute) get_token() Token { return n.token }
fn (n &Attribute) str() string      { return 'Attribute(attr=\'${n.attr}\', ctx=${n.ctx})' }

// ──────────────────────────────────────────────────

struct Subscript {
pub:
	token Token
	value Expression
	slice Expression
pub mut:
	ctx   ExprContext
}

fn (n &Subscript) get_token() Token { return n.token }
fn (n &Subscript) str() string      { return 'Subscript(ctx=${n.ctx})' }

// ──────────────────────────────────────────────────

struct Slice {
pub:
	token Token
	lower ?Expression
	upper ?Expression
	step  ?Expression
}

fn (n &Slice) get_token() Token { return n.token }
fn (n &Slice) str() string      { return 'Slice' }

// ──────────────────────────────────────────────────

struct Lambda {
pub:
	token  Token
	args   Arguments
	body   Expression
}

fn (n &Lambda) get_token() Token { return n.token }
fn (n &Lambda) str() string      { return 'Lambda' }

// ──────────────────────────────────────────────────

struct Comprehension {
pub:
	target Expression
	iter   Expression
	ifs    []Expression
	is_async bool
}

struct ListComp {
pub:
	token      Token
	elt        Expression
	generators []Comprehension
}

fn (n &ListComp) get_token() Token { return n.token }
fn (n &ListComp) str() string      { return 'ListComp' }

// ──────────────────────────────────────────────────

struct DictComp {
pub:
	token      Token
	key        Expression
	value      Expression
	generators []Comprehension
}

fn (n &DictComp) get_token() Token { return n.token }
fn (n &DictComp) str() string      { return 'DictComp' }

// ──────────────────────────────────────────────────

struct SetComp {
pub:
	token      Token
	elt        Expression
	generators []Comprehension
}

fn (n &SetComp) get_token() Token { return n.token }
fn (n &SetComp) str() string      { return 'SetComp' }

// ──────────────────────────────────────────────────

struct GeneratorExp {
pub:
	token      Token
	elt        Expression
	generators []Comprehension
}

fn (n &GeneratorExp) get_token() Token { return n.token }
fn (n &GeneratorExp) str() string      { return 'GeneratorExp' }

// ──────────────────────────────────────────────────

struct Await {
pub:
	token Token
	value Expression
}

fn (n &Await) get_token() Token { return n.token }
fn (n &Await) str() string      { return 'Await' }

// ──────────────────────────────────────────────────

struct Yield {
pub:
	token Token
	value ?Expression
}

fn (n &Yield) get_token() Token { return n.token }
fn (n &Yield) str() string      { return 'Yield' }

// ──────────────────────────────────────────────────

struct YieldFrom {
pub:
	token Token
	value Expression
}

fn (n &YieldFrom) get_token() Token { return n.token }
fn (n &YieldFrom) str() string      { return 'YieldFrom' }

// ──────────────────────────────────────────────────

struct Starred {
pub:
	token Token
pub mut:
	value Expression
	ctx   ExprContext
}

fn (n &Starred) get_token() Token { return n.token }
fn (n &Starred) str() string      { return 'Starred(ctx=${n.ctx})' }

// ──────────────────────────────────────────────────

struct IfExp {
pub:
	token  Token
	test   Expression
	body   Expression
	orelse Expression
}

fn (n &IfExp) get_token() Token { return n.token }
fn (n &IfExp) str() string      { return 'IfExp' }

// ──────────────────────────────────────────────────
// Statements
// ──────────────────────────────────────────────────

struct Module {
pub:
	token    Token
	body     []Statement
	filename string
}

fn (n &Module) get_token() Token { return n.token }
fn (n &Module) str() string      { return 'Module(body=[...])' }

// ──────────────────────────────────────────────────

struct Expr {
pub:
	token Token
	value Expression
}

fn (n &Expr) get_token() Token { return n.token }
fn (n &Expr) str() string      { return 'Expr' }

// ──────────────────────────────────────────────────

struct Assign {
pub:
	token   Token
	targets []Expression
	value   Expression
}

fn (n &Assign) get_token() Token { return n.token }
fn (n &Assign) str() string      { return 'Assign' }

// ──────────────────────────────────────────────────

struct AugAssign {
pub:
	token    Token
	target   Expression
	op       Token
	value    Expression
}

fn (n &AugAssign) get_token() Token { return n.token }
fn (n &AugAssign) str() string      { return 'AugAssign' }

// ──────────────────────────────────────────────────

struct AnnAssign {
pub:
	token      Token
	target     Expression
	annotation Expression
	value      ?Expression
	simple     int
}

fn (n &AnnAssign) get_token() Token { return n.token }
fn (n &AnnAssign) str() string      { return 'AnnAssign' }

// ──────────────────────────────────────────────────

struct If {
pub:
	token  Token
	test   Expression
	body   []Statement
	orelse []Statement
}

fn (n &If) get_token() Token { return n.token }
fn (n &If) str() string      { return 'If' }

// ──────────────────────────────────────────────────

struct While {
pub:
	token  Token
	test   Expression
	body   []Statement
	orelse []Statement
}

fn (n &While) get_token() Token { return n.token }
fn (n &While) str() string      { return 'While' }

// ──────────────────────────────────────────────────

struct For {
pub:
	token    Token
	target   Expression
	iter     Expression
	body     []Statement
	orelse   []Statement
	is_async bool
}

fn (n &For) get_token() Token { return n.token }
fn (n &For) str() string      { return 'For' }

// ──────────────────────────────────────────────────

struct WithItem {
pub:
	context_expr  Expression
	optional_vars ?Expression
}

struct With {
pub:
	token    Token
	items    []WithItem
	body     []Statement
	is_async bool
}

fn (n &With) get_token() Token { return n.token }
fn (n &With) str() string      { return 'With' }

// ──────────────────────────────────────────────────

struct Arguments {
pub:
	args []Parameter
	// Add more (vararg, kwarg, etc) if needed
}

struct Parameter {
pub:
	arg        string
	annotation ?Expression
	default_   ?Expression
	// kind       ParamKind // Python AST uses separate lists for different kinds
}

struct FunctionDef {
pub:
	token      Token
	name       string
	args       Arguments
	body       []Statement
	decorator_list []Expression
	returns    ?Expression
	is_async   bool
}

fn (n &FunctionDef) get_token() Token { return n.token }
fn (n &FunctionDef) str() string      { return 'FunctionDef(name=\'${n.name}\')' }

// ──────────────────────────────────────────────────

struct Return {
pub:
	token Token
	value ?Expression
}

fn (n &Return) get_token() Token { return n.token }
fn (n &Return) str() string      { return 'Return' }

// ──────────────────────────────────────────────────

struct ClassDef {
pub:
	token          Token
	name           string
	bases          []Expression
	keywords       []KeywordArg
	body           []Statement
	decorator_list []Expression
}

fn (n &ClassDef) get_token() Token { return n.token }
fn (n &ClassDef) str() string      { return 'ClassDef(name=\'${n.name}\')' }

// ──────────────────────────────────────────────────

struct Alias {
pub:
	name   string
	asname ?string
}

struct Import {
pub:
	token Token
	names []Alias
}

fn (n &Import) get_token() Token { return n.token }
fn (n &Import) str() string      { return 'Import' }

// ──────────────────────────────────────────────────

struct ImportFrom {
pub:
	token  Token
	module string
	names  []Alias
	level  int
}

fn (n &ImportFrom) get_token() Token { return n.token }
fn (n &ImportFrom) str() string      { return 'ImportFrom' }

// ──────────────────────────────────────────────────

struct Global {
pub:
	token Token
	names []string
}

fn (n &Global) get_token() Token { return n.token }
fn (n &Global) str() string      { return 'Global' }

// ──────────────────────────────────────────────────

struct Nonlocal {
pub:
	token Token
	names []string
}

fn (n &Nonlocal) get_token() Token { return n.token }
fn (n &Nonlocal) str() string      { return 'Nonlocal' }

// ──────────────────────────────────────────────────

struct Assert {
pub:
	token Token
	test  Expression
	msg   ?Expression
}

fn (n &Assert) get_token() Token { return n.token }
fn (n &Assert) str() string      { return 'Assert' }

// ──────────────────────────────────────────────────

struct Raise {
pub:
	token     Token
	exc       ?Expression
	cause     ?Expression
}

fn (n &Raise) get_token() Token { return n.token }
fn (n &Raise) str() string      { return 'Raise' }

// ──────────────────────────────────────────────────

struct ExceptHandler {
pub:
	token Token
	typ   ?Expression
	name  ?string
	body  []Statement
}

struct Try {
pub:
	token     Token
	body      []Statement
	handlers  []ExceptHandler
	orelse    []Statement
	finalbody []Statement
}

fn (n &Try) get_token() Token { return n.token }
fn (n &Try) str() string      { return 'Try' }

// ──────────────────────────────────────────────────

struct Pass {
pub:
	token Token
}

fn (n &Pass) get_token() Token { return n.token }
fn (n &Pass) str() string      { return 'Pass' }

// ──────────────────────────────────────────────────

struct Break {
pub:
	token Token
}

fn (n &Break) get_token() Token { return n.token }
fn (n &Break) str() string      { return 'Break' }

// ──────────────────────────────────────────────────

struct Continue {
pub:
	token Token
}

fn (n &Continue) get_token() Token { return n.token }
fn (n &Continue) str() string      { return 'Continue' }

// ──────────────────────────────────────────────────

struct Delete {
pub:
	token   Token
	targets []Expression
}

fn (n &Delete) get_token() Token { return n.token }
fn (n &Delete) str() string      { return 'Delete' }

// ──────────────────────────────────────────────────

struct MatchCase {
pub:
	pattern Pattern
	guard   ?Expression
	body    []Statement
}

struct Match {
pub:
	token   Token
	subject Expression
	cases   []MatchCase
}

fn (n &Match) get_token() Token { return n.token }
fn (n &Match) str() string      { return 'Match' }

// ──────────────────────────────────────────────────
// Patterns
// ──────────────────────────────────────────────────

struct MatchValue {
pub:
	token Token
	value Expression
}

fn (n &MatchValue) get_token() Token { return n.token }
fn (n &MatchValue) str() string      { return 'MatchValue' }

// ──────────────────────────────────────────────────

struct MatchSingleton {
pub:
	token Token
	value Token
}

fn (n &MatchSingleton) get_token() Token { return n.token }
fn (n &MatchSingleton) str() string      { return 'MatchSingleton' }

// ──────────────────────────────────────────────────

struct MatchSequence {
pub:
	token    Token
	patterns []Pattern
}

fn (n &MatchSequence) get_token() Token { return n.token }
fn (n &MatchSequence) str() string      { return 'MatchSequence' }

// ──────────────────────────────────────────────────

struct MatchMapping {
pub:
	token    Token
	keys     []Expression
	patterns []Pattern
	rest     ?string
}

fn (n &MatchMapping) get_token() Token { return n.token }
fn (n &MatchMapping) str() string      { return 'MatchMapping' }

// ──────────────────────────────────────────────────

struct MatchClass {
pub:
	token        Token
	cls          Expression
	patterns     []Pattern
	kwd_attrs    []string
	kwd_patterns []Pattern
}

fn (n &MatchClass) get_token() Token { return n.token }
fn (n &MatchClass) str() string      { return 'MatchClass' }

// ──────────────────────────────────────────────────

struct MatchStar {
pub:
	token Token
	name  ?string
}

fn (n &MatchStar) get_token() Token { return n.token }
fn (n &MatchStar) str() string      { return 'MatchStar' }

// ──────────────────────────────────────────────────

struct MatchAs {
pub:
	token   Token
	pattern ?Pattern
	name    ?string
}

fn (n &MatchAs) get_token() Token { return n.token }
fn (n &MatchAs) str() string      { return 'MatchAs' }

// ──────────────────────────────────────────────────

struct MatchOr {
pub:
	token    Token
	patterns []Pattern
}

fn (n &MatchOr) get_token() Token { return n.token }
fn (n &MatchOr) str() string      { return 'MatchOr' }
