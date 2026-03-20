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

// ==================== PATTERNS ====================

interface Pattern {
	ASTNode
}

// ──────────────────────────────────────────────────
// Expressions
// ──────────────────────────────────────────────────

struct Identifier {
pub:
	token Token
	name  string
}

fn (n &Identifier) get_token() Token { return n.token }
fn (n &Identifier) str() string      { return 'Identifier(${n.name})' }

// ──────────────────────────────────────────────────

struct NumberLiteral {
pub:
	token  Token
	value  f64
	is_int bool
	raw    string
}

fn (n &NumberLiteral) get_token() Token { return n.token }
fn (n &NumberLiteral) str() string      { return 'NumberLiteral(${n.raw})' }

// ──────────────────────────────────────────────────

struct StringLiteral {
pub:
	token Token
	value string
	raw   string
}

fn (n &StringLiteral) get_token() Token { return n.token }
fn (n &StringLiteral) str() string      { return "StringLiteral('${n.value}')" }

// ──────────────────────────────────────────────────

struct BoolLiteral {
pub:
	token Token
	value bool
}

fn (n &BoolLiteral) get_token() Token { return n.token }
fn (n &BoolLiteral) str() string      { return 'BoolLiteral(${n.value})' }

// ──────────────────────────────────────────────────

struct NoneLiteral {
pub:
	token Token
}

fn (n &NoneLiteral) get_token() Token { return n.token }
fn (n &NoneLiteral) str() string      { return 'NoneLiteral' }

// ──────────────────────────────────────────────────

struct ListLiteral {
pub:
	token    Token
	elements []Expression
}

fn (n &ListLiteral) get_token() Token { return n.token }
fn (n &ListLiteral) str() string      { return 'ListLiteral(len=${n.elements.len})' }

// ──────────────────────────────────────────────────

struct DictEntry {
pub:
	key   Expression
	value Expression
}

struct DictLiteral {
pub:
	token Token
	pairs []DictEntry
}

fn (n &DictLiteral) get_token() Token { return n.token }
fn (n &DictLiteral) str() string      { return 'DictLiteral(len=${n.pairs.len})' }

// ──────────────────────────────────────────────────

struct TupleLiteral {
pub:
	token    Token
	elements []Expression
}

fn (n &TupleLiteral) get_token() Token { return n.token }
fn (n &TupleLiteral) str() string      { return 'TupleLiteral(len=${n.elements.len})' }

// ──────────────────────────────────────────────────

struct SetLiteral {
pub:
	token    Token
	elements []Expression
}

fn (n &SetLiteral) get_token() Token { return n.token }
fn (n &SetLiteral) str() string      { return 'SetLiteral(len=${n.elements.len})' }

// ──────────────────────────────────────────────────

struct BinaryOp {
pub:
	token    Token
	left     Expression
	operator Token
	right    Expression
}

fn (n &BinaryOp) get_token() Token { return n.token }
fn (n &BinaryOp) str() string      { return 'BinaryOp(${n.operator.value})' }

// ──────────────────────────────────────────────────

struct UnaryOp {
pub:
	token    Token
	operator Token
	operand  Expression
}

fn (n &UnaryOp) get_token() Token { return n.token }
fn (n &UnaryOp) str() string      { return 'UnaryOp(${n.operator.value})' }

// ──────────────────────────────────────────────────

struct Compare {
pub:
	token       Token
	left        Expression
	operators   []Token
	comparators []Expression
}

fn (n &Compare) get_token() Token { return n.token }
fn (n &Compare) str() string      { return 'Compare' }

// ──────────────────────────────────────────────────

