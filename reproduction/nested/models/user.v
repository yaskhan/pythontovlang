module models

struct User {

}

fn new_User(order Order) User {
    mut self := User{}
    self.order = order
    return self
}
