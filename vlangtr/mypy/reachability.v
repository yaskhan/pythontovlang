// reachability.v — Utilities for determining code reachability
// Translated from mypy/reachability.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 13:30

module mypy

// Значения истинности выражений
pub const always_true = 1
pub const mypy_true = 2 // True в mypy, False в runtime
pub const always_false = 3
pub const mypy_false = 4 // False в mypy, True в runtime
pub const truth_value_unknown = 5

// inverted_truth_mapping — инвертированные значения истинности
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

// reverse_op — обратные операторы сравнения
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

// infer_reachability_of_if_statement определяет достижимость if statement
pub fn infer_reachability_of_if_statement(mut s IfStmt, options Options) {
	for i in 0 .. s.expr.len {
		result := infer_condition_value(s.expr[i], options)
		if result == always_false || result == mypy_false {
			// Условие всегда false, пропускаем тело if/elif
			mark_block_unreachable(mut s.body[i])
		} else if result == always_true || result == mypy_true {
			// Условие всегда true, остальные elif/else недостижимы
			if result == mypy_true {
				mark_block_mypy_only(mut s.body[i])
			}
			for body in s.body[i + 1..] {
				mark_block_unreachable(mut body)
			}

			// Убеждаемся, что else body существует и помечен как недостижимый
			if s.else_body == none {
				s.else_body = Block{}
			}
			mark_block_unreachable(mut s.else_body or { Block{} })
			break
		}
	}
}

// infer_reachability_of_match_statement определяет достижимость match statement
pub fn infer_reachability_of_match_statement(mut s MatchStmt, options Options) {
	for i, guard in s.guards {
		pattern_value := infer_pattern_value(s.patterns[i])

		guard_value := always_true
		if guard != none {
			guard_value = infer_condition_value(guard or { Expression(none) }, options)
		}

		if pattern_value == always_false || pattern_value == mypy_false
			|| guard_value == always_false || guard_value == mypy_false {
			// Case всегда false, пропускаем тело
			mark_block_unreachable(mut s.bodies[i])
		} else if (pattern_value == always_true || pattern_value == mypy_true)
			&& (guard_value == always_true || guard_value == mypy_true) {
			for body in s.bodies[i + 1..] {
				mark_block_unreachable(mut body)
			}
		}

		if guard_value == mypy_true {
			mark_block_mypy_only(mut s.bodies[i])
		}
	}
}

// assert_will_always_fail проверяет, всегда ли assert fails
pub fn assert_will_always_fail(s AssertStmt, options Options) bool {
	result := infer_condition_value(s.expr, options)
	return result == always_false || result == mypy_false
}

