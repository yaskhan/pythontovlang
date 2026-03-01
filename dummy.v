module main

__global (
    planner Planner
)

const (
    REQUIRED = Strength(1, 2)
)

fn py_main() {
    // global planner
    planner := Planner()
}

fn main() {
    planner = none
}