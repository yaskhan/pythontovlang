// Я Cline работаю над этим файлом. Начало: 2026-03-22 14:21
// constraints.v — Type inference constraints
// Переведён из mypy/constraints.py

module mypy

pub enum ConstraintOp {
	subtype_of
	supertype_of
}

// Constraint представляет ограничение типа: T <: type или T :> type
pub struct Constraint {
pub mut:
	type_var        TypeVarId
	op              ConstraintOp // subtype_of или supertype_of
	target          MypyTypeNode
	origin_type_var TypeVarLikeType
	// Дополнительные типовые переменные, которые должны решаться вместе с type_var
	extra_tvars []TypeVarLikeType
}


// new_constraint создаёт новый Constraint
pub fn new_constraint(type_var TypeVarLikeType, op ConstraintOp, target MypyTypeNode) Constraint {

	return Constraint{
		type_var:        type_var.id
		op:              op
		target:          target
		origin_type_var: type_var
		extra_tvars:     []
	}
}

// str возвращает строковое представление Constraint
pub fn (c Constraint) str() string {
	op_str := if c.op == supertype_of { ':>' } else { '<:' }
	return '${c.type_var} ${op_str} ${c.target}'
}

// hash возвращает хеш Constraint
pub fn (c Constraint) hash() int {
	return hash('${c.type_var}${c.op}${c.target}')
}

// eq проверяет равенство двух Constraint
pub fn (c Constraint) eq(other Constraint) bool {
	return c.type_var == other.type_var && c.op == other.op && c.target.str() == other.target.str()
}

// infer_constraints_for_callable выводит ограничения типовых переменных для вызываемого типа
pub fn infer_constraints_for_callable(callee CallableType, arg_types []MypyTypeNode, arg_kinds []ArgKind, arg_names []string, formal_to_actual [][]int) []Constraint {
	mut constraints := []Constraint{}
	mut incomplete_star_mapping := false
	mut param_spec_arg_types := []MypyTypeNode{}
	mut param_spec_arg_names := []string{}
	mut param_spec_arg_kinds := []ArgKind{}

	for i, actuals in formal_to_actual {
		for actual in actuals {
			if actual == -1 && callee.arg_kinds[i] in [ArgKind.star, ArgKind.star2] {
				incomplete_star_mapping = true
				break
			}
		}
	}

	for i, actuals in formal_to_actual {
		for actual in actuals {
			if actual == -1 {
				continue
			}
			actual_arg_type := arg_types[actual] or { continue }
			if callee.arg_kinds[i] in [ArgKind.star, ArgKind.star2] {
				if !incomplete_star_mapping {
					param_spec_arg_types << actual_arg_type
					param_spec_arg_kinds << arg_kinds[actual]
					if arg_names.len > actual {
						param_spec_arg_names << arg_names[actual]
					}
				}
			} else {
				c := infer_constraints(callee.arg_types[i], actual_arg_type, supertype_of)
				constraints << c
			}
		}
	}

	return constraints
}

// infer_constraints выводит ограничения типов
// Сопоставляет шаблонный тип, который может содержать ссылки на типовые переменные,
// рекурсивно с типом, не содержащим (те же) ссылки на типовые переменные
pub fn infer_constraints(template MypyTypeNode, actual MypyTypeNode, direction int) []Constraint {
	// TODO: проверка рекурсивных типов через type_state
	// TODO: обработка has_recursive_types
	return infer_constraints_internal(template, actual, direction)
}

// infer_constraints_internal — внутренняя реализация вывода ограничений
fn infer_constraints_internal(template MypyTypeNode, actual MypyTypeNode, direction int) []Constraint {
	// Если шаблон — типовая переменная, возвращаем Constraint напрямую
	if template is TypeVarType {
		return [new_constraint(template, direction, actual)]
	}

	// TODO: полная реализация с ConstraintBuilderVisitor
	// Включает обработку Union, Instance, Callable, Tuple, TypedDict и т.д.
	return []
}

