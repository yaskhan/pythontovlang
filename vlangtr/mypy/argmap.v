// Я Cline работаю над этим файлом. Начало: 2026-03-22 21:33
// argmap.v — Utilities for mapping between actual and formal arguments
// Переведён из mypy/argmap.py

module mypy

// map_actuals_to_formals вычисляет маппинг между фактическими и формальными аргументами
// Возвращает список индексов фактических аргументов для каждого формального
pub fn map_actuals_to_formals(actual_kinds []ArgKind,
	actual_names ?[]string,
	formal_kinds []ArgKind,
	formal_names []string,
	actual_arg_type fn (int) MypyTypeNode) [][]int {
	nformals := formal_kinds.len
	mut formal_to_actual := [][]int{len: nformals, init: []int{}}
	mut ambiguous_actual_kwargs := []int{}
	mut fi := 0

	for ai, actual_kind in actual_kinds {
		if actual_kind == arg_pos {
			if fi < nformals {
				if formal_kinds[fi] != arg_star && formal_kinds[fi] != arg_star2 {
					formal_to_actual[fi] << ai
					fi++
				} else if formal_kinds[fi] == arg_star {
					formal_to_actual[fi] << ai
				}
			}
		} else if actual_kind == arg_star {
			actualt := get_proper_type(actual_arg_type(ai))
			if actualt is TupleTypeNode {
				for _ in 0 .. actualt.items.len {
					if fi < nformals {
						if formal_kinds[fi] != arg_star2 {
							formal_to_actual[fi] << ai
						} else {
							break
						}
						if formal_kinds[fi] != arg_star {
							fi++
						}
					}
				}
			} else {
				for fi < nformals {
					if formal_kinds[fi] == arg_star2 {
						break
					} else {
						formal_to_actual[fi] << ai
					}
					if formal_kinds[fi] == arg_star {
						break
					}
					fi++
				}
			}
		} else if actual_kind == arg_named {
			names := actual_names or { []string{} }
			if ai < names.len {
				name := names[ai]
				for idx, fname in formal_names {
					if fname == name && formal_kinds[idx] != arg_star {
						formal_to_actual[idx] << ai
						break
					}
				}
			}
			// Если имя не найдено, добавляем в **kwargs если есть
			for idx, fk in formal_kinds {
				if fk == arg_star2 {
					formal_to_actual[idx] << ai
					break
				}
			}
		} else {
			// ARG_STAR2
			actualt := get_proper_type(actual_arg_type(ai))
			if actualt is TypedDictTypeNode {
				for name in actualt.items.keys() {
					for idx, fname in formal_names {
						if fname == name {
							formal_to_actual[idx] << ai
							break
						}
					}
				}
			} else {
				ambiguous_actual_kwargs << ai
			}
		}
	}

	// Обрабатываем неоднозначные **kwargs
	if ambiguous_actual_kwargs.len > 0 {
		mut unmatched_formals := []int{}
		for idx in 0 .. nformals {
			if formal_to_actual[idx].len == 0 {
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

// map_formals_to_actuals вычисляет обратный маппинг
pub fn map_formals_to_actuals(actual_kinds []ArgKind,
	actual_names ?[]string,
	formal_kinds []ArgKind,
	formal_names []string,
	actual_arg_type fn (int) MypyTypeNode) [][]int {
	formal_to_actual := map_actuals_to_formals(actual_kinds, actual_names, formal_kinds,
		formal_names, actual_arg_type)

	// Обращаем маппинг
	mut actual_to_formal := [][]int{len: actual_kinds.len, init: []int{}}
	for formal, actuals in formal_to_actual {
		for actual in actuals {
			actual_to_formal[actual] << formal
		}
	}
	return actual_to_formal
}

// ArgTypeExpander — утилита для маппинга типов фактических аргументов на формальные
pub struct ArgTypeExpander {
pub mut:
	tuple_index int
	kwargs_used ?map[string]bool
}

// new_arg_type_expander создаёт новый ArgTypeExpander
pub fn new_arg_type_expander() ArgTypeExpander {
	return ArgTypeExpander{
		tuple_index: 0
		kwargs_used: none
	}
}

// expand_actual_type возвращает фактический тип для формального аргумента
pub fn (mut ae ArgTypeExpander) expand_actual_type(actual_type MypyTypeNode,
	actual_kind ArgKind,
	formal_name ?string,
	formal_kind ArgKind) MypyTypeNode {
	original := actual_type
	p_actual := get_proper_type(actual_type)

	if actual_kind == arg_star {
		if p_actual is TupleType {
			if ae.tuple_index >= p_actual.items.len {
				ae.tuple_index = 1
			} else {
				ae.tuple_index++
			}
			return p_actual.items[ae.tuple_index - 1]
		} else if p_actual is Instance {
			// Для Iterable[T] возвращаем T
			if p_actual.args.len > 0 {
				return p_actual.args[0]
			}
		}
		return AnyType{
			reason: TypeOfAny.from_error
		}
	} else if actual_kind == arg_star2 {
		if p_actual is TypedDictType {
			if ae.kwargs_used == none {
				ae.kwargs_used = map[string]bool{}
			}
			used := ae.kwargs_used or {
				map[string]bool{}
			}

			if formal_kind != arg_star2 && formal_name != none {
				name := formal_name or { '' }
				if name in p_actual.items {
					return p_actual.items[name]
				}
			}
			// Выбираем произвольный неиспользованный ключ
			for key in p_actual.items.keys() {
				if key !in used {
					used[key] = true
					ae.kwargs_used = used
					return p_actual.items[key]
				}
			}
		} else if p_actual is Instance {
			// Для Mapping[K, V] возвращаем V
			if p_actual.args.len > 1 {
				return p_actual.args[1]
			}
		}
		return AnyType{
			reason: TypeOfAny.from_error
		}
	}

	// Для других видов аргументов — 1:1 маппинг
	return original
}

// Вспомогательные функции-заглушки
fn get_proper_type(t MypyTypeNode) MypyTypeNode {
	return t
}
