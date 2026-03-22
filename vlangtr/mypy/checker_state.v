// checker_state.v — Global mutable state for type checker
// Translated from mypy/checker_state.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 17:00

module mypy

// TypeCheckerState — глобальное изменяемое состояние для type checker
pub struct TypeCheckerState {
pub mut:
	type_checker ?&TypeCheckerSharedApi
}

// new_type_checker_state создаёт новый TypeCheckerState
pub fn new_type_checker_state(type_checker ?&TypeCheckerSharedApi) TypeCheckerState {
	return TypeCheckerState{
		type_checker: type_checker
	}
}

// set устанавливает значение и возвращает предыдущее (для использования в defer)
pub fn (mut s TypeCheckerState) set(value &TypeCheckerSharedApi) ?&TypeCheckerSharedApi {
	saved := s.type_checker
	s.type_checker = value
	return saved
}

// restore восстанавливает предыдущее значение
pub fn (mut s TypeCheckerState) restore(value ?&TypeCheckerSharedApi) {
	s.type_checker = value
}

// checker_state — глобальное состояние
mut checker_state := TypeCheckerState{
	type_checker: none
}

// with_checker_state — context manager для установки состояния
// Использование:
//   saved := checker_state.set(&checker)
//   defer { checker_state.restore(saved) }
//   ... работа с checker ...

// get_checker возвращает текущий type checker
pub fn get_checker() ?&TypeCheckerSharedApi {
	return checker_state.type_checker
}

// set_checker устанавливает type checker
pub fn set_checker(checker &TypeCheckerSharedApi) ?&TypeCheckerSharedApi {
	return checker_state.set(checker)
}