// infer_constraints_if_possible выводит ограничения или возвращает None если связь неразрешима
pub fn infer_constraints_if_possible(template MypyTypeNode, actual MypyTypeNode, direction int) ?[]Constraint {
	if direction == .subtype_of {
		if !is_subtype_v(erase_typevars(template), actual) {
			return none
		}
	}
	if direction == .supertype_of {
		if !is_subtype_v(actual, erase_typevars(template)) {
			return none
		}
	}

	if direction == .supertype_of && template is TypeVarType {
		if !is_subtype_v(actual, erase_typevars(template.upper_bound)) {
			return none
		}
	}

	return infer_constraints(template, actual, direction)
}

// select_trivial выбирает только списки ограничений против Any
pub fn select_trivial(options [][]Constraint) [][]Constraint {
	mut res := [][]Constraint{}
	for option in options {
		mut all_any := true
		for c in option {
			if !is_any_type(c.target) {
				all_any = false
				break
			}
		}
		if all_any {
			res << option
		}
	}
	return res
}

// merge_with_any преобразует цель ограничения в объединение с Any
pub fn merge_with_any(constraint Constraint) Constraint {
	target := constraint.target
	if is_union_with_any(target) {
		return constraint
	}
	any_type := create_any_type(TypeOfAny.implementation_artifact)
	new_target := make_union([target, any_type])
	return Constraint{
		type_var:        constraint.origin_type_var.id
		op:              constraint.op
		target:          new_target
		origin_type_var: constraint.origin_type_var
		extra_tvars:     constraint.extra_tvars
	}
}

// any_constraints выводит что можем из коллекции списков ограничений
pub fn any_constraints(options [][]Constraint, eager bool) []Constraint {
	mut valid_options := [][]Constraint{}

	for option in options {
		if eager {
			if option.len > 0 {
				valid_options << option
			}
		} else {
			valid_options << option
		}
	}

	if valid_options.len == 0 {
		return []
	}

	if valid_options.len == 1 {
		return valid_options[0]
	}

	// Проверяем, все ли опции одинаковы
	mut all_same := true
	for i := 1; i < valid_options.len; i++ {
		if !is_same_constraints(valid_options[0], valid_options[i]) {
			all_same = false
			break
		}
	}
	if all_same {
		return valid_options[0]
	}

	// Проверяем, все ли опции имеют одинаковую структуру
	mut all_similar := true
	for i := 1; i < valid_options.len; i++ {
		if !is_similar_constraints(valid_options[0], valid_options[i]) {
			all_similar = false
			break
		}
	}
	if all_similar {
		trivial_options := select_trivial(valid_options)
		if trivial_options.len > 0 && trivial_options.len < valid_options.len {
			mut merged_options := [][]Constraint{}
			for option in valid_options {
				if option in trivial_options {
					continue
				}
				mut merged := []Constraint{}
				for c in option {
					merged << merge_with_any(c)
				}
				merged_options << merged
			}
			return any_constraints(merged_options, eager)
		}
	}

	return []
}

