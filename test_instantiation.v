module main

struct Strength {

}
struct Weakness {

}

fn new_Strength(value int, name int) Strength {
    self.value := value
    self.name := name
}

fn main() {
    s := new_Strength(0, 'required')
    w := Weakness{}
}