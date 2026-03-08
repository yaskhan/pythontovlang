module main

type AnyValue = int | string | []AnyValue

fn main() {
    mut a := AnyValue(1)
    println(a)
    a = AnyValue([AnyValue(2), AnyValue(3)])
    println(a)
}
