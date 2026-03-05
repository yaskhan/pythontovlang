module main

pub struct DatabaseHandler {
}
pub struct ApplicationService {
    DatabaseHandler
}

pub fn get_sorter() fn (int) int {
    return fn (x int) int { return x * -1 }
}
pub fn my_counter(ch_out chan int, ch_in chan PyGeneratorInput, n int) {
    _ := <-ch_in
    for i in 0..n {
        py_yield(ch_out, ch_in, i)
    }
    ch_out.close()
}
pub fn (self ApplicationService) log(message string) {
    println('Log: ${message}')
}
pub fn (self DatabaseHandler) save(data string) {
    println('Saving ${data} to DB')
}
pub fn (self ApplicationService) process() {
    self.log('Starting process')
    self.save('user_data')
    self.log('Process complete')
}
pub fn test() {
    sorter := get_sorter()
    println('${sorter(5)}')
    ch_1 := chan int{cap: 0}
    ch_in_1 := chan PyGeneratorInput{cap: 0}
    gen_1 := PyGenerator[int]{out: ch_1, in_: ch_in_1}
    spawn my_counter(ch_1, ch_in_1, 3)
    for num in gen_1 {
        println('${num}')
    }
    app := ApplicationService{}
    app.process()
}

fn main() {
    // if __name__ == '__main__':
    test()
}