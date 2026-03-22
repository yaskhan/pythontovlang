// exprtotype.v — Translate an Expression to a Type value
// Translated from mypy/exprtotype.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 18:00

module mypy

// TypeTranslationError — исключение для ошибок трансляции типа
pub type TypeTranslationError = string

// expr_to_unanalyzed_type транслирует выражение в тип
// Результат не проходит семантический анализ
pub fn expr_to_unanalyzed_type(expr Expression,
	options Options,
	allow_new_syntax bool,
	parent ?Expression,
	allow_unpack bool,
	lookup_qualified ?fn (string, Context) ?&SymbolTableNode) !MypyTypeNode {
	return match expr {
		NameExpr {
			name := expr.name
			if name == 'True' {
				RawExpressionType{
					literal_value:  any(true)
					base_type_name: 'builtins.bool'
					line:           expr.line
					column:         expr.column
				}
			} else if name == 'False' {
				RawExpressionType{
					literal_value:  any(false)
					base_type_name: 'builtins.bool'
					line:           expr.line
					column:         expr.column
				}
			} else {
				UnboundType{
					name:   name
					line:   expr.line
					column: expr.column
				}
			}
		}
		MemberExpr {
			// fullname := get_member_expr_fullname(expr)
			// if fullname {
			//     return UnboundType{fullname: fullname, line: expr.line, column: expr.column}
			// }
			return TypeTranslationError('MemberExpr without fullname')
		}
		IndexExpr {
			base := expr_to_unanalyzed_type(expr.base, options, allow_new_syntax, expr,
				false, lookup_qualified) or { return TypeTranslationError('Cannot translate base') }

			if base is UnboundType {
				mut ub := base as UnboundType
				if ub.args.len > 0 {
					return TypeTranslationError('Base already has args')
				}

				args := if expr.index is TupleExpr {
					(expr.index as TupleExpr).items
				} else {
					[expr.index]
				}

				// Проверка на Annotated[...]
				if expr.base is RefExpr {
					// TODO: lookup fullname
				}

				mut new_args := []MypyTypeNode{}
				for arg in args {
					arg_type := expr_to_unanalyzed_type(arg, options, allow_new_syntax,
						expr, true, lookup_qualified) or {
						return TypeTranslationError('Cannot translate arg')
					}
					new_args << arg_type
				}
				ub.args = new_args
				if new_args.len == 0 {
					ub.empty_tuple_index = true
				}
				return ub
			} else {
				return TypeTranslationError('Base is not UnboundType')
			}
		}
		OpExpr {
			if expr.op == '|' && (options.python_version[0] >= 3 && options.python_version[1] >= 10
				|| allow_new_syntax) {
				left := expr_to_unanalyzed_type(expr.left, options, allow_new_syntax,
					none, false, lookup_qualified) or {
					return TypeTranslationError('Cannot translate left')
				}

				right := expr_to_unanalyzed_type(expr.right, options, allow_new_syntax,
					none, false, lookup_qualified) or {
					return TypeTranslationError('Cannot translate right')
				}

				return UnionType{
					items:              [left, right]
					uses_pep604_syntax: true
					line:               expr.line
					column:             expr.column
				}
			} else {
				return TypeTranslationError('OpExpr with unsupported op')
			}
		}
		CallExpr {
			if parent !is ListExpr {
				return TypeTranslationError('CallExpr not in ListExpr')
			}
			// TODO: Handle CallableArgument
			return TypeTranslationError('CallExpr handling not fully implemented')
		}
		ListExpr {
			mut items := []MypyTypeNode{}
			for t in expr.items {
				item := expr_to_unanalyzed_type(t, options, allow_new_syntax, expr, true,
					lookup_qualified) or {
					return TypeTranslationError('Cannot translate list item')
				}
				items << item
			}
			return TypeList{
				items:  items
				line:   expr.line
				column: expr.column
			}
		}
		StrExpr {
			// return parse_type_string(expr.value, 'builtins.str', expr.line, expr.column)
			return UnboundType{
				name:   expr.value
				line:   expr.line
				column: expr.column
			}
		}
		BytesExpr {
			// return parse_type_string(expr.value, 'builtins.bytes', expr.line, expr.column)
			return UnboundType{
				name:   expr.value
				line:   expr.line
				column: expr.column
			}
		}
		UnaryExpr {
			typ := expr_to_unanalyzed_type(expr.expr, options, allow_new_syntax, none,
				false, lookup_qualified) or {
				return TypeTranslationError('Cannot translate unary expr')
			}

			if typ is RawExpressionType {
				mut re := typ as RawExpressionType
				if re.literal_value is int {
					val := re.literal_value as int
					if expr.op == '-' {
						re.literal_value = -val
						return re
					} else if expr.op == '+' {
						return re
					}
				}
			}
			return TypeTranslationError('UnaryExpr with unsupported type')
		}
		IntExpr {
			return RawExpressionType{
				literal_value:  any(expr.value)
				base_type_name: 'builtins.int'
				line:           expr.line
				column:         expr.column
			}
		}
		FloatExpr {
			// Floats are not valid parameters for RawExpressionType
			return RawExpressionType{
				literal_value:  any(none)
				base_type_name: 'builtins.float'
				line:           expr.line
				column:         expr.column
			}
		}
		ComplexExpr {
			// Complex numbers are not valid parameters for RawExpressionType
			return RawExpressionType{
				literal_value:  any(none)
				base_type_name: 'builtins.complex'
				line:           expr.line
				column:         expr.column
			}
		}
		EllipsisExpr {
			return EllipsisType{
				line:   expr.line
				column: expr.column
			}
		}
		StarExpr {
			if allow_unpack {
				inner := expr_to_unanalyzed_type(expr.expr, options, allow_new_syntax,
					none, false, lookup_qualified) or {
					return TypeTranslationError('Cannot translate star expr')
				}
				return UnpackType{
					type:             inner
					from_star_syntax: true
					line:             expr.line
					column:           expr.column
				}
			} else {
				return TypeTranslationError('StarExpr without allow_unpack')
			}
		}
		DictExpr {
			if expr.items.len == 0 {
				return TypeTranslationError('Empty DictExpr')
			}

			mut items := map[string]MypyTypeNode{}
			mut extra_items_from := []MypyTypeNode{}

			for item_name, value in expr.items {
				if item_name == none {
					extra := expr_to_unanalyzed_type(value, options, allow_new_syntax,
						expr, false, lookup_qualified) or {
						return TypeTranslationError('Cannot translate extra item')
					}
					extra_items_from << extra
					continue
				}

				name_expr := item_name or { return TypeTranslationError('Invalid item name') }
				if name_expr !is StrExpr {
					return TypeTranslationError('Dict key is not StrExpr')
				}

				se := name_expr as StrExpr
				val_type := expr_to_unanalyzed_type(value, options, allow_new_syntax,
					expr, false, lookup_qualified) or {
					return TypeTranslationError('Cannot translate dict value')
				}
				items[se.value] = val_type
			}

			return TypedDictType{
				items:  items
				line:   expr.line
				column: expr.column
				// TODO: extra_items_from
			}
		}
		else {
			return TypeTranslationError('Unsupported expression type')
		}
	}
}

// _extract_argument_name извлекает имя аргумента из выражения
pub fn _extract_argument_name(expr Expression) !string {
	return match expr {
		NameExpr {
			if expr.name == 'None' {
				'' // Пустая строка означает None
			} else {
				return TypeTranslationError('NameExpr is not None')
			}
		}
		StrExpr {
			expr.value
		}
		else {
			return TypeTranslationError('Unsupported expression for argument name')
		}
	}
}
