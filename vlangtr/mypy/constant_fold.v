// Я Cline работаю над этим файлом. Начало: 2026-03-22 14:29
// constant_fold.v — Constant folding of expressions
// Переведён из mypy/constant_fold.py
//
// ---------------------------------------------------------------------------

module mypy

// ConstantValue — тип результата свёртки констант
pub type ConstantValue = bool | f64 | i64 | string

// constant_fold_expr возвращает константное значение выражения для поддерживаемых операций
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
		// Привязка к финальным константам текущего модуля
		if expr.node is Var {
			node := expr.node
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

// constant_fold_binary_op выполняет свёртку бинарной операции
pub fn constant_fold_binary_op(op string, left ConstantValue, right ConstantValue) ?ConstantValue {
	// Целочисленная арифметика
	if left is i64 && right is i64 {
		return constant_fold_binary_int_op(op, left, right)
	}

	// Арифметика с float и смешанная int/float
	if left is f64 && right is f64 {
		return constant_fold_binary_float_op(op, left, right)
	}
	if left is f64 && right is i64 {
		return constant_fold_binary_float_op(op, left, f64(right))
	}
	if left is i64 && right is f64 {
		return constant_fold_binary_float_op(op, f64(left), right)
	}

	// Конкатенация и умножение строк
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

// constant_fold_binary_int_op выполняет свёртку бинарной операции для целых чисел
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
				return left << right
			}
		}
		'>>' {
			if right >= 0 {
				return left >> right
			}
		}
		'**' {
			if right >= 0 {
				// i64 возведение в степень
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

// constant_fold_binary_float_op выполняет свёртку бинарной операции для float
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

// constant_fold_unary_op выполняет свёртку унарной операции
pub fn constant_fold_unary_op(op string, value ConstantValue) ?ConstantValue {
	if op == '-' && value is i64 {
		return -value
	}
	if op == '-' && value is f64 {
		return -value
	}
	if op == '~' && value is i64 {
		return ~value
	}
	if op == '+' && value is i64 {
		return value
	}
	if op == '+' && value is f64 {
		return value
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
