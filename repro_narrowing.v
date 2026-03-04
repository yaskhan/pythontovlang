module main

pub fn test_loop_narrowing() none {
    data := map[string]int{'name': 1, 'age': 2}
    for key in ['name', 'age'] {
         := key.upper()
         = data[key]
    }
}
