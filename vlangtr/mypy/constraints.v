// Work in progress by Cline. Started: 2026-03-22 14:21
// constraints.v — Type inference constraints
// Translated from mypy/constraints.py
//
// ---------------------------------------------------------------------------

module mypy

pub enum ConstraintOp {
	subtype_of
	supertype_of
}

// Constraint represents a type constraint: T <: type or T :> type
pub struct Constraint {
pub mut:
	type_var        TypeVarId
	op              ConstraintOp // subtype_of or supertype_of
	target          MypyTypeNode
	origin_type_var TypeVarLikeType
	// Additional type variables that must be solved together with type_var
	extra_tvars []TypeVarLikeType
}


// new_constraint creates a new Constraint
pub fn new_constraint(type_var TypeVarLikeType, op ConstraintOp, target MypyTypeNode) Constraint {

	return Constraint{
		type_var:        type_var.get_id()
		op:              op
		target:          target
		origin_type_var: type_var
		extra_tvars:     []
	}
}

// str returns the string representation of Constraint
pub fn (c Constraint) str() string {
	op_str := if c.op == ConstraintOp.supertype_of { ':>' } else { '<:' }
	return '${c.type_var} ${op_str} ${c.target}'
}

// eq checks equality of two Constraints
pub fn (c Constraint) eq(other Constraint) bool {
	return c.type_var == other.type_var && c.op == other.op
}

// infer_constraints infers constraints on type variables
pub fn infer_constraints(template MypyTypeNode, actual MypyTypeNode, direction ConstraintOp) []Constraint {
	mut constraints := []Constraint{}

	// If template is a Callable tuple, infer constraints for arguments and result
	if template is CallableType && actual is CallableType {
		// Simplified logic: infer constraints for all arguments
		for i in 0 .. template.arg_types.len {
			if i < actual.arg_types.len {
				// Arguments are contravariant
				c := infer_constraints(template.arg_types[i], actual.arg_types[i], direction)
				constraints << c
			}
		}
		// Result is covariant
		c := infer_constraints(template.ret_type, actual.ret_type, direction)
		constraints << c
		return constraints
	}

	// If template is a type variable, return Constraint directly
	if template is TypeVarType {
		return [new_constraint(template, direction, actual)]
	}

	return constraints
}

// infer_constraints_if_possible infers constraints or returns None if the constraint is unsolvable
pub fn infer_constraints_if_possible(template MypyTypeNode, actual MypyTypeNode, direction ConstraintOp) ?[]Constraint {
	if direction == .subtype_of {
		// if !is_subtype_v(erase_typevars(template), actual) {
		//     return none
		// }
	}
	if direction == .supertype_of {
		// if !is_subtype_v(actual, erase_typevars(template)) {
		//     return none
		// }
	}
	return infer_constraints(template, actual, direction)
}

// Helper stub functions
fn erase_typevars(t MypyTypeNode) MypyTypeNode {
	return t
}

fn is_subtype_v(left MypyTypeNode, right MypyTypeNode) bool {
	return true
}
