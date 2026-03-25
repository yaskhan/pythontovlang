// patterns.v — Match statement pattern nodes
// Translated from mypy/patterns.py to V 0.5.x

module mypy

// ---------------------------------------------------------------------------
// PatternBase embeds NodeBase for source location.
// ---------------------------------------------------------------------------

pub struct PatternBase {
pub mut:
	base NodeBase
}

// ---------------------------------------------------------------------------
// AsPattern — `<pattern> as <name>`, capture pattern, or wildcard pattern
//
// Python semantics:
//   pattern=None, name=X  → capture pattern
//   pattern=None, name=None → wildcard (_)
//   pattern=P,    name=X  → as-pattern
// ---------------------------------------------------------------------------

pub struct AsPattern {
pub mut:
	pbase   PatternBase
	pattern ?PatternNode // None → capture or wildcard
	name    ?NameExpr
}

pub fn (n AsPattern) get_context() Context {
	return n.pbase.base.ctx
}

pub fn (mut n AsPattern) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_as_pattern(mut n)!
}

// ---------------------------------------------------------------------------
// OrPattern — `<p1> | <p2> | ...`
// ---------------------------------------------------------------------------

pub struct OrPattern {
pub mut:
	pbase    PatternBase
	patterns []PatternNode
}

pub fn (n OrPattern) get_context() Context {
	return n.pbase.base.ctx
}

pub fn (mut n OrPattern) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_or_pattern(mut n)!
}

// ---------------------------------------------------------------------------
// ValuePattern — `x.y` or `x.y.z`
// ---------------------------------------------------------------------------

pub struct ValuePattern {
pub mut:
	pbase PatternBase
	expr  Expression
}

pub fn (n ValuePattern) get_context() Context {
	return n.pbase.base.ctx
}

pub fn (mut n ValuePattern) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_value_pattern(mut n)!
}

// ---------------------------------------------------------------------------
// SingletonPattern — True, False, or None
// ---------------------------------------------------------------------------

// SingletonValue represents exactly True, False or None from Python.
pub enum SingletonValue {
	true_
	false_
	none_
}

pub struct SingletonPattern {
pub mut:
	pbase PatternBase
	// None in Python → .none_ here; True → .true_; False → .false_
	value ?SingletonValue
}

pub fn (n SingletonPattern) get_context() Context {
	return n.pbase.base.ctx
}

pub fn (mut n SingletonPattern) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_singleton_pattern(mut n)!
}

// ---------------------------------------------------------------------------
// SequencePattern — `[<p1>, <p2>, ...]`
// ---------------------------------------------------------------------------

pub struct SequencePattern {
pub mut:
	pbase    PatternBase
	patterns []PatternNode
}

pub fn (n SequencePattern) get_context() Context {
	return n.pbase.base.ctx
}

pub fn (mut n SequencePattern) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_sequence_pattern(mut n)!
}

// ---------------------------------------------------------------------------
// StarredPattern — `*<name>` inside a sequence pattern
// capture=None means `*_` (wildcard spread)
// ---------------------------------------------------------------------------

pub struct StarredPattern {
pub mut:
	pbase   PatternBase
	capture ?NameExpr
}

pub fn (n StarredPattern) get_context() Context {
	return n.pbase.base.ctx
}

pub fn (mut n StarredPattern) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_starred_pattern(mut n)!
}

// ---------------------------------------------------------------------------
// MappingPattern — `{<key>: <pattern>, ..., **<rest>}`
// Invariant: len(keys) == len(values)
// ---------------------------------------------------------------------------

pub struct MappingPattern {
pub mut:
	pbase  PatternBase
	keys   []Expression
	values []PatternNode
	rest   ?NameExpr
}

pub fn (n MappingPattern) get_context() Context {
	return n.pbase.base.ctx
}

pub fn (mut n MappingPattern) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_mapping_pattern(mut n)!
}

// ---------------------------------------------------------------------------
// ClassPattern — `Cls(<positional>, keyword=<pattern>)`
// Invariant: len(keyword_keys) == len(keyword_values)
// ---------------------------------------------------------------------------

pub struct ClassPattern {
pub mut:
	pbase PatternBase
	// class_ref is always a MemberExpr or NameExpr (both are in Expression)
	class_ref      Expression
	positionals    []PatternNode
	keyword_keys   []string
	keyword_values []PatternNode
}

pub fn (n ClassPattern) get_context() Context {
	return n.pbase.base.ctx
}

pub fn (mut n ClassPattern) accept(mut v NodeVisitor) !AnyNode {
	return v.visit_class_pattern(mut n)!
}

// ---------------------------------------------------------------------------
// PatternNode sum-type — mirrors Python's Pattern base class
// All concrete pattern structs are listed here so the compiler can
// exhaustively match on them.
// ---------------------------------------------------------------------------

pub type PatternNode = AsPattern
	| ClassPattern
	| MappingPattern
	| OrPattern
	| SequencePattern
	| SingletonPattern
	| StarredPattern
	| ValuePattern

pub fn (mut p PatternNode) accept(mut v NodeVisitor) !AnyNode {
	return match mut p {
		AsPattern { p.accept(mut v)! }
		OrPattern { p.accept(mut v)! }
		ValuePattern { p.accept(mut v)! }
		SingletonPattern { p.accept(mut v)! }
		SequencePattern { p.accept(mut v)! }
		StarredPattern { p.accept(mut v)! }
		MappingPattern { p.accept(mut v)! }
		ClassPattern { p.accept(mut v)! }
	}
}

