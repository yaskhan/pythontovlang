// applytype.v — Apply generic type arguments to callable types
// Translated from mypy/applytype.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 18:30

module mypy

// get_target_type получает целевой тип для переменной типа
pub fn get_target_type(tvar TypeVarLikeType,
	typ MypyTypeNode,
	callable CallableType,
	context Context,
	skip_unsatisfied bool) ?MypyTypeNode {
	p_type := get_proper_type(typ)

	// Проверка на UninhabitedType и default
	if p_type is UninhabitedType && tvar.has_default() {
		return tvar.default
	}

	// ParamSpecType и TypeVarTupleType возвращаются как есть
	if tvar is ParamSpecType || tvar is TypeVarTupleType {
		return typ
	}

	// TypeVarType обработка
	if tvar !is TypeVarType {
		return none
	}

	tv := tvar as TypeVarType
	values := tv.values

	if values.len > 0 {
		if p_type is AnyType {
			return typ
		}

		// Проверка значений constraints
		mut matching := []MypyTypeNode{}
		for value in values {
			if is_subtype(typ, value) {
				matching << value
			}
		}

		if matching.len > 0 {
			mut best := matching[0]
			for m in matching[1..] {
				if is_subtype(m, best) {
					best = m
				}
			}
			return best
		}

		if skip_unsatisfied {
			return none
		}
		// report_incompatible_typevar_value(callable, typ, tv.name, context)
		return none
	} else {
		upper_bound := tv.upper_bound
		if tv.name == 'Self' {
			upper_bound = erase_typevars(upper_bound)
		}

		if !is_subtype(typ, upper_bound) {
			if skip_unsatisfied {
				return none
			}
			// report_incompatible_typevar_value(callable, typ, tv.name, context)
			return none
		}
	}

	return typ
}

// apply_generic_arguments применяет общие аргументы типа к callable type
pub fn apply_generic_arguments(callable CallableType,
	orig_types []?MypyTypeNode,
	context Context,
	skip_unsatisfied bool) CallableType {
	tvars := callable.variables
	assert len(orig_types) <= len(tvars)

	// Создаём map от id типа к целевому типу
	mut id_to_type := map[string]MypyTypeNode{}

	for i, tvar in tvars {
		if i >= orig_types.len {
			break
		}

		typ := orig_types[i]
		if typ == none {
			continue
		}

		target_type := get_target_type(tvar, typ or { MypyTypeNode(none) }, callable,
			context, skip_unsatisfied)

		if target_type != none {
			id_to_type[tvar.id.str()] = target_type or { MypyTypeNode(none) }
		}
	}

	// Проверка на ParamSpec
	param_spec := callable.param_spec()
	if param_spec != none {
		ps := param_spec or { return callable }
		nt := id_to_type[ps.id.str()]
		if nt != MypyTypeNode(none) {
			// ParamSpec expansion special case
			expanded := expand_type(callable, id_to_type)
			if expanded is CallableType {
				ct := expanded as CallableType
				mut remaining := []TypeVarLikeType{}
				for tv in tvars {
					if tv.id.str() !in id_to_type {
						remaining << tv
					}
				}
				ct.variables = remaining
				return ct
			}
		}
	}

	// Применение аргументов к типам аргументов
	var_arg := callable.var_arg()
	if var_arg != none && var_arg.typ is UnpackType {
		// Variadic types expansion
		expanded := expand_type(callable, id_to_type)
		if expanded is CallableType {
			ct := expanded as CallableType
			mut remaining := []TypeVarLikeType{}
			for tv in tvars {
				if tv.id.str() !in id_to_type {
					remaining << tv
				}
			}
			ct.variables = remaining
			return ct
		}
	}

	// Expand arg_types
	mut new_arg_types := []MypyTypeNode{}
	for at in callable.arg_types {
		new_arg_types << expand_type(at, id_to_type)
	}

	// Apply to type_guard
	mut type_guard := ?MypyTypeNode(none)
	if callable.type_guard != none {
		type_guard = expand_type(callable.type_guard or { MypyTypeNode(none) }, id_to_type)
	}

	// Apply to type_is
	mut type_is := ?MypyTypeNode(none)
	if callable.type_is != none {
		type_is = expand_type(callable.type_is or { MypyTypeNode(none) }, id_to_type)
	}

	// Remaining type vars
	mut remaining_tvars := []TypeVarLikeType{}
	for tv in tvars {
		if tv.id.str() in id_to_type {
			continue
		}
		if !tv.has_default() {
			remaining_tvars << tv
			continue
		}
		// Expand TypeVar default
		typ := expand_type(tv, id_to_type)
		if typ is TypeVarLikeType {
			remaining_tvars << typ
		}
	}

	// Expand ret_type
	ret_type := expand_type(callable.ret_type, id_to_type)

	return CallableType{
		arg_types:  new_arg_types
		ret_type:   ret_type
		variables:  remaining_tvars
		type_guard: type_guard
		type_is:    type_is
		line:       callable.line
		column:     callable.column
	}
}

