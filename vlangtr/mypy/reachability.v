// reachability.v — Utilities for determining code reachability
// Translated from mypy/reachability.py to V 0.5.x

module mypy

// Truth values of expressions
pub const always_true = 1
pub const mypy_true = 2 // True in mypy, False in runtime
pub const always_false = 3
pub const mypy_false = 4 // False in mypy, True in runtime
pub const truth_value_unknown = 5

// inverted_truth_mapping — inverted truth values
pub fn inverted_truth_mapping(value int) int {
	return match value {
		always_true { always_false }
		always_false { always_true }
		truth_value_unknown { truth_value_unknown }
		mypy_true { mypy_false }
		mypy_false { mypy_true }
		else { truth_value_unknown }
	}
}

// reverse_op — reverse comparison operators
pub fn reverse_op(op string) string {
	return match op {
		'==' { '==' }
		'!=' { '!=' }
		'<' { '>' }
		'>' { '<' }
		'<=' { '>=' }
		'>=' { '<=' }
		else { op }
	}
}

// infer_reachability_of_if_statement determines reachability of if statement
pub fn infer_reachability_of_if_statement(mut s IfStmt, options Options) {
	for i in 0 .. s.expr.len {
		result := infer_condition_value(s.expr[i], options)
		if result == always_false || result == mypy_false {
			// Condition is always false, skip if/elif body
			mark_block_unreachable(mut s.body[i])
		} else if result == always_true || result == mypy_true {
			// Condition is always true, remaining elif/else are unreachable
			if result == mypy_true {
				mark_block_mypy_only(mut s.body[i])
			}
			for j in i + 1 .. s.body.len {
				mark_block_unreachable(mut s.body[j])
			}

			// Ensure else body exists and mark as unreachable
			if mut eb := s.else_body {
				mark_block_unreachable(mut eb)
			}
			break
		}
	}
}

// infer_reachability_of_match_statement determines reachability of match statement
pub fn infer_reachability_of_match_statement(mut s MatchStmt, options Options) {
	for i in 0 .. s.guards.len {
		guard := s.guards[i]
		pattern_value := infer_pattern_value(s.patterns[i])

		mut guard_value := always_true
		if mut g := guard {
			guard_value = infer_condition_value(g, options)
		}

		if pattern_value == always_false || pattern_value == mypy_false
			|| guard_value == always_false || guard_value == mypy_false {
			// Case is always false, skip body
			mark_block_unreachable(mut s.bodies[i])
		} else if (pattern_value == always_true || pattern_value == mypy_true)
			&& (guard_value == always_true || guard_value == mypy_true) {
			for j in i + 1 .. s.bodies.len {
				mark_block_unreachable(mut s.bodies[j])
			}
		}

		if guard_value == mypy_true {
			mark_block_mypy_only(mut s.bodies[i])
		}
	}
}

// assert_will_always_fail checks if assert always fails
pub fn assert_will_always_fail(s AssertStmt, options Options) bool {
	result := infer_condition_value(s.expr, options)
	return result == always_false || result == mypy_false
}

// infer_condition_value determines the truth value of a condition
pub fn infer_condition_value(expr Expression, options Options) int {
	// Check for "not"
	if expr is UnaryExpr {
		ue := expr as UnaryExpr
		if ue.op == 'not' {
			positive := infer_condition_value(ue.expr, options)
			return inverted_truth_mapping(positive)
		}
	}

	pyversion := options.python_version
	mut name := ''

	mut result := truth_value_unknown

	match expr {
		NameExpr {
			name = expr.name
		}
		MemberExpr {
			name = expr.name
		}
		OpExpr {
			if expr.op !in ['or', 'and'] {
				return truth_value_unknown
			}

			left := infer_condition_value(expr.left, options)
			right := infer_condition_value(expr.right, options)
			results := [left, right]

			if expr.op == 'or' {
				if always_true in results {
					return always_true
				} else if mypy_true in results {
					return mypy_true
				} else if left == mypy_false && right == mypy_false {
					return mypy_false
				} else if results.all(it == always_false || it == mypy_false) {
					return always_false
				}
			} else if expr.op == 'and' {
				if always_false in results {
					return always_false
				} else if mypy_false in results {
					return mypy_false
				} else if left == always_true && right == always_true {
					return always_true
				} else if results.all(it == always_true || it == mypy_true) {
					return mypy_true
				}
			}
			return truth_value_unknown
		}
		else {
			result = consider_sys_version_info(expr, pyversion)
			if result == truth_value_unknown {
				result = consider_sys_platform(expr, options.platform)
			}
		}
	}

	if result == truth_value_unknown {
		if name == 'PY2' {
			result = always_false
		} else if name == 'PY3' {
			result = always_true
		} else if name == 'MYPY' || name == 'TYPE_CHECKING' {
			result = mypy_true
		} else if name in options.always_true {
			result = always_true
		} else if name in options.always_false {
			result = always_false
		}
	}

	return result
}

