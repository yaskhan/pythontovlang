// I, Cline, am working on this file. Started: 2026-03-22 19:57
// solve.v — Type inference constraint solving
// Translated from mypy/solve.py

module mypy

// Bounds — mapping TypeVarId -> set of types
pub type Bounds = map[TypeVarId]map[string]bool

// ConstraintGraph — set of edges between type variables
pub type ConstraintGraph = map[string]bool

// Solutions — mapping TypeVarId -> solution
pub type Solutions = map[TypeVarId]?MypyTypeNode

// solve_constraints solves type constraints
// Returns the best types for type variables
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
	for tv in vars {
		cmap[tv] = []Constraint{}
	}
	for tv in extra_vars {
		cmap[tv] = []Constraint{}
	}
	for con in constraints {
		if con.type_var in vars {
			cmap[con.type_var] << con
		} else if con.type_var in extra_vars {
			cmap[con.type_var] << con
		}
	}

	mut solutions := map[TypeVarId]?MypyTypeNode{}
	for tv, cs in cmap {
		if cs.len == 0 {
			continue
		}
		mut lowers_t := []MypyTypeNode{}
		mut uppers_t := []MypyTypeNode{}
		for c in cs {
			if c.op == ConstraintOp.supertype_of {
				lowers_t << c.target
			} else {
				uppers_t << c.target
			}
		}
		solution := solve_one(lowers_t, uppers_t)
		solutions[tv] = solution
	}

	mut res := []?MypyTypeNode{}
	for v in vars {
		if v in solutions {
			res << solutions[v]
		} else {
			if strict {
				res << ?MypyTypeNode(UninhabitedType{})
			} else {
				res << ?MypyTypeNode(AnyType{
					type_of_any: .special_form
				})
			}
		}
	}

	return res, []TypeVarLikeType{}
}

// solve_one solves constraints using meet of upper bounds and join of lower bounds
pub fn solve_one(lowers []MypyTypeNode, uppers []MypyTypeNode) ?MypyTypeNode {
	mut new_uppers := []MypyTypeNode{}
	for u in uppers {
		pu := get_proper_type(u)
		if pu !is UninhabitedType {
			new_uppers << u
		}
	}

	if new_uppers.len == 0 && lowers.len == 0 {
		return none
	}

	mut bottom := ?MypyTypeNode(none)
	mut top := ?MypyTypeNode(none)

	if lowers.len > 0 {
		bottom = ?MypyTypeNode(join_type_list(lowers))
	}

	for target in new_uppers {
		if t_ := top {
			top = ?MypyTypeNode(meet_types(t_, target))
		} else {
			top = ?MypyTypeNode(target)
		}
	}

	p_top := if t := top { get_proper_type(t) } else { MypyTypeNode(NoneType{}) }
	p_bottom := if b := bottom { get_proper_type(b) } else { MypyTypeNode(NoneType{}) }

	if p_top is AnyType || p_bottom is AnyType {
		source_any := if p_top is AnyType { top } else { bottom }
		if sa := source_any {
			if sa is AnyType {
				return AnyType{
					type_of_any: .from_another_any
					// source_any: sa
				}
			}
		}
		return source_any
	} else if bottom == none {
		if top != none {
			return top
		} else {
			return none
		}
	} else if top == none {
		return bottom
	} else {
		b := bottom or { return none }
		t := top or { return none }
		if is_subtype(b, t) {
			return b
		} else {
			return none
		}
	}
}

// transitive_closure finds transitive closure for constraints
pub fn transitive_closure(tvars []TypeVarId, constraints []Constraint) (ConstraintGraph, Bounds, Bounds) {
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
			// true as TypeVarId check removed

			mut lower := c.type_var
			mut upper := tid
			if c.op == ConstraintOp.supertype_of {
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
		} else if c.op == ConstraintOp.subtype_of {
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

// find_linear checks if a constraint is linear
pub fn find_linear(c Constraint) (bool, ?TypeVarId) {
	target := get_proper_type(c.target)
	if target is TypeVarType {
		return true, target.id
	}
	return false, none
}

// compute_dependencies computes dependencies between type variables
pub fn compute_dependencies(tvars []TypeVarId, graph ConstraintGraph, lowers Bounds, uppers Bounds) map[TypeVarId][]TypeVarId {
	mut res := map[TypeVarId][]TypeVarId{}
	for tv in tvars {
		mut deps := []TypeVarId{}
		for lt, _ in lowers[tv] {
			deps << get_vars_from_str(lt, tvars)
		}
		for ut, _ in uppers[tv] {
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

// check_linear checks that SCC contains only linear constraints
pub fn check_linear(scc []TypeVarId, lowers Bounds, uppers Bounds) bool {
	for tv in scc {
		for lt, _ in lowers[tv] {
			vars := get_vars_from_str(lt, scc)
			if vars.len > 0 {
				return false
			}
		}
		for ut, _ in uppers[tv] {
			vars := get_vars_from_str(ut, scc)
			if vars.len > 0 {
				return false
			}
		}
	}
	return true
}

// get_vars finds type variables in a target type
pub fn get_vars(target MypyTypeNode, vars []TypeVarId) []TypeVarId {
	mut result := []TypeVarId{}
	it_target := get_proper_type(target)
	match it_target {
		TypeVarType {
			if it_target.id in vars {
				result << it_target.id
			}
		}
		Instance {
			for arg in it_target.args {
				result << get_vars(arg, vars)
			}
		}
		CallableType {
			for at in it_target.arg_types {
				result << get_vars(at, vars)
			}
			result << get_vars(it_target.ret_type, vars)
		}
		TupleType {
			for item in it_target.items {
				result << get_vars(item, vars)
			}
		}
		UnionType {
			for item in it_target.items {
				result << get_vars(item, vars)
			}
		}
		else {}
	}
	return result
}

fn get_vars_from_str(s string, tvars []TypeVarId) []TypeVarId {
	mut result := []TypeVarId{}
	for tv in tvars {
		if s.contains(tv.str()) {
			result << tv
		}
	}
	return result
}