// is_same_constraints проверяет равенство двух списков ограничений
pub fn is_same_constraints(x []Constraint, y []Constraint) bool {
	for c1 in x {
		mut found := false
		for c2 in y {
			if is_same_constraint(c1, c2) {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	for c1 in y {
		mut found := false
		for c2 in x {
			if is_same_constraint(c1, c2) {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}

// is_same_constraint проверяет равенство двух ограничений
pub fn is_same_constraint(c1 Constraint, c2 Constraint) bool {
	// Игнорируем направление при сравнении ограничений против Any
	skip_op_check := is_any_type(c1.target) && is_any_type(c2.target)
	return c1.type_var == c2.type_var && (c1.op == c2.op || skip_op_check)
		&& is_same_type(c1.target, c2.target)
}

// is_similar_constraints проверяет相似ность двух списков ограничений
pub fn is_similar_constraints(x []Constraint, y []Constraint) bool {
	return is_similar_constraints_impl(x, y) && is_similar_constraints_impl(y, x)
}

// is_similar_constraints_impl проверяет что каждый ограничение в первом списке имеет相似ный во втором
fn is_similar_constraints_impl(x []Constraint, y []Constraint) bool {
	for c1 in x {
		mut has_similar := false
		for c2 in y {
			skip_op_check := is_any_type(c1.target) || is_any_type(c2.target)
			if c1.type_var == c2.type_var && (c1.op == c2.op || skip_op_check) {
				has_similar = true
				break
			}
		}
		if !has_similar {
			return false
		}
	}
	return true
}

// neg_op инвертирует направление: subtype_of -> supertype_of и наоборот
pub fn neg_op(op int) int {
	if op == subtype_of {
		return supertype_of
	} else if op == supertype_of {
		return subtype_of
	} else {
		panic('Invalid operator ${op}')
	}
}

// filter_imprecise_kinds фильтрует неточные ограничения для ParamSpec
pub fn filter_imprecise_kinds(cs []Constraint) []Constraint {
	mut have_precise := map[string]bool{}
	for c in cs {
		if c.origin_type_var is ParamSpecType {
			if c.target is ParamSpecType {
				have_precise['${c.type_var}'] = true
			} else if c.target is ParametersType {
				if !c.target.imprecise_arg_kinds {
					have_precise['${c.type_var}'] = true
				}
			}
		}
	}

	mut new_cs := []Constraint{}
	for c in cs {
		if c.origin_type_var is ParamSpecType {
			if '${c.type_var}' !in have_precise {
				new_cs << c
			}
		} else {
			new_cs << c
		}
		if c.target is ParametersType {
			if !c.target.imprecise_arg_kinds {
				new_cs << c
			}
		}
	}
	return new_cs
}

// filter_satisfiable оставляет только разрешимые ограничения
pub fn filter_satisfiable(option []Constraint) ?[]Constraint {
	if option.len == 0 {
		return option
	}

	mut satisfiable := []Constraint{}
	for c in option {
		if c.origin_type_var is TypeVarType {
			if c.origin_type_var.values.len > 0 {
				for value in c.origin_type_var.values {
					if is_subtype(c.target, value) {
						satisfiable << c
						break
					}
				}
			} else if is_subtype(c.target, c.origin_type_var.upper_bound) {
				satisfiable << c
			}
		}
	}

	if satisfiable.len == 0 {
		return none
	}
	return satisfiable
}

// exclude_non_meta_vars исключает ограничения с не-meta переменными
pub fn exclude_non_meta_vars(option []Constraint) ?[]Constraint {
	if option.len == 0 {
		return option
	}

	mut result := []Constraint{}
	for c in option {
		if c.type_var.is_meta_var() {
			result << c
		}
	}

	if result.len == 0 {
		return none
	}
	return result
}

// Вспомогательные функции (заглушки для совместимости)
fn is_subtype_v(left MypyTypeNode, right MypyTypeNode) bool {
	return is_subtype(left, right, SubtypeContext{})
}


fn is_same_type(left MypyTypeNode, right MypyTypeNode) bool {
	// TODO: полная реализация
	return left.str() == right.str()
}

fn erase_typevars(tp MypyTypeNode) MypyTypeNode {
	// TODO: полная реализация из mypy/erasetype.v
	return tp
}

fn is_any_type(tp MypyTypeNode) bool {
	return tp is AnyType
}

fn is_union_with_any(tp MypyTypeNode) bool {
	// TODO: реализация
	return false
}

fn create_any_type(reason TypeOfAny) MypyTypeNode {
	// TODO: реализация
	return AnyType{
		reason: reason
	}
}

fn make_union(items []MypyTypeNode) MypyTypeNode {
	// TODO: реализация из mypy/types.v
	if items.len == 1 {
		return items[0]
	}
	return UnionType{
		items: items
	}
}
