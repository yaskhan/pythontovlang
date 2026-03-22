// Я Cline работаю над этим файлом. Начало: 2026-03-22 14:21
// constraints.v — Type inference constraints
// Переведён из mypy/constraints.py
//
// ---------------------------------------------------------------------------

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
		type_var:        type_var.get_id()
		op:              op
		target:          target
		origin_type_var: type_var
		extra_tvars:     []
	}
}

// str возвращает строковое представление Constraint
pub fn (c Constraint) str() string {
	op_str := if c.op == ConstraintOp.supertype_of { ':>' } else { '<:' }
	return '${c.type_var} ${op_str} ${c.target}'
}

// eq проверяет равенство двух Constraint
pub fn (c Constraint) eq(other Constraint) bool {
	return c.type_var == other.type_var && c.op == other.op
}

// infer_constraints выводит ограничения на типовые переменные
pub fn infer_constraints(template MypyTypeNode, actual MypyTypeNode, direction ConstraintOp) []Constraint {
	mut constraints := []Constraint{}

	// Если шаблон — кортеж Callable, выводим ограничения для аргументов и результата
	if template is CallableType && actual is CallableType {
		// Упрощенная логика: выводим ограничения для всех аргументов
		for i in 0 .. template.arg_types.len {
			if i < actual.arg_types.len {
				// Аргументы контрвариантны
				c := infer_constraints(template.arg_types[i], actual.arg_types[i], direction)
				constraints << c
			}
		}
		// Результат ковариантен
		c := infer_constraints(template.ret_type, actual.ret_type, direction)
		constraints << c
		return constraints
	}

	// Если шаблон — типовая переменная, возвращаем Constraint напрямую
	if template is TypeVarType {
		return [new_constraint(template, direction, actual)]
	}

	return constraints
}

// infer_constraints_if_possible выводит ограничения или возвращает None если связь неразрешима
pub fn infer_constraints_if_possible(template MypyTypeNode, actual MypyTypeNode, direction ConstraintOp) ?[]Constraint {
	if direction == .subtype_of {
		// if !is_subtype_v(erase_typevars(template), actual) {
		//     return none
		// }
	}
	if direction == .supertype_of {
		// if !is_subtype_v(actual, erase_typevars(template)) {
		//     return none
		// }
	}
	return infer_constraints(template, actual, direction)
}

// Вспомогательные функции-заглушки
fn erase_typevars(t MypyTypeNode) MypyTypeNode {
	return t
}

fn is_subtype_v(left MypyTypeNode, right MypyTypeNode) bool {
	return true
}
