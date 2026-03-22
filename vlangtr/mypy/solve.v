// Я Cline работаю над этим файлом. Начало: 2026-03-22 19:57
// solve.v — Type inference constraint solving
// Переведён из mypy/solve.py

module mypy

// Bounds — маппинг TypeVarId -> множество типов
pub type Bounds = map[TypeVarId]map[string]bool

// Graph — множество рёбер между типовыми переменными
pub type Graph = map[string]bool

// Solutions — маппинг TypeVarId -> решение
pub type Solutions = map[TypeVarId]?MypyTypeNode

// solve_constraints решает ограничения типов
// Возвращает лучшие типы для типовых переменных
pub fn solve_constraints(original_vars []TypeVarLikeType, constraints []Constraint, strict bool, allow_polymorphic bool) ([]?MypyTypeNode, []TypeVarLikeType) {
	mut vars := []TypeVarId{}
	for tv in original_vars {
		vars << tv.id
	}

	if vars.len == 0 {
		return []?MypyTypeNode{}, []TypeVarLikeType{}
	}

	mut originals := map[TypeVarId]TypeVarLikeType{}
	for tv in original_vars {
		originals[tv.id] = tv
	}

	mut extra_vars := []TypeVarId{}
	for c in constraints {
		for v in c.extra_tvars {
			if v.id !in vars && v.id !in extra_vars {
				extra_vars << v.id
			}
			if v.id !in originals {
				originals[v.id] = v
			}
		}
	}

	mut cmap := map[TypeVarId][]Constraint{}
	for tv in vars + extra_vars {
		cmap[tv] = []Constraint{}
	}
	for con in constraints {
		if con.type_var in vars + extra_vars {
			cmap[con.type_var] << con
		}
	}

	mut solutions := map[TypeVarId]?MypyTypeNode{}
	for tv, cs in cmap {
		if cs.len == 0 {
			continue
		}
		mut lowers := []MypyTypeNode{}
		mut uppers := []MypyTypeNode{}
		for c in cs {
			if c.op == supertype_of {
				lowers << c.target
			} else {
				uppers << c.target
			}
		}
		solution := solve_one(lowers, uppers)
		solutions[tv] = solution
	}

	mut res := []?MypyTypeNode{}
	for v in vars {
		if v in solutions {
			res << solutions[v]
		} else {
			if strict {
				mut candidate := UninhabitedTypeNode{}
				res << candidate
			} else {
				res << AnyTypeNode{
					reason: TypeOfAny.special_form
				}
			}
		}
	}

	return res, []TypeVarLikeType{}
}

// solve_one решает ограничения используя meet верхних границ и join нижних границ
pub fn solve_one(lowers []MypyTypeNode, uppers []MypyTypeNode) ?MypyTypeNode {
	mut candidate := ?MypyTypeNode(none)

	mut new_uppers := []MypyTypeNode{}
	for u in uppers {
		pu := get_proper_type(u)
		if pu !is UninhabitedTypeNode {
			new_uppers << u
		}
	}

	lowers_list := lowers
	if new_uppers.len == 0 && lowers_list.len == 0 {
		return none
	}

	mut bottom := ?MypyTypeNode(none)
	mut top := ?MypyTypeNode(none)

	if lowers_list.len > 0 {
		bottom = join_type_list(lowers_list)
	}

	for target in new_uppers {
		if top == none {
			top = target
		} else {
			top = meet_types(top or { target }, target)
		}
	}

	p_top := if t := top { get_proper_type(t) } else { MypyTypeNode(none) }
	p_bottom := if b := bottom { get_proper_type(b) } else { MypyTypeNode(none) }

	if p_top is AnyTypeNode || p_bottom is AnyTypeNode {
		source_any := if p_top is AnyTypeNode { top } else { bottom }
		if sa := source_any {
			if sa is AnyTypeNode {
				return AnyTypeNode{
					reason:     TypeOfAny.from_another_any
					source_any: sa
				}
			}
		}
		return source_any
	} else if bottom == none {
		if top != none {
			candidate = top
		} else {
			return none
		}
	} else if top == none {
		candidate = bottom
	} else {
		b := bottom or { return none }
		t := top or { return none }
		if is_subtype(b, t) {
			candidate = b
		} else {
			candidate = none
		}
	}
	return candidate
}

