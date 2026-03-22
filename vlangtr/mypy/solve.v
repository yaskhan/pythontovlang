// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 11:30
module mypy

// solve.v — Решатель ограничений (Type Constraint Solver).
// Он принимает список ограничений T <: X, T >: Y и находит, чему равен T.

// В Mypy `Constraint` определен в constraints.py, но пока он у нас в infer.v.
// Вынесем логику решения в отдельный файл.

// solve_constraints - Основной метод
pub fn (mut ctx ArgumentInferContext) solve_constraints_v(
	type_vars []MypyTypeNode,
	constraints []Constraint,
	strict bool,
	allow_polymorphic bool
) ([]?MypyTypeNode, []MypyTypeNode) {
	
	mut lowers := map[string][]MypyTypeNode{}
	mut uppers := map[string][]MypyTypeNode{}
	
	// 1. Собираем верхние (uppers) и нижние (lowers) границы для каждой TypeVar
	for c in constraints {
		tv_name := c.type_var.type_str() // В идеале TypeVarId.
		// Если Constraint(T <: X) (sub_type_of)
		if c.op == .subtype_of {
			uppers[tv_name] << c.target
		} else {
			lowers[tv_name] << c.target
		}
	}
	
	mut res := []?MypyTypeNode{}
	
	// 2. Решаем
	for tv in type_vars {
		tv_name := tv.type_str()
		solved := solve_one(lowers[tv_name], uppers[tv_name])
		
		if solved != none {
			res << solved
		} else if strict {
			// fallback к Any в Mypy если не нашли (или ошибка)
			res << none
		} else {
			res << MypyTypeNode(AnyType{type_of_any: .special_form})
		}
	}
	
	return res, type_vars
}

// solve_one - Решает ограничения для ОДНОЙ переменной T.
pub fn solve_one(lowers []MypyTypeNode, uppers []MypyTypeNode) ?MypyTypeNode {
	mut bottom := ?MypyTypeNode(none)
	mut top := ?MypyTypeNode(none)
	
	// Если есть нижние границы: мы должны найти их Least Upper Bound (Join)
	if lowers.len > 0 {
		bottom = join_type_list(lowers)
	}
	
	// Если есть верхние границы: мы должны найти их Greatest Lower Bound (Meet)
	if uppers.len > 0 {
		top = meet_type_list(uppers)
	}
	
	// Если есть и top, и bottom, нужно проверить что bottom <: top
	// Mypy делает это и выбирает bottom (так как нам нужен наиболее точный тип).
	if b := bottom {
		return b
	} else if t := top {
		return t
	}
	
	return none
}
