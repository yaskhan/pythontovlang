module builtins

pub type Any = bool | char | i8 | i16 | int | i64 | u8 | u16 | u32 | u64 | f32 | f64 | string | []u8 | none

pub struct object {}

pub fn list[T](items ...T) []T {
    return items
}

pub fn dict[K, V]() map[K]V {
    return map[K]V{}
}

pub fn hasattr(obj Any, name string) bool {
    // Runtime check placeholder
    return false
}

pub fn getattr(obj Any, name string, default Any) Any {
    // Runtime attribute access placeholder
    return default
}
