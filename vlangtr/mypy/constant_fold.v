// Work in progress by Cline. Started: 2026-03-22 14:29
// constant_fold.v — Constant folding of expressions
// Translated from mypy/constant_fold.py
//
// ---------------------------------------------------------------------------

module mypy

// ConstantValue — type of constant folding result
pub type ConstantValue = bool | f64 | i64 | string

// constant_fold_expr returns the constant value of an expression for supported operations
pub fn constant_fold_expr(expr Expression, cur_mod_id string) ?ConstantValue {
	if expr is IntExpr {
		return expr.value
	}
	if expr is StrExpr {
		return expr.value
	}
	if expr is FloatExpr {
		return expr.value
	}
	if expr is NameExpr {
		if expr.name == 'True' {
			return true
		}
		if expr.name == 'False' {
			return false
		}
		// Binding to final constants of the current module
		if sym_node := expr.node {
			if sym_node is Var {
				node := sym_node
				if node.is_final {
					parts := node.fullname.split('.')
					if parts.len >= 2 {
						mod_name := parts[..parts.len - 1].join('.')
						if mod_name == cur_mod_id {
							if fval := node.final_value {
								return constant_fold_expr(fval, cur_mod_id)
							}
						}
					}
				}
			}
		}
	}
	if expr is OpExpr {
		left := constant_fold_expr(expr.left, cur_mod_id) or { return none }
		right := constant_fold_expr(expr.right, cur_mod_id) or { return none }
		return constant_fold_binary_op(expr.op, left, right)
	}
	if expr is UnaryExpr {
		value := constant_fold_expr(expr.expr, cur_mod_id) or { return none }
		return constant_fold_unary_op(expr.op, value)
	}
	return none
}

// constant_fold_binary_op performs binary operation folding
pub fn constant_fold_binary_op(op string, left ConstantValue, right ConstantValue) ?ConstantValue {
	// Integer arithmetic
	if left is i64 && right is i64 {
		return constant_fold_binary_int_op(op, left, right)
	}

	// Float arithmetic and mixed int/float
	if left is f64 && right is f64 {
		return constant_fold_binary_float_op(op, left, right)
	}
	if left is f64 && right is i64 {
		return constant_fold_binary_float_op(op, left, f64(right))
	}
	if left is i64 && right is f64 {
		return constant_fold_binary_float_op(op, f64(left), right)
	}

	// String concatenation and multiplication
	if op == '+' && left is string && right is string {
		return left + right
	}
	if op == '*' && left is string && right is i64 {
		return left.repeat(int(right))
	}
	if op == '*' && left is i64 && right is string {
		return right.repeat(int(left))
	}

	return none
}

// constant_fold_binary_int_op performs binary operation folding for integers
pub fn constant_fold_binary_int_op(op string, left i64, right i64) ?ConstantValue {
	match op {
		'+' {
			return left + right
		}
		'-' {
			return left - right
		}
		'*' {
			return left * right
		}
		'/' {
			if right != 0 {
				return f64(left) / f64(right)
			}
		}
		'//' {
			if right != 0 {
				return left / right
			}
		}
		'%' {
			if right != 0 {
				return left % right
			}
		}
		'&' {
			return left & right
		}
		'|' {
			return left | right
		}
		'^' {
			return left ^ right
		}
		'<<' {
			if right >= 0 {
				return i64(u64(left) << u32(right))
			}
		}
		'>>' {
			if right >= 0 {
				return left >> right
			}
		}
		'**' {
			if right >= 0 {
				// i64 exponentiation
				mut result := i64(1)
				mut base := left
				mut exp := right
				for exp > 0 {
					if exp & 1 == 1 {
						result *= base
					}
					base *= base
					exp >>= 1
				}
				return result
			}
		}
		else {}
	}
	return none
}

// constant_fold_binary_float_op performs binary operation folding for float
pub fn constant_fold_binary_float_op(op string, left f64, right f64) ?ConstantValue {
	match op {
		'+' {
			return left + right
		}
		'-' {
			return left - right
		}
		'*' {
			return left * right
		}
		'/' {
			if right != 0.0 {
				return left / right
			}
		}
		'//' {
			if right != 0.0 {
				return f64(i64(left / right))
			}
		}
		'%' {
			if right != 0.0 {
				return fmod(left, right)
			}
		}
		'**' {
			if (left < 0.0 && right == f64(i64(right))) || left > 0.0 {
				return pow(left, right)
			}
		}
		else {}
	}
	return none
}

// constant_fold_unary_op performs unary operation folding
pub fn constant_fold_unary_op(op string, value ConstantValue) ?ConstantValue {
	if op == '-' && value is i64 {
		v := value as i64
		mut neg := -v
		return neg
	}
	if op == '-' && value is f64 {
		v := value as f64
		mut neg := -v
		return neg
	}
	if op == '~' && value is i64 {
		v := value as i64
		mut bit := ~v
		return bit
	}
	if op == '+' && value is i64 {
		v := value as i64
		mut out := v
		return out
	}
	if op == '+' && value is f64 {
		v := value as f64
		mut out := v
		return out
	}
	return none
}

fn pow(base f64, exp f64) f64 {
	mut result := 1.0
	mut b := base
	mut e := i64(exp)
	for e > 0 {
		if e & 1 == 1 {
			result *= b
		}
		b *= b
		e >>= 1
	}
	return result
}

fn fmod(x f64, y f64) f64 {
	return x - f64(i64(x / y)) * y
}
