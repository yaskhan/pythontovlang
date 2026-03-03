module models

struct user__User {

}

fn new_user__User(order reproduction.nested.models.order.Order) user__User {
    mut self := user__User{}
    self.order = order
    return self
}