// PolyTranslationError — исключение для ошибок poly translation
pub type PolyTranslationError = string

// apply_poly делает свободные переменные типа generic в типе
pub fn apply_poly(tp CallableType, poly_tvars []TypeVarLikeType) ?CallableType {
	translator := PolyTranslator{
		poly_tvars:   poly_tvars
		bound_tvars:  map[string]bool{}
		seen_aliases: map[string]bool{}
	}

	mut new_arg_types := []MypyTypeNode{}
	for t in tp.arg_types {
		result := translator.visit(t)
		if result == PolyTranslationError('') {
			return none
		}
		new_arg_types << result
	}

	ret_result := translator.visit(tp.ret_type)
	if ret_result == PolyTranslationError('') {
		return none
	}

	return tp.copy_modified(
		arg_types: new_arg_types
		ret_type:  ret_result
		variables: []TypeVarLikeType{}
	)
}

// PolyTranslator — переводчик для создания polymorphic типов
pub struct PolyTranslator {
pub mut:
	poly_tvars   []TypeVarLikeType
	bound_tvars  map[string]bool
	seen_aliases map[string]bool
}

// CallableOrParameters — sum-type для callable или parameters
pub type CallableOrParameters = CallableType | Parameters

// collect_vars собирает переменные типа из callable
pub fn (mut pt PolyTranslator) collect_vars(t CallableOrParameters) []TypeVarLikeType {
	mut found_vars := []TypeVarLikeType{}

	arg_types := match t {
		CallableType { t.arg_types }
		Parameters { t.arg_types }
		else { []MypyTypeNode{} }
	}

	for arg in arg_types {
		tvs := get_all_type_vars(arg)
		for tv in tvs {
			normalized := tv
			if tv is ParamSpecType {
				// normalized = tv.copy_modified(flavor: ParamSpecFlavor.BARE, prefix: Parameters{})
			}

			mut found := false
			for pv in pt.poly_tvars {
				if pv.id.str() == normalized.id.str() {
					found = true
					break
				}
			}

			if found && !pt.bound_tvars[normalized.id.str()] {
				found_vars << normalized
			}
		}
	}

	return remove_dups(found_vars)
}

// visit посещает тип и применяет translation
pub fn (mut pt PolyTranslator) visit(t MypyTypeNode) MypyTypeNode {
	return match t {
		CallableType {
			found_vars := pt.collect_vars(t)
			for fv in found_vars {
				pt.bound_tvars[fv.id.str()] = true
			}

			result := pt.visit_callable_type(t)

			for fv in found_vars {
				pt.bound_tvars[fv.id.str()] = false
			}

			result
		}
		TypeVarType {
			if pt.is_poly_tvar(t) {
				return PolyTranslationError('PolyTranslationError')
			}
			t
		}
		ParamSpecType {
			if pt.is_poly_tvar(t) {
				return PolyTranslationError('PolyTranslationError')
			}
			t
		}
		TypeVarTupleType {
			if pt.is_poly_tvar(t) {
				return PolyTranslationError('PolyTranslationError')
			}
			t
		}
		TypeAliasType {
			if t.args.len == 0 {
				return t
			}
			if !t.is_recursive {
				return pt.visit(get_proper_type(t))
			}
			return PolyTranslationError('PolyTranslationError')
		}
		Instance {
			pt.visit_instance(t)
		}
		else {
			t
		}
	}
}

