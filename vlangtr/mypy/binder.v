// Tracking conditional variable types (Type Narrowing).

module mypy

pub struct CurrentType {
pub:
	typ             MypyTypeNode
	from_assignment bool
}

pub struct Frame {
pub:
	id int
pub mut:
	types                         map[string]CurrentType // Key is literal_hash
	unreachable                   bool
	conditional_frame             bool
	suppress_unreachable_warnings bool
}

pub struct ConditionalTypeBinder {
pub mut:
	next_id           int
	frames            []&Frame
	options_on_return [][]&Frame
	declarations      map[string]MypyTypeNode
	dependencies      map[string][]string
	last_pop_changed  bool
	try_frames        map[int]bool
	break_frames      []int
	continue_frames   []int
	bind_all          bool
	version           int
}

pub fn new_conditional_type_binder(options &Options) &ConditionalTypeBinder {
	mut b := &ConditionalTypeBinder{
		next_id:  1
		bind_all: options.allow_redefinition_new
	}
	b.frames << &Frame{
		id: b.get_id()
	}
	return b
}

pub fn (mut b ConditionalTypeBinder) get_id() int {
	b.next_id++
	return b.next_id
}

pub fn (mut b ConditionalTypeBinder) push_frame(conditional_frame bool) &Frame {
	f := &Frame{
		id:                b.get_id()
		conditional_frame: conditional_frame
	}
	b.frames << f
	b.options_on_return << []&Frame{}
	return f
}

pub fn (mut b ConditionalTypeBinder) put(node Expression, typ MypyTypeNode, from_assignment bool) {
	key := chk_literal_hash(node) or { return }
	if key !in b.declarations {
		b.declarations[key] = get_declaration(node) or {
			MypyTypeNode(AnyType{
				type_of_any: .unannotated
			})
		}
		// add dependencies
	}
	b.frames.last().types[key] = CurrentType{
		typ:             typ
		from_assignment: from_assignment
	}
	b.version++
}

pub fn (b &ConditionalTypeBinder) get(node Expression) ?MypyTypeNode {
	key := chk_literal_hash(node)?
	for i := b.frames.len - 1; i >= 0; i-- {
		if ct := b.frames[i].types[key] {
			return ct.typ
		}
	}
	return none
}

pub fn (mut b ConditionalTypeBinder) pop_frame(can_skip bool, fall_through int, discard bool) &Frame {
	if fall_through > 0 {
		b.allow_jump(-fall_through)
	}

	res := b.frames.pop()
	opts := b.options_on_return.pop()

	if discard {
		b.last_pop_changed = false
		return res
	}

	mut actual_opts := opts.clone()
	if can_skip {
		actual_opts.insert(0, b.frames.last())
	}

	b.last_pop_changed = b.update_from_options(actual_opts)
	return res
}

pub fn (mut b ConditionalTypeBinder) allow_jump(index int) {
	mut idx := index
	if idx < 0 {
		idx += b.options_on_return.len
	}
	// Simplified jump logic
	mut frame := &Frame{
		id: b.get_id()
	}
	for f in b.frames[idx + 1..] {
		for k, v in f.types {
			frame.types[k] = v
		}
		if f.unreachable {
			frame.unreachable = true
		}
	}
	b.options_on_return[idx] << frame
}

pub fn (mut b ConditionalTypeBinder) update_from_options(frames []&Frame) bool {
	// Simplified union logic
	if frames.len == 0 {
		return false
	}
	// ... logic to simplify union of types from different frames
	return false
}

pub fn (mut b ConditionalTypeBinder) unreachable() {
	b.frames.last().unreachable = true
}

pub fn (mut b ConditionalTypeBinder) handle_break() {
	// Simplified break logic
	b.unreachable()
}

pub fn (mut b ConditionalTypeBinder) handle_continue() {
	// Simplified continue logic
	b.unreachable()
}

// Helpers
fn get_declaration(node Expression) ?MypyTypeNode {
	if node is NameExpr {
		if sym := node.node {
			if sym is Var {
				return sym.type_
			}
		}
	} else if node is MemberExpr {
		if sym := node.node {
			if sym is Var {
				return sym.type_
			}
		}
	}
	return none
}

fn chk_literal_hash(node Expression) ?string {
	// Simplified hash for debugging/narrowing
	if node is NameExpr {
		return node.name
	}
	if node is MemberExpr {
		return chk_literal_hash(node.expr)? + '.' + node.name
	}
	return none
}
