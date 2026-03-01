module main

struct ForwardClass {

}

fn test_fn() {
    x := ForwardClass(1)
}
fn new_ForwardClass(val int) ForwardClass {
    self.val := val
}
