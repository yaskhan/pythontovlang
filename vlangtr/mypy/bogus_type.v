// Work in progress by Codex. Started: 2026-03-22 21:46:00 +05:00
module mypy

pub const mypyc = false

// Bogus mirrors the Python alias used to relax runtime typing.
// In V we model it as a transparent generic wrapper instead of `any`.
pub struct Bogus[T] {
pub:
	value T
}

pub fn bogus[T](val T) T {
	return val
}

pub fn bogus_erased[T](val T) T {
	return val
}
