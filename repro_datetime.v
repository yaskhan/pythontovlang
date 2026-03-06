module main

import time

pub fn test_datetime() {
    now := time.now()
    today := time.now()
    dt := time.new(time.Time{ year: 2023, month: 10, day: 27, hour: 12, minute: 0, second: 0 })
    d := time.new(time.Time{ year: 2023, month: 10, day: 27 })
    println('${now} ${today} ${dt} ${d}')
}
