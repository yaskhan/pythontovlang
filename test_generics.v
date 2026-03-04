struct Test[T] {
    val T
}

fn (t Test[T]) foo[T]() {
    println(t.val)
}

fn main() {
    t := Test[int]{val: 1}
    t.foo()
}
