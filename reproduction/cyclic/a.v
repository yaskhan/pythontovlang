module cyclic

struct a__A {

}

fn new_a__A() a__A {
    mut self := a__A{}
    self.b = b__B()
    return self
}
