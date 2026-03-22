// Я Codex работаю над этим файлом. Начало: 2026-03-22 14:45:16 +05:00
module mypy

// TypeCheckerState stores per-file mutable checker context.
pub struct TypeCheckerState {
pub mut:
	type_checker ?TypeCheckerSharedApi
}

// set_temporarily mirrors Python contextmanager logic:
// save current checker, set new value, run body, restore previous value.
pub fn (mut s TypeCheckerState) set_temporarily(value TypeCheckerSharedApi, body fn ()) {
	saved := s.type_checker
	s.type_checker = value
	body()
	s.type_checker = saved
}

__global checker_state = TypeCheckerState{
	type_checker: none
}
