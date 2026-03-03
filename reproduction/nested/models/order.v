module models

struct Order {

}

fn new_Order(user User) Order {
    mut self := Order{}
    self.user = user
    return self
}
