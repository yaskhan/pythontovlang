module functions

import ast

fn scan_type_expr(expr ast.Expression, type_vars map[string]bool, mut found map[string]bool) {
	match expr {
		ast.Name {
			if expr.id in type_vars {
				found[expr.id] = true
			}
		}
		ast.Attribute {
			if expr.attr in type_vars {
				found[expr.attr] = true
			}
			scan_type_expr(expr.value, type_vars, mut found)
		}
		ast.Subscript {
			scan_type_expr(expr.value, type_vars, mut found)
			scan_type_expr(expr.slice, type_vars, mut found)
		}
		ast.Tuple {
			for item in expr.elements {
				scan_type_expr(item, type_vars, mut found)
			}
		}
		ast.List {
			for item in expr.elements {
				scan_type_expr(item, type_vars, mut found)
			}
		}
		ast.Set {
			for item in expr.elements {
				scan_type_expr(item, type_vars, mut found)
			}
		}
		ast.Dict {
			for key in expr.keys {
				scan_type_expr(key, type_vars, mut found)
			}
			for value in expr.values {
				scan_type_expr(value, type_vars, mut found)
			}
		}
		ast.Call {
			scan_type_expr(expr.func, type_vars, mut found)
			for arg in expr.args {
				scan_type_expr(arg, type_vars, mut found)
			}
			for kw in expr.keywords {
				scan_type_expr(kw.value, type_vars, mut found)
			}
		}
		ast.BinaryOp {
			scan_type_expr(expr.left, type_vars, mut found)
			scan_type_expr(expr.right, type_vars, mut found)
		}
		ast.UnaryOp {
			scan_type_expr(expr.operand, type_vars, mut found)
		}
		ast.Compare {
			scan_type_expr(expr.left, type_vars, mut found)
			for comparator in expr.comparators {
				scan_type_expr(comparator, type_vars, mut found)
			}
		}
		ast.IfExp {
			scan_type_expr(expr.test, type_vars, mut found)
			scan_type_expr(expr.body, type_vars, mut found)
			scan_type_expr(expr.orelse, type_vars, mut found)
		}
		ast.JoinedStr {
			for value in expr.values {
				scan_type_expr(value, type_vars, mut found)
			}
		}
		ast.FormattedValue {
			scan_type_expr(expr.value, type_vars, mut found)
			if format_spec := expr.format_spec {
				scan_type_expr(format_spec, type_vars, mut found)
			}
		}
		ast.ListComp {
			scan_type_expr(expr.elt, type_vars, mut found)
			for generator in expr.generators {
				scan_type_expr(generator.target, type_vars, mut found)
				scan_type_expr(generator.iter, type_vars, mut found)
				for cond in generator.ifs {
					scan_type_expr(cond, type_vars, mut found)
				}
			}
		}
		ast.SetComp {
			scan_type_expr(expr.elt, type_vars, mut found)
			for generator in expr.generators {
				scan_type_expr(generator.target, type_vars, mut found)
				scan_type_expr(generator.iter, type_vars, mut found)
				for cond in generator.ifs {
					scan_type_expr(cond, type_vars, mut found)
				}
			}
		}
		ast.DictComp {
			scan_type_expr(expr.key, type_vars, mut found)
			scan_type_expr(expr.value, type_vars, mut found)
			for generator in expr.generators {
				scan_type_expr(generator.target, type_vars, mut found)
				scan_type_expr(generator.iter, type_vars, mut found)
				for cond in generator.ifs {
					scan_type_expr(cond, type_vars, mut found)
				}
			}
		}
		ast.GeneratorExp {
			scan_type_expr(expr.elt, type_vars, mut found)
			for generator in expr.generators {
				scan_type_expr(generator.target, type_vars, mut found)
				scan_type_expr(generator.iter, type_vars, mut found)
				for cond in generator.ifs {
					scan_type_expr(cond, type_vars, mut found)
				}
			}
		}
		else {}
	}
}

// extract_implicit_generics extracts type vars used in annotations.
pub fn extract_implicit_generics(
	node &ast.FunctionDef,
	type_vars map[string]bool,
	constrained_typevars map[string]bool,
	current_class_generics []string,
	sanitize_fn fn (string, bool) string,
) []string {
	mut implicit_generics := map[string]bool{}

	mut all_type_vars := type_vars.clone()
	for cg in current_class_generics {
		all_type_vars[cg] = true
	}

	for param in node.args.posonlyargs {
		if annotation := param.annotation {
			scan_type_expr(annotation, all_type_vars, mut implicit_generics)
		}
	}
	for param in node.args.args {
		if annotation := param.annotation {
			scan_type_expr(annotation, all_type_vars, mut implicit_generics)
		}
	}
	for param in node.args.kwonlyargs {
		if annotation := param.annotation {
			scan_type_expr(annotation, all_type_vars, mut implicit_generics)
		}
	}
	if vararg := node.args.vararg {
		if annotation := vararg.annotation {
			scan_type_expr(annotation, all_type_vars, mut implicit_generics)
		}
	}
	if kwarg := node.args.kwarg {
		if annotation := kwarg.annotation {
			scan_type_expr(annotation, all_type_vars, mut implicit_generics)
		}
	}
	if returns := node.returns {
		scan_type_expr(returns, all_type_vars, mut implicit_generics)
	}

	mut filtered := map[string]bool{}
	for gen in implicit_generics.keys() {
		if gen !in constrained_typevars {
			filtered[gen] = true
		}
	}

/*
	for gen in current_class_generics {
		filtered.delete(gen)
	}
*/

	mut result := filtered.keys()
	result.sort()
	return result
}

// find_captured_vars returns closure captures. This implementation keeps the
// interface stable and can be expanded later without changing call sites.
pub fn find_captured_vars(
	node ast.ASTNode,
	scope_stack []map[string]bool,
	sanitize_fn fn (string, bool) string,
) []string {
	_ = node
	_ = scope_stack
	_ = sanitize_fn
	return []string{}
}

// is_empty_body checks whether a function body is effectively empty.
pub fn is_empty_body(body []ast.Statement) bool {
	for stmt in body {
		if stmt is ast.Pass {
			continue
		}
		if stmt is ast.Expr {
			expr_stmt := stmt
			if expr_stmt.value is ast.Constant {
				if expr_stmt.value.value == '...' || expr_stmt.value.value.starts_with("'''")
					|| expr_stmt.value.value.starts_with('"""') {
					continue
				}
			}
		}
		if stmt is ast.Raise {
			raise_stmt := stmt
			if exc := raise_stmt.exc {
				if exc is ast.Name {
					if exc.id == 'NotImplementedError' {
						continue
					}
				} else if exc is ast.Call {
					if exc.func is ast.Name && exc.func.id == 'NotImplementedError' {
						continue
					}
				} else {
					continue
				}
			}
		}
		return false
	}
	return true
}
