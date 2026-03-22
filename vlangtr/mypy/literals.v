// Literals and literal_hash for mypy (literals.py)
module mypy

// Key is a hashable key for expressions
pub type Key = string

// Literal kinds (from nodes.py)
pub const literal_no = 0 // Not a literal
pub const literal_type = 1 // Variable reference
pub const literal_yes = 2 // Literal value

// literal_hash generates a hashable key for expressions supported by the binder.
pub fn literal_hash(e Expression) ?Key {
	h := Hasher{}
	match e {
		IntExpr { return h.visit_int_expr(&e) }
		StrExpr { return h.visit_str_expr(&e) }
		BytesExpr { return h.visit_bytes_expr(&e) }
		FloatExpr { return h.visit_float_expr(&e) }
		ComplexExpr { return h.visit_complex_expr(&e) }
		StarExpr { return h.visit_star_expr(&e) }
		NameExpr { return h.visit_name_expr(&e) }
		MemberExpr { return h.visit_member_expr(&e) }
		OpExpr { return h.visit_op_expr(&e) }
		ComparisonExpr { return h.visit_comparison_expr(&e) }
		UnaryExpr { return h.visit_unary_expr(&e) }
		ListExpr { return h.visit_list_expr(&e) }
		DictExpr { return h.visit_dict_expr(&e) }
		TupleExpr { return h.visit_tuple_expr(&e) }
		SetExpr { return h.visit_set_expr(&e) }
		IndexExpr { return h.visit_index_expr(&e) }
		AssignmentExpr { return h.visit_assignment_expr(&e) }
		else { return none }
	}
}

// literal returns the literal kind for an expression.
pub fn literal(e Expression) int {
	match e {
		ComparisonExpr {
			mut min_lit := literal_yes
			for o in e.operands {
				lit := literal(o)
				if lit < min_lit {
					min_lit = lit
				}
			}
			return min_lit
		}
		OpExpr {
			left_lit := literal(e.left)
			right_lit := literal(e.right)
			if left_lit < right_lit {
				return left_lit
			}
			return right_lit
		}
		MemberExpr {
			return literal(e.expr)
		}
		UnaryExpr {
			return literal(e.expr)
		}
		StarExpr {
			return literal(e.expr)
		}
		AssignmentExpr {
			return literal(e.target)
		}
		IndexExpr {
			if literal(e.index) == literal_yes {
				return literal(e.base_)
			} else {
				return literal_no
			}
		}
		NameExpr {
			if node := e.node {
				if node is Var {
					v := node as Var
					if v.is_final && v.final_value != none {
						return literal_yes
					}
				}
			}
			return literal_type
		}
		IntExpr, FloatExpr, ComplexExpr, StrExpr, BytesExpr {
			return literal_yes
		}
		else {}
	}

	if literal_hash(e) != none {
		return literal_yes
	}

	return literal_no
}

pub struct Hasher {}

pub fn (h Hasher) visit_int_expr(e &IntExpr) ?Key {
	return Key('Literal:${e.value}')
}

pub fn (h Hasher) visit_str_expr(e &StrExpr) ?Key {
	return Key('Literal:${e.value}')
}

pub fn (h Hasher) visit_bytes_expr(e &BytesExpr) ?Key {
	return Key('Literal:${e.value}')
}

pub fn (h Hasher) visit_float_expr(e &FloatExpr) ?Key {
	return Key('Literal:${e.value}')
}

pub fn (h Hasher) visit_complex_expr(e &ComplexExpr) ?Key {
	return Key('Literal:${e.real}:${e.imag}')
}

pub fn (h Hasher) visit_star_expr(e &StarExpr) ?Key {
	hash := literal_hash(e.expr) or { return none }
	return Key('Star:${hash}')
}

pub fn (h Hasher) visit_name_expr(e &NameExpr) ?Key {
	if node := e.node {
		if node is Var {
			v := node as Var
			if v.is_final && v.final_value != none {
				return Key('Literal:${v.final_value}')
			}
		}
	}
	return Key('Var:${e.fullname}')
}

pub fn (h Hasher) visit_member_expr(e &MemberExpr) ?Key {
	base_hash := literal_hash(e.expr) or { return none }
	return Key('Member:${base_hash}:${e.name}')
}

pub fn (h Hasher) visit_op_expr(e &OpExpr) ?Key {
	left_hash := literal_hash(e.left) or { return none }
	right_hash := literal_hash(e.right) or { return none }
	return Key('Binary:${e.op}:${left_hash}:${right_hash}')
}

pub fn (h Hasher) visit_comparison_expr(e &ComparisonExpr) ?Key {
	mut parts := ['Comparison']
	for op in e.operators {
		parts << op
	}
	for o in e.operands {
		hash := literal_hash(o) or { return none }
		parts << hash
	}
	return Key(parts.join(':'))
}

pub fn (h Hasher) visit_unary_expr(e &UnaryExpr) ?Key {
	expr_hash := literal_hash(e.expr) or { return none }
	return Key('Unary:${e.op}:${expr_hash}')
}

pub fn (h Hasher) seq_expr(items []Expression, name string) ?Key {
	for x in items {
		if literal(x) != literal_yes {
			return none
		}
	}

	mut parts := [name]
	for x in items {
		hash := literal_hash(x) or { return none }
		parts << hash
	}
	return Key(parts.join(':'))
}

pub fn (h Hasher) visit_list_expr(e &ListExpr) ?Key {
	return h.seq_expr(e.items, 'List')
}

pub fn (h Hasher) visit_dict_expr(e &DictExpr) ?Key {
	for item in e.items {
		if item.key == none {
			return none
		}
		if ka := item.key {
			if literal(ka) != literal_yes || literal(item.value) != literal_yes {
				return none
			}
		}
	}

	mut parts := ['Dict']
	for item in e.items {
		a_hash := if ka := item.key { literal_hash(ka) or { 'none' } } else { 'none' }
		b_hash := literal_hash(item.value) or { return none }
		parts << '${a_hash}:${b_hash}'
	}
	return Key(parts.join(':'))
}

pub fn (h Hasher) visit_tuple_expr(e &TupleExpr) ?Key {
	return h.seq_expr(e.items, 'Tuple')
}

pub fn (h Hasher) visit_set_expr(e &SetExpr) ?Key {
	return h.seq_expr(e.items, 'Set')
}

pub fn (h Hasher) visit_index_expr(e &IndexExpr) ?Key {
	if literal(e.index) == literal_yes {
		base_hash := literal_hash(e.base_) or { return none }
		index_hash := literal_hash(e.index) or { return none }
		return Key('Index:${base_hash}:${index_hash}')
	}
	return none
}

pub fn (h Hasher) visit_assignment_expr(e &AssignmentExpr) ?Key {
	return literal_hash(e.target)
}
