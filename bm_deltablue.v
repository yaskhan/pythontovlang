module main

type Any = bool | int | i64 | f64 | string | []u8
import div72.vexc
import strings

type OrderedCollection = []int
struct Strength {
    object
}
struct Constraint {
    object
}
struct UrnaryConstraint {
    Constraint
}
struct StayConstraint {
    UrnaryConstraint
}
struct EditConstraint {
    UrnaryConstraint
}
struct Direction {
    object
    NONE Final
    FORWARD Final
    BACKWARD Final
}
struct BinaryConstraint {
    Constraint
}
struct ScaleConstraint {
    BinaryConstraint
}
struct EqualityConstraint {
    BinaryConstraint
}
struct Variable {
    object
}
struct Planner {
    object
}
struct Plan {
    object
}
struct PyGeneratorInput {
    val Any
    is_exc bool
    exc_msg string
}
struct PyGenerator[T] {
mut:
    out chan ?T
    in_ chan PyGeneratorInput
    open bool = true
}

fn new_Strength(strength i64, name string) Strength {
    self.object.__init__()
    self.strength := strength
    self.name := name
}
// @classmethod
fn stronger(cls int, s1 Strength, s2 Strength) bool {
    return s1.strength < s2.strength
}
// @classmethod
fn weaker(cls int, s1 Strength, s2 Strength) bool {
    return s1.strength > s2.strength
}
// @classmethod
fn weakest_of(cls int, s1 Strength, s2 Strength) Strength {
    if cls.weaker(s1, s2) {
        return s1
    }
    return s2
}
// @classmethod
fn strongest(cls int, s1 Strength, s2 Strength) Strength {
    if cls.stronger(s1, s2) {
        return s1
    }
    return s2
}
fn (self Strength) next_weaker() Strength {
    strengths := map[string]int{0: WEAKEST, 1: WEAK_DEFAULT, 2: NORMAL, 3: STRONG_DEFAULT, 4: PREFERRED, 5: REQUIRED}
    return strengths[self.strength]
}
fn new_Constraint(strength Strength) Constraint {
    self.object.__init__()
    self.strength := strength
}
fn (self Constraint) add_constraint() none {
    // global planner
    self.add_to_graph()
    assert planner != none
    planner.incremental_add(self)
}
fn (self Constraint) satisfy(mark i64) ?Constraint {
    // global planner
    self.choose_method(mark)
    if !self.is_satisfied() {
        if self.strength == REQUIRED {
            println('Could not satisfy a required constraint!')
        }
        return none
    }
    self.mark_inputs(mark)
    out := self.output()
    overridden := out.determined_by
    if overridden != none {
        overridden.mark_unsatisfied()
    }
    out.determined_by := self
    assert planner != none
    if !planner.add_propagate(self, mark) {
        println('Cycle encountered')
    }
    out.mark := mark
    return overridden
}
fn (self Constraint) destroy_constraint() none {
    // global planner
    if self.is_satisfied() {
        assert planner != none
        planner.incremental_remove(self)
    } else {
        self.remove_from_graph()
    }
}
fn (self Constraint) is_input() bool {
    return false
}
// @abstractmethod
fn (self Constraint) add_to_graph() none {
    vexc.raise('NotImplementedError', '')
}
// @abstractmethod
fn (self Constraint) remove_from_graph() none {
    vexc.raise('NotImplementedError', '')
}
// @abstractmethod
fn (self Constraint) is_satisfied() bool {
    vexc.raise('NotImplementedError', '')
}
// @abstractmethod
fn (self Constraint) mark_unsatisfied() none {
    vexc.raise('NotImplementedError', '')
}
// @abstractmethod
fn (self Constraint) execute() none {
    vexc.raise('NotImplementedError', '')
}
// @abstractmethod
fn (self Constraint) output() Variable {
    vexc.raise('NotImplementedError', '')
}
// @abstractmethod
fn (self Constraint) recalculate() none {
    vexc.raise('NotImplementedError', '')
}
// @abstractmethod
fn (self Constraint) choose_method(mark i64) none {
    vexc.raise('NotImplementedError', '')
}
// @abstractmethod
fn (self Constraint) mark_inputs(mark i64) none {
    vexc.raise('NotImplementedError', '')
}
// @abstractmethod
fn (self Constraint) inputs_known(mark i64) bool {
    vexc.raise('NotImplementedError', '')
}
fn new_UrnaryConstraint(v Variable, strength Strength) UrnaryConstraint {
    self.Constraint.__init__(strength)
    self.my_output := v
    self.satisfied := false
    self.add_constraint()
}
fn (self UrnaryConstraint) add_to_graph() none {
    self.my_output.add_constraint(self)
    self.satisfied := false
}
fn (self UrnaryConstraint) choose_method(mark i64) none {
    if self.my_output.mark != mark && Strength.stronger(self.strength, self.my_output.walk_strength) {
        self.satisfied := true
    } else {
        self.satisfied := false
    }
}
fn (self UrnaryConstraint) is_satisfied() bool {
    return self.satisfied
}
fn (self UrnaryConstraint) mark_inputs(mark i64) none {
}
fn (self UrnaryConstraint) output() Variable {
    return self.my_output
}
fn (self UrnaryConstraint) recalculate() none {
    self.my_output.walk_strength := self.strength
    self.my_output.stay := !self.is_input()
    if self.my_output.stay {
        self.execute()
    }
}
fn (self UrnaryConstraint) mark_unsatisfied() none {
    self.satisfied := false
}
fn (self UrnaryConstraint) inputs_known(mark i64) bool {
    return true
}
fn (self UrnaryConstraint) remove_from_graph() none {
    if self.my_output != none {
        self.my_output.remove_constraint(self)
        self.satisfied := false
    }
}
fn new_StayConstraint(v Variable, string Strength) StayConstraint {
    self.UrnaryConstraint.__init__(v, string)
}
fn (self StayConstraint) execute() none {
}
fn new_EditConstraint(v Variable, string Strength) EditConstraint {
    self.UrnaryConstraint.__init__(v, string)
}
fn (self EditConstraint) is_input() bool {
    return true
}
fn (self EditConstraint) execute() none {
}
fn new_BinaryConstraint(v1 Variable, v2 Variable, strength Strength) BinaryConstraint {
    self.Constraint.__init__(strength)
    self.v1 := v1
    self.v2 := v2
    self.direction := Direction.NONE
    self.add_constraint()
}
fn (self BinaryConstraint) choose_method(mark i64) none {
    if self.v1.mark == mark {
        if self.v2.mark != mark && Strength.stronger(self.strength, self.v2.walk_strength) {
            self.direction := Direction.FORWARD
        } else {
            self.direction := Direction.BACKWARD
        }
    }
    if self.v2.mark == mark {
        if self.v1.mark != mark && Strength.stronger(self.strength, self.v1.walk_strength) {
            self.direction := Direction.BACKWARD
        } else {
            self.direction := Direction.NONE
        }
    }
    if Strength.weaker(self.v1.walk_strength, self.v2.walk_strength) {
        if Strength.stronger(self.strength, self.v1.walk_strength) {
            self.direction := Direction.BACKWARD
        } else {
            self.direction := Direction.NONE
        }
    } else {
        if Strength.stronger(self.strength, self.v2.walk_strength) {
            self.direction := Direction.FORWARD
        } else {
            self.direction := Direction.BACKWARD
        }
    }
}
fn (self BinaryConstraint) add_to_graph() none {
    self.v1.add_constraint(self)
    self.v2.add_constraint(self)
    self.direction := Direction.NONE
}
fn (self BinaryConstraint) is_satisfied() bool {
    return self.direction != Direction.NONE
}
fn (self BinaryConstraint) mark_inputs(mark i64) none {
    self.input().mark := mark
}
fn (self BinaryConstraint) input() Variable {
    if self.direction == Direction.FORWARD {
        return self.v1
    }
    return self.v2
}
fn (self BinaryConstraint) output() Variable {
    if self.direction == Direction.FORWARD {
        return self.v2
    }
    return self.v1
}
fn (self BinaryConstraint) recalculate() none {
    ihn := self.input()
    out := self.output()
    out.walk_strength := Strength.weakest_of(self.strength, ihn.walk_strength)
    out.stay := ihn.stay
    if out.stay {
        self.execute()
    }
}
fn (self BinaryConstraint) mark_unsatisfied() none {
    self.direction := Direction.NONE
}
fn (self BinaryConstraint) inputs_known(mark i64) bool {
    i := self.input()
    return i.mark == mark || i.stay || i.determined_by == none
}
fn (self BinaryConstraint) remove_from_graph() none {
    if self.v1 != none {
        self.v1.remove_constraint(self)
    }
    if self.v2 != none {
        self.v2.remove_constraint(self)
    }
    self.direction := Direction.NONE
}
fn new_ScaleConstraint(src Variable, scale Variable, offset Variable, dest Variable, strength Strength) ScaleConstraint {
    self.direction := Direction.NONE
    self.scale := scale
    self.offset := offset
    self.BinaryConstraint.__init__(src, dest, strength)
}
fn (self ScaleConstraint) add_to_graph() none {
    self.BinaryConstraint.add_to_graph()
    self.scale.add_constraint(self)
    self.offset.add_constraint(self)
}
fn (self ScaleConstraint) remove_from_graph() none {
    self.BinaryConstraint.remove_from_graph()
    if self.scale != none {
        self.scale.remove_constraint(self)
    }
    if self.offset != none {
        self.offset.remove_constraint(self)
    }
}
fn (self ScaleConstraint) mark_inputs(mark i64) none {
    self.BinaryConstraint.mark_inputs(mark)
    self.scale.mark := mark
    self.offset.mark := mark
}
fn (self ScaleConstraint) execute() none {
    if self.direction == Direction.FORWARD {
        self.v2.value := self.v1.value * self.scale.value + self.offset.value
    } else {
        self.v1.value := self.v2.value - self.offset.value / self.scale.value
    }
}
fn (self ScaleConstraint) recalculate() none {
    ihn := self.input()
    out := self.output()
    out.walk_strength := Strength.weakest_of(self.strength, ihn.walk_strength)
    out.stay := ihn.stay && self.scale.stay && self.offset.stay
    if out.stay {
        self.execute()
    }
}
fn (self EqualityConstraint) execute() none {
    self.output().value := self.input().value
}
fn new_Variable(name string, initial_value f64) Variable {
    self.object.__init__()
    self.name := name
    self.value := initial_value
    self.constraints := OrderedCollection()
    self.determined_by := none
    self.mark := 0
    self.walk_strength := WEAKEST
    self.stay := true
}
fn (self Variable) str() string {
    return py_string_format('<Variable: %s - %s>', self.name, self.value)
}
fn (self Variable) add_constraint(constraint Constraint) none {
    self.constraints.append(constraint)
}
fn (self Variable) remove_constraint(constraint Constraint) none {
    self.constraints.remove(constraint)
    if self.determined_by == constraint {
        self.determined_by := none
    }
}
fn new_Planner() Planner {
    self.object.__init__()
    self.current_mark := 0
}
fn (self Planner) incremental_add(constraint Constraint) none {
    mark := self.new_mark()
    overridden := constraint.satisfy(mark)
    for overridden != none {
        overridden := overridden.satisfy(mark)
    }
}
fn (self Planner) incremental_remove(constraint Constraint) none {
    out := constraint.output()
    constraint.mark_unsatisfied()
    constraint.remove_from_graph()
    unsatisfied := self.remove_propagate_from(out)
    strength := REQUIRED
    repeat := true
    for repeat {
        for u in unsatisfied {
            if u.strength == strength {
                self.incremental_add(u)
            }
            strength := strength.next_weaker()
        }
        repeat := strength != WEAKEST
    }
}
fn (self Planner) new_mark() i64 {
    self.current_mark += 1
    return self.current_mark
}
fn (self Planner) make_plan(sources []Constraint) Plan {
    mark := self.new_mark()
    plan := Plan()
    todo := sources
    for len(todo) {
        c := todo.pop(0)
        if c.output().mark != mark && c.inputs_known(mark) {
            plan.add_constraint(c)
            c.output().mark := mark
            self.add_constraints_consuming_to(c.output(), todo)
        }
    }
    return plan
}
fn (self Planner) extract_plan_from_constraints(constraints []Constraint) Plan {
    sources := OrderedCollection()
    for c in constraints {
        if c.is_input() && c.is_satisfied() {
            sources.append(c)
        }
    }
    return self.make_plan(sources)
}
fn (self Planner) add_propagate(c Constraint, mark i64) bool {
    todo := OrderedCollection()
    todo.append(c)
    for len(todo) {
        d := todo.pop(0)
        if d.output().mark == mark {
            self.incremental_remove(c)
            return false
        }
        d.recalculate()
        self.add_constraints_consuming_to(d.output(), todo)
    }
    return true
}
fn (self Planner) remove_propagate_from(out Variable) []Constraint {
    out.determined_by := none
    out.walk_strength := WEAKEST
    out.stay := true
    unsatisfied := OrderedCollection()
    todo := OrderedCollection()
    todo.append(out)
    for len(todo) {
        v := todo.pop(0)
        for c in v.constraints {
            if !c.is_satisfied() {
                unsatisfied.append(c)
            }
        }
        determining := v.determined_by
        for c in v.constraints {
            if c != determining && c.is_satisfied() {
                c.recalculate()
                todo.append(c.output())
            }
        }
    }
    return unsatisfied
}
fn (self Planner) add_constraints_consuming_to(v Variable, coll []Constraint) none {
    determining := v.determined_by
    cc := v.constraints
    for c in cc {
        if c != determining && c.is_satisfied() {
            coll.append(c)
        }
    }
}
fn new_Plan() Plan {
    self.object.__init__()
    self.v := []int{}
}
fn (self Plan) add_constraint(c Constraint) none {
    self.v.append(c)
}
fn (self Plan) __len__() int {
    return len(self.v)
}
fn (self Plan) __getitem__(index i64) Constraint {
    return self.v[index]
}
fn (self Plan) execute() none {
    for c in self.v {
        c.execute()
    }
}
fn chain_test(n i64) none {
    // This is the standard DeltaBlue benchmark. A long chain of equality
    //     constraints is constructed with a stay constraint on one end. An
    //     edit constraint is then added to the opposite end and the time is
    //     measured for adding and removing this constraint, and extracting
    //     and executing a constraint satisfaction plan. There are two cases.
    //     In case 1, the added constraint is stronger than the stay
    //     constraint and values must propagate down the entire length of the
    //     chain. In case 2, the added constraint is weaker than the stay
    //     constraint so it cannot be accomodated. The cost in this case is,
    //     of course, very low. Typical situations lie somewhere between these
    //     two extremes.
    // global planner
    planner := Planner()
    prev := none
    for i in 0..i64(n + 1) {
        name := py_string_format('v%s', i)
        v := Variable(name)
        if prev != none {
            EqualityConstraint(prev, v, REQUIRED)
        }
        if i == 0 {
            first := v
        }
        if i == n {
            last := v
        }
        prev := v
    }
    StayConstraint(last, STRONG_DEFAULT)
    edit := EditConstraint(first, PREFERRED)
    edits := OrderedCollection()
    edits.append(edit)
    plan := planner.extract_plan_from_constraints(edits)
    for j in 0..100 {
        first.value := float(j)
        plan.execute()
        if last.value != j {
            println('Chain test failed.')
        }
    }
}
fn projection_test(n int) none {
    // This test constructs a two sets of variables related to each
    //     other by a simple linear transformation (scale and offset). The
    //     time is measured to change a variable on either side of the
    //     mapping and to change the scale and offset factors.
    // global planner
    planner := Planner()
    scale := Variable('scale', 10)
    offset := Variable('offset', 1000)
    dests := OrderedCollection()
    for i in 0..n {
        src := Variable(py_string_format('src%s', i), i)
        dst := Variable(py_string_format('dst%s', i), i)
        dests.append(dst)
        StayConstraint(src, NORMAL)
        ScaleConstraint(src, scale, offset, dst, REQUIRED)
    }
    change(src, 17)
    if dst.value != 1170 {
        println('Projection 1 failed')
    }
    change(dst, 1050)
    assert src != none
    if src.value != 5 {
        println('Projection 2 failed')
    }
    change(scale, 5)
    for i in 0..n - 1 {
        if dests[i].value != i * 5 + 1000 {
            println('Projection 3 failed')
        }
    }
    change(offset, 2000)
    for i in 0..n - 1 {
        if dests[i].value != i * 5 + 2000 {
            println('Projection 4 failed')
        }
    }
}
fn change(v Variable, new_value f64) none {
    // global planner
    edit := EditConstraint(v, PREFERRED)
    edits := OrderedCollection()
    edits.append(edit)
    assert planner != none
    plan := planner.extract_plan_from_constraints(edits)
    for i in 0..10 {
        v.value := float(new_value)
        plan.execute()
    }
    edit.destroy_constraint()
}
fn run_delta_blue(n i64) none {
    chain_test(n)
    projection_test(n)
}
// @benchmark()
fn deltablue() none {
    n := 100
    for i in 0..10 {
        run_delta_blue(n)
    }
}
fn py_format(val Any, spec string) string {
    // Dynamic format specifier support is limited.
    // V does not support runtime format string construction easily.
    // We fallback to standard string representation.
    return '${val}'
}
fn (mut g PyGenerator[T]) next() ?T {
    if !g.open { return none }
    g.in_ <- PyGeneratorInput{val: 0} // Send dummy value
    res := <-g.out
    if res == none { g.open = false }
    return res
}
fn (mut g PyGenerator[T]) send(val Any) ?T {
    if !g.open { panic('StopIteration') }
    g.in_ <- PyGeneratorInput{val: val}
    res := <-g.out
    if res == none { g.open = false }
    return res
}
fn (mut g PyGenerator[T]) throw(msg string) ?T {
    if !g.open { panic('StopIteration') }
    g.in_ <- PyGeneratorInput{is_exc: true, exc_msg: msg}
    res := <-g.out
    if res == none { g.open = false }
    return res
}
fn (mut g PyGenerator[T]) close() {
    g.open = false
    g.in_.close()
    // g.out will be closed by the generator function loop when it detects in_ closed or panic
}
fn py_yield[T](ch_out chan ?T, ch_in chan PyGeneratorInput, val T) Any {
    ch_out <- val
    inp := <-ch_in
    if inp.is_exc {
        panic(inp.exc_msg)
    }
    return inp.val
}
fn py_bytes_format(fmt []u8, args Any) []u8 {
    // Simplistic implementation for b'%s' % b'val'
    // Converts bytes to string, formats, and converts back.
    // This is not efficient or correct for non-ASCII bytes but works for simple cases.
    fmt_str := fmt.bytestr()
    // TODO: handle args properly. V's string interpolation/formatting expects distinct args.
    // If args is []u8, treat as string.
    arg_str := if args is []u8 { args.bytestr() } else { '${args}' }

    // Manual substitution of %s
    // V does not have sprintf for runtime strings easily available in core without C interop.
    // Simple replace for %s
    res := fmt_str.replace('%s', arg_str)
    return res.bytes()
}
fn py_string_format(fmt string, args ...Any) string {
    mut res := strings.new_builder(fmt.len + 16)
    mut arg_idx := 0
    mut i := 0
    for i < fmt.len {
        if fmt[i] == `%` {
            if i + 1 < fmt.len {
                if fmt[i+1] == `%` {
                    res.write_string('%')
                    i += 2
                    continue
                }
                // Parse flags
                mut j := i + 1
                mut flag_zero := false
                mut flag_minus := false
                for j < fmt.len {
                    if fmt[j] == `0` {
                        flag_zero = true
                        j++
                    } else if fmt[j] == `-` {
                        flag_minus = true
                        j++
                    } else {
                        break
                    }
                }
                // Parse width
                mut width := 0
                mut width_str := ''
                for j < fmt.len && fmt[j].is_digit() {
                    width_str += fmt[j].ascii_str()
                    j++
                }
                if width_str != '' {
                    width = width_str.int()
                }
                // Parse precision
                mut precision := -1
                if j < fmt.len && fmt[j] == `.` {
                    j++
                    mut prec_str := ''
                    for j < fmt.len && fmt[j].is_digit() {
                        prec_str += fmt[j].ascii_str()
                        j++
                    }
                    if prec_str != '' {
                        precision = prec_str.int()
                    } else {
                        precision = 0
                    }
                }
                // Parse specifier
                if j < fmt.len {
                    spec := fmt[j]
                    if arg_idx >= args.len {
                        res.write_string('%')
                        i++
                        continue
                    }
                    arg := args[arg_idx]
                    arg_idx++

                    mut s_val := ''
                    if spec == `s` {
                        s_val = '${arg}'
                    } else if spec == `d` || spec == `i` || spec == `u` {
                        // Integer formatting
                        // If arg is float, cast to int?
                        // Using V interpolation format if possible, but we need dynamic width/prec
                        // Easier to manually format
                        val_int := '${arg}'.int()
                        s_val = '${val_int}'
                        if flag_zero && width > s_val.len && !flag_minus {
                             s_val = '0'.repeat(width - s_val.len) + s_val
                        }
                    } else if spec == `f` || spec == `F` {
                        // Float formatting
                        val_f := '${arg}'.f64()
                        prec := if precision >= 0 { precision } else { 6 }
                        s_val = '${val_f:.${prec}f}'
                    } else if spec == `e` || spec == `E` {
                        val_f := '${arg}'.f64()
                        prec := if precision >= 0 { precision } else { 6 }
                        s_val = '${val_f:.${prec}e}'
                    } else if spec == `g` || spec == `G` {
                        val_f := '${arg}'.f64()
                        // V doesn't strictly support %g in interpolation same as C, but close enough
                        s_val = '${val_f}'
                    } else if spec == `x` {
                        val_int := '${arg}'.int()
                        s_val = '${val_int:x}'
                    } else if spec == `X` {
                        val_int := '${arg}'.int()
                        s_val = '${val_int:X}'
                    } else if spec == `o` {
                        val_int := '${arg}'.int()
                        s_val = '${val_int:o}'
                    } else if spec == `r` {
                        s_val = '${arg}'
                    } else if spec == `c` {
                         val_int := '${arg}'.int()
                         s_val = u8(val_int).ascii_str()
                    } else {
                        s_val = '${arg}'
                    }

                    // Apply width/align
                    if width > s_val.len {
                        pad := width - s_val.len
                        if flag_minus {
                            s_val = s_val + ' '.repeat(pad)
                        } else if !flag_zero || spec == `s` {
                             // Zero padding handled for ints above if no minus
                             // For string or default, space pad
                             s_val = ' '.repeat(pad) + s_val
                        }
                    }
                    res.write_string(s_val)
                    i = j + 1
                    continue
                }
            }
        }
        res.write_u8(fmt[i])
        i++
    }
    return res.str()
}

fn main() {
    // deltablue.py
    // ============
    //
    // Ported for the PyPy project.
    // Contributed by Daniel Lindsley
    //
    // This implementation of the DeltaBlue benchmark was directly ported
    // from the `V8's source code`_, which was in turn derived
    // from the Smalltalk implementation by John Maloney and Mario
    // Wolczko. The original Javascript implementation was licensed under the GPL.
    //
    // It's been updated in places to be more idiomatic to Python (for loops over
    // collections, a couple magic methods, ``OrderedCollection`` being a list & things
    // altering those collections changed to the builtin methods) but largely retains
    // the layout & logic from the original. (Ugh.)
    //
    // .. _`V8's source code`: (https://github.com/v8/v8/blob/master/benchmarks/deltablue.js)
    planner := none
    REQUIRED := Strength(0, 'required')
    STRONG_PREFERRED := Strength(1, 'strongPreferred')
    PREFERRED := Strength(2, 'preferred')
    STRONG_DEFAULT := Strength(3, 'strongDefault')
    NORMAL := Strength(4, 'normal')
    WEAK_DEFAULT := Strength(5, 'weakDefault')
    WEAKEST := Strength(6, 'weakest')
}