// infer_condition_value определяет истинность условия
pub fn infer_condition_value(expr Expression, options Options) int {
	// Проверяем на "not"
	if expr is UnaryExpr {
		ue := expr as UnaryExpr
		if ue.op == 'not' {
			positive := infer_condition_value(ue.expr, options)
			return inverted_truth_mapping(positive)
		}
	}

	pyversion := options.python_version
	name := ''

	mut result := truth_value_unknown

	if expr is NameExpr {
		name = (expr as NameExpr).name
	} else if expr is MemberExpr {
		name = (expr as MemberExpr).name
	} else if expr is OpExpr {
		oe := expr as OpExpr
		if oe.op !in ['or', 'and'] {
			return truth_value_unknown
		}

		left := infer_condition_value(oe.left, options)
		right := infer_condition_value(oe.right, options)
		results := [left, right]

		if oe.op == 'or' {
			if always_true in results {
				return always_true
			} else if mypy_true in results {
				return mypy_true
			} else if left == mypy_false && right == mypy_false {
				return mypy_false
			} else if results.all(it == always_false || it == mypy_false) {
				return always_false
			}
		} else if oe.op == 'and' {
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
	} else {
		result = consider_sys_version_info(expr, pyversion)
		if result == truth_value_unknown {
			result = consider_sys_platform(expr, options.platform)
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

// infer_pattern_value определяет истинность паттерна
pub fn infer_pattern_value(pattern Pattern) int {
	if pattern is AsPattern {
		ap := pattern as AsPattern
		if ap.pattern == none {
			return always_true
		}
	} else if pattern is OrPattern {
		op := pattern as OrPattern
		for p in op.patterns {
			if infer_pattern_value(p) == always_true {
				return always_true
			}
		}
	}
	return truth_value_unknown
}

// consider_sys_version_info проверяет сравнения с sys.version_info
pub fn consider_sys_version_info(expr Expression, pyversion []int) int {
	if expr !is ComparisonExpr {
		return truth_value_unknown
	}

	ce := expr as ComparisonExpr
	if ce.operators.len > 1 {
		return truth_value_unknown
	}

	op := ce.operators[0]
	if op !in ['==', '!=', '<=', '>=', '<', '>'] {
		return truth_value_unknown
	}

	// Упрощённая версия — без полной поддержки всех случаев
	return truth_value_unknown
}

// consider_sys_platform проверяет сравнения с sys.platform
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

		// Проверяем sys.platform
		if !is_sys_attr(ce.operands[0], 'platform') {
			return truth_value_unknown
		}

		right := ce.operands[1]
		if right !is StrExpr {
			return truth_value_unknown
		}

		se := right as StrExpr
		return fixed_comparison(platform, op, se.value)
	} else if expr is CallExpr {
		ce := expr as CallExpr
		if ce.callee !is MemberExpr {
			return truth_value_unknown
		}

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

	return truth_value_unknown
}

// fixed_comparison выполняет сравнение значений
pub fn fixed_comparison(left any, op string, right any) int {
	rmap := {
		false: always_false
		true:  always_true
	}

	return match op {
		'==' { rmap[left == right] }
		'!=' { rmap[left != right] }
		'<=' { rmap[left <= right] }
		'>=' { rmap[left >= right] }
		'<' { rmap[left < right] }
		'>' { rmap[left > right] }
		else { truth_value_unknown }
	}
}

// contains_int_or_tuple_of_ints проверяет, является ли expr int или tuple of ints
pub fn contains_int_or_tuple_of_ints(expr Expression) ?any {
	if expr is IntExpr {
		return (expr as IntExpr).value
	}
	if expr is TupleExpr {
		te := expr as TupleExpr
		mut thing := []int{}
		for item in te.items {
			if item !is IntExpr {
				return none
			}
			thing << (item as IntExpr).value
		}
		return thing
	}
	return none
}

// contains_sys_version_info проверяет, является ли expr sys.version_info
pub fn contains_sys_version_info(expr Expression) ?any {
	if is_sys_attr(expr, 'version_info') {
		return [none, none] // sys.version_info[:]
	}

	if expr is IndexExpr {
		ie := expr as IndexExpr
		if is_sys_attr(ie.base, 'version_info') {
			index := ie.index
			if index is IntExpr {
				return (index as IntExpr).value
			}
			if index is SliceExpr {
				se := index as SliceExpr
				if se.stride != none && (se.stride !is IntExpr || (se.stride as IntExpr).value != 1) {
					return none
				}
				mut begin := ?int(none)
				mut end := ?int(none)
				if se.begin_index != none {
					if se.begin_index !is IntExpr {
						return none
					}
					begin = (se.begin_index as IntExpr).value
				}
				if se.end_index != none {
					if se.end_index !is IntExpr {
						return none
					}
					end = (se.end_index as IntExpr).value
				}
				return [begin, end]
			}
		}
	}

	return none
}

// is_sys_attr проверяет, является ли expr sys.<name>
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

// mark_block_unreachable помечает блок как недостижимый
pub fn mark_block_unreachable(mut block Block) {
	block.is_unreachable = true
	mut visitor := MarkImportsUnreachableVisitor{}
	visitor.visit_block(mut block)
}

// MarkImportsUnreachableVisitor — посетитель для пометки импортов как недостижимых
pub struct MarkImportsUnreachableVisitor {}

pub fn (mut v MarkImportsUnreachableVisitor) visit_block(mut block Block) {
	for stmt in block.body {
		if stmt is Import {
			(stmt as Import).is_unreachable = true
		} else if stmt is ImportFrom {
			(stmt as ImportFrom).is_unreachable = true
		} else if stmt is ImportAll {
			(stmt as ImportAll).is_unreachable = true
		}
	}
}

// mark_block_mypy_only помечает блок как mypy-only
pub fn mark_block_mypy_only(mut block Block) {
	mut visitor := MarkImportsMypyOnlyVisitor{}
	visitor.visit_block(mut block)
}

// MarkImportsMypyOnlyVisitor — посетитель для пометки импортов как mypy-only
pub struct MarkImportsMypyOnlyVisitor {}

pub fn (mut v MarkImportsMypyOnlyVisitor) visit_block(mut block Block) {
	for stmt in block.body {
		if stmt is Import {
			(stmt as Import).is_mypy_only = true
		} else if stmt is ImportFrom {
			(stmt as ImportFrom).is_mypy_only = true
		} else if stmt is ImportAll {
			(stmt as ImportAll).is_mypy_only = true
		} else if stmt is FuncDef {
			(stmt as FuncDef).is_mypy_only = true
		}
	}
}
