module models

struct order__Order {

}

fn new_order__Order(user reproduction.nested.models.user.User) order__Order {
    mut self := order__Order{}
    self.user = user
    return self
}
