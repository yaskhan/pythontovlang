module main

import asyncio

pub fn my_decorator(func int) {
    mut wrapper := fn [func] (args ...int, kwargs map[string]string) {
        println('Before call')
        result := func(...args, kwargs)
        println('After call')
        return result
    }
    return wrapper
}
// @my_decorator
pub fn greet(name string) {
    println('Hello, ${name}!')
    return name
}
pub fn fetch_data(id int) string {
    println('Fetching ${id}...')
    /* await */ asyncio.sleep(0.1)
    return 'Data_${id}'
}
pub fn main_async() {
    data := /* await */ fetch_data(42)
    println('${data}')
}
pub fn test() {
    greet('Alice')
    asyncio.run(main_async())
}

fn main() {
    // if __name__ == '__main__':
    test()
}