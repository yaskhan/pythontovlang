module main

struct ImportedClass {

}

fn new_ImportedClass(val int) ImportedClass {
    self.val := val
}
fn test_fn() {
    x := new_ImportedClass(1)
}
