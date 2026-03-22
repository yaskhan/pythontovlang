// Work in progress by Antigravity. Started: 2026-03-22 10:10
module mypy

// Type checking for Pattern Matching constructs (match/case).

pub struct PatternTypeResult {
pub mut:
	type_    MypyTypeNode
	captures map[string]MypyTypeNode
}

pub struct PatternChecker {
pub mut:
	chk           &TypeChecker
	type_context  []MypyTypeNode
}

pub fn (mut pc PatternChecker) accept(p PatternNode, type_context MypyTypeNode) PatternTypeResult {
	pc.type_context << type_context
	mut res := PatternTypeResult{ type_: type_context }
	
	match p {
		AsPattern { res = pc.visit_as_pattern(p) }
		OrPattern { res = pc.visit_or_pattern(p) }
		ValuePattern { res = pc.visit_value_pattern(p) }
		SingletonPattern { res = pc.visit_singleton_pattern(p) }
		SequencePattern { res = pc.visit_sequence_pattern(p) }
		StarredPattern { res = pc.visit_starred_pattern(p) }
		MappingPattern { res = pc.visit_mapping_pattern(p) }
		ClassPattern { res = pc.visit_class_pattern(p) }
	}
	
	pc.type_context.pop()
	return res
}

pub fn (mut pc PatternChecker) visit_as_pattern(p &AsPattern) PatternTypeResult {
	// as-pattern can be variable binding or wildcard (if pattern=none, name=none)
	mut res := PatternTypeResult{
		type_: pc.type_context.last()
	}
	
	if pattern := p.pattern {
		res = pc.accept(pattern, pc.type_context.last())
	}
	
	if name_expr := p.name {
		res.captures[name_expr.name] = res.type_
	}
	
	return res
}

pub fn (mut pc PatternChecker) visit_or_pattern(p &OrPattern) PatternTypeResult {
	mut res := PatternTypeResult{ type_: pc.type_context.last() }
	// In Mypy all sub-type impressions are merged
	for pat in p.patterns {
		_ = pc.accept(pat, pc.type_context.last())
	}
	return res
}

pub fn (mut pc PatternChecker) visit_value_pattern(p &ValuePattern) PatternTypeResult {
	// Value must match expected type. We just check the right side.
	pc.chk.expr_checker_.accept(p.expr, pc.type_context.last(), false, false, false)
	return PatternTypeResult{ type_: pc.type_context.last() }
}

pub fn (mut pc PatternChecker) visit_singleton_pattern(p &SingletonPattern) PatternTypeResult {
	// None, True, False
	return PatternTypeResult{ type_: pc.type_context.last() }
}

pub fn (mut pc PatternChecker) visit_sequence_pattern(p &SequencePattern) PatternTypeResult {
	// Check sequence elements
	mut res := PatternTypeResult{ type_: pc.type_context.last() }
	item_ctx := MypyTypeNode(AnyType{type_of_any: .special_form}) // fallback item context
	for pat in p.patterns {
		pat_res := pc.accept(pat, item_ctx)
		for k, v in pat_res.captures {
			res.captures[k] = v
		}
	}
	return res
}

pub fn (mut pc PatternChecker) visit_starred_pattern(p &StarredPattern) PatternTypeResult {
	mut res := PatternTypeResult{ type_: pc.type_context.last() }
	if name_expr := p.capture {
		res.captures[name_expr.name] = MypyTypeNode(AnyType{type_of_any: .special_form})
	}
	return res
}

pub fn (mut pc PatternChecker) visit_mapping_pattern(p &MappingPattern) PatternTypeResult {
	mut res := PatternTypeResult{ type_: pc.type_context.last() }
	for val_pat in p.values {
		pat_res := pc.accept(val_pat, MypyTypeNode(AnyType{type_of_any: .special_form}))
		for k, v in pat_res.captures {
			res.captures[k] = v
		}
	}
	
	if rest := p.rest {
		res.captures[rest.name] = MypyTypeNode(AnyType{type_of_any: .special_form})
	}
	return res
}

pub fn (mut pc PatternChecker) visit_class_pattern(p &ClassPattern) PatternTypeResult {
	mut res := PatternTypeResult{ type_: pc.type_context.last() }
	
	for pat in p.positionals {
		pat_res := pc.accept(pat, MypyTypeNode(AnyType{type_of_any: .special_form}))
		for k, v in pat_res.captures {
			res.captures[k] = v
		}
	}
	
	for pat in p.keyword_values {
		pat_res := pc.accept(pat, MypyTypeNode(AnyType{type_of_any: .special_form}))
		for k, v in pat_res.captures {
			res.captures[k] = v
		}
	}
	
	return res
}