// transitive_closure находит транзитивное замыкание для ограничений
pub fn transitive_closure(tvars []TypeVarId, constraints []Constraint) (Graph, Bounds, Bounds) {
	mut uppers := map[TypeVarId]map[string]bool{}
	mut lowers := map[TypeVarId]map[string]bool{}
	mut graph := map[string]bool{}

	for tv in tvars {
		uppers[tv] = map[string]bool{}
		lowers[tv] = map[string]bool{}
		graph['${tv}:${tv}'] = true
	}

	mut remaining := constraints.clone()
	for remaining.len > 0 {
		c := remaining.pop()
		is_linear, target_id := find_linear(c)

		if is_linear {
			tid := target_id or { continue }
			if tid !in tvars {
				continue
			}

			mut lower := c.type_var
			mut upper := tid
			if c.op == supertype_of {
				lower, upper = upper, lower
			}

			key := '${lower}:${upper}'
			if key in graph {
				continue
			}

			for l in tvars {
				for u in tvars {
					if '${l}:${lower}' in graph && '${upper}:${u}' in graph {
						graph['${l}:${u}'] = true
					}
				}
			}
		} else if c.op == subtype_of {
			for l in tvars {
				if '${l}:${c.type_var}' in graph {
					target_key := c.target.str()
					uppers[l][target_key] = true
				}
			}
		} else {
			for u in tvars {
				if '${c.type_var}:${u}' in graph {
					target_key := c.target.str()
					lowers[u][target_key] = true
				}
			}
		}
	}
	return graph, lowers, uppers
}

// find_linear проверяет является ли ограничение линейным
pub fn find_linear(c Constraint) (bool, ?TypeVarId) {
	if c.target is TypeVarTypeNode {
		return true, c.target.id
	}
	return false, none
}

// compute_dependencies вычисляет зависимости между типовыми переменными
pub fn compute_dependencies(tvars []TypeVarId, graph Graph, lowers Bounds, uppers Bounds) map[TypeVarId][]TypeVarId {
	mut res := map[TypeVarId][]TypeVarId{}
	for tv in tvars {
		mut deps := []TypeVarId{}
		for lt in lowers[tv].keys() {
			deps << get_vars_from_str(lt, tvars)
		}
		for ut in uppers[tv].keys() {
			deps << get_vars_from_str(ut, tvars)
		}
		for other in tvars {
			if other == tv {
				continue
			}
			if '${tv}:${other}' in graph || '${other}:${tv}' in graph {
				deps << other
			}
		}
		res[tv] = deps
	}
	return res
}

// check_linear проверяет что в SCC только линейные ограничения
pub fn check_linear(scc []TypeVarId, lowers Bounds, uppers Bounds) bool {
	for tv in scc {
		for lt in lowers[tv].keys() {
			vars := get_vars_from_str(lt, scc)
			if vars.len > 0 {
				return false
			}
		}
		for ut in uppers[tv].keys() {
			vars := get_vars_from_str(ut, scc)
			if vars.len > 0 {
				return false
			}
		}
	}
	return true
}

// get_vars находит типовые переменные в целевом типе
pub fn get_vars(target MypyTypeNode, vars []TypeVarId) []TypeVarId {
	mut result := []TypeVarId{}
	// TODO: рекурсивный обход типа для поиска TypeVar
	return result
}

// Вспомогательные функции-заглушки
fn get_proper_type(t MypyTypeNode) MypyTypeNode {
	return t
}

fn is_subtype(left MypyTypeNode, right MypyTypeNode) bool {
	return true
}

fn join_type_list(types []MypyTypeNode) MypyTypeNode {
	if types.len == 0 {
		return UninhabitedTypeNode{}
	}
	return types[0]
}

fn meet_types(left MypyTypeNode, right MypyTypeNode) MypyTypeNode {
	return left
}

fn get_vars_from_str(s string, tvars []TypeVarId) []TypeVarId {
	// TODO: извлечь TypeVarId из строкового представления
	return []TypeVarId{}
}
