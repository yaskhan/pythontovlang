// exprtotype.v — Translate an Expression to a Type value
// Translated from mypy/exprtotype.py to V 0.5.x

module mypy

// expr_to_unanalyzed_type translates expression to type
// Result does not pass semantic analysis
pub fn expr_to_unanalyzed_type(expr Expression,
	options Options,
	allow_new_syntax bool,
	parent ?Expression,
	allow_unpack bool,
	lookup_qualified ?fn (string, Context) ?&SymbolTableNode) !MypyTypeNode {
	mut res := MypyTypeNode(AnyType{type_of_any: .from_error})
	match expr {
		NameExpr {
			name := expr.name
			if name == 'True' {
				res = MypyTypeNode(RawExpressionType{
					literal_value:  Any(true)
					base_type_name: 'builtins.bool'
					line:           expr.base.ctx.line
				})
			} else if name == 'False' {
				res = MypyTypeNode(RawExpressionType{
					literal_value:  Any(false)
					base_type_name: 'builtins.bool'
					line:           expr.base.ctx.line
				})
			} else {
				res = MypyTypeNode(UnboundType{
					name: name
					line: expr.base.ctx.line
				})
			}
		}
		MemberExpr {
			// Simple fallback for qualified names
			res = MypyTypeNode(UnboundType{
				name: expr.name
				line: expr.base.ctx.line
			})
		}
		IndexExpr {
			base_ := expr_to_unanalyzed_type(expr.base_, options, allow_new_syntax, Expression(expr),
				false, lookup_qualified)!

			if base_ is UnboundType {
				mut ub := base_ as UnboundType
				if ub.args.len > 0 {
					return error('Base already has args')
				}

				args := if expr.index is TupleExpr {
					(expr.index as TupleExpr).items
				} else {
					[expr.index]
				}

				mut new_args := []MypyTypeNode{}
				for arg in args {
					arg_type_node := expr_to_unanalyzed_type(arg, options, allow_new_syntax,
						Expression(expr), true, lookup_qualified)!
					new_args << arg_type_node
				}
				ub.args = new_args
				if new_args.len == 0 {
					ub.empty_tuple_index = true
				}
				res = MypyTypeNode(ub)
			} else {
				return error('Base is not UnboundType')
			}
		}
		OpExpr {
			if expr.op == '|' && ((options.python_version[0] >= 3 && options.python_version[1] >= 10)
				|| allow_new_syntax) {
				left := expr_to_unanalyzed_type(expr.left, options, allow_new_syntax,
					none, false, lookup_qualified)!

				right := expr_to_unanalyzed_type(expr.right, options, allow_new_syntax,
					none, false, lookup_qualified)!

				res = MypyTypeNode(UnionType{
					items: [left, right]
					line:  expr.base.ctx.line
				})
			} else {
				return error('OpExpr with unsupported op')
			}
		}
		CallExpr {
			if p := parent {
				if p !is ListExpr {
					return error('CallExpr not in ListExpr (callable args expected)')
				}
			} else {
				return error('CallExpr not in ListExpr (callable args expected)')
			}
			// Handle arg_name=type in Callable
			res = MypyTypeNode(AnyType{
				type_of_any: .special_form
			})
		}
		ListExpr {
			mut items := []MypyTypeNode{}
			for t in expr.items {
				item := expr_to_unanalyzed_type(t, options, allow_new_syntax, Expression(expr), true,
					lookup_qualified)!
				items << item
			}
			res = MypyTypeNode(TypeList{
				items: items
			})
		}
		StrExpr {
			res = MypyTypeNode(UnboundType{
				name: expr.value
				line: expr.base.ctx.line
			})
		}
		BytesExpr {
			res = MypyTypeNode(UnboundType{
				name: expr.value
				line: expr.base.ctx.line
			})
		}
		UnaryExpr {
			typ := expr_to_unanalyzed_type(expr.expr, options, allow_new_syntax, none,
				false, lookup_qualified)!

			if typ is RawExpressionType {
				mut re := typ as RawExpressionType
				if re.literal_value is int {
					val := re.literal_value as int
					if expr.op == '-' {
						mut neg := -val
						re.literal_value = Any(neg)
						return MypyTypeNode(re)
					} else if expr.op == '+' {
						return MypyTypeNode(re)
					}
				}
			}
			return error('UnaryExpr with unsupported type')
		}
		IntExpr {
			res = MypyTypeNode(RawExpressionType{
				literal_value:  Any(expr.value)
				base_type_name: 'builtins.int'
				line:           expr.base.ctx.line
			})
		}
		FloatExpr {
			res = MypyTypeNode(RawExpressionType{
				literal_value:  Any(expr.value)
				base_type_name: 'builtins.float'
				line:           expr.base.ctx.line
			})
		}
		ComplexExpr {
			res = MypyTypeNode(RawExpressionType{
				literal_value:  Any(expr.real)
				base_type_name: 'builtins.complex'
				line:           expr.base.ctx.line
			})
		}
		EllipsisExpr {
			res = MypyTypeNode(EllipsisType{})
		}
		StarExpr {
			if allow_unpack {
				inner := expr_to_unanalyzed_type(expr.expr, options, allow_new_syntax,
					none, false, lookup_qualified)!
				res = MypyTypeNode(UnpackType{
					type: inner
				})
			} else {
				return error('StarExpr without allow_unpack')
			}
		}
		DictExpr {
			if expr.items.len == 0 {
				return error('Empty DictExpr')
			}
			mut items := map[string]MypyTypeNode{}
			for item in expr.items {
				if key_expr := item.key {
					if key_expr is StrExpr {
						val_type := expr_to_unanalyzed_type(item.value, options, allow_new_syntax,
							Expression(expr), false, lookup_qualified)!
						items[key_expr.value] = val_type
					} else {
						return error('Dict key is not StrExpr')
					}
				}
			}
			res = MypyTypeNode(TypedDictType{
				items: items
				line:  expr.base.ctx.line
			})
		}
		else {
			return error('Unsupported expression for type')
		}
	}
	return res
}
