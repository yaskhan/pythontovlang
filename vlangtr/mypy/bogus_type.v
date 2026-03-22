// Я Codex работаю над этим файлом. Начало: 2026-03-22 20:18:52 +05:00
module mypy

// mypy sets this to true only in mypyc compilations.
// In the default runtime mode it stays false.
pub const mypyc = false

// bogus is the default Bogus[T] behaviour: keep T unchanged.
// It mirrors `Bogus = FlexibleAlias[T, T]` from Python when mypyc is disabled.
pub fn bogus[T](value T) T {
	return value
}

// bogus_erased is a helper for places where we explicitly need to erase
// static type information to `any`, similar to `FlexibleAlias[T, Any]`.
pub fn bogus_erased[T](value T) any {
	return value
}
