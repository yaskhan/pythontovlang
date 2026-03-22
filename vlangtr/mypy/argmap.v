// argmap.v — Mapping actual arguments to formal parameters.
module mypy

pub fn map_actuals_to_formals(actual_kinds []ArgKind, actual_names []?string, formal_kinds []ArgKind, formal_names []?string, actual_arg_type fn (int) MypyTypeNode) [][]int {
	nformals := formal_kinds.len
	mut formal_to_actual := [][]int{len: nformals, init: []int{}}
	mut ambiguous_actual_kwargs := []int{}
	mut fi := 0

	for ai, actual_kind in actual_kinds {
		if actual_kind == ArgKind.arg_pos {
			if fi < nformals {
				if formal_kinds[fi] != ArgKind.arg_star && formal_kinds[fi] != ArgKind.arg_star2 {
					formal_to_actual[fi] << ai
					fi++
				} else if formal_kinds[fi] == ArgKind.arg_star {
					formal_to_actual[fi] << ai
				}
			}
		} else if actual_kind == ArgKind.arg_star {
			// Compute type for varargs...
			actualt := get_proper_type(actual_arg_type(ai))
			if actualt is TupleType {
				for _ in 0 .. actualt.items.len {
					if fi < nformals {
						if formal_kinds[fi] != ArgKind.arg_star2 {
							formal_to_actual[fi] << ai
						} else {
							break
						}

						if formal_kinds[fi] != ArgKind.arg_star {
							fi++
						}
					}
				}
			} else {
				for fi < nformals {
					if formal_kinds[fi] == ArgKind.arg_named || formal_kinds[fi] == ArgKind.arg_opt || formal_kinds[fi] == ArgKind.arg_named_opt {
						break
					} else {
						formal_to_actual[fi] << ai
					}
					if formal_kinds[fi] == ArgKind.arg_star {
						break
					}
					fi++
				}
			}
		} else if actual_kind == ArgKind.arg_named || actual_kind == ArgKind.arg_opt {
			name := actual_names[ai] or { '' }
			mut found_idx := -1
			for idx, fname in formal_names {
				if fname == name {
					found_idx = idx
					break
				}
			}

			if found_idx != -1 && formal_kinds[found_idx] != ArgKind.arg_star {
				formal_to_actual[found_idx] << ai
			} else {
				// Fallback to **kwargs
				mut star2_idx := -1
				for idx, fk in formal_kinds {
					if fk == ArgKind.arg_star2 {
						star2_idx = idx
						break
					}
				}
				if star2_idx != -1 {
					formal_to_actual[star2_idx] << ai
				}
			}
		} else if actual_kind == ArgKind.arg_star2 {
			actualt := get_proper_type(actual_arg_type(ai))
			if actualt is TypedDictType {
				// TypedDict **kwargs mapping (simplified)
			} else {
				ambiguous_actual_kwargs << ai
			}
		}
	}

	if ambiguous_actual_kwargs.len > 0 {
		mut unmatched_formals := []int{}
		for index in 0 .. nformals {
			fname := formal_names[index]
			if (fname != none && (formal_to_actual[index].len == 0 || actual_kinds[formal_to_actual[index][0]] == ArgKind.arg_star) && formal_kinds[index] != ArgKind.arg_star) || formal_kinds[index] == ArgKind.arg_star2 {
				unmatched_formals << index
			}
		}

		for ai in ambiguous_actual_kwargs {
			for index in unmatched_formals {
				formal_to_actual[index] << ai
			}
		}
	}

	return formal_to_actual
}

pub fn map_formals_to_actuals(actual_kinds []ArgKind, actual_names []?string, formal_kinds []ArgKind, formal_names []?string, actual_arg_type fn (int) MypyTypeNode) [][]int {
	formal_to_actual := map_actuals_to_formals(actual_kinds, actual_names, formal_kinds, formal_names, actual_arg_type)
	mut actual_to_formal := [][]int{len: actual_kinds.len, init: []int{}}

	for formal, actuals in formal_to_actual {
		for actual in actuals {
			actual_to_formal[actual] << formal
		}
	}

	return actual_to_formal
}
