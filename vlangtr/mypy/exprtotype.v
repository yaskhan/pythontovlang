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
			return error('MemberExpr without fullname')
		}
		IndexExpr {
			base := expr_to_unanalyzed_type(expr.base_, options, allow_new_syntax, Expression(expr),
				false, lookup_qualified)!

			if base is UnboundType {
				mut ub := base as UnboundType
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
					arg_type := expr_to_unanalyzed_type(arg, options, allow_new_syntax,
						Expression(expr), true, lookup_qualified)!
					new_args << arg_type
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
		else {
			return error('Unsupported expression for type')
		}
	}
	return res
}
