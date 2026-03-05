module main



pub fn process_numbers(nums []Any) []int {
    // Process a list of numbers and strings.
    result := []int{}
    for num in nums {
        {
            defer {
                println('Processing complete for element.')
            }
        if C.try() {
            if num is str {
                result.append(int(num))
            } else {
                result.append(num)
            }
            vexc.end_try()
        } else {
            _exc_1 := vexc.get_curr_exc()
            if _exc_1.name == 'ValueError' {
                println('Failed to convert: ${num}')
            }
            else {
                vexc.raise(_exc_1.name, _exc_1.msg)
            }
        }
        }
    }
    return result
}
pub fn multiplier(n int) int {
    return n * factor
}
pub fn create_multiplier(factor int) {
    // Creates a closure.
    return multiplier
}
pub fn test() {
    mut data := []Any{cap: 4}
    data << 1
    data << '2'
    data << 'three'
    data << 4
    processed := process_numbers(data)
    times_two := create_multiplier(2)
    mut final_result := []int{}
    for x in processed {
        final_result << times_two(x)
    }
    println('${final_result}')
}

fn main() {
    // if __name__ == '__main__':
    test()
}