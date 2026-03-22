// Я Codex работаю над этим файлом. Начало: 2026-03-22 22:12:00 +05:00
module mypy

pub struct TypeCheckerState {
pub mut:
	type_checker ?&TypeChecker
}

pub fn new_type_checker_state(type_checker ?&TypeChecker) TypeCheckerState {
	return TypeCheckerState{
		type_checker: type_checker
	}
}

pub fn (mut s TypeCheckerState) set(value &TypeChecker) ?&TypeChecker {
	saved := s.type_checker
	s.type_checker = value
	return saved
}

pub fn (mut s TypeCheckerState) restore(value ?&TypeChecker) {
	s.type_checker = value
}

// The translated checker state is currently process-local no-op state.
pub fn get_checker() ?&TypeChecker {
	return none
}

pub fn set_checker(checker &TypeChecker) ?&TypeChecker {
	_ = checker
	return none
}
