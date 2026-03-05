module main

pub struct Data {
}

pub fn new_data() Data {
    mut self := Data{}
    self.value = 0
    return self
}
pub fn test() {
    d := new_data()
    d.value = 'hello'
    println('${d.value.upper()}')
    d.value = 123
    println('${d.value + 1}')
}

fn main() {
    // if __name__ == '__main__':
    test()
}