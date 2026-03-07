module types

pub type Any = bool | char | i8 | i16 | int | i64 | u8 | u16 | u32 | u64 | f32 | f64 | string | []u8 | none

pub const NotImplemented = none

pub fn NotImplementedType() Any {
    return none
}

pub fn LambdaType() Any {
    return none
}
