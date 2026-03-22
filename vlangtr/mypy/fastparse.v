// Work in progress by Cline. Started: 2026-03-22 15:48
// Version: 5234
// fastparse.v — Fast Python 3.10+ parser for V 0.5.x
// Translated from mypy/fastparse.py

module mypy

// JSONAny — simplified type for nodes from JSON/external parser
pub type JSONAny = string | int | bool | map[string]JSONAny | []JSONAny

// AST — simplified interface for external parser nodes
pub type AST = map[string]JSONAny

pub interface IAST {
	get_lineno() int
	get_col_offset() int
	get_end_lineno() int
	get_end_col_offset() int
}

// get_int extracts integer from AST node
fn get_int(a AST, key string) int {
	val := a[key] or { return 0 }
	match val {
		int { return val }
		else { return 0 }
	}
}

// get_string extracts string or none
fn get_string(a AST, key string) ?string {
	val := a[key] or { return none }
	match val {
		string { return val }
		else { return none }
	}
}

// get_list extracts list of nodes
fn get_list(a AST, key string) []AST {
	val := a[key] or { return []AST{} }
	match val {
		[]JSONAny {
			mut res := []AST{}
			for item in val {
				match item {
					map[string]JSONAny { res << AST(item) }
					else {}
				}
			}
			return res
		}
		else {
			return []AST{}
		}
	}
}

// ASTConverter converts external AST to internal mypy structures
pub struct ASTConverter {
pub mut:
	errors &Errors
}

// visit performs dispatch by node type
pub fn (mut conv ASTConverter) visit(n AST) ?MypyNode {
	kind := get_string(n, 'type') or { return none }
	match kind {
		'Module' { return MypyNode(conv.visit_module(n)) }
		'Name' { return MypyNode(conv.visit_name(n)) }
		'Expr' { return MypyNode(conv.visit_expr_stmt(n)) }
		'Assign' { return MypyNode(conv.visit_assign(n)) }
		'Return' { return MypyNode(conv.visit_return(n)) }
		else { return none }
	}
}

// visit_module converts Module
fn (mut conv ASTConverter) visit_module(n AST) Block {
	body := get_list(n, 'body')
	mut res := Block{
		body: conv.translate_stmt_list(body)
	}
	return conv.set_line(res, n) as Block
}

// visit_name converts Name
fn (mut conv ASTConverter) visit_name(n AST) NameExpr {
	mut e := NameExpr{
		name: get_string(n, 'id') or { '' }
	}
	return conv.set_line(e, n) as NameExpr
}

// visit_expr_stmt converts Expr (expression as statement)
fn (mut conv ASTConverter) visit_expr_stmt(n AST) ExpressionStmt {
	val := n['value'] or { return ExpressionStmt{} }
	match val {
		map[string]JSONAny {
			expr := conv.visit(val as map[string]JSONAny) or { return ExpressionStmt{} }
			if res := expr.as_expression() {
				return conv.set_line(ExpressionStmt{ expr: res }, n) as ExpressionStmt
			}
		}
		else {}
	}
	return ExpressionStmt{}
}

// visit_assign converts Assign
fn (mut conv ASTConverter) visit_assign(n AST) AssignmentStmt {
	targets := get_list(n, 'targets')
	val := n['value'] or { return AssignmentStmt{} }
	match val {
		map[string]JSONAny {
			rvalue_node := conv.visit(val as map[string]JSONAny) or { return AssignmentStmt{} }
			if rvalue := rvalue_node.as_expression() {
				mut res_targets := []Expression{}
				for t in targets {
					t_node := conv.visit(t) or { continue }
					if te := t_node.as_expression() {
						res_targets << te
					}
				}
				return conv.set_line(AssignmentStmt{ lvalues: res_targets, rvalue: rvalue },
					n) as AssignmentStmt
			}
		}
		else {}
	}
	return AssignmentStmt{}
}

// visit_return converts Return
fn (mut conv ASTConverter) visit_return(n AST) ReturnStmt {
	val := n['value'] or { return ReturnStmt{} }
	mut ret_expr := ?Expression(none)
	match val {
		map[string]JSONAny {
			node := conv.visit(val as map[string]JSONAny) or {
				return conv.set_line(ReturnStmt{ expr: none }, n) as ReturnStmt
			}
			ret_expr = node.as_expression()
		}
		else {
			ret_expr = none
		}
	}
	return conv.set_line(ReturnStmt{ expr: ret_expr }, n) as ReturnStmt
}

// set_line sets coordinates from AST
fn (mut conv ASTConverter) set_line(node MypyNode, n AST) MypyNode {
	mut res := node
	line := get_int(n, 'lineno')
	column := get_int(n, 'col_offset')
	match mut res {
		AssignmentStmt {
			res.base.ctx.line = line
			res.base.ctx.column = column
		}
		Block {
			res.base.ctx.line = line
			res.base.ctx.column = column
		}
		ExpressionStmt {
			res.base.ctx.line = line
			res.base.ctx.column = column
		}
		ReturnStmt {
			res.base.ctx.line = line
			res.base.ctx.column = column
		}
		NameExpr {
			res.base.ctx.line = line
			res.base.ctx.column = column
		}
		else {}
	}
	return res
}

// translate_expr_list converts list of expressions
pub fn (mut conv ASTConverter) translate_expr_list(l []AST) []Expression {
	mut res := []Expression{}
	for e in l {
		if node := conv.visit(e) {
			if expr := node.as_expression() {
				res << expr
			}
		}
	}
	return res
}

// translate_stmt_list converts list of statements
pub fn (mut conv ASTConverter) translate_stmt_list(l []AST) []Statement {
	mut res := []Statement{}
	for stmt in l {
		if node := conv.visit(stmt) {
			if s := node.as_statement() {
				res << s
			}
		}
	}
	return res
}
