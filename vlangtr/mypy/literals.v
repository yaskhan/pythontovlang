// Я Qwen Code работаю над этим файлом. Начало: 2026-03-22 16:00
// Literals and literal_hash for mypy (literals.py)

module mypy

// [Note Literals and literal_hash]
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//
// Mypy uses the term "literal" to refer to any expression built out of:
// * Plain literal expressions, like `1` (integer, float, string, etc.)
// * Compound literal expressions, like `(lit1, lit2)` (list, dict, set, or tuple)
// * Operator expressions, like `lit1 + lit2`
// * Variable references, like `x`
// * Member references, like `lit.m`
// * Index expressions, like `lit[0]`
//
// A typical "literal" looks like `x[(i,j+1)].m`.
//
// An expression that is a literal has a `literal_hash`, with the following properties:
// * `literal_hash` is a Key: a tuple containing basic data types and possibly other Keys.
// * Two expressions have equal `literal_hash`es if and only if they are syntactically equal.
// * The elements of `literal_hash` that are tuples are exactly the subexpressions.

// Key is a hashable key for expressions
pub type Key = string

// Literal kinds (from nodes.py)
pub const literal_no = 0 // Not a literal

pub const literal_type = 1 // Variable reference

pub const literal_yes = 2 // Literal value

// literal_hash generates a hashable key for expressions supported by the binder.
// These allow using expressions as dictionary keys based on structural/value matching.
// Return none if the expression type is not supported (it cannot be narrowed).
// NOTE: This is not directly related to literal types.
pub fn literal_hash(e Expression) ?Key {
	return e.accept(_hasher)
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
			return left_lit < right_lit?
			left_lit:
			right_lit
		}
		MemberExpr, UnaryExpr, StarExpr {
			expr := match e {
				MemberExpr { e.expr }
				UnaryExpr { e.expr }
				StarExpr { e.expr }
				else { return literal_no }
			}
			return literal(expr)
		}
		AssignmentExpr {
			return literal(e.target)
		}
		IndexExpr {
			if literal(e.index) == literal_yes {
				return literal(e.base)
			} else {
				return literal_no
			}
		}
		NameExpr {
			if e.node is Var {
				v := e.node as Var
				if v.is_final && v.final_value != none {
					return literal_yes
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

// subkeys returns sub-keys from a key.
pub fn subkeys(key Key) []Key {
	// TODO: implement based on actual Key structure
	return []Key{}
}

// extract_var_from_literal_hash extracts Var from a key if it refers to a Var node.
pub fn extract_var_from_literal_hash(key Key) ?Var {
	// TODO: implement based on actual Key structure
	return none
}

// _Hasher is an expression visitor that generates literal hashes.
pub struct _Hasher {}

// visit_int_expr generates hash for integer expressions.
pub fn (h _Hasher) visit_int_expr(e &IntExpr) ?Key {
	return Key('Literal:${e.value}')
}

// visit_str_expr generates hash for string expressions.
pub fn (h _Hasher) visit_str_expr(e &StrExpr) ?Key {
	return Key('Literal:${e.value}')
}

// visit_bytes_expr generates hash for bytes expressions.
pub fn (h _Hasher) visit_bytes_expr(e &BytesExpr) ?Key {
	return Key('Literal:${e.value}')
}

// visit_float_expr generates hash for float expressions.
pub fn (h _Hasher) visit_float_expr(e &FloatExpr) ?Key {
	return Key('Literal:${e.value}')
}

// visit_complex_expr generates hash for complex expressions.
pub fn (h _Hasher) visit_complex_expr(e &ComplexExpr) ?Key {
	return Key('Literal:${e.value}')
}

// visit_star_expr generates hash for star expressions.
pub fn (h _Hasher) visit_star_expr(e &StarExpr) ?Key {
	hash := literal_hash(e.expr) or { return none }
	return Key('Star:${hash}')
}

// visit_name_expr generates hash for name expressions.
pub fn (h _Hasher) visit_name_expr(e &NameExpr) ?Key {
	if e.node is Var {
		v := e.node as Var
		if v.is_final && v.final_value != none {
			return Key('Literal:${v.final_value}')
		}
	}
	// N.B: We use the node itself as the key, and not the name,
	// because using the name causes issues when there is shadowing.
	return Key('Var:${e.node}')
}

// visit_member_expr generates hash for member expressions.
pub fn (h _Hasher) visit_member_expr(e &MemberExpr) ?Key {
	base_hash := literal_hash(e.expr) or { return none }
	return Key('Member:${base_hash}:${e.name}')
}

// visit_op_expr generates hash for binary operator expressions.
pub fn (h _Hasher) visit_op_expr(e &OpExpr) ?Key {
	left_hash := literal_hash(e.left) or { return none }
	right_hash := literal_hash(e.right) or { return none }
	return Key('Binary:${e.op}:${left_hash}:${right_hash}')
}

// visit_comparison_expr generates hash for comparison expressions.
pub fn (h _Hasher) visit_comparison_expr(e &ComparisonExpr) ?Key {
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

// visit_unary_expr generates hash for unary expressions.
pub fn (h _Hasher) visit_unary_expr(e &UnaryExpr) ?Key {
	expr_hash := literal_hash(e.expr) or { return none }
	return Key('Unary:${e.op}:${expr_hash}')
}

// seq_expr generates hash for sequence expressions (list, tuple, set).
pub fn (h _Hasher) seq_expr(items []Expression, name string) ?Key {
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

// visit_list_expr generates hash for list expressions.
pub fn (h _Hasher) visit_list_expr(e &ListExpr) ?Key {
	return _Hasher{}.seq_expr(e.items, 'List')
}

// visit_dict_expr generates hash for dict expressions.
pub fn (h _Hasher) visit_dict_expr(e &DictExpr) ?Key {
	for item in e.items {
		a := item[0]
		b := item[1]
		if a == none {
			return none
		}
		if literal(a) != literal_yes || literal(b) != literal_yes {
			return none
		}
	}

	mut parts := ['Dict']
	for item in e.items {
		a := item[0]
		b := item[1]
		a_hash := if a != none { literal_hash(a) or { 'none' } } else { 'none' }
		b_hash := literal_hash(b) or { return none }
		parts << '${a_hash}:${b_hash}'
	}
	return Key(parts.join(':'))
}

// visit_tuple_expr generates hash for tuple expressions.
pub fn (h _Hasher) visit_tuple_expr(e &TupleExpr) ?Key {
	return _Hasher{}.seq_expr(e.items, 'Tuple')
}

// visit_set_expr generates hash for set expressions.
pub fn (h _Hasher) visit_set_expr(e &SetExpr) ?Key {
	return _Hasher{}.seq_expr(e.items, 'Set')
}

// visit_index_expr generates hash for index expressions.
pub fn (h _Hasher) visit_index_expr(e &IndexExpr) ?Key {
	if literal(e.index) == literal_yes {
		base_hash := literal_hash(e.base) or { return none }
		index_hash := literal_hash(e.index) or { return none }
		return Key('Index:${base_hash}:${index_hash}')
	}
	return none
}

// visit_assignment_expr generates hash for assignment expressions.
pub fn (h _Hasher) visit_assignment_expr(e &AssignmentExpr) ?Key {
	return literal_hash(e.target)
}

// Expressions that cannot be hashed (return none)

pub fn (h _Hasher) visit_call_expr(e &CallExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_slice_expr(e &SliceExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_cast_expr(e &CastExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_type_form_expr(e &TypeFormExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_assert_type_expr(e &AssertTypeExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_conditional_expr(e &ConditionalExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_ellipsis(e &EllipsisExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_yield_from_expr(e &YieldFromExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_yield_expr(e &YieldExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_reveal_expr(e &RevealExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_super_expr(e &SuperExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_type_application(e &TypeApplication) ?Key {
	return none
}

pub fn (h _Hasher) visit_lambda_expr(e &LambdaExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_list_comprehension(e &ListComprehension) ?Key {
	return none
}

pub fn (h _Hasher) visit_set_comprehension(e &SetComprehension) ?Key {
	return none
}

pub fn (h _Hasher) visit_dictionary_comprehension(e &DictionaryComprehension) ?Key {
	return none
}

pub fn (h _Hasher) visit_generator_expr(e &GeneratorExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_type_var_expr(e &TypeVarExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_paramspec_expr(e &ParamSpecExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_type_var_tuple_expr(e &TypeVarTupleExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_type_alias_expr(e &TypeAliasExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_namedtuple_expr(e &NamedTupleExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_enum_call_expr(e &EnumCallExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_typeddict_expr(e &TypedDictExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_newtype_expr(e &NewTypeExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit__promote_expr(e &PromoteExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_await_expr(e &AwaitExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_template_str_expr(e &TemplateStrExpr) ?Key {
	return none
}

pub fn (h _Hasher) visit_temp_node(e &TempNode) ?Key {
	return none
}

// Global hasher instance
pub const _hasher = _Hasher{}
