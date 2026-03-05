module main

pub struct Data {
    value int | string
}

pub fn new_Data() Data {
    mut self := Data{}
    return self
}
pub fn test() {
    d := new_Data()
    d.value = 'hello'
    println('${d.value.upper()}')
    d.value = 123
    println('${d.value + 1}')
}

fn main() {
    // if __name__ == '__main__':
    test()
}