struct KeywordArg {
pub:
	name  string
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
fn (n &Call) str() string      { return 'Call(${n.func.str()})' }

// ──────────────────────────────────────────────────

struct Attribute {
pub:
	token Token
	value Expression
	attr  string
}

fn (n &Attribute) get_token() Token { return n.token }
fn (n &Attribute) str() string      { return 'Attribute(${n.attr})' }

// ──────────────────────────────────────────────────

struct Subscript {
pub:
	token Token
	value Expression
	slice Expression
}

fn (n &Subscript) get_token() Token { return n.token }
fn (n &Subscript) str() string      { return 'Subscript' }

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
	params []Parameter
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

struct StarredExpr {
pub:
	token Token
	value Expression
}

fn (n &StarredExpr) get_token() Token { return n.token }
fn (n &StarredExpr) str() string      { return 'StarredExpr' }

// ──────────────────────────────────────────────────

struct IfExpr {
pub:
	token  Token
	test   Expression
	body   Expression
	orelse Expression
}

fn (n &IfExpr) get_token() Token { return n.token }
fn (n &IfExpr) str() string      { return 'IfExpr' }

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
fn (n &Module) str() string      { return 'Module(${n.filename}, stmts=${n.body.len})' }

// ──────────────────────────────────────────────────

struct ExpressionStmt {
pub:
	token      Token
	expression Expression
}

fn (n &ExpressionStmt) get_token() Token { return n.token }
fn (n &ExpressionStmt) str() string      { return 'ExpressionStmt' }

// ──────────────────────────────────────────────────

struct Assignment {
pub:
	token           Token
	targets         []Expression
	value           Expression
	annotated_type  ?Expression
}

fn (n &Assignment) get_token() Token { return n.token }
fn (n &Assignment) str() string      { return 'Assignment' }

// ──────────────────────────────────────────────────

struct AugmentedAssignment {
pub:
	token    Token
	target   Expression
	operator Token
	value    Expression
}

fn (n &AugmentedAssignment) get_token() Token { return n.token }
fn (n &AugmentedAssignment) str() string      { return 'AugmentedAssignment(${n.operator.value})' }

// ──────────────────────────────────────────────────

struct AnnAssignment {
pub:
	token      Token
	target     Expression
	annotation Expression
	value      ?Expression
}

fn (n &AnnAssignment) get_token() Token { return n.token }
fn (n &AnnAssignment) str() string      { return 'AnnAssignment' }

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

enum ParamKind {
	positional
	positional_or_keyword
	var_positional
	keyword_only
	var_keyword
}

struct Parameter {
pub:
	name       string
	annotation ?Expression
	default_   ?Expression
	kind       ParamKind
}

struct FunctionDef {
pub:
	token      Token
	name       string
	params     []Parameter
	body       []Statement
	decorators []Expression
	returns    ?Expression
	is_async   bool
}

fn (n &FunctionDef) get_token() Token { return n.token }
fn (n &FunctionDef) str() string      { return 'FunctionDef(${n.name})' }

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
	token      Token
	name       string
	bases      []Expression
	keywords   []KeywordArg
	body       []Statement
	decorators []Expression
}

fn (n &ClassDef) get_token() Token { return n.token }
fn (n &ClassDef) str() string      { return 'ClassDef(${n.name})' }

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
fn (n &ImportFrom) str() string      { return 'ImportFrom(${n.module})' }

// ──────────────────────────────────────────────────

struct Global {
pub:
	token Token
	names []string
}

fn (n &Global) get_token() Token { return n.token }
fn (n &Global) str() string      { return 'Global(${n.names})' }

// ──────────────────────────────────────────────────

struct Nonlocal {
pub:
	token Token
	names []string
}

fn (n &Nonlocal) get_token() Token { return n.token }
fn (n &Nonlocal) str() string      { return 'Nonlocal(${n.names})' }

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
	exception ?Expression
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

struct TypeAlias {
pub:
	token Token
	name  Expression
	value Expression
}

fn (n &TypeAlias) get_token() Token { return n.token }
fn (n &TypeAlias) str() string      { return 'TypeAlias' }

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
fn (n &MatchSingleton) str() string      { return 'MatchSingleton(${n.value.value})' }

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