// is_poly_tvar проверяет, является ли tvar poly tvar
pub fn (pt PolyTranslator) is_poly_tvar(t TypeVarLikeType) bool {
	for pv in pt.poly_tvars {
		if pv.id.str() == t.id.str() && !pt.bound_tvars[t.id.str()] {
			return true
		}
	}
	return false
}

// visit_callable_type посещает callable type
pub fn (mut pt PolyTranslator) visit_callable_type(t CallableType) CallableType {
	found_vars := pt.collect_vars(t)
	for fv in found_vars {
		pt.bound_tvars[fv.id.str()] = true
	}

	mut new_arg_types := []MypyTypeNode{}
	for arg in t.arg_types {
		new_arg_types << pt.visit(arg)
	}

	ret := pt.visit(t.ret_type)

	for fv in found_vars {
		pt.bound_tvars[fv.id.str()] = false
	}

	mut new_variables := t.variables
	for fv in found_vars {
		new_variables << fv
	}

	return t.copy_modified(
		arg_types: new_arg_types
		ret_type:  ret
		variables: new_variables
	)
}

// visit_instance посещает instance type
pub fn (mut pt PolyTranslator) visit_instance(t Instance) MypyTypeNode {
	if t.type.has_param_spec_type {
		// Special handling for param spec types
		// TODO: Implement full logic
	}

	if t.args.len > 0 && t.type.is_protocol && t.protocol_members == ['__call__'] {
		// Callback protocol handling
		// TODO: Implement full logic
	}

	return t
}

// get_all_type_vars получает все переменные типа из типа
pub fn get_all_type_vars(typ MypyTypeNode) []TypeVarLikeType {
	mut result := []TypeVarLikeType{}

	match typ {
		TypeVarType {
			result << typ
		}
		ParamSpecType {
			result << typ
		}
		TypeVarTupleType {
			result << typ
		}
		CallableType {
			for arg in typ.arg_types {
				for tv in get_all_type_vars(arg) {
					result << tv
				}
			}
			for tv in get_all_type_vars(typ.ret_type) {
				result << tv
			}
			for tv in typ.variables {
				result << tv
			}
		}
		Instance {
			for arg in typ.args {
				for tv in get_all_type_vars(arg) {
					result << tv
				}
			}
		}
		UnionType {
			for item in typ.items {
				for tv in get_all_type_vars(item) {
					result << tv
				}
			}
		}
		else {}
	}

	return result
}

// remove_dups удаляет дубликаты из списка TypeVarLikeType
pub fn remove_dups(items []TypeVarLikeType) []TypeVarLikeType {
	mut seen := map[string]bool{}
	mut result := []TypeVarLikeType{}

	for item in items {
		key := item.id.str()
		if key !in seen {
			seen[key] = true
			result << item
		}
	}

	return result
}

// erase_typevars удаляет переменные типа из типа
pub fn erase_typevars(typ MypyTypeNode) MypyTypeNode {
	// Упрощённая версия
	return typ
}

// expand_type расширяет тип с помощью map id_to_type
pub fn expand_type(typ any, id_to_type map[string]MypyTypeNode) MypyTypeNode {
	// Упрощённая версия — возвращает тип как есть
	return match typ {
		MypyTypeNode {
			typ
		}
		TypeVarLikeType {
			key := typ.id.str()
			if key in id_to_type {
				return id_to_type[key]
			}
			return MypyTypeNode(typ)
		}
		else {
			MypyTypeNode(none)
		}
	}
}

// is_subtype проверяет, является ли тип подтипом другого
pub fn is_subtype(sub MypyTypeNode, sup MypyTypeNode) bool {
	// Упрощённая версия
	return sub.type_str() == sup.type_str()
}

// get_proper_type получает proper type
pub fn get_proper_type(t MypyTypeNode) MypyTypeNode {
	return match t {
		TypeAliasType {
			if t.alias != none {
				// return t.alias.target
			}
			t
		}
		else {
			t
		}
	}
}
