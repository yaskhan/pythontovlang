module main



pub fn wrapper(kwargs map[string]string, args ...int) {
    println('Before call')
    result := func(...args, kwargs)
    println('After call')
    return result
}
pub fn my_decorator(func int) {
    return wrapper
}
// @my_decorator
pub fn greet(name string) {
    println('Hello, ${name}!')
    return name
}
pub fn fetch_data(id int) string {
    println('Fetching ${id}...')

    return 'Data_${id}'
}
pub fn main_async() {
    data := /* await */ fetch_data(42)
    println('${data}')
}
pub fn test() {
    greet('Alice')
    main_async()
}

fn main() {
    // if __name__ == '__main__':
    test()
}