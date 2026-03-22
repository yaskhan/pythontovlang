// Work in progress by Codex. Started: 2026-03-22 21:52:00 +05:00
module mypy

pub fn map_actuals_to_formals(actual_kinds []ArgKind, actual_names ?[]string, formal_kinds []ArgKind, formal_names []string, actual_arg_type fn (int) MypyTypeNode) [][]int {
	nformals := formal_kinds.len
	mut formal_to_actual := [][]int{len: nformals, init: []int{}}
	mut ambiguous_actual_kwargs := []int{}
	mut fi := 0

	for ai, actual_kind in actual_kinds {
		match actual_kind {
			.arg_pos, .arg_opt {
				if fi < nformals {
					if !is_star_kind(formal_kinds[fi]) {
						formal_to_actual[fi] << ai
						fi++
					} else if formal_kinds[fi] == .arg_star {
						formal_to_actual[fi] << ai
					}
				}
			}
			.arg_star {
				actualt := get_proper_type(actual_arg_type(ai))
				if actualt is TupleType {
					for _ in 0 .. actualt.items.len {
						if fi >= nformals {
							break
						}
						if formal_kinds[fi] == .arg_star2 {
							break
						}
						formal_to_actual[fi] << ai
						if formal_kinds[fi] != .arg_star {
							fi++
						}
					}
				} else {
					for fi < nformals {
						if is_named_kind(formal_kinds[fi], true) {
							break
						}
						formal_to_actual[fi] << ai
						if formal_kinds[fi] == .arg_star {
							break
						}
						fi++
					}
				}
			}
			.arg_named, .arg_named_opt {
				names := actual_names or { []string{} }
				if ai < names.len {
					name := names[ai]
					if name in formal_names {
						formal_index := formal_names.index(name)
						if formal_index >= 0 && formal_kinds[formal_index] != .arg_star {
							formal_to_actual[formal_index] << ai
						}
					} else if star2_index := first_formal_index(formal_kinds, .arg_star2) {
						formal_to_actual[star2_index] << ai
					}
				}
			}
			.arg_star2 {
				actualt := get_proper_type(actual_arg_type(ai))
				_ = actualt
				ambiguous_actual_kwargs << ai
			}
		}
	}

	if ambiguous_actual_kwargs.len > 0 {
		mut unmatched_formals := []int{}
		for idx in 0 .. nformals {
			if (formal_names[idx] != '' && (formal_to_actual[idx].len == 0
				|| actual_kinds[formal_to_actual[idx][0]] == .arg_star)
				&& formal_kinds[idx] != .arg_star) || formal_kinds[idx] == .arg_star2 {
				unmatched_formals << idx
			}
		}
		for ai in ambiguous_actual_kwargs {
			for ffi in unmatched_formals {
				formal_to_actual[ffi] << ai
			}
		}
	}

	return formal_to_actual
}

pub fn map_formals_to_actuals(actual_kinds []ArgKind, actual_names ?[]string, formal_kinds []ArgKind, formal_names []string, actual_arg_type fn (int) MypyTypeNode) [][]int {
	formal_to_actual := map_actuals_to_formals(actual_kinds, actual_names, formal_kinds,
		formal_names, actual_arg_type)
	mut actual_to_formal := [][]int{len: actual_kinds.len, init: []int{}}
	for formal, actuals in formal_to_actual {
		for actual in actuals {
			actual_to_formal[actual] << formal
		}
	}
	return actual_to_formal
}

pub struct ArgTypeExpander {
pub mut:
	tuple_index int
	kwargs_used map[string]bool
}

pub fn new_arg_type_expander() ArgTypeExpander {
	return ArgTypeExpander{
		tuple_index: 0
		kwargs_used: map[string]bool{}
	}
}

pub fn (mut ae ArgTypeExpander) expand_actual_type(actual_type MypyTypeNode, actual_kind ArgKind, formal_name ?string, formal_kind ArgKind) MypyTypeNode {
	original := actual_type
	p_actual := get_proper_type(actual_type)

	match actual_kind {
		.arg_star {
			if p_actual is TupleType {
				if ae.tuple_index >= p_actual.items.len {
					ae.tuple_index = 1
				} else {
					ae.tuple_index++
				}
				return p_actual.items[ae.tuple_index - 1]
			}
			if p_actual is Instance && p_actual.args.len > 0 {
				return p_actual.args[0]
			}
			return AnyType{
				type_of_any: .from_error
			}
		}
		.arg_star2 {
			if p_actual is Instance && p_actual.args.len > 1 {
				return p_actual.args[1]
			}
			return AnyType{
				type_of_any: .from_error
			}
		}
		else {
			return original
		}
	}
}

fn is_star_kind(kind ArgKind) bool {
	return kind == .arg_star || kind == .arg_star2
}

fn is_named_kind(kind ArgKind, star bool) bool {
	if kind == .arg_named || kind == .arg_named_opt {
		return true
	}
	return star && kind == .arg_star2
}

fn first_formal_index(formal_kinds []ArgKind, target ArgKind) ?int {
	for idx, kind in formal_kinds {
		if kind == target {
			return idx
		}
	}
	return none
}
