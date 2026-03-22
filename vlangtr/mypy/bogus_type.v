// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 20:55
// bogus_type.v — A Bogus[T] type alias for marking when we subvert the type system
// Переведён из mypy/bogus_type.py

module mypy

// MYPYC — константа, указывающая на компиляцию через mypyc.
// В V версии мы по умолчанию устанавливаем её в false.
pub const mypyc = false

/*
We need this for compiling with mypyc, which inserts runtime
typechecks that cause problems when we subvert the type system. So
when compiling with mypyc, we turn those places into Any, while
keeping the types around for normal typechecks.
*/

// В V мы не можем использовать generic type aliases напрямую как в Python (Bogus[T] = T).
// Поэтому мы определяем Bogus как синоним для any (в духе mypyc рантайма)
// или просто предоставляем хелперы.

// Bogus — в V это будет просто псевдоним для any для совместимости с тем,
// как mypyc видит эти типы в скомпилированном виде.
pub type Bogus = any

// bogus — вспомогательная функция, которая "оборачивает" значение.
// В V она просто возвращает само значение как any.
pub fn bogus[T](val T) any {
	return val
}

// bogus_erased — возвращает значение как any.
pub fn bogus_erased(val any) any {
	return val
}