// infer_pattern_value determines the truth value of a pattern
pub fn infer_pattern_value(pattern Pattern) int {
	// We handle few cases and return unknown for others
	return truth_value_unknown
}

// consider_sys_version_info checks comparisons with sys.version_info
pub fn consider_sys_version_info(expr Expression, pyversion []int) int {
	if expr is ComparisonExpr {
		ce := expr as ComparisonExpr
		if ce.operators.len > 1 {
			return truth_value_unknown
		}

		op := ce.operators[0]
		if op !in ['==', '!=', '<=', '>=', '<', '>'] {
			return truth_value_unknown
		}
	}
	return truth_value_unknown
}

// consider_sys_platform checks comparisons with sys.platform
pub fn consider_sys_platform(expr Expression, platform string) int {
	if expr is ComparisonExpr {
		ce := expr as ComparisonExpr
		if ce.operators.len > 1 {
			return truth_value_unknown
		}
		op := ce.operators[0]
		if op !in ['==', '!='] {
			return truth_value_unknown
		}

		// Check sys.platform
		if !is_sys_attr(ce.operands[0], 'platform') {
			return truth_value_unknown
		}

		right := ce.operands[1]
		if right is StrExpr {
			return fixed_comparison(platform, op, (right as StrExpr).value)
		}
		return truth_value_unknown
	} else if expr is CallExpr {
		ce := expr as CallExpr
		if ce.callee is MemberExpr {
			me := ce.callee as MemberExpr
			if ce.args.len != 1 || ce.args[0] !is StrExpr {
				return truth_value_unknown
			}

			if !is_sys_attr(me.expr, 'platform') {
				return truth_value_unknown
			}

			if me.name != 'startswith' {
				return truth_value_unknown
			}

			se := ce.args[0] as StrExpr
			if platform.starts_with(se.value) {
				return always_true
			} else {
				return always_false
			}
		}
	}

	return truth_value_unknown
}

// fixed_comparison performs value comparison
pub fn fixed_comparison(left string, op string, right string) int {
	return match op {
		'==' { if left == right { always_true } else { always_false } }
		'!=' { if left != right { always_true } else { always_false } }
		else { truth_value_unknown }
	}
}

// contains_int_or_tuple_of_ints checks if expr is int or tuple of ints
pub fn contains_int_or_tuple_of_ints(expr Expression) ?string {
	if expr is IntExpr {
		return (expr as IntExpr).value.str()
	}
	return none
}

// contains_sys_version_info checks if expr is sys.version_info
pub fn contains_sys_version_info(expr Expression) ?string {
	return none
}

// is_sys_attr checks if expr is sys.<name>
pub fn is_sys_attr(expr Expression, name string) bool {
	if expr is MemberExpr {
		me := expr as MemberExpr
		if me.name == name {
			if me.expr is NameExpr {
				ne := me.expr as NameExpr
				if ne.name == 'sys' {
					return true
				}
			}
		}
	}
	return false
}

// mark_block_unreachable marks a block as unreachable
pub fn mark_block_unreachable(mut block Block) {
	block.is_unreachable = true
	mut visitor := MarkImportsUnreachableVisitor{}
	visitor.visit_block(mut block)
}

// MarkImportsUnreachableVisitor — visitor for marking imports as unreachable
pub struct MarkImportsUnreachableVisitor {}

pub fn (mut v MarkImportsUnreachableVisitor) visit_block(mut block Block) {
	for mut stmt in block.body {
		match mut stmt {
			Import { stmt.is_unreachable = true }
			ImportFrom { stmt.is_unreachable = true }
			ImportAll { stmt.is_unreachable = true }
			else {}
		}
	}
}

// mark_block_mypy_only marks a block as mypy-only
pub fn mark_block_mypy_only(mut block Block) {
	mut visitor := MarkImportsMypyOnlyVisitor{}
	visitor.visit_block(mut block)
}

// MarkImportsMypyOnlyVisitor — visitor for marking imports as mypy-only
pub struct MarkImportsMypyOnlyVisitor {}

pub fn (mut v MarkImportsMypyOnlyVisitor) visit_block(mut block Block) {
	for mut stmt in block.body {
		match mut stmt {
			Import { stmt.is_mypy_only = true }
			ImportFrom { stmt.is_mypy_only = true }
			ImportAll { stmt.is_mypy_only = true }
			FuncDef { stmt.is_mypy_only = true }
			else {}
		}
	}
}
